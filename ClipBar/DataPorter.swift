import Foundation

enum DataPorter {
    struct ExportEnvelope: Codable {
        var version: Int
        var exportDate: Date
        var settings: Settings
        var history: [HistoryItem]
        var clips: [Clip]
        var excludedApps: [String]
        var blobs: [String: String] // filename -> base64

        struct Settings: Codable {
            var historyLimit: Int
            var pasteAsPlainText: Bool
        }
    }

    enum PorterError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let v):
                return "Unsupported export version: \(v). This file may have been created by a newer version of ClipBar."
            }
        }
    }

    static func buildExportData() throws -> Data {
        // Read history
        let historyURL = StoragePaths.base.appendingPathComponent("history.json")
        let history: [HistoryItem]
        if let data = try? Data(contentsOf: historyURL) {
            history = (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
        } else {
            history = []
        }

        // Read clips
        let clipsURL = StoragePaths.base.appendingPathComponent("clips.json")
        let clips: [Clip]
        if let data = try? Data(contentsOf: clipsURL) {
            clips = (try? JSONDecoder().decode([Clip].self, from: data)) ?? []
        } else {
            clips = []
        }

        // Read excluded apps
        let excludedURL = StoragePaths.base.appendingPathComponent("excluded_apps.json")
        let excludedApps: [String]
        if let data = try? Data(contentsOf: excludedURL) {
            excludedApps = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            excludedApps = []
        }

        // Read blobs
        var blobs: [String: String] = [:]
        let blobDir = StoragePaths.blobs
        if let files = try? FileManager.default.contentsOfDirectory(atPath: blobDir.path) {
            for file in files {
                let fileURL = blobDir.appendingPathComponent(file)
                if let data = try? Data(contentsOf: fileURL) {
                    blobs[file] = data.base64EncodedString()
                }
            }
        }

        // Read settings
        let defaults = UserDefaults.standard
        let settings = ExportEnvelope.Settings(
            historyLimit: defaults.integer(forKey: "historyLimit"),
            pasteAsPlainText: defaults.bool(forKey: "pasteAsPlainText")
        )

        let envelope = ExportEnvelope(
            version: 1,
            exportDate: Date(),
            settings: settings,
            history: history,
            clips: clips,
            excludedApps: excludedApps,
            blobs: blobs
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    struct ImportResult {
        var historyCount: Int
        var clipCount: Int
        var excludedAppCount: Int
        var imageCount: Int
        var pdfCount: Int
        var richTextCount: Int
    }

    @discardableResult
    static func importData(
        from url: URL,
        merge: Bool,
        historyStore: HistoryStore,
        clipStore: ClipStore,
        excludedAppsStore: ExcludedAppsStore,
        settingsStore: SettingsStore
    ) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        guard envelope.version == 1 else {
            throw PorterError.unsupportedVersion(envelope.version)
        }

        let blobDir = StoragePaths.blobs

        var newBlobFilenames: Set<String> = []

        if merge {
            // Write only new blobs (don't overwrite existing)
            for (filename, base64) in envelope.blobs {
                let dest = blobDir.appendingPathComponent(filename)
                if !FileManager.default.fileExists(atPath: dest.path),
                   let blobData = Data(base64Encoded: base64) {
                    try? blobData.write(to: dest, options: .atomic)
                    newBlobFilenames.insert(filename)
                }
            }
        } else {
            // Replace: clear existing blobs and write all
            if let existing = try? FileManager.default.contentsOfDirectory(atPath: blobDir.path) {
                for file in existing {
                    try? FileManager.default.removeItem(at: blobDir.appendingPathComponent(file))
                }
            }
            for (filename, base64) in envelope.blobs {
                if let blobData = Data(base64Encoded: base64) {
                    try? blobData.write(to: blobDir.appendingPathComponent(filename), options: .atomic)
                }
            }
        }

        // Restore files from blobs for fileURL items
        let filesDir = StoragePaths.base.appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
        if !merge {
            if let existing = try? FileManager.default.contentsOfDirectory(atPath: filesDir.path) {
                for file in existing {
                    try? FileManager.default.removeItem(at: filesDir.appendingPathComponent(file))
                }
            }
        }

        var importedHistory = envelope.history
        var importedClips = envelope.clips

        for i in importedHistory.indices {
            if importedHistory[i].contentType == .fileURL,
               let blob = importedHistory[i].blobFile,
               let blobData = BlobStorage.load(blob),
               let originalPath = importedHistory[i].fileURLs?.first {
                let filename = (originalPath as NSString).lastPathComponent
                let destURL = filesDir.appendingPathComponent(filename)
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    try? blobData.write(to: destURL, options: .atomic)
                }
                importedHistory[i].fileURLs = [destURL.path]
            }
        }

        for i in importedClips.indices {
            if importedClips[i].contentType == .fileURL,
               let blob = importedClips[i].blobFile,
               let blobData = BlobStorage.load(blob),
               let originalPath = importedClips[i].fileURLs?.first {
                let filename = (originalPath as NSString).lastPathComponent
                let destURL = filesDir.appendingPathComponent(filename)
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    try? blobData.write(to: destURL, options: .atomic)
                }
                importedClips[i].fileURLs = [destURL.path]
            }
        }

        let encoder = JSONEncoder()
        var newHistoryCount: Int
        var newClipCount: Int
        var newExcludedAppCount: Int

        if merge {
            // Merge: add items that don't already exist (by ID)
            let existingHistoryIDs = Set(historyStore.items.map(\.id))
            let newHistory = importedHistory.filter { !existingHistoryIDs.contains($0.id) }
            let mergedHistory = historyStore.items + newHistory
            let historyData = try encoder.encode(mergedHistory)
            try historyData.write(to: StoragePaths.base.appendingPathComponent("history.json"), options: .atomic)
            newHistoryCount = newHistory.count

            let existingClipIDs = Set(clipStore.clips.map(\.id))
            let newClips = importedClips.filter { !existingClipIDs.contains($0.id) }
            let mergedClips = clipStore.clips + newClips
            let clipsData = try encoder.encode(mergedClips)
            try clipsData.write(to: StoragePaths.base.appendingPathComponent("clips.json"), options: .atomic)
            newClipCount = newClips.count

            let newExcludedApps = excludedAppsStore.excludedBundleIDs.union(envelope.excludedApps)
            let excludedData = try encoder.encode(newExcludedApps)
            try excludedData.write(to: StoragePaths.base.appendingPathComponent("excluded_apps.json"), options: .atomic)
            newExcludedAppCount = newExcludedApps.count - excludedAppsStore.excludedBundleIDs.count
        } else {
            // Replace all
            let historyData = try encoder.encode(importedHistory)
            try historyData.write(to: StoragePaths.base.appendingPathComponent("history.json"), options: .atomic)
            newHistoryCount = importedHistory.count

            let clipsData = try encoder.encode(importedClips)
            try clipsData.write(to: StoragePaths.base.appendingPathComponent("clips.json"), options: .atomic)
            newClipCount = importedClips.count

            let excludedData = try encoder.encode(envelope.excludedApps)
            try excludedData.write(to: StoragePaths.base.appendingPathComponent("excluded_apps.json"), options: .atomic)
            newExcludedAppCount = envelope.excludedApps.count

            // Apply settings only on replace
            let defaults = UserDefaults.standard
            defaults.set(envelope.settings.historyLimit, forKey: "historyLimit")
            defaults.set(envelope.settings.pasteAsPlainText, forKey: "pasteAsPlainText")
            settingsStore.historyLimit = envelope.settings.historyLimit
            settingsStore.pasteAsPlainText = envelope.settings.pasteAsPlainText
        }

        // Reload all stores
        historyStore.load()
        clipStore.load()
        excludedAppsStore.load()

        var imageCount = 0
        var pdfCount = 0
        var richTextCount = 0
        let blobsToCount = merge ? newBlobFilenames : Set(envelope.blobs.keys)
        for filename in blobsToCount {
            let ext = (filename as NSString).pathExtension.lowercased()
            switch ext {
            case "png", "tiff":
                imageCount += 1
            case "pdf":
                pdfCount += 1
            case "rtf", "html":
                richTextCount += 1
            default:
                break
            }
        }

        return ImportResult(
            historyCount: newHistoryCount,
            clipCount: newClipCount,
            excludedAppCount: newExcludedAppCount,
            imageCount: imageCount,
            pdfCount: pdfCount,
            richTextCount: richTextCount
        )
    }
}

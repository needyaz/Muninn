import Foundation

enum DataPorter {
    struct ExportEnvelope: Codable {
        var version: Int
        var exportDate: Date
        var settings: Settings
        var history: [HistoryItem]
        var clips: [Clip]
        var excludedApps: [String]
        var excludedTypes: [String]?
        var blobs: [String: String] // filename -> base64

        struct Settings: Codable {
            var historyLimit: Int
            var pasteAsPlainText: Bool
            var enableStats: Bool?
            var enableRichPreviews: Bool?
            var captureSound: String?
            var captureScreenshots: Bool?
            var enableOCR: Bool?
            var enableQRDetection: Bool?
            var enablePDFTextExtraction: Bool?
            var hasSeenOnboarding: Bool?
            var popoverHeight: Double?
            var popoverWidth: Double?
            var sensitiveHandling: String?
        }
    }

    enum PorterError: LocalizedError {
        case unsupportedVersion(Int)
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let v):
                return "Unsupported export version: \(v). This file may have been created by a newer version of Muninn."
            case .fileTooLarge:
                return "This file is too large to be a Muninn export."
            }
        }
    }

    /// Imports are read fully into memory, so refuse anything implausibly large.
    static let maxImportBytes = 1_000_000_000

    /// Settings in an import file are untrusted: only these values are accepted for `sensitiveHandling`
    /// (never "allow", so an import can't quietly weaken privacy), and the history limit is clamped.
    static let allowedSensitiveHandling: Set<String> = ["skip", "mask"]
    static let historyLimitRange = 25...500

    static func buildExportData() throws -> Data {
        // Read history
        let historyURL = StoragePaths.base.appendingPathComponent("history.json")
        let history: [HistoryItem]
        if let data = try? Data(contentsOf: historyURL) {
            history = ((try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []).filter { $0.isSensitive != true }
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

        // Read excluded types
        let excludedTypesURL = StoragePaths.base.appendingPathComponent("excluded_types.json")
        let excludedTypes: [String]
        if let data = try? Data(contentsOf: excludedTypesURL) {
            excludedTypes = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            excludedTypes = []
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
            pasteAsPlainText: defaults.bool(forKey: "pasteAsPlainText"),
            enableStats: defaults.bool(forKey: "enableStats"),
            enableRichPreviews: defaults.bool(forKey: "enableRichPreviews"),
            captureSound: defaults.string(forKey: "captureSound") ?? "",
            captureScreenshots: defaults.bool(forKey: "captureScreenshots"),
            enableOCR: defaults.bool(forKey: "enableOCR"),
            enableQRDetection: defaults.bool(forKey: "enableQRDetection"),
            enablePDFTextExtraction: defaults.bool(forKey: "enablePDFTextExtraction"),
            hasSeenOnboarding: defaults.bool(forKey: "hasSeenOnboarding"),
            popoverHeight: defaults.double(forKey: "popoverHeight"),
            popoverWidth: defaults.double(forKey: "popoverWidth"),
            sensitiveHandling: defaults.string(forKey: "sensitiveHandling")
        )

        let envelope = ExportEnvelope(
            version: 1,
            exportDate: Date(),
            settings: settings,
            history: history,
            clips: clips,
            excludedApps: excludedApps,
            excludedTypes: excludedTypes,
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
        var excludedTypeCount: Int
        var imageCount: Int
        var pdfCount: Int
        var richTextCount: Int
        var failedBlobCount: Int
    }

    @discardableResult
    static func importData(
        from url: URL,
        merge: Bool,
        historyStore: HistoryStore,
        clipStore: ClipStore,
        excludedAppsStore: ExcludedAppsStore,
        excludedTypesStore: ExcludedTypesStore,
        settingsStore: SettingsStore
    ) throws -> ImportResult {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maxImportBytes else { throw PorterError.fileTooLarge }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        guard envelope.version == 1 else {
            throw PorterError.unsupportedVersion(envelope.version)
        }

        let blobDir = StoragePaths.blobs

        // Decode and validate every blob before touching anything on disk.
        var failedBlobCount = 0
        var decodedBlobs: [String: Data] = [:]
        for (filename, base64) in envelope.blobs {
            guard BlobStorage.isValidFilename(filename), let blobData = Data(base64Encoded: base64) else {
                failedBlobCount += 1
                continue
            }
            decodedBlobs[filename] = blobData
        }

        // An imported item may only refer to a blob that is valid and actually present.
        func sanitized(_ name: String?) -> String? {
            guard let name, BlobStorage.isValidFilename(name) else { return nil }
            return name
        }

        var newBlobFilenames: Set<String> = []
        if merge {
            // Write only new blobs (don't overwrite existing)
            for (filename, blobData) in decodedBlobs {
                let dest = blobDir.appendingPathComponent(filename)
                guard !FileManager.default.fileExists(atPath: dest.path) else { continue }
                do {
                    try blobData.write(to: dest, options: .atomic)
                    newBlobFilenames.insert(filename)
                } catch {
                    failedBlobCount += 1
                }
            }
        } else {
            // Replace: stage the new blobs next to the old ones, then swap, so a failure part-way
            // leaves the existing blobs alone.
            let staging = StoragePaths.base.appendingPathComponent("blobs-import-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging) }
            for (filename, blobData) in decodedBlobs {
                try blobData.write(to: staging.appendingPathComponent(filename), options: .atomic)
            }
            if let existing = try? FileManager.default.contentsOfDirectory(atPath: blobDir.path) {
                for file in existing {
                    try? FileManager.default.removeItem(at: blobDir.appendingPathComponent(file))
                }
            }
            for filename in decodedBlobs.keys {
                try? FileManager.default.moveItem(at: staging.appendingPathComponent(filename), to: blobDir.appendingPathComponent(filename))
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
        for i in importedHistory.indices { importedHistory[i].blobFile = sanitized(importedHistory[i].blobFile) }
        for i in importedClips.indices { importedClips[i].blobFile = sanitized(importedClips[i].blobFile) }

        for i in importedHistory.indices {
            if importedHistory[i].contentType == .fileURL,
               let blob = importedHistory[i].blobFile,
               let blobData = BlobStorage.load(blob),
               let originalPath = importedHistory[i].fileURLs?.first {
                let filename = (originalPath as NSString).lastPathComponent
                guard BlobStorage.isValidFilename(filename) else { continue }
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
                guard BlobStorage.isValidFilename(filename) else { continue }
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
        var newExcludedTypeCount: Int

        let importedExcludedTypes = envelope.excludedTypes ?? []

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

            let importedTypes = Set(importedExcludedTypes.compactMap { ClipboardContentType(rawValue: $0) })
            let newExcludedTypes = excludedTypesStore.excludedTypes.union(importedTypes)
            let excludedTypesData = try encoder.encode(newExcludedTypes)
            try excludedTypesData.write(to: StoragePaths.base.appendingPathComponent("excluded_types.json"), options: .atomic)
            newExcludedTypeCount = newExcludedTypes.count - excludedTypesStore.excludedTypes.count
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

            let replacedTypes = Set(importedExcludedTypes.compactMap { ClipboardContentType(rawValue: $0) })
            let excludedTypesData = try encoder.encode(replacedTypes)
            try excludedTypesData.write(to: StoragePaths.base.appendingPathComponent("excluded_types.json"), options: .atomic)
            newExcludedTypeCount = replacedTypes.count

            // Apply settings only on replace
            if historyLimitRange.contains(envelope.settings.historyLimit) {
                settingsStore.historyLimit = envelope.settings.historyLimit
            }
            settingsStore.pasteAsPlainText = envelope.settings.pasteAsPlainText
            if let enableStats = envelope.settings.enableStats {
                settingsStore.enableStats = enableStats
            }
            if let enableRichPreviews = envelope.settings.enableRichPreviews {
                settingsStore.enableRichPreviews = enableRichPreviews
            }
            if let captureSound = envelope.settings.captureSound {
                settingsStore.captureSound = captureSound
            }
            if let captureScreenshots = envelope.settings.captureScreenshots {
                settingsStore.captureScreenshots = captureScreenshots
            }
            if let enableOCR = envelope.settings.enableOCR {
                settingsStore.enableOCR = enableOCR
            }
            if let enableQRDetection = envelope.settings.enableQRDetection {
                settingsStore.enableQRDetection = enableQRDetection
            }
            if let enablePDFTextExtraction = envelope.settings.enablePDFTextExtraction {
                settingsStore.enablePDFTextExtraction = enablePDFTextExtraction
            }
            if let hasSeenOnboarding = envelope.settings.hasSeenOnboarding {
                settingsStore.hasSeenOnboarding = hasSeenOnboarding
            }
            if let popoverHeight = envelope.settings.popoverHeight, popoverHeight > 0 {
                settingsStore.popoverHeight = popoverHeight
            }
            if let popoverWidth = envelope.settings.popoverWidth, popoverWidth > 0 {
                settingsStore.popoverWidth = popoverWidth
            }
            if let sensitiveHandling = envelope.settings.sensitiveHandling, allowedSensitiveHandling.contains(sensitiveHandling) {
                settingsStore.sensitiveHandling = sensitiveHandling
            }
        }

        // Reload all stores
        historyStore.load()
        clipStore.load()
        excludedAppsStore.load()
        excludedTypesStore.load()

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
            excludedTypeCount: newExcludedTypeCount,
            imageCount: imageCount,
            pdfCount: pdfCount,
            richTextCount: richTextCount,
            failedBlobCount: failedBlobCount
        )
    }
}

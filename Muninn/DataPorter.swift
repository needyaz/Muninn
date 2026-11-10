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
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .writeFailed:
                return "The import could not be written. Your existing data was left unchanged."
            case .unsupportedVersion(let v):
                return "Unsupported export version: \(v). This file may have been created by a newer version of Muninn."
            case .fileTooLarge:
                return "This file is too large to be a Muninn export."
            }
        }
    }

    /// The write steps of a Replace import; a test can make one of them fail.
    enum ImportStep: CaseIterable {
        case history, clips, excludedApps, excludedTypes, blobs, files
    }

    /// Test-only: when set, a Replace import throws at this step's write.
    static var failingStepOverride: ImportStep? = nil

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
        }

        // Restore files from blobs for fileURL items. Merge writes them straight away; Replace only
        // collects them, so nothing on disk changes until the staged data is swapped in.
        let filesDir = StoragePaths.base.appendingPathComponent("files", isDirectory: true)
        if merge { try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true) }
        var stagedFiles: [String: Data] = [:]

        func restoreFile(blob: String?, fileURLs: [String]?) -> [String]? {
            guard let blob,
                  let blobData = merge ? BlobStorage.load(blob) : decodedBlobs[blob],
                  let originalPath = fileURLs?.first else { return nil }
            let filename = (originalPath as NSString).lastPathComponent
            guard BlobStorage.isValidFilename(filename) else { return nil }
            let destURL = filesDir.appendingPathComponent(filename)
            if merge {
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    try? blobData.write(to: destURL, options: .atomic)
                }
            } else if stagedFiles[filename] == nil {
                stagedFiles[filename] = blobData
            }
            return [destURL.path]
        }

        var importedHistory = envelope.history
        var importedClips = envelope.clips
        for i in importedHistory.indices { importedHistory[i].blobFile = sanitized(importedHistory[i].blobFile) }
        for i in importedClips.indices { importedClips[i].blobFile = sanitized(importedClips[i].blobFile) }

        for i in importedHistory.indices where importedHistory[i].contentType == .fileURL {
            if let urls = restoreFile(blob: importedHistory[i].blobFile, fileURLs: importedHistory[i].fileURLs) {
                importedHistory[i].fileURLs = urls
            }
        }
        for i in importedClips.indices where importedClips[i].contentType == .fileURL {
            if let urls = restoreFile(blob: importedClips[i].blobFile, fileURLs: importedClips[i].fileURLs) {
                importedClips[i].fileURLs = urls
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
            // Newest first (stable for equal timestamps), then trim to the user's current limit.
            var mergedHistory = (historyStore.items + newHistory).enumerated()
                .sorted { $0.element.timestamp != $1.element.timestamp
                    ? $0.element.timestamp > $1.element.timestamp : $0.offset < $1.offset }
                .map(\.element)
            let limit = settingsStore.historyLimit
            var keptNew = newHistory.count
            if mergedHistory.count > limit {
                let evicted = mergedHistory[limit...]
                let evictedIDs = Set(evicted.map(\.id))
                keptNew = newHistory.filter { !evictedIDs.contains($0.id) }.count
                mergedHistory = Array(mergedHistory.prefix(limit))
                let keptBlobs = Set(mergedHistory.compactMap(\.blobFile))
                for old in evicted {
                    if let blob = old.blobFile, !keptBlobs.contains(blob) { BlobStorage.delete(blob) }
                }
            }
            let historyData = try encoder.encode(mergedHistory)
            try historyData.write(to: StoragePaths.base.appendingPathComponent("history.json"), options: .atomic)
            newHistoryCount = keptNew

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
            // Replace all: write everything to a staging folder first, then swap it in.
            let fm = FileManager.default
            let base = StoragePaths.base
            let stage = base.appendingPathComponent("import-staging-\(UUID().uuidString)", isDirectory: true)
            let backup = base.appendingPathComponent("import-backup-\(UUID().uuidString)", isDirectory: true)
            let privateDir: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
            try fm.createDirectory(at: stage, withIntermediateDirectories: true, attributes: privateDir)
            try fm.createDirectory(at: backup, withIntermediateDirectories: true, attributes: privateDir)
            defer {
                try? fm.removeItem(at: stage)
                try? fm.removeItem(at: backup)
            }

            func stageStep(_ step: ImportStep, _ write: () throws -> Void) throws {
                if failingStepOverride == step { throw PorterError.writeFailed }
                try write()
            }

            let replacedTypes = Set(importedExcludedTypes.compactMap { ClipboardContentType(rawValue: $0) })
            try stageStep(.history) {
                try encoder.encode(importedHistory).write(to: stage.appendingPathComponent("history.json"), options: .atomic)
            }
            try stageStep(.clips) {
                try encoder.encode(importedClips).write(to: stage.appendingPathComponent("clips.json"), options: .atomic)
            }
            try stageStep(.excludedApps) {
                try encoder.encode(envelope.excludedApps).write(to: stage.appendingPathComponent("excluded_apps.json"), options: .atomic)
            }
            try stageStep(.excludedTypes) {
                try encoder.encode(replacedTypes).write(to: stage.appendingPathComponent("excluded_types.json"), options: .atomic)
            }
            try stageStep(.blobs) {
                let dir = stage.appendingPathComponent("blobs", isDirectory: true)
                try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: privateDir)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                var mutableDir = dir
                try? mutableDir.setResourceValues(values)
                for (filename, blobData) in decodedBlobs {
                    try blobData.write(to: dir.appendingPathComponent(filename), options: .atomic)
                }
            }
            try stageStep(.files) {
                let dir = stage.appendingPathComponent("files", isDirectory: true)
                try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: privateDir)
                for (filename, fileData) in stagedFiles {
                    try fileData.write(to: dir.appendingPathComponent(filename), options: .atomic)
                }
            }

            // Swap in. Each existing item is moved to the backup folder first, so a failure rolls back.
            var swapped: [String] = []
            do {
                for name in ["history.json", "clips.json", "excluded_apps.json", "excluded_types.json", "blobs", "files"] {
                    let dest = base.appendingPathComponent(name)
                    if fm.fileExists(atPath: dest.path) {
                        try fm.moveItem(at: dest, to: backup.appendingPathComponent(name))
                    }
                    swapped.append(name)
                    try fm.moveItem(at: stage.appendingPathComponent(name), to: dest)
                }
            } catch {
                for name in swapped.reversed() {
                    let dest = base.appendingPathComponent(name)
                    let saved = backup.appendingPathComponent(name)
                    try? fm.removeItem(at: dest)
                    if fm.fileExists(atPath: saved.path) { try? fm.moveItem(at: saved, to: dest) }
                }
                throw error
            }

            newHistoryCount = importedHistory.count
            newClipCount = importedClips.count
            newExcludedAppCount = envelope.excludedApps.count
            newExcludedTypeCount = replacedTypes.count

            // Apply settings only on replace, and only once the swap has succeeded
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

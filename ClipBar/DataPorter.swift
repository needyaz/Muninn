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

    static func importData(
        from url: URL,
        historyStore: HistoryStore,
        clipStore: ClipStore,
        excludedAppsStore: ExcludedAppsStore,
        settingsStore: SettingsStore
    ) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        guard envelope.version == 1 else {
            throw PorterError.unsupportedVersion(envelope.version)
        }

        // Write blobs
        let blobDir = StoragePaths.blobs
        // Clear existing blobs
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

        // Write JSON files
        let encoder = JSONEncoder()

        let historyData = try encoder.encode(envelope.history)
        try historyData.write(to: StoragePaths.base.appendingPathComponent("history.json"), options: .atomic)

        let clipsData = try encoder.encode(envelope.clips)
        try clipsData.write(to: StoragePaths.base.appendingPathComponent("clips.json"), options: .atomic)

        let excludedData = try encoder.encode(envelope.excludedApps)
        try excludedData.write(to: StoragePaths.base.appendingPathComponent("excluded_apps.json"), options: .atomic)

        // Apply settings
        let defaults = UserDefaults.standard
        defaults.set(envelope.settings.historyLimit, forKey: "historyLimit")
        defaults.set(envelope.settings.pasteAsPlainText, forKey: "pasteAsPlainText")

        // Reload all stores
        settingsStore.historyLimit = envelope.settings.historyLimit
        settingsStore.pasteAsPlainText = envelope.settings.pasteAsPlainText
        historyStore.load()
        clipStore.load()
        excludedAppsStore.load()
    }
}

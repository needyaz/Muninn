import Testing
import Foundation
import AppKit
@testable import Muninn

// MARK: - Fake pasteboard

private final class RecordingPasteboard: PasteboardTarget {
    var clearCount = 0
    var strings: [(String, NSPasteboard.PasteboardType)] = []
    var datas: [(Data?, NSPasteboard.PasteboardType)] = []

    var writeCount: Int { strings.count + datas.count }

    @discardableResult func clearContents() -> Int {
        clearCount += 1
        return clearCount
    }

    @discardableResult func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        strings.append((string, type))
        return true
    }

    @discardableResult func setData(_ data: Data?, forType type: NSPasteboard.PasteboardType) -> Bool {
        datas.append((data, type))
        return true
    }
}

@Suite("Data safety fixes", .serialized)
struct DataSafetyTests {

    // MARK: - Helpers

    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MuninnDataSafety-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func withTempBase(_ body: (URL) throws -> Void) throws {
        let dir = tempDir()
        StoragePaths.baseOverride = dir
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("blobs", isDirectory: true),
                                                withIntermediateDirectories: true)
        let savedLimit = UserDefaults.standard.object(forKey: "historyLimit")
        defer {
            DataPorter.failingStepOverride = nil
            StoragePaths.baseOverride = nil
            if let savedLimit { UserDefaults.standard.set(savedLimit, forKey: "historyLimit") }
            else { UserDefaults.standard.removeObject(forKey: "historyLimit") }
            try? FileManager.default.removeItem(at: dir)
        }
        try body(dir)
    }

    private func writeExport(_ envelope: DataPorter.ExportEnvelope) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let outDir = tempDir()
        let file = outDir.appendingPathComponent("import.muninn")
        try encoder.encode(envelope).write(to: file, options: .atomic)
        return file
    }

    private func envelope(
        history: [HistoryItem] = [],
        clips: [Clip] = [],
        excludedApps: [String] = [],
        excludedTypes: [String]? = nil,
        blobs: [String: String] = [:],
        historyLimit: Int = 50
    ) -> DataPorter.ExportEnvelope {
        DataPorter.ExportEnvelope(
            version: 1,
            exportDate: Date(),
            settings: .init(historyLimit: historyLimit, pasteAsPlainText: false),
            history: history,
            clips: clips,
            excludedApps: excludedApps,
            excludedTypes: excludedTypes,
            blobs: blobs
        )
    }

    private func runImport(_ file: URL, merge: Bool, settings: SettingsStore? = nil) throws -> DataPorter.ImportResult {
        let settingsStore = settings ?? SettingsStore()
        return try DataPorter.importData(
            from: file,
            merge: merge,
            historyStore: HistoryStore(settingsStore: settingsStore),
            clipStore: ClipStore(),
            excludedAppsStore: ExcludedAppsStore(),
            excludedTypesStore: ExcludedTypesStore(),
            settingsStore: settingsStore
        )
    }

    /// Every regular file under `dir`, keyed by its path relative to `dir`.
    private func snapshot(_ dir: URL) -> [String: Data] {
        var result: [String: Data] = [:]
        let root = dir.resolvingSymlinksInPath().path
        guard let walker = FileManager.default.enumerator(atPath: root) else { return result }
        while let rel = walker.nextObject() as? String {
            let full = (root as NSString).appendingPathComponent(rel)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue,
               let data = FileManager.default.contents(atPath: full) {
                result[rel] = data
            }
        }
        return result
    }

    private func listing(_ dir: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
    }

    /// Writes an existing data set into `dir` and returns an import file that carries different data.
    private func seedExistingAndMakeReplaceImport(in dir: URL) throws -> URL {
        let oldHistory = [HistoryItem(value: "old history", timestamp: Date(timeIntervalSince1970: 1_700_000_000))]
        let oldClips = [Clip(name: "Old", value: "old clip")]
        try JSONEncoder().encode(oldHistory).write(to: dir.appendingPathComponent("history.json"))
        try JSONEncoder().encode(oldClips).write(to: dir.appendingPathComponent("clips.json"))
        try JSONEncoder().encode(["com.old.app"]).write(to: dir.appendingPathComponent("excluded_apps.json"))
        try JSONEncoder().encode(["color"]).write(to: dir.appendingPathComponent("excluded_types.json"))
        try Data("old blob".utf8).write(to: dir.appendingPathComponent("blobs/old.png"))
        let filesDir = dir.appendingPathComponent("files", isDirectory: true)
        try FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
        try Data("old file".utf8).write(to: filesDir.appendingPathComponent("old.txt"))

        let newHistory = [
            HistoryItem(value: "new history", timestamp: Date(timeIntervalSince1970: 1_750_000_000)),
            HistoryItem(value: "report.txt", timestamp: Date(timeIntervalSince1970: 1_750_000_100),
                        contentType: .fileURL, blobFile: "report.txt", fileURLs: ["/home/someone/report.txt"]),
        ]
        return try writeExport(envelope(
            history: newHistory,
            clips: [Clip(name: "New", value: "new clip")],
            excludedApps: ["com.new.app"],
            excludedTypes: ["image"],
            blobs: ["new.png": Data("new blob".utf8).base64EncodedString(),
                    "report.txt": Data("report body".utf8).base64EncodedString()]
        ))
    }

    // MARK: - MUN-SENS-012

    @Test("MUN-SENS-012: writing a masked item leaves the pasteboard untouched, a normal item is written")
    func mun_sens_012_maskedItemUntouched() {
        let masked = RecordingPasteboard()
        PasteboardWriter.write(HistoryItem(value: nil, contentType: .text, isSensitive: true), to: masked)
        #expect(masked.clearCount == 0)
        #expect(masked.writeCount == 0)

        let maskedWithValue = RecordingPasteboard()
        PasteboardWriter.write(HistoryItem(value: "hunter2", contentType: .text, isSensitive: true), to: maskedWithValue)
        #expect(maskedWithValue.clearCount == 0)
        #expect(maskedWithValue.writeCount == 0)

        let normal = RecordingPasteboard()
        PasteboardWriter.write(HistoryItem(value: "plain words", contentType: .text), to: normal)
        #expect(normal.clearCount >= 1)
        #expect(normal.strings.contains { $0.0 == "plain words" })
    }

    // MARK: - MUN-POP-008

    private func isDirectlyInTemp(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        let temp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        return parent == temp
    }

    @Test("MUN-POP-008: drag temp URL stays in the temp directory with a valid name; valid names are used unchanged")
    func mun_pop_008_dragTempURL() {
        for value in ["../evil.png", "a/b.png", "..", ""] {
            let url = dragImageTempURL(value: value, blobExtension: "png")
            #expect(isDirectlyInTemp(url), "value \(value)")
            #expect(BlobStorage.isValidFilename(url.lastPathComponent), "value \(value)")
        }
        #expect(dragImageTempURL(value: "../evil.png", blobExtension: "png").lastPathComponent == "evil.png")
        #expect(dragImageTempURL(value: "..", blobExtension: "png").lastPathComponent == "Image.png")
        #expect(dragImageTempURL(value: "", blobExtension: "png").lastPathComponent == "Image.png")

        let kept = dragImageTempURL(value: "Screenshot-2026-11-10.png", blobExtension: "png")
        #expect(kept.lastPathComponent == "Screenshot-2026-11-10.png")
        #expect(isDirectlyInTemp(kept))
    }

    // MARK: - MUN-PORT-018 / MUN-PORT-021

    @Test("MUN-PORT-018: a Replace import failing at any write step throws and leaves every existing file byte-identical")
    func mun_port_018_failedReplaceLeavesData() throws {
        for step in DataPorter.ImportStep.allCases {
            try withTempBase { dir in
                let file = try seedExistingAndMakeReplaceImport(in: dir)
                let before = snapshot(dir)
                let blobsBefore = listing(dir.appendingPathComponent("blobs"))
                let filesBefore = listing(dir.appendingPathComponent("files"))

                DataPorter.failingStepOverride = step
                #expect(throws: (any Error).self, "step \(step)") {
                    _ = try runImport(file, merge: false)
                }
                DataPorter.failingStepOverride = nil

                let after = snapshot(dir)
                for (path, data) in before {
                    #expect(after[path] == data, "step \(step): \(path) changed")
                }
                #expect(listing(dir.appendingPathComponent("blobs")) == blobsBefore, "step \(step)")
                #expect(listing(dir.appendingPathComponent("files")) == filesBefore, "step \(step)")
            }
        }
    }

    @Test("MUN-PORT-018 (keeps): a successful Replace import still replaces everything")
    func mun_port_018_KEEPS_successfulReplace() throws {
        try withTempBase { dir in
            let file = try seedExistingAndMakeReplaceImport(in: dir)
            _ = try runImport(file, merge: false)
            let history = HistoryStore(settingsStore: SettingsStore())
            #expect(history.items.map(\.value).contains("new history"))
            #expect(!history.items.map(\.value).contains("old history"))
            #expect(ClipStore().clips.map(\.name) == ["New"])
            #expect(ExcludedAppsStore().excludedBundleIDs == ["com.new.app"])
            #expect(ExcludedTypesStore().excludedTypes == [.image])
            #expect(listing(dir.appendingPathComponent("blobs")).contains("new.png"))
            #expect(!listing(dir.appendingPathComponent("blobs")).contains("old.png"))
        }
    }

    @Test("MUN-PORT-021: files/ is untouched by a failed Replace and old files go only on a successful one")
    func mun_port_021_filesRemovedOnlyOnSwap() throws {
        for step in DataPorter.ImportStep.allCases {
            try withTempBase { dir in
                let file = try seedExistingAndMakeReplaceImport(in: dir)
                let oldFile = dir.appendingPathComponent("files/old.txt")
                DataPorter.failingStepOverride = step
                _ = try? runImport(file, merge: false)
                DataPorter.failingStepOverride = nil
                #expect(FileManager.default.contents(atPath: oldFile.path) == Data("old file".utf8), "step \(step)")
            }
        }
        try withTempBase { dir in
            let file = try seedExistingAndMakeReplaceImport(in: dir)
            _ = try runImport(file, merge: false)
            let files = listing(dir.appendingPathComponent("files"))
            #expect(!files.contains("old.txt"))
            #expect(files.contains("report.txt"))
        }
    }

    // MARK: - MUN-HIST-009

    @Test("MUN-HIST-009: an unreadable history.json ends up in history.json.bak before the next save")
    func mun_hist_009_unreadableHistoryBackedUp() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let original = Data("{ this is not history".utf8)
        try original.write(to: dir.appendingPathComponent("history.json"))

        let store = HistoryStore(settingsStore: SettingsStore(), baseURL: dir)
        store.load()
        store.save()

        let backup = FileManager.default.contents(atPath: dir.appendingPathComponent("history.json.bak").path)
        #expect(backup == original)
    }

    // MARK: - MUN-SENS-013

    @Test("MUN-SENS-013: Load Demo Data inserts sensitive items with no value")
    func mun_sens_013_demoSensitiveHasNoValue() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(settingsStore: SettingsStore(), baseURL: dir)
        store.loadDemoData()
        let sensitive = store.items.filter { $0.isSensitive == true }
        #expect(!sensitive.isEmpty)
        for item in sensitive {
            #expect(item.value == nil)
        }
    }

    // MARK: - MUN-PORT-022

    @Test("MUN-PORT-022: a Merge import keeps history newest-first and trimmed to the history limit")
    func mun_port_022_mergeOrdersAndTrims() throws {
        try withTempBase { dir in
            let base = 1_750_000_000.0
            // Existing: 20 items in the middle of the time range, newest first.
            let existing = (0..<20).map { i in
                HistoryItem(value: "existing \(i)", timestamp: Date(timeIntervalSince1970: base - Double(i) * 60))
            }
            try JSONEncoder().encode(existing).write(to: dir.appendingPathComponent("history.json"))
            // Imported: 10 newer and 10 older than all the existing ones.
            let newer = (0..<10).map { i in
                HistoryItem(value: "newer \(i)", timestamp: Date(timeIntervalSince1970: base + 3600 + Double(i) * 60))
            }
            let older = (0..<10).map { i in
                HistoryItem(value: "older \(i)", timestamp: Date(timeIntervalSince1970: base - 7200 - Double(i) * 60))
            }
            let file = try writeExport(envelope(history: older + newer))

            let settings = SettingsStore()
            settings.historyLimit = 25
            let history = HistoryStore(settingsStore: settings)
            _ = try DataPorter.importData(from: file, merge: true, historyStore: history, clipStore: ClipStore(),
                                          excludedAppsStore: ExcludedAppsStore(), excludedTypesStore: ExcludedTypesStore(),
                                          settingsStore: settings)

            #expect(history.items.count == 25)
            let stamps = history.items.map(\.timestamp)
            #expect(stamps == stamps.sorted(by: >))
            #expect(history.items.allSatisfy { !($0.value ?? "").hasPrefix("older") })
            #expect(history.items.first?.value == "newer 9")

            let reloaded = HistoryStore(settingsStore: settings)
            #expect(reloaded.items.count == 25)
        }
    }
}

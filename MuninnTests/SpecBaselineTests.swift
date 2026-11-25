import Testing
import Foundation
@testable import Muninn

@Suite("Spec baseline: core behaviours", .serialized)
struct SpecBaselineTests {

    private func isolatedSettings() -> (SettingsStore, () -> Void) {
        let name = "MuninnSpecBaseline-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (SettingsStore(defaults: defaults), { defaults.removePersistentDomain(forName: name) })
    }

    // MARK: - Data model

    @Test("content types are text, image, pdf, fileURL and color with their display names")
    func contentTypeNames() {
        #expect(ClipboardContentType.allCases.map(\.rawValue) == ["text", "image", "pdf", "fileURL", "color"])
        #expect(ClipboardContentType.text.displayName == "Text")
        #expect(ClipboardContentType.image.displayName == "Images")
        #expect(ClipboardContentType.pdf.displayName == "PDFs")
        #expect(ClipboardContentType.fileURL.displayName == "Files")
        #expect(ClipboardContentType.color.displayName == "Colors")
    }

    @Test("PDF item preview returns the extracted text")
    func pdfPreviewUsesExtractedText() {
        let item = HistoryItem(contentType: .pdf, ocrText: "Quarterly report")
        #expect(item.preview == "Quarterly report")
    }

    // MARK: - Search

    @Test("color item matches a search for its type name")
    func colorMatchesTypeName() {
        let item = HistoryItem(contentType: .color, colorComponents: [1, 0, 0, 1])
        let hits = filterHistoryItems([item], search: "color", typeFilter: nil, enableQRDetection: false)
        #expect(hits.count == 1)
    }

    @Test("PDF item matches a search for its extracted text")
    func pdfMatchesExtractedText() {
        let item = HistoryItem(contentType: .pdf, ocrText: "invoice number 42")
        let other = HistoryItem(contentType: .pdf, ocrText: "meeting notes")
        let hits = filterHistoryItems([item, other], search: "INVOICE", typeFilter: nil, enableQRDetection: false)
        #expect(hits == [item])
    }

    @Test("masked sensitive item never matches a non-empty search")
    func maskedItemNeverMatches() {
        let masked = HistoryItem(value: nil, isSensitive: true)
        let hits = filterHistoryItems([masked], search: "s", typeFilter: nil, enableQRDetection: true)
        #expect(hits.isEmpty)
        let all = filterHistoryItems([masked], search: "", typeFilter: nil, enableQRDetection: true)
        #expect(all.count == 1)
    }

    // MARK: - History store

    @Test("identical image, file and color items are all kept")
    func nonTextNeverDeduplicated() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }
        let (settings, cleanup) = isolatedSettings()
        defer { cleanup() }
        let store = HistoryStore(settingsStore: settings, baseURL: dir)

        for _ in 0..<2 {
            store.add(HistoryItem(contentType: .image, blobFile: "same.png"))
            store.add(HistoryItem(contentType: .fileURL, fileURLs: ["/tmp/a.txt"]))
            store.add(HistoryItem(contentType: .color, colorComponents: [0, 0, 0, 1]))
        }
        #expect(store.items.count == 6)
    }

    @Test("trimming evicts the oldest items and deletes their blobs")
    func trimEvictsOldestAndBlobs() throws {
        let dir = makeTempDir()
        let blobDir = dir.appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)
        BlobStorage.blobDirOverride = blobDir
        defer {
            BlobStorage.blobDirOverride = nil
            removeTempDir(dir)
        }
        let (settings, cleanup) = isolatedSettings()
        defer { cleanup() }
        settings.historyLimit = 2
        let store = HistoryStore(settingsStore: settings, baseURL: dir)

        let oldBlob = BlobStorage.save(Data("old".utf8), id: UUID(), ext: "png")
        let newBlob = BlobStorage.save(Data("new".utf8), id: UUID(), ext: "png")
        store.add(HistoryItem(contentType: .image, blobFile: oldBlob))
        store.add(HistoryItem(contentType: .image, blobFile: newBlob))
        store.add(HistoryItem(value: "newest"))

        #expect(store.items.count == 2)
        #expect(store.items.first?.value == "newest")
        #expect(BlobStorage.load(oldBlob) == nil)
        #expect(BlobStorage.load(newBlob) != nil)
    }

    // MARK: - Snippets

    @Test("with no clips.json the store seeds four example snippets and saves them")
    func clipStoreSeedsExamples() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }
        let store = ClipStore(baseURL: dir)

        #expect(store.clips.map(\.name) == ["Name", "Email", "Phone", "Website"])
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("clips.json").path))
    }

    // MARK: - Settings

    @Test("default settings match the documented defaults")
    func settingsDefaults() {
        let (s, cleanup) = isolatedSettings()
        defer { cleanup() }

        #expect(s.historyLimit == 50)
        #expect(s.pasteAsPlainText == false)
        #expect(s.enableStats == true)
        #expect(s.enableRichPreviews == true)
        #expect(s.captureSound == "")
        #expect(s.captureScreenshots == false)
        #expect(s.enableOCR == false)
        #expect(s.enableQRDetection == false)
        #expect(s.enablePDFTextExtraction == false)
        #expect(s.hasSeenOnboarding == false)
        #expect(s.popoverHeight == 400)
        #expect(s.popoverWidth == 320)
        #expect(s.sensitiveHandling == "skip")
    }

    @Test("a setting is written to its defaults as soon as it changes")
    func settingsWriteThrough() {
        let name = "MuninnSpecBaseline-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let s = SettingsStore(defaults: defaults)

        s.historyLimit = 200
        s.enableOCR = true
        #expect(defaults.integer(forKey: "historyLimit") == 200)
        #expect(defaults.bool(forKey: "enableOCR") == true)
    }
}

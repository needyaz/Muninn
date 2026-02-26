import Testing
import Foundation
@testable import Muninn

@Suite("HistoryStore", .serialized)
struct HistoryStoreTests {

    private func makeStore(historyLimit: Int = 50) -> (HistoryStore, URL) {
        let dir = makeTempDir()
        let settings = SettingsStore()
        settings.historyLimit = historyLimit
        let store = HistoryStore(settingsStore: settings, baseURL: dir)
        return (store, dir)
    }

    @Test("add deduplicates text items by value")
    func addDedup() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "hello"))
        store.add(HistoryItem(value: "hello"))
        #expect(store.items.count == 1)
    }

    @Test("add does not deduplicate non-text items")
    func addNonDedup() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(contentType: .image, blobFile: "a.png"))
        store.add(HistoryItem(contentType: .image, blobFile: "b.png"))
        #expect(store.items.count == 2)
    }

    @Test("add inserts at top")
    func addInsertsAtTop() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "first"))
        store.add(HistoryItem(value: "second"))
        #expect(store.items[0].value == "second")
    }

    @Test("trimToLimit caps items")
    func trimToLimit() {
        let (store, dir) = makeStore(historyLimit: 3)
        defer { removeTempDir(dir) }

        for i in 0..<5 {
            store.add(HistoryItem(value: "item\(i)"))
        }
        #expect(store.items.count == 3)
    }

    @Test("update OCR text")
    func updateOCR() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        let item = HistoryItem(contentType: .image)
        store.add(item)
        store.update(id: item.id, ocrText: "recognized")
        #expect(store.items[0].ocrText == "recognized")
    }

    @Test("update detected barcode")
    func updateBarcode() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        let item = HistoryItem(contentType: .image)
        store.add(item)
        store.update(id: item.id, detectedBarcode: "https://example.com")
        #expect(store.items[0].detectedBarcode == "https://example.com")
    }

    @Test("delete removes item")
    func deleteItem() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        let item = HistoryItem(value: "delete me")
        store.add(item)
        store.delete(item)
        #expect(store.items.isEmpty)
    }

    @Test("delete sets up pendingUndo")
    func deleteSetsPendingUndo() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        let item = HistoryItem(value: "undo me")
        store.add(item)
        store.delete(item)
        #expect(store.items.isEmpty)
        #expect(store.pendingUndo != nil)
        #expect(store.pendingUndo?.items.count == 1)
        #expect(store.pendingUndo?.items[0].value == "undo me")
    }

    @Test("undo restores deleted item")
    func undoRestoresItem() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        let item = HistoryItem(value: "restore me")
        store.add(item)
        store.delete(item)
        store.undo()
        #expect(store.items.count == 1)
        #expect(store.items[0].value == "restore me")
        #expect(store.pendingUndo == nil)
    }

    @Test("commitPendingUndo clears undo state")
    func commitPendingUndo() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        let item = HistoryItem(value: "gone")
        store.add(item)
        store.delete(item)
        store.commitPendingUndo()
        #expect(store.pendingUndo == nil)
    }

    @Test("second delete commits first undo")
    func secondDeleteCommitsFirst() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "first"))
        store.add(HistoryItem(value: "second"))
        let first = store.items.first { $0.value == "first" }!
        let second = store.items.first { $0.value == "second" }!
        store.delete(first)
        store.delete(second)
        // Only second delete is undoable
        store.undo()
        #expect(store.items.count == 1)
        #expect(store.items[0].value == "second")
    }

    @Test("clearAll removes all items")
    func clearAll() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "a"))
        store.add(HistoryItem(value: "b"))
        store.clearAll()
        #expect(store.items.isEmpty)
    }

    @Test("clearAll sets up pendingUndo for all items")
    func clearAllSetsPendingUndo() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "a"))
        store.add(HistoryItem(value: "b"))
        store.clearAll()
        #expect(store.items.isEmpty)
        #expect(store.pendingUndo?.items.count == 2)
    }

    @Test("undo after clearAll restores all items")
    func undoClearAll() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "a"))
        store.add(HistoryItem(value: "b"))
        store.clearAll()
        store.undo()
        #expect(store.items.count == 2)
    }

    @Test("deleteMultiple removes multiple items")
    func deleteMultiple() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "one"))
        store.add(HistoryItem(value: "two"))
        store.add(HistoryItem(value: "three"))
        let toDelete = store.items.filter { $0.value == "one" || $0.value == "three" }
        store.deleteMultiple(toDelete)
        #expect(store.items.count == 1)
        #expect(store.items[0].value == "two")
    }

    @Test("deleteMultiple sets up undo")
    func deleteMultipleUndo() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "a"))
        store.add(HistoryItem(value: "b"))
        let toDelete = store.items
        store.deleteMultiple(toDelete)
        #expect(store.items.isEmpty)
        #expect(store.pendingUndo?.items.count == 2)
        store.undo()
        #expect(store.items.count == 2)
    }

    @Test("deleteMultiple with empty array is no-op")
    func deleteMultipleEmpty() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "keep"))
        store.deleteMultiple([])
        #expect(store.items.count == 1)
        #expect(store.pendingUndo == nil)
    }

    @Test("undo restores blob data to disk")
    func undoRestoresBlob() throws {
        let dir = makeTempDir()
        let blobDir = dir.appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)
        BlobStorage.blobDirOverride = blobDir
        defer {
            BlobStorage.blobDirOverride = nil
            removeTempDir(dir)
        }

        let settings = SettingsStore()
        let store = HistoryStore(settingsStore: settings, baseURL: dir)

        let blobData = Data("image bytes".utf8)
        let blobFilename = BlobStorage.save(blobData, id: UUID(), ext: "png")

        let item = HistoryItem(contentType: .image, blobFile: blobFilename)
        store.add(item)
        store.delete(item)

        // Blob should be gone from disk
        #expect(BlobStorage.load(blobFilename) == nil)

        // Undo should restore it
        store.undo()
        #expect(BlobStorage.load(blobFilename) == blobData)
        #expect(store.items.count == 1)
    }

    @Test("scanForPDFText skips fileURL items with non-pdf blob extension")
    func scanForPDFTextSkipsNonPDFFileURLs() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(contentType: .fileURL, blobFile: "file.txt", fileURLs: ["/tmp/doc.txt"]))
        store.add(HistoryItem(contentType: .fileURL, blobFile: "notes.docx", fileURLs: ["/tmp/notes.docx"]))
        store.scanForPDFText()

        for item in store.items {
            #expect(!store.isScanning(id: item.id))
        }
    }

    @Test("scanForPDFText triggers scan for fileURL item with pdf blob")
    func scanForPDFTextIncludesFileURLPDFs() throws {
        let dir = makeTempDir()
        let blobDir = dir.appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)
        BlobStorage.blobDirOverride = blobDir
        defer {
            BlobStorage.blobDirOverride = nil
            removeTempDir(dir)
        }

        let settings = SettingsStore()
        let store = HistoryStore(settingsStore: settings, baseURL: dir)

        let fakePDFData = Data("not a real pdf".utf8)
        let blobFilename = BlobStorage.save(fakePDFData, id: UUID(), ext: "pdf")

        let item = HistoryItem(contentType: .fileURL, blobFile: blobFilename, fileURLs: ["/tmp/doc.pdf"])
        store.add(item)
        store.scanForPDFText()

        #expect(store.isScanning(id: item.id))
    }

    @Test("persistence: data survives reload")
    func persistence() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let settings = SettingsStore()
        let store1 = HistoryStore(settingsStore: settings, baseURL: dir)
        store1.add(HistoryItem(value: "persist"))

        let store2 = HistoryStore(settingsStore: settings, baseURL: dir)
        #expect(store2.items.count == 1)
        #expect(store2.items[0].value == "persist")
    }
}

import Testing
import Foundation
@testable import ClipBar

@Suite("HistoryStore")
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

    @Test("clearAll removes all items")
    func clearAll() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.add(HistoryItem(value: "a"))
        store.add(HistoryItem(value: "b"))
        store.clearAll()
        #expect(store.items.isEmpty)
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

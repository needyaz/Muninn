import Foundation

@Observable
class HistoryStore {
    var items: [HistoryItem] = []

    private let settingsStore: SettingsStore
    private let fileURL = StoragePaths.base.appendingPathComponent("history.json")

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("ClipBar: failed to load history: \(error)")
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ClipBar: failed to save history: \(error)")
        }
    }

    func add(_ item: HistoryItem) {
        // Deduplicate only text items by value
        if item.contentType == .text, let value = item.value {
            items.removeAll { $0.contentType == .text && $0.value == value }
        }
        // Insert at top
        items.insert(item, at: 0)
        // Cap at limit, cleaning up blobs for evicted items
        trimToLimit()
        save()
    }

    func update(id: UUID, ocrText: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].ocrText = ocrText
        save()
    }

    func delete(_ item: HistoryItem) {
        if let blob = item.blobFile { BlobStorage.delete(blob) }
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        for item in items {
            if let blob = item.blobFile { BlobStorage.delete(blob) }
        }
        items.removeAll()
        save()
    }

    func trimToLimit() {
        let limit = settingsStore.historyLimit
        if items.count > limit {
            let evicted = items[limit...]
            for old in evicted {
                if let blob = old.blobFile { BlobStorage.delete(blob) }
            }
            items = Array(items.prefix(limit))
        }
    }
}

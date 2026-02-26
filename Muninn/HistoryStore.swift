import Foundation

@Observable
class HistoryStore {
    var items: [HistoryItem] = []

    // MARK: - Undo

    struct UndoableOperation {
        let items: [HistoryItem]
        let blobs: [(filename: String, data: Data)]
        let label: String
    }

    /// Most recent undoable delete. Nil when no undo is available.
    var pendingUndo: UndoableOperation?

    private var undoTimer: Timer?
    private static let maxUndoBlobBytes = 50_000_000 // 50 MB

    func undo() {
        guard let operation = pendingUndo else { return }
        for (filename, data) in operation.blobs {
            BlobStorage.restore(data, filename: filename)
        }
        items.insert(contentsOf: operation.items, at: 0)
        save()
        pendingUndo = nil
        undoTimer?.invalidate()
        undoTimer = nil
    }

    func commitPendingUndo() {
        pendingUndo = nil
        undoTimer?.invalidate()
        undoTimer = nil
    }

    private func startUndoTimer() {
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.commitPendingUndo()
        }
    }

    private func blobBackup(for items: [HistoryItem]) -> [(filename: String, data: Data)] {
        var backup: [(filename: String, data: Data)] = []
        var totalBytes = 0
        for item in items {
            if let blob = item.blobFile, let data = BlobStorage.load(blob) {
                guard totalBytes + data.count <= Self.maxUndoBlobBytes else { continue }
                backup.append((filename: blob, data: data))
                totalBytes += data.count
            }
        }
        return backup
    }

    // MARK: - Scan tracking

    /// Tracks in-flight OCR/QR scan tasks per item ID. UI observes this to show progress indicators.
    private var pendingScanCounts: [UUID: Int] = [:]

    func isScanning(id: UUID) -> Bool {
        (pendingScanCounts[id] ?? 0) > 0
    }

    func beginScanning(id: UUID) {
        pendingScanCounts[id, default: 0] += 1
    }

    func endScanning(id: UUID) {
        let current = pendingScanCounts[id] ?? 0
        if current <= 1 {
            pendingScanCounts.removeValue(forKey: id)
        } else {
            pendingScanCounts[id] = current - 1
        }
    }

    private let settingsStore: SettingsStore
    private let fileURL: URL

    init(settingsStore: SettingsStore, baseURL: URL = StoragePaths.base) {
        self.settingsStore = settingsStore
        self.fileURL = baseURL.appendingPathComponent("history.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("Muninn: failed to load history: \(error)")
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Muninn: failed to save history: \(error)")
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

    func update(id: UUID, detectedBarcode: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].detectedBarcode = detectedBarcode
        save()
    }

    func delete(_ item: HistoryItem) {
        let backup = blobBackup(for: [item])
        commitPendingUndo()
        if let blob = item.blobFile { BlobStorage.delete(blob) }
        items.removeAll { $0.id == item.id }
        save()
        pendingUndo = UndoableOperation(items: [item], blobs: backup, label: "1 item deleted")
        startUndoTimer()
    }

    func deleteMultiple(_ itemsToDelete: [HistoryItem]) {
        guard !itemsToDelete.isEmpty else { return }
        let backup = blobBackup(for: itemsToDelete)
        commitPendingUndo()
        let idsToDelete = Set(itemsToDelete.map(\.id))
        for item in itemsToDelete {
            if let blob = item.blobFile { BlobStorage.delete(blob) }
        }
        items.removeAll { idsToDelete.contains($0.id) }
        save()
        let count = itemsToDelete.count
        pendingUndo = UndoableOperation(
            items: itemsToDelete,
            blobs: backup,
            label: "\(count) item\(count == 1 ? "" : "s") deleted"
        )
        startUndoTimer()
    }

    func clearAll() {
        let snapshot = items
        let backup = blobBackup(for: snapshot)
        commitPendingUndo()
        for item in snapshot {
            if let blob = item.blobFile { BlobStorage.delete(blob) }
        }
        items.removeAll()
        save()
        let count = snapshot.count
        pendingUndo = UndoableOperation(
            items: snapshot,
            blobs: backup,
            label: "\(count) item\(count == 1 ? "" : "s") cleared"
        )
        startUndoTimer()
    }

    func scanForOCR() {
        for item in items where item.contentType == .image && item.ocrText == nil {
            if let blob = item.blobFile, let data = BlobStorage.load(blob) {
                let id = item.id
                beginScanning(id: id)
                OCRService.extractText(from: data) { [weak self] text in
                    self?.endScanning(id: id)
                    guard let text else { return }
                    self?.update(id: id, ocrText: text)
                }
            }
        }
    }

    func scanForPDFText() {
        for item in items where item.ocrText == nil {
            let blobExt = item.blobFile.map { ($0 as NSString).pathExtension.lowercased() }
            let shouldExtract = item.contentType == .pdf
                || (item.contentType == .fileURL && blobExt == "pdf")
            guard shouldExtract else { continue }
            if let blob = item.blobFile, let data = BlobStorage.load(blob) {
                let id = item.id
                beginScanning(id: id)
                PDFTextService.extractText(from: data) { [weak self] text in
                    self?.endScanning(id: id)
                    guard let text else { return }
                    self?.update(id: id, ocrText: text)
                }
            }
        }
    }

    func scanForBarcodes() {
        for item in items where item.contentType == .image && item.detectedBarcode == nil {
            if let blob = item.blobFile, let data = BlobStorage.load(blob) {
                let id = item.id
                beginScanning(id: id)
                QRService.detectBarcode(from: data) { [weak self] value in
                    self?.endScanning(id: id)
                    guard let value else { return }
                    self?.update(id: id, detectedBarcode: value)
                }
            }
        }
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

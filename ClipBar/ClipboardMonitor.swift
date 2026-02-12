import AppKit
import Combine

@Observable
class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var selfCopyChangeCount: Int?
    private let historyStore: HistoryStore
    private let excludedAppsStore: ExcludedAppsStore

    init(historyStore: HistoryStore, excludedAppsStore: ExcludedAppsStore) {
        self.historyStore = historyStore
        self.excludedAppsStore = excludedAppsStore
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func didSelfCopy() {
        selfCopyChangeCount = NSPasteboard.general.changeCount
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let current = pasteboard.changeCount

        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // Skip if this was our own copy
        if let selfCount = selfCopyChangeCount, selfCount == current {
            selfCopyChangeCount = nil
            return
        }
        selfCopyChangeCount = nil

        // Skip if frontmost app is excluded
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedAppsStore.isExcluded(bundleID) {
            return
        }

        let types = pasteboard.types ?? []
        let id = UUID()

        // 1. File URLs
        if types.contains(.fileURL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            let paths = urls.map { $0.path }
            let item = HistoryItem(
                id: id,
                contentType: .fileURL,
                fileURLs: paths
            )
            historyStore.add(item)
            return
        }

        // 2. Image (PNG or TIFF)
        if types.contains(.png) || types.contains(.tiff) {
            let imageData: Data?
            if types.contains(.png) {
                imageData = pasteboard.data(forType: .png)
            } else {
                imageData = pasteboard.data(forType: .tiff)
            }
            if let data = imageData {
                let ext = types.contains(.png) ? "png" : "tiff"
                let blobFile = BlobStorage.save(data, id: id, ext: ext)
                let item = HistoryItem(
                    id: id,
                    contentType: .image,
                    blobFile: blobFile
                )
                historyStore.add(item)
                return
            }
        }

        // 3. PDF
        if types.contains(.pdf) {
            if let data = pasteboard.data(forType: .pdf) {
                let blobFile = BlobStorage.save(data, id: id, ext: "pdf")
                let item = HistoryItem(
                    id: id,
                    contentType: .pdf,
                    blobFile: blobFile
                )
                historyStore.add(item)
                return
            }
        }

        // 4. Color
        if types.contains(.color) {
            if let data = pasteboard.data(forType: .color),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                let c = color.usingColorSpace(.sRGB) ?? color
                let components = [
                    Double(c.redComponent),
                    Double(c.greenComponent),
                    Double(c.blueComponent),
                    Double(c.alphaComponent)
                ]
                let item = HistoryItem(
                    id: id,
                    contentType: .color,
                    colorComponents: components
                )
                historyStore.add(item)
                return
            }
        }

        // 5. Text (with optional rich text blob)
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            var blobFile: String?
            // Save RTF blob if present for faithful paste-back
            if let rtfData = pasteboard.data(forType: .rtf) {
                blobFile = BlobStorage.save(rtfData, id: id, ext: "rtf")
            } else if let htmlData = pasteboard.data(forType: .html) {
                blobFile = BlobStorage.save(htmlData, id: id, ext: "html")
            }

            let item = HistoryItem(
                id: id,
                value: string,
                contentType: .text,
                blobFile: blobFile
            )
            historyStore.add(item)
        }
    }
}

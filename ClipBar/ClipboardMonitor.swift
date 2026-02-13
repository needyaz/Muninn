import AppKit
import Combine

@Observable
class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var selfCopyChangeCount: Int?
    private let historyStore: HistoryStore
    private let excludedAppsStore: ExcludedAppsStore

    var isPaused = false
    var pauseResumeDate: Date?
    private var pauseTimer: Timer?

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

    // MARK: - Pause / Resume

    func pause(for duration: TimeInterval?) {
        isPaused = true
        pauseTimer?.invalidate()
        pauseTimer = nil

        if let duration {
            pauseResumeDate = Date().addingTimeInterval(duration)
            pauseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.resume()
            }
        } else {
            pauseResumeDate = nil
        }
    }

    func resume() {
        isPaused = false
        pauseResumeDate = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
        // Re-sync change count so we don't capture stale clipboard content
        lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Polling

    private func poll() {
        guard !isPaused else { return }

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

        // Capture source app bundle ID
        let sourceAppBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // Skip if frontmost app is excluded
        if let bundleID = sourceAppBundleID,
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

            // Save file data as blob so export/import preserves the actual content
            var blobFile: String?
            if urls.count == 1, let data = try? Data(contentsOf: urls[0]) {
                let ext = urls[0].pathExtension.isEmpty ? "dat" : urls[0].pathExtension
                blobFile = BlobStorage.save(data, id: id, ext: ext)
            }

            let item = HistoryItem(
                id: id,
                contentType: .fileURL,
                blobFile: blobFile,
                fileURLs: paths,
                sourceAppBundleID: sourceAppBundleID
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
                    blobFile: blobFile,
                    sourceAppBundleID: sourceAppBundleID
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
                    blobFile: blobFile,
                    sourceAppBundleID: sourceAppBundleID
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
                    colorComponents: components,
                    sourceAppBundleID: sourceAppBundleID
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
                blobFile: blobFile,
                sourceAppBundleID: sourceAppBundleID
            )
            historyStore.add(item)
        }
    }
}

import AppKit
import os.log

private let logger = Logger(subsystem: "blue.luci.Muninn", category: "ScreenshotMonitor")

@Observable
class ScreenshotMonitor {
    private var query: NSMetadataQuery?
    private var knownPaths: Set<String> = []
    /// Paths we've seen but haven't successfully copied yet — allows changed events to retry
    private var pendingPaths: Set<String> = []
    private let settingsStore: SettingsStore
    private let onCopied: (Int, String?) -> Void
    private var folderURL: URL?

    init(settingsStore: SettingsStore, onCopied: @escaping (Int, String?) -> Void) {
        self.settingsStore = settingsStore
        self.onCopied = onCopied
    }

    func start(folderURL: URL?) {
        guard let folderURL = folderURL else { return }
        self.folderURL = folderURL
        _ = folderURL.startAccessingSecurityScopedResource()

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [folderURL]
        query.operationQueue = .main
        self.query = query

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGatherComplete(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQueryUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        query.start()
    }

    func stop() {
        query?.stop()
        NotificationCenter.default.removeObserver(self)
        query = nil
        folderURL?.stopAccessingSecurityScopedResource()
        folderURL = nil
    }

    func restart(folderURL: URL?) {
        stop()
        start(folderURL: folderURL)
    }

    @objc private func handleGatherComplete(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.disableUpdates()
        for i in 0..<query.resultCount {
            if let item = query.result(at: i) as? NSMetadataItem,
               let path = item.value(forAttribute: kMDItemPath as String) as? String {
                knownPaths.insert(path)
            }
        }
        query.enableUpdates()
    }

    @objc private func handleQueryUpdate(_ notification: Notification) {
        let addedItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]
        let changedItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]

        let itemsToProcess = (addedItems ?? []) + (changedItems ?? [])
        guard !itemsToProcess.isEmpty else { return }

        for item in itemsToProcess {
            guard settingsStore.captureScreenshots else { continue }
            guard let path = item.value(forAttribute: kMDItemPath as String) as? String else { continue }
            guard !knownPaths.contains(path) else { continue }

            if pendingPaths.contains(path) { continue }
            pendingPaths.insert(path)
            copyToPasteboard(path: path)
        }
    }

    private func copyToPasteboard(path: String, attempt: Int = 1) {
        let url = URL(fileURLWithPath: path)

        do {
            let data = try Data(contentsOf: url)

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(data, forType: .png)
            onCopied(pasteboard.changeCount, (path as NSString).lastPathComponent)

            knownPaths.insert(path)
            pendingPaths.remove(path)
        } catch {
            if attempt <= 5 {
                let delay = Double(attempt) * 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.copyToPasteboard(path: path, attempt: attempt + 1)
                }
            } else {
                logger.error("Failed to read screenshot after \(attempt, privacy: .public) attempts: \(path, privacy: .public)")
                pendingPaths.remove(path)
            }
        }
    }
}

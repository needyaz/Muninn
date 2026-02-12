import AppKit
import Combine

@Observable
class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var selfCopyChangeCount: Int?
    private let historyStore: HistoryStore
    private let excludedAppsStore: ExcludedAppsStore

    private static let maxSize = 50_000 // 50 KB

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

        guard let string = pasteboard.string(forType: .string) else { return }

        // Skip empty/whitespace
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Skip entries over max size
        guard string.utf8.count <= Self.maxSize else { return }

        historyStore.add(string)
    }
}

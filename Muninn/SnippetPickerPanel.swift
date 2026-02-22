import AppKit
import SwiftUI

class SnippetPickerPanel {
    static let shared = SnippetPickerPanel()

    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?

    func toggle(clipStore: ClipStore, settingsStore: SettingsStore, monitor: ClipboardMonitor) {
        if let panel, panel.isVisible {
            close()
        } else {
            show(clipStore: clipStore, settingsStore: settingsStore, monitor: monitor)
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func show(clipStore: ClipStore, settingsStore: SettingsStore, monitor: ClipboardMonitor) {
        previousApp = NSWorkspace.shared.frontmostApplication

        let view = SnippetPickerView(
            clipStore: clipStore,
            settingsStore: settingsStore,
            monitor: monitor,
            previousApp: previousApp,
            onDismiss: { [weak self] in self?.close() }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
    }
}

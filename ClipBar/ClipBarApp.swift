import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopover = Self("togglePopover")
}

@main
struct ClipBarApp: App {
    @State private var settingsStore: SettingsStore
    @State private var store: ClipStore
    @State private var historyStore: HistoryStore
    @State private var excludedAppsStore: ExcludedAppsStore
    @State private var excludedTypesStore: ExcludedTypesStore
    @State private var statsStore: StatsStore
    @State private var monitor: ClipboardMonitor?

    init() {
        StoragePaths.migrateIfNeeded()
        let settings = SettingsStore()
        _settingsStore = State(initialValue: settings)
        _store = State(initialValue: ClipStore())
        _historyStore = State(initialValue: HistoryStore(settingsStore: settings))
        _excludedAppsStore = State(initialValue: ExcludedAppsStore())
        _excludedTypesStore = State(initialValue: ExcludedTypesStore())
        _statsStore = State(initialValue: StatsStore())
    }

    var body: some Scene {
        MenuBarExtra("ClipBar", systemImage: monitor?.isPaused == true ? "pause.circle" : "clipboard") {
            PopoverContentView()
                .environment(settingsStore)
                .environment(store)
                .environment(historyStore)
                .environment(excludedAppsStore)
                .environment(excludedTypesStore)
                .environment(statsStore)
                .environment(monitor ?? ClipboardMonitor(historyStore: historyStore, excludedAppsStore: excludedAppsStore, excludedTypesStore: excludedTypesStore, settingsStore: settingsStore, statsStore: statsStore))
                .onAppear {
                    if monitor == nil {
                        let m = ClipboardMonitor(historyStore: historyStore, excludedAppsStore: excludedAppsStore, excludedTypesStore: excludedTypesStore, settingsStore: settingsStore, statsStore: statsStore)
                        m.start()
                        monitor = m
                        setupGlobalHotkey()
                        observeHistoryLimitChanges()
                    }
                }
        }
        .menuBarExtraStyle(.window)

        Window("Edit Clips", id: "editor") {
            ClipEditorView()
                .environment(store)
        }
        .defaultSize(width: 450, height: 350)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(settingsStore)
                .environment(excludedAppsStore)
                .environment(excludedTypesStore)
                .environment(statsStore)
                .environment(historyStore)
                .environment(store)
        }
    }

    private func setupGlobalHotkey() {
        KeyboardShortcuts.onKeyUp(for: .togglePopover) {
            toggleMenuBarPopover()
        }
    }

    private func observeHistoryLimitChanges() {
        NotificationCenter.default.addObserver(
            forName: .historyLimitChanged,
            object: nil,
            queue: .main
        ) { _ in
            historyStore.trimToLimit()
            historyStore.save()
        }
    }
}

private func toggleMenuBarPopover() {
    // Find the status bar button and click it to toggle the popover
    if let window = NSApp.windows.first(where: {
        $0.className.contains("NSStatusBarWindow") || $0.className.contains("MenuBarExtra")
    }) {
        // Attempt to find the status item button
        if let button = window.contentView?.subviews.compactMap({ $0 as? NSStatusBarButton }).first {
            button.performClick(nil)
            return
        }
    }
    // Fallback: iterate status items
    for window in NSApp.windows {
        if let button = window.value(forKey: "statusItemButton") as? NSStatusBarButton {
            button.performClick(nil)
            return
        }
    }
    // Last resort: send a click to all status bar buttons we can find
    if let button = NSApp.windows.lazy.compactMap({ $0.contentView }).flatMap({ $0.subviews }).first(where: { $0 is NSStatusBarButton }) as? NSStatusBarButton {
        button.performClick(nil)
    }
}

import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopover = Self("togglePopover")
    static let snippetPicker = Self("snippetPicker")
}

@main
struct MuninnApp: App {
    @State private var settingsStore: SettingsStore
    @State private var store: ClipStore
    @State private var historyStore: HistoryStore
    @State private var excludedAppsStore: ExcludedAppsStore
    @State private var excludedTypesStore: ExcludedTypesStore
    @State private var statsStore: StatsStore
    /// Nil only in the debug screenshot mode, which never creates either monitor.
    @State private var monitor: ClipboardMonitor?
    @State private var screenshotMonitor: ScreenshotMonitor?

    init() {
        #if DEBUG
        if ScreenshotMode.isRequested {
            // Fixture data in a temporary folder and a private defaults suite: nothing real is read, and no monitor exists.
            let stores = ScreenshotFixtures.makeStores(baseURL: ScreenshotMode.makeFixtureDirectory(), defaults: ScreenshotFixtures.makeDefaults())
            _settingsStore = State(initialValue: stores.settings)
            _store = State(initialValue: stores.clips)
            _historyStore = State(initialValue: stores.history)
            _excludedAppsStore = State(initialValue: stores.excludedApps)
            _excludedTypesStore = State(initialValue: stores.excludedTypes)
            _statsStore = State(initialValue: stores.stats)
            _monitor = State(initialValue: nil)
            _screenshotMonitor = State(initialValue: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated { ScreenshotMode.run(stores: stores) }
            }
            return
        }
        #endif
        StoragePaths.migrateIfNeeded()
        let settings = SettingsStore()
        let history = HistoryStore(settingsStore: settings)
        let excludedApps = ExcludedAppsStore()
        let excludedTypes = ExcludedTypesStore()
        let stats = StatsStore()
        _settingsStore = State(initialValue: settings)
        let clips = ClipStore()
        _store = State(initialValue: clips)
        _historyStore = State(initialValue: history)
        _excludedAppsStore = State(initialValue: excludedApps)
        _excludedTypesStore = State(initialValue: excludedTypes)
        _statsStore = State(initialValue: stats)

        let m = ClipboardMonitor(historyStore: history, excludedAppsStore: excludedApps, excludedTypesStore: excludedTypes, settingsStore: settings, statsStore: stats)
        m.start()
        _monitor = State(initialValue: m)

        let sm = ScreenshotMonitor(settingsStore: settings) { changeCount, filename in
            m.noteScreenshot(changeCount: changeCount, filename: filename)
        }
        sm.start(folderURL: settings.screenshotFolderURL)
        _screenshotMonitor = State(initialValue: sm)

        // Registered here, not when the popover first appears: the hotkeys and observers must work from launch.
        Self.registerHotkeys(clipStore: clips, settingsStore: settings, monitor: m)
        Self.observeChanges(historyStore: history, settingsStore: settings, screenshotMonitor: sm)
    }

    var body: some Scene {
        MenuBarExtra("Muninn", image: monitor?.isPaused == true ? "MenuBarIconPaused" : "MenuBarIcon") {
            PopoverContentView()
                .environment(settingsStore)
                .environment(store)
                .environment(historyStore)
                .environment(excludedAppsStore)
                .environment(excludedTypesStore)
                .environment(statsStore)
                .environment(monitor)
        }
        .menuBarExtraStyle(.window)

        Window("Edit Clips", id: "editor") {
            ClipEditorView()
                .environment(store)
        }
        .defaultSize(width: 450, height: 350)
        .windowResizability(.contentSize)

        Window("Welcome to Muninn", id: "onboarding") {
            OnboardingView()
                .environment(settingsStore)
        }
        .defaultSize(width: 500, height: 420)
        .windowResizability(.contentSize)

        Window("Muninn Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 440, height: 520)
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

    private static func registerHotkeys(clipStore: ClipStore, settingsStore: SettingsStore, monitor: ClipboardMonitor) {
        KeyboardShortcuts.onKeyUp(for: .togglePopover) {
            toggleMenuBarPopover()
        }
        KeyboardShortcuts.onKeyUp(for: .snippetPicker) {
            SnippetPickerPanel.shared.toggle(clipStore: clipStore, settingsStore: settingsStore, monitor: monitor)
        }
    }

    private static func observeChanges(historyStore: HistoryStore, settingsStore: SettingsStore, screenshotMonitor: ScreenshotMonitor) {
        NotificationCenter.default.addObserver(forName: .historyLimitChanged, object: nil, queue: .main) { _ in
            historyStore.trimToLimit()
            historyStore.save()
        }
        NotificationCenter.default.addObserver(forName: .screenshotFolderChanged, object: nil, queue: .main) { _ in
            screenshotMonitor.restart(folderURL: settingsStore.screenshotFolderURL)
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

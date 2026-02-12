import SwiftUI

@main
struct ClipBarApp: App {
    @State private var store = ClipStore()
    @State private var historyStore = HistoryStore()
    @State private var excludedAppsStore = ExcludedAppsStore()
    @State private var monitor: ClipboardMonitor?

    var body: some Scene {
        MenuBarExtra("ClipBar", systemImage: "clipboard") {
            PopoverContentView()
                .environment(store)
                .environment(historyStore)
                .environment(excludedAppsStore)
                .environment(monitor ?? ClipboardMonitor(historyStore: historyStore, excludedAppsStore: excludedAppsStore))
                .onAppear {
                    if monitor == nil {
                        let m = ClipboardMonitor(historyStore: historyStore, excludedAppsStore: excludedAppsStore)
                        m.start()
                        monitor = m
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

        Window("Excluded Apps", id: "excluded-apps") {
            ExcludedAppsView()
                .environment(excludedAppsStore)
        }
        .defaultSize(width: 400, height: 500)
        .windowResizability(.contentSize)
    }
}

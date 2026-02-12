import SwiftUI

@main
struct ClipBarApp: App {
    @State private var store = ClipStore()
    @State private var historyStore = HistoryStore()
    @State private var monitor: ClipboardMonitor?

    var body: some Scene {
        MenuBarExtra("ClipBar", systemImage: "clipboard") {
            PopoverContentView()
                .environment(store)
                .environment(historyStore)
                .environment(monitor ?? ClipboardMonitor(historyStore: historyStore))
                .onAppear {
                    if monitor == nil {
                        let m = ClipboardMonitor(historyStore: historyStore)
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
    }
}

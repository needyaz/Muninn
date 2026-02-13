import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ExcludedAppsView()
                .tabItem { Label("Excluded Apps", systemImage: "xmark.app") }
            ShortcutTab()
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
        }
        .frame(width: 450, height: 500)
    }
}

private struct GeneralTab: View {
    @Environment(SettingsStore.self) private var settingsStore

    private let limitOptions = [25, 50, 100, 200, 500]

    var body: some View {
        @Bindable var settings = settingsStore
        Form {
            Picker("History limit:", selection: $settings.historyLimit) {
                ForEach(limitOptions, id: \.self) { n in
                    Text("\(n) items").tag(n)
                }
            }
            .onChange(of: settingsStore.historyLimit) {
                // Post notification so HistoryStore can trim
                NotificationCenter.default.post(name: .historyLimitChanged, object: nil)
            }

            Toggle("Paste as plain text by default", isOn: $settings.pasteAsPlainText)
                .padding(.top, 4)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ShortcutTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle ClipBar:", name: .togglePopover)
        }
        .formStyle(.grouped)
        .padding()
    }
}

extension Notification.Name {
    static let historyLimitChanged = Notification.Name("historyLimitChanged")
}

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ExcludedAppsTab()
                .tabItem { Label("Excluded Apps", systemImage: "xmark.app") }
            ShortcutTab()
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
        }
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
                NotificationCenter.default.post(name: .historyLimitChanged, object: nil)
            }

            Toggle("Paste as plain text by default", isOn: $settings.pasteAsPlainText)
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}

private struct ExcludedAppsTab: View {
    var body: some View {
        ExcludedAppsView()
            .frame(width: 400, height: 450)
    }
}

private struct ShortcutTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle ClipBar:", name: .togglePopover)
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}

extension Notification.Name {
    static let historyLimitChanged = Notification.Name("historyLimitChanged")
}

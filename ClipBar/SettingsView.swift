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
            DataTab()
                .tabItem { Label("Data", systemImage: "externaldrive") }
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

private struct DataTab: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(HistoryStore.self) private var historyStore
    @Environment(ClipStore.self) private var clipStore
    @Environment(ExcludedAppsStore.self) private var excludedAppsStore

    @State private var showImportConfirmation = false
    @State private var importURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showExportSuccess = false

    var body: some View {
        Form {
            Section("Export") {
                Button("Export Data\u{2026}") {
                    exportData()
                }
                Text("Exports all history, snippets, settings, and excluded apps to a file.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Section("Import") {
                Button("Import Data\u{2026}") {
                    chooseImportFile()
                }
                Text("Replaces all current data with the imported file.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .alert("Import Data", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) { importURL = nil }
            Button("Replace All Data", role: .destructive) {
                performImport()
            }
        } message: {
            Text("This will replace all your current data including history, snippets, settings, and excluded apps. This cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK") {}
        } message: {
            Text("Your data has been exported successfully.")
        }
    }

    private func exportData() {
        DispatchQueue.main.async {
            let previousPolicy = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let panel = NSSavePanel()
            panel.nameFieldStringValue = "ClipBar Export.clipbar"
            panel.canCreateDirectories = true
            let response = panel.runModal()

            NSApp.setActivationPolicy(previousPolicy)

            guard response == .OK, let url = panel.url else { return }

            do {
                let data = try DataPorter.buildExportData()
                try data.write(to: url, options: .atomic)
                showExportSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func chooseImportFile() {
        DispatchQueue.main.async {
            let previousPolicy = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            let response = panel.runModal()

            NSApp.setActivationPolicy(previousPolicy)

            guard response == .OK, let url = panel.url else { return }

            importURL = url
            showImportConfirmation = true
        }
    }

    private func performImport() {
        guard let url = importURL else { return }
        defer { importURL = nil }

        do {
            try DataPorter.importData(
                from: url,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                settingsStore: settingsStore
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

extension Notification.Name {
    static let historyLimitChanged = Notification.Name("historyLimitChanged")
}

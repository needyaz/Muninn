import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ExcludedAppsTab()
                .tabItem { Label("Excluded Apps", systemImage: "xmark.app") }
            ExcludedTypesTab()
                .tabItem { Label("Excluded Types", systemImage: "line.3.horizontal.decrease.circle") }
            StatsTab()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            ShortcutTab()
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
            DataTab()
                .tabItem { Label("Data", systemImage: "externaldrive") }
        }
    }
}

private struct GeneralTab: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(HistoryStore.self) private var historyStore

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

            Toggle("Show rich previews", isOn: $settings.enableRichPreviews)

            Toggle("Track clipboard statistics", isOn: $settings.enableStats)

            Toggle("Auto-capture screenshots to clipboard", isOn: $settings.captureScreenshots)

            Toggle("Extract text from images (OCR)", isOn: $settings.enableOCR)
                .onChange(of: settingsStore.enableOCR) { _, newValue in
                    if newValue { historyStore.scanForOCR() }
                }

            Toggle("Detect QR codes and barcodes in images", isOn: $settings.enableQRDetection)
                .onChange(of: settingsStore.enableQRDetection) { _, newValue in
                    if newValue { historyStore.scanForBarcodes() }
                }

            Picker("Sensitive content:", selection: $settings.sensitiveHandling) {
                Text("Don't record").tag("skip")
                Text("Record masked").tag("mask")
                Text("Record normally").tag("allow")
            }
            .help("How to handle passwords and other sensitive clipboard items from password managers")

            HStack {
                Picker("Capture sound:", selection: $settings.captureSound) {
                    Text("None").tag("")
                    Divider()
                    ForEach(systemSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                if !settingsStore.captureSound.isEmpty {
                    Button("Preview") {
                        NSSound(named: NSSound.Name(settingsStore.captureSound))?.play()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
    }

    private let systemSounds = [
        "Tink", "Pop", "Glass", "Bottle", "Frog", "Funk",
        "Ping", "Purr", "Submarine", "Wobble", "Basso", "Blow",
    ]
}

private struct ExcludedAppsTab: View {
    var body: some View {
        ExcludedAppsView()
            .frame(width: 500, height: 450)
    }
}

private struct ExcludedTypesTab: View {
    @Environment(ExcludedTypesStore.self) private var excludedTypesStore

    var body: some View {
        Form {
            ForEach(ClipboardContentType.allCases, id: \.self) { type in
                Toggle(isOn: Binding(
                    get: { excludedTypesStore.isExcluded(type) },
                    set: { _ in excludedTypesStore.toggle(type) }
                )) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(type.displayName)
                            Text(type.typeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: type.systemImage)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
    }
}

private struct StatsTab: View {
    var body: some View {
        StatsView()
    }
}

private struct ShortcutTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle ClipBar:", name: .togglePopover)
            KeyboardShortcuts.Recorder("Snippet Picker:", name: .snippetPicker)
        }
        .formStyle(.grouped)
        .frame(width: 500)
    }
}

private struct DataTab: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(HistoryStore.self) private var historyStore
    @Environment(ClipStore.self) private var clipStore
    @Environment(ExcludedAppsStore.self) private var excludedAppsStore
    @Environment(ExcludedTypesStore.self) private var excludedTypesStore

    @State private var showImportConfirmation = false
    @State private var importURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showExportSuccess = false
    @State private var showImportSuccess = false
    @State private var importResultMessage = ""

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
                Text("Import from a backup file. You can merge or replace your current data.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .alert("Import Data", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) { importURL = nil }
            Button("Merge") {
                performImport(merge: true)
            }
            Button("Replace All", role: .destructive) {
                performImport(merge: false)
            }
        } message: {
            Text("Merge adds new items and keeps your current data. Replace overwrites everything.")
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
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") {}
        } message: {
            Text(importResultMessage)
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

    private func performImport(merge: Bool) {
        guard let url = importURL else { return }
        defer { importURL = nil }

        do {
            let result = try DataPorter.importData(
                from: url,
                merge: merge,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )
            var parts: [String] = [
                "\(result.historyCount) history item\(result.historyCount == 1 ? "" : "s")",
                "\(result.clipCount) snippet\(result.clipCount == 1 ? "" : "s")",
                "\(result.excludedAppCount) excluded app\(result.excludedAppCount == 1 ? "" : "s")",
                "\(result.excludedTypeCount) excluded type\(result.excludedTypeCount == 1 ? "" : "s")",
            ]
            if result.imageCount > 0 {
                parts.append("\(result.imageCount) image\(result.imageCount == 1 ? "" : "s")")
            }
            if result.pdfCount > 0 {
                parts.append("\(result.pdfCount) PDF\(result.pdfCount == 1 ? "" : "s")")
            }
            if result.richTextCount > 0 {
                parts.append("\(result.richTextCount) rich text format\(result.richTextCount == 1 ? "" : "s")")
            }
            let last = parts.removeLast()
            let verb = merge ? "Merged" : "Imported"
            importResultMessage = verb + " " + (parts.isEmpty ? last : parts.joined(separator: ", ") + ", and " + last) + "."
            showImportSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

extension Notification.Name {
    static let historyLimitChanged = Notification.Name("historyLimitChanged")
}

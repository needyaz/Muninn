import SwiftUI

private struct InstalledApp: Identifiable {
    let id: String // bundleIdentifier
    let name: String
    let icon: NSImage
}

struct ExcludedAppsView: View {
    @Environment(ExcludedAppsStore.self) private var store

    @State private var apps: [InstalledApp] = []
    @State private var search = ""

    private var filteredApps: [InstalledApp] {
        if search.isEmpty { return apps }
        let q = search.lowercased()
        return apps.filter { $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps…", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)

            Divider()

            List {
                ForEach(filteredApps) { app in
                    HStack {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text(app.name)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.isExcluded(app.id) },
                            set: { _ in store.toggle(app.id) }
                        ))
                        .toggleStyle(.switch)
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .onAppear { loadInstalledApps() }
    }

    private func loadInstalledApps() {
        var seen = Set<String>()
        var result: [InstalledApp] = []
        let ownBundleID = Bundle.main.bundleIdentifier

        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        for dir in dirs {
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                // Don't recurse into .app bundles
                enumerator.skipDescendants()

                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      bundleID != ownBundleID,
                      !seen.contains(bundleID) else { continue }

                seen.insert(bundleID)

                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let icon = NSWorkspace.shared.icon(forFile: url.path)
                result.append(InstalledApp(id: bundleID, name: name, icon: icon))
            }
        }

        apps = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

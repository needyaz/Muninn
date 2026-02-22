import Foundation

@Observable
class ExcludedAppsStore {
    var excludedBundleIDs: Set<String> = []

    private let fileURL: URL

    init(baseURL: URL = StoragePaths.base) {
        self.fileURL = baseURL.appendingPathComponent("excluded_apps.json")
        load()
    }

    func isExcluded(_ bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    func toggle(_ bundleID: String) {
        if excludedBundleIDs.contains(bundleID) {
            excludedBundleIDs.remove(bundleID)
        } else {
            excludedBundleIDs.insert(bundleID)
        }
        save()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let ids = try JSONDecoder().decode(Set<String>.self, from: data)
            excludedBundleIDs = ids
        } catch {
            print("Muninn: failed to load excluded apps: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(excludedBundleIDs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Muninn: failed to save excluded apps: \(error)")
        }
    }
}

import Foundation

@Observable
class ExcludedTypesStore {
    var excludedTypes: Set<ClipboardContentType> = []

    private let fileURL: URL

    init(baseURL: URL = StoragePaths.base) {
        self.fileURL = baseURL.appendingPathComponent("excluded_types.json")
        load()
    }

    func isExcluded(_ type: ClipboardContentType) -> Bool {
        excludedTypes.contains(type)
    }

    func toggle(_ type: ClipboardContentType) {
        if excludedTypes.contains(type) {
            excludedTypes.remove(type)
        } else {
            excludedTypes.insert(type)
        }
        save()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let types = try JSONDecoder().decode(Set<ClipboardContentType>.self, from: data)
            excludedTypes = types
        } catch {
            print("ClipBar: failed to load excluded types: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(excludedTypes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ClipBar: failed to save excluded types: \(error)")
        }
    }
}

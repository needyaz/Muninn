import Foundation

enum StoragePaths {
    static let base: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let blobs: URL = {
        let url = base.appendingPathComponent("blobs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func migrateIfNeeded() {
        let fm = FileManager.default
        let oldDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/clipbar", isDirectory: true)

        guard fm.fileExists(atPath: oldDir.path) else { return }

        // Skip if new directory already has data
        let contents = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
        let hasData = contents.contains { $0.hasSuffix(".json") || $0 == "blobs" }
        guard !hasData else { return }

        // Copy everything from old directory to new
        guard let items = try? fm.contentsOfDirectory(atPath: oldDir.path) else { return }
        for item in items {
            let src = oldDir.appendingPathComponent(item)
            let dst = base.appendingPathComponent(item)
            try? fm.copyItem(at: src, to: dst)
        }
    }
}

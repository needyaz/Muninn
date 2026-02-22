import Foundation

enum StoragePaths {
    static var baseOverride: URL? = nil

    static var base: URL {
        if let override = baseOverride { return override }
        return _base
    }

    private static let _base: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Muninn", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static var blobs: URL {
        let url = base.appendingPathComponent("blobs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func migrateIfNeeded() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        // Migrate from ClipBar → Muninn (rebrand)
        let clipBarDir = appSupport.appendingPathComponent("ClipBar", isDirectory: true)
        if fm.fileExists(atPath: clipBarDir.path) {
            let contents = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
            let hasData = contents.contains { $0.hasSuffix(".json") || $0 == "blobs" }
            if !hasData {
                guard let items = try? fm.contentsOfDirectory(atPath: clipBarDir.path) else { return }
                for item in items {
                    let src = clipBarDir.appendingPathComponent(item)
                    let dst = base.appendingPathComponent(item)
                    try? fm.copyItem(at: src, to: dst)
                }
            }
            return
        }

        // Migrate from legacy .config/clipbar
        let oldDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/clipbar", isDirectory: true)
        guard fm.fileExists(atPath: oldDir.path) else { return }

        let contents = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
        let hasData = contents.contains { $0.hasSuffix(".json") || $0 == "blobs" }
        guard !hasData else { return }

        guard let items = try? fm.contentsOfDirectory(atPath: oldDir.path) else { return }
        for item in items {
            let src = oldDir.appendingPathComponent(item)
            let dst = base.appendingPathComponent(item)
            try? fm.copyItem(at: src, to: dst)
        }
    }
}

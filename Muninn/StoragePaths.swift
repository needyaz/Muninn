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
        makePrivateDirectory(url)
        return url
    }()

    static var blobs: URL {
        let url = base.appendingPathComponent("blobs", isDirectory: true)
        makePrivateDirectory(url)
        return url
    }

    /// Clipboard history is sensitive: the folder is readable by the owner only and left out of Time Machine and other backups.
    private static func makePrivateDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try? mutable.setResourceValues(values)
    }

    /// Muninn was called ClipBar before release: copy a leftover ClipBar folder in if there is no Muninn data yet.
    static func migrateIfNeeded() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clipBarDir = appSupport.appendingPathComponent("ClipBar", isDirectory: true)
        guard fm.fileExists(atPath: clipBarDir.path) else { return }

        let contents = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
        guard !contents.contains(where: { $0.hasSuffix(".json") || $0 == "blobs" }) else { return }
        for item in (try? fm.contentsOfDirectory(atPath: clipBarDir.path)) ?? [] {
            try? fm.copyItem(at: clipBarDir.appendingPathComponent(item), to: base.appendingPathComponent(item))
        }
    }
}

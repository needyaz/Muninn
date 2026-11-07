import Foundation

enum BlobStorage {
    static var blobDirOverride: URL? = nil
    private static var blobDir: URL { blobDirOverride ?? StoragePaths.blobs }

    /// Blob filenames come from `history.json`, `clips.json` and import files, so they are untrusted.
    /// A valid name is a single path component of letters, digits, `.`, `_` and `-`, with no leading dot,
    /// so it can never point outside the blob directory.
    static func isValidFilename(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 128, !name.hasPrefix(".") else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            (scalar.value < 128) && (CharacterSet.alphanumerics.contains(scalar) || "._-".unicodeScalars.contains(scalar))
        }
    }

    private static func url(for filename: String) -> URL? {
        isValidFilename(filename) ? blobDir.appendingPathComponent(filename) : nil
    }

    static func save(_ data: Data, id: UUID, ext: String) -> String {
        let filename = "\(id.uuidString).\(ext)"
        let url = blobDir.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return filename
    }

    static func load(_ filename: String) -> Data? {
        guard let url = url(for: filename) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func delete(_ filename: String) {
        guard let url = url(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func restore(_ data: Data, filename: String) {
        guard let url = url(for: filename) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func copy(_ filename: String, newID: UUID) -> String? {
        guard let sourceURL = url(for: filename) else { return nil }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let ext = (filename as NSString).pathExtension
        let newFilename = "\(newID.uuidString).\(ext)"
        let destURL = blobDir.appendingPathComponent(newFilename)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return newFilename
        } catch {
            Log.storage.error("failed to copy blob: \(error.localizedDescription)")
            return nil
        }
    }
}

import Foundation

enum BlobStorage {
    static var blobDirOverride: URL? = nil
    private static var blobDir: URL { blobDirOverride ?? StoragePaths.blobs }

    static func save(_ data: Data, id: UUID, ext: String) -> String {
        let filename = "\(id.uuidString).\(ext)"
        let url = blobDir.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return filename
    }

    static func load(_ filename: String) -> Data? {
        let url = blobDir.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    static func delete(_ filename: String) {
        let url = blobDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    static func copy(_ filename: String, newID: UUID) -> String? {
        let sourceURL = blobDir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let ext = (filename as NSString).pathExtension
        let newFilename = "\(newID.uuidString).\(ext)"
        let destURL = blobDir.appendingPathComponent(newFilename)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return newFilename
        } catch {
            print("Muninn: failed to copy blob: \(error)")
            return nil
        }
    }
}

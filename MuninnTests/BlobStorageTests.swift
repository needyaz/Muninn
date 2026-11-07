import Testing
import Foundation
@testable import Muninn

@Suite("BlobStorage", .serialized)
struct BlobStorageTests {

    private func withTempBlobDir(_ body: (URL) throws -> Void) throws {
        let dir = makeTempDir().appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        BlobStorage.blobDirOverride = dir
        defer {
            BlobStorage.blobDirOverride = nil
            removeTempDir(dir.deletingLastPathComponent())
        }
        try body(dir)
    }

    @Test("save and load round-trip")
    func saveLoadRoundTrip() throws {
        try withTempBlobDir { _ in
            let data = Data("hello blob".utf8)
            let id = UUID()
            let filename = BlobStorage.save(data, id: id, ext: "txt")
            #expect(filename == "\(id.uuidString).txt")

            let loaded = BlobStorage.load(filename)
            #expect(loaded == data)
        }
    }

    @Test("load missing file returns nil")
    func loadMissing() throws {
        try withTempBlobDir { _ in
            #expect(BlobStorage.load("nonexistent.txt") == nil)
        }
    }

    @Test("delete removes file")
    func deleteFile() throws {
        try withTempBlobDir { _ in
            let data = Data("delete me".utf8)
            let filename = BlobStorage.save(data, id: UUID(), ext: "txt")
            BlobStorage.delete(filename)
            #expect(BlobStorage.load(filename) == nil)
        }
    }

    @Test("copy duplicates file with new ID")
    func copyFile() throws {
        try withTempBlobDir { _ in
            let data = Data("copy me".utf8)
            let filename = BlobStorage.save(data, id: UUID(), ext: "png")
            let newID = UUID()
            let copied = BlobStorage.copy(filename, newID: newID)
            #expect(copied == "\(newID.uuidString).png")
            #expect(BlobStorage.load(copied!) == data)
            // Original still exists
            #expect(BlobStorage.load(filename) == data)
        }
    }

    @Test("copy missing file returns nil")
    func copyMissing() throws {
        try withTempBlobDir { _ in
            let result = BlobStorage.copy("missing.png", newID: UUID())
            #expect(result == nil)
        }
    }

    // MARK: - Filename validation

    @Test("accepts the names Muninn generates and rejects anything that could leave the blob directory")
    func filenameValidation() {
        #expect(BlobStorage.isValidFilename("\(UUID().uuidString).png"))
        #expect(BlobStorage.isValidFilename("test-blob.png"))
        for bad in ["", ".", "..", "../history.json", "a/b.png", "/etc/passwd", ".hidden", "a\\b", "x\u{0}.png", "na\u{ef}ve.png",
                    String(repeating: "a", count: 200)] {
            #expect(!BlobStorage.isValidFilename(bad), "\(bad.debugDescription) should be rejected")
        }
    }

    @Test("load, delete, restore and copy ignore traversal names")
    func traversalNamesAreIgnored() throws {
        try withTempBlobDir { dir in
            let outside = dir.deletingLastPathComponent().appendingPathComponent("secret.txt")
            try Data("secret".utf8).write(to: outside)

            #expect(BlobStorage.load("../secret.txt") == nil)
            BlobStorage.delete("../secret.txt")
            #expect(FileManager.default.fileExists(atPath: outside.path))
            BlobStorage.restore(Data("x".utf8), filename: "../planted.txt")
            #expect(!FileManager.default.fileExists(atPath: dir.deletingLastPathComponent().appendingPathComponent("planted.txt").path))
            #expect(BlobStorage.copy("../secret.txt", newID: UUID()) == nil)
        }
    }
}

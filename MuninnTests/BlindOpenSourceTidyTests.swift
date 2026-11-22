import Testing
import Foundation

@Suite struct BlindOpenSourceTidyTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func textFiles() -> [URL] {
        let skip: Set<String> = [".git", "build", "DerivedData", "Muninn.xcodeproj"]
        var out: [URL] = []
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return out }
        for case let url as URL in e {
            if skip.contains(url.lastPathComponent) { e.skipDescendants(); continue }
            if url.lastPathComponent.hasPrefix("Blind") { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            out.append(url)
        }
        return out
    }

    @Test func noHomeDirectoryPathsInTree() {
        let needle = "/Us" + "ers/"
        for url in Self.textFiles() {
            guard let s = try? String(contentsOf: url, encoding: .utf8) else { continue }
            #expect(!s.contains(needle), "\(url.lastPathComponent) contains a home path")
        }
    }

    @Test func teamIDIsNotCommitted() {
        let team = "46XLY7" + "Y9P8"
        for url in Self.textFiles() {
            guard let s = try? String(contentsOf: url, encoding: .utf8) else { continue }
            #expect(!s.contains(team), "\(url.lastPathComponent) contains the team id")
        }
    }

    @Test func logoHasNoGeneratorMetadata() throws {
        let url = Self.root.appendingPathComponent("Muninn/Assets.xcassets/BlueLuciLogo.imageset/BlueLuciLogo.png")
        let data = try Data(contentsOf: url)
        for marker in ["caBX", "c2pa", "trainedAlgorithmicMedia", "OpenAI", "ChatGPT", "iTXt", "tEXt", "eXIf"] {
            #expect(data.range(of: Data(marker.utf8)) == nil, "logo contains \(marker)")
        }
    }
}

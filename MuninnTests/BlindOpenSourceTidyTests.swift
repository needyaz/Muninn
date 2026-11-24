import Testing
import Foundation

@Suite struct BlindOpenSourceTidyTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    /// Committed files only: `git ls-files` when available, otherwise a directory
    /// walk that honours the simple patterns in `.gitignore`.
    static func textFiles() -> [URL] {
        if let tracked = gitTrackedFiles(), !tracked.isEmpty { return tracked }
        return walkHonouringGitignore()
    }

    private static func gitTrackedFiles() -> [URL]? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "-C", root.path, "ls-files", "-z"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let names = String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
        return names
            .filter { !URL(fileURLWithPath: $0).lastPathComponent.hasPrefix("Blind") }
            .map { root.appendingPathComponent($0) }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
    }

    static func walkHonouringGitignore() -> [URL] {
        var skip: Set<String> = [".git"]
        var skipPaths: Set<String> = []
        if let ignore = try? String(contentsOf: root.appendingPathComponent(".gitignore"), encoding: .utf8) {
            for raw in ignore.split(separator: "\n") {
                var line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }
                if line.hasSuffix("/") { line.removeLast() }
                if line.hasPrefix("/") { line.removeFirst() }
                if line.contains("/") { skipPaths.insert(line) }
                else if line.contains("*") {
                    // `*.ext` / `*.ext/` style patterns only
                    if line.hasPrefix("*.") { skip.insert(line) } 
                } else { skip.insert(line) }
            }
        }
        var out: [URL] = []
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return out }
        for case let url as URL in e {
            let name = url.lastPathComponent
            let rel = String(url.path.dropFirst(root.path.count + 1))
            let ignoredByGlob = skip.contains { $0.hasPrefix("*.") && name.hasSuffix(String($0.dropFirst())) }
            if skip.contains(name) || skipPaths.contains(rel) || ignoredByGlob {
                e.skipDescendants(); continue
            }
            if name.hasPrefix("Blind") { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            out.append(url)
        }
        return out
    }

    @Test func gitignoredFilesAreNotScanned() {
        let paths = Self.walkHonouringGitignore().map(\.path)
        #expect(!paths.contains { $0.hasSuffix("/make/local.mk") })
        #expect(!paths.contains { $0.contains("/DerivedData/") })
        #expect(!paths.contains { $0.hasSuffix(".DS_Store") })
        #expect(!Self.textFiles().contains { $0.path.hasSuffix("/make/local.mk") })
    }

    @Test func workingFilesAreAbsentAndArchitectureDocExists() {
        let fm = FileManager.default
        for gone in ["CLAUDE.md", "spec", "deltas"] {
            #expect(!fm.fileExists(atPath: Self.root.appendingPathComponent(gone).path), "\(gone) should be absent")
        }
        #expect(fm.fileExists(atPath: Self.root.appendingPathComponent("docs/ARCHITECTURE.md").path))
    }

    @Test func appStoreUploadPassesTeam() throws {
        let mk = try String(contentsOf: Self.root.appendingPathComponent("make/store.mk"), encoding: .utf8)
        let block = try #require(mk.range(of: "_build-upload: generate")).upperBound
        let recipe = String(mk[block...])
        #expect(recipe.contains("TEAM is required"))
        #expect(recipe.contains("DEVELOPMENT_TEAM=$(TEAM)"))
        #expect(recipe.contains("teamID string $(TEAM)"))
        #expect(!recipe.contains("-exportOptionsPlist make/ExportOptions-upload.plist"))
    }

    @Test func teamIsCheckedBeforeAnyStoreStep() throws {
        let mk = try String(contentsOf: Self.root.appendingPathComponent("make/store.mk"), encoding: .utf8)
        let start = try #require(mk.range(of: "\n_preflight:\n")).upperBound
        let firstLine = mk[start...].split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        #expect(firstLine.contains("TEAM is required"))
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

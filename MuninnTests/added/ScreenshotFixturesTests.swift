import Testing
import Foundation
@testable import Muninn

/// Every piece of fixture text a screenshot can show: item values, OCR text, clip names and clip values.
private func fixtureTexts() -> [String] {
    var texts: [String] = []
    for item in ScreenshotFixtures.historyItems {
        if let value = item.value { texts.append(value) }
        if let ocr = item.ocrText { texts.append(ocr) }
    }
    for clip in ScreenshotFixtures.clips {
        texts.append(clip.name)
        if let value = clip.value { texts.append(value) }
    }
    return texts
}

@Suite("Screenshot fixtures and scenes", .serialized)
@MainActor
struct ScreenshotFixturesTests {

    @Test("MUN-BLD-004: the fixtures provide clipboard history and snippets")
    func fixturesAreNotEmpty() {
        #expect(!ScreenshotFixtures.historyItems.isEmpty)
        #expect(!ScreenshotFixtures.clips.isEmpty)
    }

    @Test("MUN-BLD-004: no fixture item is sensitive or uses password-like words")
    func fixturesAreNotSensitive() {
        let items = ScreenshotFixtures.historyItems
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.isSensitive != true })
        let words = ["password", "passcode", "secret", "token", "api key"]
        for text in fixtureTexts() {
            let lower = text.lowercased()
            for word in words {
                #expect(!lower.contains(word), "fixture text contains \(word): \(text)")
            }
        }
    }

    @Test("MUN-BLD-004: fixture timestamps are relative to the frozen clock, never after it")
    func timestampsFollowFrozenClock() {
        let items = ScreenshotFixtures.historyItems
        #expect(!items.isEmpty)
        for item in items {
            #expect(item.timestamp <= ScreenshotFixtures.now)
        }
    }

    @Test("MUN-BLD-004: there are at least four scenes, each with its own PNG file name and a caption")
    func sceneList() {
        let scenes = ScreenshotScene.all
        #expect(scenes.count >= 4)
        #expect(Set(scenes.map(\.id)).count == scenes.count)
        #expect(Set(scenes.map(\.fileName)).count == scenes.count)
        for scene in scenes {
            #expect(scene.fileName.lowercased().hasSuffix(".png"))
            #expect(!scene.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test("MUN-BLD-004: the screenshot defaults are a separate suite, not the standard defaults")
    func defaultsAreSeparate() {
        let suite = ScreenshotFixtures.defaultsSuiteName
        #expect(suite != "blue.luci.Muninn")
        #expect(suite != Bundle.main.bundleIdentifier)
        let key = "MuninnScreenshotFixturesTests-\(UUID().uuidString)"
        let defaults = ScreenshotFixtures.makeDefaults()
        defer {
            defaults.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        #expect(defaults !== UserDefaults.standard)
        defaults.set("x", forKey: key)
        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }

    @Test("MUN-BLD-004: the stores built for screenshots hold the fixture history and snippets")
    func storesHoldFixtures() {
        let dir = makeTempDir()
        let blobs = makeTempDir()
        let suite = "MuninnScreenshotStoresTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let savedBlobDir = BlobStorage.blobDirOverride
        BlobStorage.blobDirOverride = blobs
        defer {
            BlobStorage.blobDirOverride = savedBlobDir
            defaults.removePersistentDomain(forName: suite)
            removeTempDir(dir)
            removeTempDir(blobs)
        }
        let stores = ScreenshotFixtures.makeStores(baseURL: dir, defaults: defaults)
        let fixtureItems = ScreenshotFixtures.historyItems
        let fixtureClips = ScreenshotFixtures.clips
        #expect(!fixtureItems.isEmpty)
        #expect(stores.history.items.count == fixtureItems.count)
        #expect(Set(stores.history.items.compactMap(\.value)) == Set(fixtureItems.compactMap(\.value)))
        #expect(!fixtureClips.isEmpty)
        #expect(stores.clips.clips.map(\.name) == fixtureClips.map(\.name))
    }

    @Test("MUN-BLD-004: building the screenshot stores leaves the real storage folder untouched (KEEPS)")
    func realStorageUntouched() throws {
        let dir = makeTempDir()
        let real = makeTempDir()
        let blobs = makeTempDir()
        let suite = "MuninnScreenshotStoresTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let savedBase = StoragePaths.baseOverride
        let savedBlobDir = BlobStorage.blobDirOverride
        StoragePaths.baseOverride = real
        BlobStorage.blobDirOverride = blobs
        defer {
            StoragePaths.baseOverride = savedBase
            BlobStorage.blobDirOverride = savedBlobDir
            defaults.removePersistentDomain(forName: suite)
            removeTempDir(dir)
            removeTempDir(real)
            removeTempDir(blobs)
        }
        _ = ScreenshotFixtures.makeStores(baseURL: dir, defaults: defaults)
        let paths = try FileManager.default.subpathsOfDirectory(atPath: real.path)
        let files = paths.filter { path in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: real.appendingPathComponent(path).path, isDirectory: &isDir)
            return !isDir.boolValue
        }
        #expect(files.isEmpty, "screenshot stores wrote into the real storage folder: \(files)")
    }

    @Test("MUN-BLD-004: screenshots are 1280 x 800 points drawn at 2.25x (KEEPS)")
    func renderSize() {
        #expect(ScreenshotMode.pointSize == CGSize(width: 1280, height: 800))
        #expect(ScreenshotMode.pixelSize == CGSize(width: 2880, height: 1800))
        #expect(ScreenshotMode.scale == 2.25)
    }
}

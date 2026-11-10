import Testing
import Foundation
@testable import Muninn

@Suite("Screenshot mode creates no monitors", .serialized)
@MainActor
struct ScreenshotModeMonitorTests {
    @Test("MUN-BLD-004: building the screenshot stores and scenes never creates a clipboard or screenshot monitor")
    func noMonitorsCreated() {
        let dir = makeTempDir()
        let suite = "MuninnScreenshotMonitorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            removeTempDir(dir)
        }
        let clipboardBefore = ClipboardMonitor.createdCount
        let screenshotBefore = ScreenshotMonitor.createdCount
        let stores = ScreenshotFixtures.makeStores(baseURL: dir, defaults: defaults)
        for scene in ScreenshotScene.all { _ = scene.view(stores: stores) }
        #expect(ClipboardMonitor.createdCount == clipboardBefore)
        #expect(ScreenshotMonitor.createdCount == screenshotBefore)
    }

    @Test("MUN-BLD-004: the monitor counter counts real instances, so the no-monitor check can fail")
    func counterCountsInstances() {
        let dir = makeTempDir()
        let suite = "MuninnScreenshotMonitorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            removeTempDir(dir)
        }
        let stores = ScreenshotFixtures.makeStores(baseURL: dir, defaults: defaults)
        let before = ScreenshotMonitor.createdCount
        _ = ScreenshotMonitor(settingsStore: stores.settings) { _, _ in }
        #expect(ScreenshotMonitor.createdCount == before + 1)
    }
}

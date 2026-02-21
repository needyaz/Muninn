import Testing
import Foundation
@testable import ClipBar

@Suite("StatsStore")
struct StatsStoreTests {

    private func makeStore() -> (StatsStore, URL) {
        let dir = makeTempDir()
        let store = StatsStore(baseURL: dir)
        return (store, dir)
    }

    @Test("recordCapture increments totalCopies")
    func recordCaptureTotal() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.recordCapture(contentType: .text, sourceApp: "com.test.app")
        store.recordCapture(contentType: .text, sourceApp: "com.test.app")
        #expect(store.stats.totalCopies == 2)
    }

    @Test("recordCapture tracks type counts")
    func recordCaptureTypeCounts() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.recordCapture(contentType: .text, sourceApp: nil)
        store.recordCapture(contentType: .image, sourceApp: nil)
        store.recordCapture(contentType: .text, sourceApp: nil)
        #expect(store.stats.typeCounts["text"] == 2)
        #expect(store.stats.typeCounts["image"] == 1)
    }

    @Test("recordCapture tracks app counts")
    func recordCaptureAppCounts() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.recordCapture(contentType: .text, sourceApp: "com.app.one")
        store.recordCapture(contentType: .text, sourceApp: "com.app.one")
        store.recordCapture(contentType: .text, sourceApp: "com.app.two")
        #expect(store.stats.appCounts["com.app.one"] == 2)
        #expect(store.stats.appCounts["com.app.two"] == 1)
    }

    @Test("recordCapture increments daily count")
    func recordCaptureDailyCount() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.recordCapture(contentType: .text, sourceApp: nil)
        store.recordCapture(contentType: .text, sourceApp: nil)
        #expect(store.stats.dailyCounts.last?.count == 2)
    }

    @Test("recordCapture with nil sourceApp does not add app count")
    func recordCaptureNilApp() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.recordCapture(contentType: .text, sourceApp: nil)
        #expect(store.stats.appCounts.isEmpty)
    }

    @Test("reset clears all stats")
    func reset() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.recordCapture(contentType: .text, sourceApp: "com.test")
        store.reset()
        #expect(store.stats.totalCopies == 0)
        #expect(store.stats.typeCounts.isEmpty)
        #expect(store.stats.appCounts.isEmpty)
        #expect(store.stats.dailyCounts.isEmpty)
    }

    @Test("persistence: data survives reload")
    func persistence() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = StatsStore(baseURL: dir)
        store1.recordCapture(contentType: .image, sourceApp: "com.test")

        let store2 = StatsStore(baseURL: dir)
        #expect(store2.stats.totalCopies == 1)
        #expect(store2.stats.typeCounts["image"] == 1)
    }
}

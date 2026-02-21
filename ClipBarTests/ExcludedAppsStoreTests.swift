import Testing
import Foundation
@testable import ClipBar

@Suite("ExcludedAppsStore")
struct ExcludedAppsStoreTests {

    private func makeStore() -> (ExcludedAppsStore, URL) {
        let dir = makeTempDir()
        let store = ExcludedAppsStore(baseURL: dir)
        return (store, dir)
    }

    @Test("isExcluded returns false for unknown bundle ID")
    func isExcludedFalse() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        #expect(!store.isExcluded("com.unknown.app"))
    }

    @Test("toggle adds then removes")
    func toggleAddRemove() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.toggle("com.test.app")
        #expect(store.isExcluded("com.test.app"))

        store.toggle("com.test.app")
        #expect(!store.isExcluded("com.test.app"))
    }

    @Test("persistence: data survives reload")
    func persistence() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = ExcludedAppsStore(baseURL: dir)
        store1.toggle("com.persist.app")

        let store2 = ExcludedAppsStore(baseURL: dir)
        #expect(store2.isExcluded("com.persist.app"))
    }

    @Test("corrupt JSON results in empty set")
    func corruptJSON() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let fileURL = dir.appendingPathComponent("excluded_apps.json")
        try! Data("broken".utf8).write(to: fileURL)

        let store = ExcludedAppsStore(baseURL: dir)
        #expect(store.excludedBundleIDs.isEmpty)
    }
}

import Testing
import Foundation
@testable import Muninn

@Suite("ExcludedTypesStore")
struct ExcludedTypesStoreTests {

    private func makeStore() -> (ExcludedTypesStore, URL) {
        let dir = makeTempDir()
        let store = ExcludedTypesStore(baseURL: dir)
        return (store, dir)
    }

    @Test("isExcluded returns false by default")
    func isExcludedFalse() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        #expect(!store.isExcluded(.image))
    }

    @Test("toggle adds then removes")
    func toggleAddRemove() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.toggle(.image)
        #expect(store.isExcluded(.image))

        store.toggle(.image)
        #expect(!store.isExcluded(.image))
    }

    @Test("persistence: data survives reload")
    func persistence() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = ExcludedTypesStore(baseURL: dir)
        store1.toggle(.pdf)

        let store2 = ExcludedTypesStore(baseURL: dir)
        #expect(store2.isExcluded(.pdf))
    }

    @Test("corrupt JSON results in empty set")
    func corruptJSON() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let fileURL = dir.appendingPathComponent("excluded_types.json")
        try! Data("broken".utf8).write(to: fileURL)

        let store = ExcludedTypesStore(baseURL: dir)
        #expect(store.excludedTypes.isEmpty)
    }
}

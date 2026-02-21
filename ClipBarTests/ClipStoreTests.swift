import Testing
import Foundation
@testable import ClipBar

@Suite("ClipStore")
struct ClipStoreTests {

    private func makeStore() -> (ClipStore, URL) {
        let dir = makeTempDir()
        let store = ClipStore(baseURL: dir)
        return (store, dir)
    }

    @Test("add appends a clip")
    func addClip() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.clips = [] // clear example clips
        let clip = Clip(name: "Test", value: "hello")
        store.add(clip)
        #expect(store.clips.count == 1)
        #expect(store.clips[0].name == "Test")
    }

    @Test("update modifies existing clip")
    func updateClip() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.clips = []
        var clip = Clip(name: "Old", value: "v1")
        store.add(clip)
        clip.name = "New"
        clip.value = "v2"
        store.update(clip)
        #expect(store.clips[0].name == "New")
        #expect(store.clips[0].value == "v2")
    }

    @Test("update with unknown ID does nothing")
    func updateMissing() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        let count = store.clips.count
        let clip = Clip(name: "Ghost", value: "boo")
        store.update(clip)
        #expect(store.clips.count == count)
    }

    @Test("delete removes clip at index")
    func deleteClip() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.clips = []
        store.add(Clip(name: "A", value: "a"))
        store.add(Clip(name: "B", value: "b"))
        store.delete(at: IndexSet(integer: 0))
        #expect(store.clips.count == 1)
        #expect(store.clips[0].name == "B")
    }

    @Test("move reorders clips")
    func moveClip() {
        let (store, dir) = makeStore()
        defer { removeTempDir(dir) }

        store.clips = []
        store.add(Clip(name: "A", value: "a"))
        store.add(Clip(name: "B", value: "b"))
        store.add(Clip(name: "C", value: "c"))
        store.move(from: IndexSet(integer: 0), to: 3)
        #expect(store.clips.map(\.name) == ["B", "C", "A"])
    }

    @Test("persistence: data survives reload")
    func persistence() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = ClipStore(baseURL: dir)
        store1.clips = []
        store1.add(Clip(name: "Persist", value: "data"))

        let store2 = ClipStore(baseURL: dir)
        #expect(store2.clips.count == 1)
        #expect(store2.clips[0].name == "Persist")
    }

    @Test("corrupt JSON loads example clips")
    func corruptJSON() {
        let dir = makeTempDir()
        defer { removeTempDir(dir) }

        let fileURL = dir.appendingPathComponent("clips.json")
        try! Data("not json".utf8).write(to: fileURL)

        let store = ClipStore(baseURL: dir)
        #expect(!store.clips.isEmpty) // falls back to example clips
    }
}

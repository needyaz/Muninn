import Foundation

@Observable
class ClipStore {
    var clips: [Clip] = []

    private let fileURL: URL

    init(baseURL: URL = StoragePaths.base) {
        self.fileURL = baseURL.appendingPathComponent("clips.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            clips = Self.exampleClips
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            clips = try JSONDecoder().decode([Clip].self, from: data)
        } catch {
            // The file exists but can't be read. Keep a copy before replacing it, so snippets aren't lost silently.
            let backup = fileURL.deletingPathExtension().appendingPathExtension("json.bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            clips = Self.exampleClips
            save()
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(clips)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.storage.error("failed to save clips: \(error.localizedDescription)")
        }
    }

    func add(_ clip: Clip) {
        clips.append(clip)
        save()
    }

    func update(_ clip: Clip) {
        if let idx = clips.firstIndex(where: { $0.id == clip.id }) {
            clips[idx] = clip
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        for idx in offsets {
            if let blob = clips[idx].blobFile { BlobStorage.delete(blob) }
        }
        clips.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        clips.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func loadDemoClips() {
        let existing = Set(clips.map { $0.name })
        let toAdd = Self.exampleClips.filter { !existing.contains($0.name) }
        clips.insert(contentsOf: toAdd, at: 0)
        save()
    }

    private static let exampleClips: [Clip] = [
        Clip(name: "Name", value: "Jane Doe"),
        Clip(name: "Email", value: "jane@example.com"),
        Clip(name: "Phone", value: "+1 (555) 123-4567"),
        Clip(name: "Website", value: "https://example.com"),
    ]
}

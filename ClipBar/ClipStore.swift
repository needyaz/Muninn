import Foundation

@Observable
class ClipStore {
    var clips: [Clip] = []

    private let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/clipbar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clips.json")
    }()

    init() {
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
            clips = Self.exampleClips
            save()
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(clips)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ClipBar: failed to save clips: \(error)")
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
        clips.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        clips.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private static let exampleClips: [Clip] = [
        Clip(name: "Name", value: "Nate"),
        Clip(name: "Email", value: "nate@example.com"),
        Clip(name: "Phone", value: "+1 (555) 123-4567"),
        Clip(name: "Website", value: "https://example.com"),
    ]
}

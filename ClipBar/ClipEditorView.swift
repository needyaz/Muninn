import SwiftUI

struct ClipEditorView: View {
    @Environment(ClipStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            List {
                ForEach($store.clips) { $clip in
                    HStack {
                        TextField("Name", text: $clip.name)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        TextField("Value", text: $clip.value)
                            .textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            if let idx = store.clips.firstIndex(where: { $0.id == clip.id }) {
                                store.delete(at: IndexSet(integer: idx))
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            HStack {
                Button {
                    store.add(Clip(name: "New Clip", value: ""))
                } label: {
                    Label("Add Clip", systemImage: "plus")
                }
                Spacer()
            }
            .padding(12)
        }
        .frame(width: 450, height: 350)
        .onChange(of: store.clips) {
            store.save()
        }
    }
}

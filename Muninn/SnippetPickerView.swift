import AppKit
import SwiftUI

struct SnippetPickerView: View {
    let clipStore: ClipStore
    let settingsStore: SettingsStore
    let monitor: ClipboardMonitor
    let previousApp: NSRunningApplication?
    let onDismiss: () -> Void

    @State private var search = ""
    @State private var selectedIndex: Int?
    @State private var eventMonitor: Any?

    private var filteredClips: [Clip] {
        let items = clipStore.clips
        if search.isEmpty { return items }
        let q = search.lowercased()
        return items.filter {
            $0.name.lowercased().contains(q) || $0.preview.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search snippets\u{2026}", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)

            Divider()

            if filteredClips.isEmpty {
                Text(search.isEmpty ? "No snippets" : "No results")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filteredClips.enumerated()), id: \.element.id) { idx, clip in
                                Button {
                                    pasteClip(clip)
                                } label: {
                                    HStack(spacing: 8) {
                                        if idx < 9 {
                                            Text("\u{2318}\(idx + 1)")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 24, alignment: .center)
                                        } else {
                                            Spacer()
                                                .frame(width: 24)
                                        }
                                        Text(clip.name)
                                            .lineLimit(1)
                                        Spacer()
                                        clipPreviewLabel(clip)
                                            .lineLimit(1)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: 140, alignment: .trailing)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(selectedIndex == idx ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .id("snippet-\(idx)")
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { _, newValue in
                        if let idx = newValue {
                            withAnimation {
                                proxy.scrollTo("snippet-\(idx)", anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .onChange(of: search) {
            selectedIndex = nil
        }
        .onAppear {
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    // MARK: - Clip preview

    @ViewBuilder
    private func clipPreviewLabel(_ clip: Clip) -> some View {
        switch clip.contentType {
        case .image:
            Label("Image", systemImage: "photo")
        case .pdf:
            Label("PDF", systemImage: "doc.richtext")
        case .fileURL:
            Label(clip.preview, systemImage: "doc")
        case .color:
            if let comps = clip.colorComponents, comps.count >= 3 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: comps[0], green: comps[1], blue: comps[2], opacity: comps.count > 3 ? comps[3] : 1))
                        .frame(width: 10, height: 10)
                    Text("Color")
                }
            } else {
                Text("Color")
            }
        case .text:
            Text(clip.value ?? "")
        }
    }

    // MARK: - Keyboard handling

    private enum KeyCode {
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let returnKey: UInt16 = 36
        static let escape: UInt16 = 53
    }

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Cmd+1..9 quick-select
        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers,
               let digit = chars.first?.wholeNumberValue,
               digit >= 1, digit <= 9 {
                let idx = digit - 1
                if idx < filteredClips.count {
                    pasteClip(filteredClips[idx])
                }
                return true
            }
        }

        switch event.keyCode {
        case KeyCode.downArrow:
            let count = filteredClips.count
            guard count > 0 else { return true }
            if selectedIndex == nil {
                selectedIndex = 0
            } else if let idx = selectedIndex, idx < count - 1 {
                selectedIndex = idx + 1
            }
            return true

        case KeyCode.upArrow:
            let count = filteredClips.count
            guard count > 0 else { return true }
            if selectedIndex == nil {
                selectedIndex = count - 1
            } else if let idx = selectedIndex, idx > 0 {
                selectedIndex = idx - 1
            }
            return true

        case KeyCode.returnKey:
            if let idx = selectedIndex, idx < filteredClips.count {
                pasteClip(filteredClips[idx])
                return true
            }
            return false

        case KeyCode.escape:
            onDismiss()
            return true

        default:
            return false
        }
    }

    // MARK: - Paste

    private func pasteClip(_ clip: Clip) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch clip.contentType {
        case .text:
            if let value = clip.value {
                pasteboard.setString(value, forType: .string)
            }
            if !settingsStore.pasteAsPlainText, let blob = clip.blobFile, let data = BlobStorage.load(blob) {
                let ext = (blob as NSString).pathExtension
                if ext == "rtf" {
                    pasteboard.setData(data, forType: .rtf)
                } else if ext == "html" {
                    pasteboard.setData(data, forType: .html)
                }
            }
        case .image:
            if let blob = clip.blobFile, let data = BlobStorage.load(blob) {
                let ext = (blob as NSString).pathExtension
                let type: NSPasteboard.PasteboardType = ext == "png" ? .png : .tiff
                pasteboard.setData(data, forType: type)
            }
        case .pdf:
            if let blob = clip.blobFile, let data = BlobStorage.load(blob) {
                pasteboard.setData(data, forType: .pdf)
            }
        case .fileURL:
            if let paths = clip.fileURLs {
                let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
                pasteboard.writeObjects(urls)
            }
        case .color:
            if let comps = clip.colorComponents, comps.count >= 4 {
                let color = NSColor(
                    srgbRed: CGFloat(comps[0]),
                    green: CGFloat(comps[1]),
                    blue: CGFloat(comps[2]),
                    alpha: CGFloat(comps[3])
                )
                pasteboard.setData(
                    try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true),
                    forType: .color
                )
            }
        }

        monitor.didSelfCopy()
        onDismiss()
        previousApp?.activate()
    }
}

import AppKit
import SwiftUI

struct PopoverContentView: View {
    @Environment(ClipStore.self) private var clipStore
    @Environment(HistoryStore.self) private var historyStore
    @Environment(ClipboardMonitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow

    @State private var search = ""
    @State private var previousApp: NSRunningApplication?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search…", text: $search)
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

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Snippets section
                    if !filteredClips.isEmpty {
                        sectionHeader("SNIPPETS")
                        ForEach(filteredClips) { clip in
                            Button {
                                copyAndPaste(clip: clip)
                            } label: {
                                HStack {
                                    Text(clip.name)
                                        .lineLimit(1)
                                    Spacer()
                                    clipPreviewLabel(clip)
                                        .lineLimit(1)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: 160, alignment: .trailing)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(HoverBackground())
                        }
                    }

                    // History section
                    if !filteredHistory.isEmpty {
                        sectionHeader("HISTORY")
                        ForEach(filteredHistory) { item in
                            HistoryRow(item: item) {
                                copyAndPaste(item: item)
                            } onPin: {
                                pinItem(item)
                            } onDelete: {
                                historyStore.delete(item)
                            }
                        }
                    }

                    if filteredClips.isEmpty && filteredHistory.isEmpty {
                        Text(search.isEmpty ? "No history yet" : "No results")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                }
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer
            HStack {
                Button("Edit Clips…") {
                    openWindow(id: "editor")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)

                Spacer()

                if !historyStore.items.isEmpty {
                    Button("Clear") {
                        historyStore.clearAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Button {
                    openWindow(id: "excluded-apps")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .frame(width: 320)
        .onAppear {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
    }

    // MARK: - Filtered data

    private var filteredClips: [Clip] {
        if search.isEmpty { return clipStore.clips }
        let q = search.lowercased()
        return clipStore.clips.filter {
            $0.name.lowercased().contains(q) || $0.preview.lowercased().contains(q)
        }
    }

    private var filteredHistory: [HistoryItem] {
        if search.isEmpty { return historyStore.items }
        let q = search.lowercased()
        return historyStore.items.filter { item in
            switch item.contentType {
            case .text:
                return item.value?.lowercased().contains(q) ?? false
            case .fileURL:
                return item.fileURLs?.contains { $0.lowercased().contains(q) } ?? false
            default:
                return item.preview.lowercased().contains(q)
            }
        }
    }

    // MARK: - Clip preview label

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

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func pinItem(_ item: HistoryItem) {
        let newID = UUID()
        var newBlobFile: String?
        if let blob = item.blobFile {
            newBlobFile = BlobStorage.copy(blob, newID: newID)
        }
        let clip = Clip(
            id: newID,
            name: String(item.preview.prefix(20)),
            value: item.value,
            contentType: item.contentType,
            blobFile: newBlobFile,
            fileURLs: item.fileURLs,
            colorComponents: item.colorComponents
        )
        clipStore.add(clip)
    }

    private func copyAndPaste(item: HistoryItem) {
        writeToPasteboard(
            contentType: item.contentType,
            value: item.value,
            blobFile: item.blobFile,
            fileURLs: item.fileURLs,
            colorComponents: item.colorComponents
        )
    }

    private func copyAndPaste(clip: Clip) {
        writeToPasteboard(
            contentType: clip.contentType,
            value: clip.value,
            blobFile: clip.blobFile,
            fileURLs: clip.fileURLs,
            colorComponents: clip.colorComponents
        )
    }

    private func writeToPasteboard(
        contentType: ClipboardContentType,
        value: String?,
        blobFile: String?,
        fileURLs: [String]?,
        colorComponents: [Double]?
    ) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch contentType {
        case .text:
            if let value {
                pasteboard.setString(value, forType: .string)
            }
            // Restore rich text blob if available
            if let blob = blobFile, let data = BlobStorage.load(blob) {
                let ext = (blob as NSString).pathExtension
                if ext == "rtf" {
                    pasteboard.setData(data, forType: .rtf)
                } else if ext == "html" {
                    pasteboard.setData(data, forType: .html)
                }
            }

        case .image:
            if let blob = blobFile, let data = BlobStorage.load(blob) {
                let ext = (blob as NSString).pathExtension
                let type: NSPasteboard.PasteboardType = ext == "png" ? .png : .tiff
                pasteboard.setData(data, forType: type)
            }

        case .pdf:
            if let blob = blobFile, let data = BlobStorage.load(blob) {
                pasteboard.setData(data, forType: .pdf)
            }

        case .fileURL:
            if let paths = fileURLs {
                let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
                pasteboard.writeObjects(urls)
            }

        case .color:
            if let comps = colorComponents, comps.count >= 4 {
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

        // Dismiss popover and refocus previous app so user can Cmd+V
        NSApp.keyWindow?.close()
        previousApp?.activate()
    }

    private func relativeTime(_ date: Date) -> String {
        Self.formatRelativeTime(date)
    }

    static func formatRelativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }
}

// MARK: - History row with delete on hover

private struct HistoryRow: View {
    let item: HistoryItem
    var onTap: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                historyPreviewContent
                Spacer()
                if isHovered {
                    Button {
                        onPin()
                    } label: {
                        Image(systemName: "pin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(PopoverContentView.formatRelativeTime(item.timestamp))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var historyPreviewContent: some View {
        switch item.contentType {
        case .image:
            if let blob = item.blobFile, let data = BlobStorage.load(blob),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 32)
            } else {
                Label("Image", systemImage: "photo")
                    .lineLimit(1)
            }
        case .pdf:
            Label("PDF Document", systemImage: "doc.richtext")
                .lineLimit(1)
        case .fileURL:
            Label(item.preview, systemImage: "doc")
                .lineLimit(1)
        case .color:
            if let comps = item.colorComponents, comps.count >= 3 {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: comps[0], green: comps[1], blue: comps[2], opacity: comps.count > 3 ? comps[3] : 1))
                        .frame(width: 16, height: 16)
                    Text("Color")
                }
            } else {
                Text("Color")
            }
        case .text:
            Text(item.preview)
                .lineLimit(1)
        }
    }
}

// MARK: - Hover effect

private struct HoverBackground: View {
    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            .onHover { isHovered = $0 }
    }
}

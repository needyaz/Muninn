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
                                copyAndPaste(clip.value)
                            } label: {
                                HStack {
                                    Text(clip.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(clip.value)
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
                                copyAndPaste(item.value)
                            } onPin: {
                                clipStore.add(Clip(name: String(item.preview.prefix(20)), value: item.value))
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
            $0.name.lowercased().contains(q) || $0.value.lowercased().contains(q)
        }
    }

    private var filteredHistory: [HistoryItem] {
        if search.isEmpty { return historyStore.items }
        let q = search.lowercased()
        return historyStore.items.filter { $0.value.lowercased().contains(q) }
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

    private func copyAndPaste(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
                Text(item.preview)
                    .lineLimit(1)
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

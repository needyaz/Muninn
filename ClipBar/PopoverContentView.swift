import AppKit
import SwiftUI

struct PopoverContentView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ClipStore.self) private var clipStore
    @Environment(HistoryStore.self) private var historyStore
    @Environment(ClipboardMonitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @State private var search = ""
    @State private var previousApp: NSRunningApplication?
    @State private var contentTypeFilter: ClipboardContentType?
    @State private var selectedIndex: Int?
    @State private var eventMonitor: Any?

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
            .onChange(of: search) {
                contentTypeFilter = nil
                selectedIndex = nil
            }

            Divider()

            // Content type filter chips
            if availableContentTypes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(label: "All", isSelected: contentTypeFilter == nil) {
                            contentTypeFilter = nil
                        }
                        ForEach(availableContentTypes, id: \.self) { type in
                            FilterChip(label: type.displayName, isSelected: contentTypeFilter == type) {
                                contentTypeFilter = contentTypeFilter == type ? nil : type
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }

                Divider()
            }

            // Scrollable content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Snippets section
                        if !filteredClips.isEmpty {
                            sectionHeader("SNIPPETS")
                            ForEach(Array(filteredClips.enumerated()), id: \.element.id) { idx, clip in
                                let globalIdx = idx
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
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(selectedIndex == globalIdx ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .background(HoverBackground())
                                .if(clip.contentType == .text && clip.value != nil) { view in
                                    view.contextMenu {
                                        Button("Copy") {
                                            copyOnly(text: clip.value!)
                                        }
                                        Divider()
                                        ForEach(TextTransform.allCases, id: \.self) { transform in
                                            Button(transform.rawValue) {
                                                let transformed = applyTransform(clip.value!, transform)
                                                copyAndPasteText(transformed)
                                            }
                                        }
                                    }
                                }
                                .id("item-\(globalIdx)")
                            }
                        }

                        // History section
                        if !filteredHistory.isEmpty {
                            sectionHeader("HISTORY")
                            ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { idx, item in
                                let globalIdx = filteredClips.count + idx
                                HistoryRow(item: item, isSelected: selectedIndex == globalIdx) {
                                    copyAndPaste(item: item)
                                } onPin: {
                                    pinItem(item)
                                } onDelete: {
                                    historyStore.delete(item)
                                } onTransform: { text, transform in
                                    let transformed = applyTransform(text, transform)
                                    copyAndPasteText(transformed)
                                }
                                .id("item-\(globalIdx)")
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
                .onChange(of: selectedIndex) { _, newValue in
                    if let idx = newValue {
                        withAnimation {
                            proxy.scrollTo("item-\(idx)", anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button {
                    openWindow(id: "editor")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .tooltip("Edit Clips")

                Spacer()

                // Pause / Resume
                if monitor.isPaused {
                    Button {
                        monitor.resume()
                    } label: {
                        Image(systemName: "play")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .tooltip("Resume clipboard monitoring")
                } else {
                    Menu {
                        Button("1 minute") { monitor.pause(for: 60) }
                        Button("5 minutes") { monitor.pause(for: 300) }
                        Button("10 minutes") { monitor.pause(for: 600) }
                        Button("30 minutes") { monitor.pause(for: 1800) }
                        Button("1 hour") { monitor.pause(for: 3600) }
                        Divider()
                        Button("Until resumed") { monitor.pause(for: nil) }
                    } label: {
                        Image(systemName: "pause")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                    .tooltip("Pause clipboard monitoring")
                }

                if !historyStore.items.isEmpty {
                    Button {
                        clearHistory()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .tooltip("Clear history")
                }

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .tooltip("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .tooltip("Quit ClipBar")
            }
            .padding(10)
        }
        .frame(width: 320)
        .onAppear {
            previousApp = NSWorkspace.shared.frontmostApplication
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    // MARK: - Selectable items count

    private var selectableCount: Int {
        filteredClips.count + filteredHistory.count
    }

    // MARK: - Content type filter

    private var availableContentTypes: [ClipboardContentType] {
        let types = Set(historyStore.items.map(\.contentType))
        return ClipboardContentType.allCases.filter { types.contains($0) }
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
        var items = historyStore.items

        // Apply content type filter
        if let typeFilter = contentTypeFilter {
            items = items.filter { $0.contentType == typeFilter }
        }

        // Apply search filter
        if !search.isEmpty {
            let q = search.lowercased()
            items = items.filter { item in
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

        return items
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

    private func clearHistory() {
        DispatchQueue.main.async {
            let previousPolicy = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = "Clear all history?"
            alert.informativeText = "This cannot be undone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Clear All")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()

            NSApp.setActivationPolicy(previousPolicy)

            if response == .alertFirstButtonReturn {
                historyStore.clearAll()
            }
        }
    }

    private func copyAndPaste(item: HistoryItem) {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        let plainText = optionHeld != settingsStore.pasteAsPlainText
        writeToPasteboard(
            contentType: item.contentType,
            value: item.value,
            blobFile: item.blobFile,
            fileURLs: item.fileURLs,
            colorComponents: item.colorComponents,
            plainTextOnly: plainText
        )
    }

    private func copyAndPaste(clip: Clip) {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        let plainText = optionHeld != settingsStore.pasteAsPlainText
        writeToPasteboard(
            contentType: clip.contentType,
            value: clip.value,
            blobFile: clip.blobFile,
            fileURLs: clip.fileURLs,
            colorComponents: clip.colorComponents,
            plainTextOnly: plainText
        )
    }

    private func copyOnly(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.didSelfCopy()
    }

    private func copyAndPasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.didSelfCopy()
        NSApp.keyWindow?.close()
        previousApp?.activate()
    }

    private func writeToPasteboard(
        contentType: ClipboardContentType,
        value: String?,
        blobFile: String?,
        fileURLs: [String]?,
        colorComponents: [Double]?,
        plainTextOnly: Bool = false
    ) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch contentType {
        case .text:
            if let value {
                pasteboard.setString(value, forType: .string)
            }
            // Restore rich text blob if available (unless plain text mode)
            if !plainTextOnly, let blob = blobFile, let data = BlobStorage.load(blob) {
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

    // MARK: - Keyboard Navigation

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
        switch event.keyCode {
        case 125: // Down arrow
            if selectedIndex == nil {
                selectedIndex = 0
            } else if let idx = selectedIndex, idx < selectableCount - 1 {
                selectedIndex = idx + 1
            }
            return true

        case 126: // Up arrow
            if selectedIndex == nil {
                selectedIndex = selectableCount - 1
            } else if let idx = selectedIndex, idx > 0 {
                selectedIndex = idx - 1
            }
            return true

        case 36: // Return/Enter
            if let idx = selectedIndex {
                activateItemAt(idx)
                return true
            }
            return false

        case 53: // Escape
            NSApp.keyWindow?.close()
            return true

        default:
            return false
        }
    }

    private func activateItemAt(_ index: Int) {
        let clipCount = filteredClips.count
        if index < clipCount {
            copyAndPaste(clip: filteredClips[index])
        } else {
            let historyIndex = index - clipCount
            if historyIndex < filteredHistory.count {
                copyAndPaste(item: filteredHistory[historyIndex])
            }
        }
    }

    // MARK: - Drag helpers

    static func makeItemProvider(
        contentType: ClipboardContentType,
        value: String?,
        blobFile: String?,
        fileURLs: [String]?,
        colorComponents: [Double]?
    ) -> NSItemProvider {
        let provider = NSItemProvider()
        switch contentType {
        case .text:
            if let value {
                provider.registerObject(value as NSString, visibility: .all)
            }
        case .image:
            if let blob = blobFile, let data = BlobStorage.load(blob),
               let image = NSImage(data: data) {
                provider.registerObject(image, visibility: .all)
            }
        case .pdf:
            if let blob = blobFile, let data = BlobStorage.load(blob) {
                provider.registerDataRepresentation(forTypeIdentifier: "com.adobe.pdf", visibility: .all) { completion in
                    completion(data, nil)
                    return nil
                }
            }
        case .fileURL:
            if let paths = fileURLs {
                for path in paths {
                    let url = URL(fileURLWithPath: path) as NSURL
                    provider.registerObject(url, visibility: .all)
                }
            }
        case .color:
            if let comps = colorComponents, comps.count >= 3 {
                let hex = String(format: "#%02X%02X%02X",
                    Int(comps[0] * 255), Int(comps[1] * 255), Int(comps[2] * 255))
                provider.registerObject(hex as NSString, visibility: .all)
            }
        }
        return provider
    }
}

// MARK: - Text transforms

private enum TextTransform: String, CaseIterable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case capitalize = "Capitalize Words"
    case trimWhitespace = "Trim Whitespace"
    case removeBlankLines = "Remove Blank Lines"
}

private func applyTransform(_ text: String, _ transform: TextTransform) -> String {
    switch transform {
    case .uppercase:
        return text.uppercased()
    case .lowercase:
        return text.lowercased()
    case .capitalize:
        return text.capitalized
    case .trimWhitespace:
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    case .removeBlankLines:
        return text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
                )
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Source app icon cache

private class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]

    func icon(for bundleID: String) -> NSImage? {
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = icon
        return icon
    }
}

// MARK: - History row with delete on hover

private struct HistoryRow: View {
    let item: HistoryItem
    var isSelected: Bool = false
    var onTap: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void
    var onTransform: ((_ text: String, _ transform: TextTransform) -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                // Source app icon
                if let bundleID = item.sourceAppBundleID,
                   let icon = AppIconCache.shared.icon(for: bundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }

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
                .fill(
                    isSelected ? Color.accentColor.opacity(0.2) :
                    isHovered ? Color.primary.opacity(0.1) : Color.clear
                )
        )
        .onHover { isHovered = $0 }
        .onDrag {
            PopoverContentView.makeItemProvider(
                contentType: item.contentType,
                value: item.value,
                blobFile: item.blobFile,
                fileURLs: item.fileURLs,
                colorComponents: item.colorComponents
            )
        }
        .if(item.contentType == .text && item.value != nil) { view in
            view.contextMenu {
                Button("Copy") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(item.value!, forType: .string)
                }
                Divider()
                ForEach(TextTransform.allCases, id: \.self) { transform in
                    Button(transform.rawValue) {
                        onTransform?(item.value!, transform)
                    }
                }
            }
        }
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

// MARK: - Tooltip

private class TooltipView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct Tooltip: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = TooltipView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        overlay(Tooltip(text: text))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

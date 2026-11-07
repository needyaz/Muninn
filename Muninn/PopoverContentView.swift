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
    @State private var sourceAppFilter: String?
    @State private var selectedIndex: Int?
    @State private var selectedIDs: Set<UUID> = []
    @State private var lastToggledID: UUID?
    @State private var eventMonitor: Any?
    @State private var mouseEventMonitor: Any?
    @State private var resizeDrag = ResizeDragState()

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
                sourceAppFilter = nil
                selectedIndex = nil
                selectedIDs.removeAll()
                lastToggledID = nil
            }

            Divider()

            // Content type filter chips
            if availableContentTypes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(label: String(localized: "All"), isSelected: contentTypeFilter == nil) {
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

            // Source app filter chips
            if availableSourceApps.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(label: String(localized: "All Apps"), isSelected: sourceAppFilter == nil) {
                            sourceAppFilter = nil
                        }
                        ForEach(availableSourceApps, id: \.bundleID) { app in
                            AppFilterChip(bundleID: app.bundleID, name: app.name, isSelected: sourceAppFilter == app.bundleID) {
                                sourceAppFilter = sourceAppFilter == app.bundleID ? nil : app.bundleID
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
                            snippetsSectionHeader()
                            ForEach(Array(filteredClips.enumerated()), id: \.element.id) { idx, clip in
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
                                        .fill(selectedIndex == idx ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .background(HoverBackground())
                                .onDrag {
                                    PopoverContentView.makeItemProvider(
                                        contentType: clip.contentType,
                                        value: clip.value,
                                        blobFile: clip.blobFile,
                                        fileURLs: clip.fileURLs,
                                        colorComponents: clip.colorComponents
                                    )
                                }
                                .if(clip.contentType == .text && clip.value != nil) { view in
                                    view.contextMenu {
                                        Button("Copy") {
                                            copyOnly(text: clip.value!)
                                        }
                                        Divider()
                                        ForEach(TextTransform.allCases, id: \.self) { transform in
                                            Button(transform.displayName) {
                                                let transformed = applyTransform(clip.value!, transform)
                                                copyAndPasteText(transformed)
                                            }
                                        }
                                    }
                                }
                                .id("item-\(idx)")
                            }
                        }

                        // History section
                        if !filteredHistory.isEmpty {
                            sectionHeader("HISTORY")
                            ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { idx, item in
                                let idx = filteredClips.count + idx
                                HistoryRow(
                                    item: item,
                                    isSelected: selectedIndex == idx,
                                    isMultiSelected: selectedIDs.contains(item.id),
                                    isInMultiSelectMode: !selectedIDs.isEmpty,
                                    showRichPreview: settingsStore.enableRichPreviews,
                                    isScanning: historyStore.isScanning(id: item.id)
                                ) {
                                    if NSEvent.modifierFlags.contains(.command) {
                                        toggleMultiSelect(item.id)
                                    } else if NSEvent.modifierFlags.contains(.shift), lastToggledID != nil {
                                        shiftSelect(to: item.id, in: filteredHistory)
                                    } else {
                                        selectedIDs.removeAll()
                                        lastToggledID = nil
                                        copyAndPaste(item: item)
                                    }
                                } onPin: {
                                    pinItem(item)
                                } onDelete: {
                                    historyStore.delete(item)
                                } onTransform: { text, transform in
                                    let transformed = applyTransform(text, transform)
                                    copyAndPasteText(transformed)
                                }
                                .id("item-\(idx)")
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
                .frame(height: settingsStore.popoverHeight)
                .onChange(of: selectedIndex) { _, newValue in
                    if let idx = newValue {
                        withAnimation {
                            proxy.scrollTo("item-\(idx)", anchor: .center)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 6) {
                        if selectedIDs.count >= 2 {
                            BulkActionBar(count: selectedIDs.count) {
                                deleteSelected()
                            } onCancel: {
                                selectedIDs.removeAll()
                                lastToggledID = nil
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if historyStore.pendingUndo != nil {
                            UndoToast(label: historyStore.pendingUndo!.label) {
                                historyStore.undo()
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 8)
                }
                .animation(.easeInOut(duration: 0.2), value: historyStore.pendingUndo != nil)
                .animation(.easeInOut(duration: 0.2), value: selectedIDs.count >= 2)
            }

            // Resize handle (corner drag — resizes both height and width)
            Divider()
            HStack {
                Spacer()
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 7))
                    .foregroundStyle(Color.secondary.opacity(resizeDrag.isHovering ? 0.7 : 0.35))
                    .frame(width: 16, height: 12)
                    .padding(.trailing, 4)
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .onHover { hovering in
                resizeDrag.isHovering = hovering
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            Divider()

            // Footer
            HStack {
                // Pause / Resume
                if monitor.isPaused {
                    Button {
                        monitor.resume()
                    } label: {
                        Image(systemName: "play")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .tooltip(String(localized: "Resume clipboard monitoring"))
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
                    .tooltip(String(localized: "Pause clipboard monitoring"))
                }

                if !historyStore.items.isEmpty {
                    Button {
                        clearHistory()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .tooltip(String(localized: "Clear history"))
                }

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .tooltip(String(localized: "Settings"))

                Button {
                    openWindow(id: "help")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .tooltip(String(localized: "Help"))

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .tooltip(String(localized: "Quit Muninn"))
            }
            .padding(10)
        }
        .frame(width: settingsStore.popoverWidth)
        .onAppear {
            previousApp = NSWorkspace.shared.frontmostApplication
            installKeyMonitor()
            installMouseMonitor()
            if !settingsStore.hasSeenOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    openWindow(id: "onboarding")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        .onDisappear {
            removeKeyMonitor()
            removeMouseMonitor()
        }
    }

    // MARK: - Selectable items count

    private var selectableCount: Int {
        filteredClips.count + filteredHistory.count
    }

    // MARK: - Content type filter

    private var availableContentTypes: [ClipboardContentType] {
        var types = Set(historyStore.items.map(\.contentType))
        types.formUnion(clipStore.clips.map(\.contentType))
        return ClipboardContentType.allCases.filter { types.contains($0) }
    }

    // MARK: - Source app filter

    private var availableSourceApps: [(bundleID: String, name: String)] {
        let bundleIDs = Set(historyStore.items.compactMap(\.sourceAppBundleID))
        return bundleIDs
            .map { (bundleID: $0, name: AppIconCache.shared.appName(for: $0)) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // MARK: - Filtered data

    private var filteredClips: [Clip] {
        filterClips(clipStore.clips, search: search, typeFilter: contentTypeFilter)
    }

    private var filteredHistory: [HistoryItem] {
        filterHistoryItems(
            historyStore.items,
            search: search,
            typeFilter: contentTypeFilter,
            appFilter: sourceAppFilter,
            enableQRDetection: settingsStore.enableQRDetection
        )
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

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func snippetsSectionHeader() -> some View {
        HStack {
            Text("SNIPPETS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                openWindow(id: "editor")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .tooltip(String(localized: "Edit Clips"))
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func pinItem(_ item: HistoryItem) {
        guard item.isSensitive != true else { return } // a masked item has no value to save
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

    // MARK: - Multi-select

    private func toggleMultiSelect(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
        lastToggledID = id
    }

    private func shiftSelect(to endID: UUID, in historyItems: [HistoryItem]) {
        guard let startID = lastToggledID,
              let startIdx = historyItems.firstIndex(where: { $0.id == startID }),
              let endIdx = historyItems.firstIndex(where: { $0.id == endID }) else {
            selectedIDs.insert(endID)
            lastToggledID = endID
            return
        }
        let lo = min(startIdx, endIdx)
        let hi = max(startIdx, endIdx)
        for i in lo...hi {
            selectedIDs.insert(historyItems[i].id)
        }
        lastToggledID = endID
    }

    private func deleteSelected() {
        let itemsToDelete = historyStore.items.filter { selectedIDs.contains($0.id) }
        historyStore.deleteMultiple(itemsToDelete)
        selectedIDs.removeAll()
        lastToggledID = nil
    }

    private func historyItemIDAt(_ globalIndex: Int) -> UUID? {
        let clipCount = filteredClips.count
        guard globalIndex >= clipCount else { return nil }
        let historyIndex = globalIndex - clipCount
        guard historyIndex < filteredHistory.count else { return nil }
        return filteredHistory[historyIndex].id
    }

    private func clearHistory() {
        DispatchQueue.main.async {
            let previousPolicy = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = String(localized: "Clear all history?")
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "Clear All"))
            alert.addButton(withTitle: String(localized: "Cancel"))
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
        PasteboardWriter.copy(text)
    }

    private func copyAndPasteText(_ text: String) {
        PasteboardWriter.copy(text)
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

    static func formatRelativeTime(_ date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    // MARK: - Resize drag via mouse monitor

    private func installMouseMonitor() {
        removeMouseMonitor()
        let drag = resizeDrag
        let settings = settingsStore
        mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { event in
            switch event.type {
            case .leftMouseDown:
                if drag.isHovering {
                    let loc = NSEvent.mouseLocation
                    drag.startY = loc.y
                    drag.startHeight = settings.popoverHeight
                    drag.startX = loc.x
                    drag.startWidth = settings.popoverWidth
                    return nil
                }
            case .leftMouseDragged:
                if let startY = drag.startY, let startH = drag.startHeight {
                    let loc = NSEvent.mouseLocation
                    let deltaY = startY - loc.y
                    settings.popoverHeight = max(200, min(800, startH + deltaY))
                    if let startX = drag.startX, let startW = drag.startWidth {
                        let deltaX = loc.x - startX
                        settings.popoverWidth = max(280, min(600, startW + deltaX))
                    }
                    return nil
                }
            case .leftMouseUp:
                if drag.startY != nil {
                    drag.startY = nil
                    drag.startHeight = nil
                    drag.startX = nil
                    drag.startWidth = nil
                    return nil
                }
            default:
                break
            }
            return event
        }
    }

    private func removeMouseMonitor() {
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
    }

    // MARK: - Keyboard Navigation

    private enum KeyCode {
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let returnKey: UInt16 = 36
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51       // Backspace
        static let forwardDelete: UInt16 = 117
    }

    private func installKeyMonitor() {
        removeKeyMonitor() // never stack a second monitor if onAppear fires twice
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
        let shiftHeld = event.modifierFlags.contains(.shift)

        switch event.keyCode {
        case KeyCode.downArrow:
            if shiftHeld, let idx = selectedIndex, let id = historyItemIDAt(idx) {
                let nextIdx = min(idx + 1, selectableCount - 1)
                if let nextID = historyItemIDAt(nextIdx) {
                    selectedIDs.insert(id)
                    selectedIDs.insert(nextID)
                    lastToggledID = nextID
                    selectedIndex = nextIdx
                }
            } else {
                if !selectedIDs.isEmpty { selectedIDs.removeAll(); lastToggledID = nil }
                if selectedIndex == nil {
                    selectedIndex = 0
                } else if let idx = selectedIndex, idx < selectableCount - 1 {
                    selectedIndex = idx + 1
                }
            }
            return true

        case KeyCode.upArrow:
            if shiftHeld, let idx = selectedIndex, let id = historyItemIDAt(idx) {
                let prevIdx = max(idx - 1, filteredClips.count)
                if let prevID = historyItemIDAt(prevIdx) {
                    selectedIDs.insert(id)
                    selectedIDs.insert(prevID)
                    lastToggledID = prevID
                    selectedIndex = prevIdx
                }
            } else {
                if !selectedIDs.isEmpty { selectedIDs.removeAll(); lastToggledID = nil }
                if selectedIndex == nil {
                    selectedIndex = selectableCount - 1
                } else if let idx = selectedIndex, idx > 0 {
                    selectedIndex = idx - 1
                }
            }
            return true

        case KeyCode.returnKey:
            if let idx = selectedIndex {
                selectedIDs.removeAll()
                lastToggledID = nil
                activateItemAt(idx)
                return true
            }
            return false

        case KeyCode.delete, KeyCode.forwardDelete:
            if !selectedIDs.isEmpty {
                deleteSelected()
                return true
            }
            return false

        case KeyCode.escape:
            if !selectedIDs.isEmpty {
                selectedIDs.removeAll()
                lastToggledID = nil
                return true
            }
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
            if let blob = blobFile, let data = BlobStorage.load(blob) {
                let ext = (blob as NSString).pathExtension
                let filename = value ?? "Image.\(ext)"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try? data.write(to: tempURL, options: .atomic)
                provider.registerObject(tempURL as NSURL, visibility: .all)
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
                let hex = hexColorString(comps)
                provider.registerObject(hex as NSString, visibility: .all)
            }
        }
        return provider
    }
}

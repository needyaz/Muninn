import AppKit
import SwiftUI

// MARK: - History row with delete on hover

struct HistoryRow: View {
    @Environment(SettingsStore.self) private var settingsStore

    let item: HistoryItem
    var isSelected: Bool = false
    var isMultiSelected: Bool = false
    var isInMultiSelectMode: Bool = false
    var showRichPreview: Bool = false
    var isScanning: Bool = false
    var onTap: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void
    var onTransform: ((_ text: String, _ transform: TextTransform) -> Void)?

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "gif", "bmp", "webp", "heic"]

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                // Multi-select indicator
                if isInMultiSelectMode {
                    Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(isMultiSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                }

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
                    .tooltip(String(localized: "Save as snippet"))
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .tooltip(String(localized: "Delete"))
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
                    isMultiSelected ? Color.accentColor.opacity(0.15) :
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
        .if(item.contentType == .text && item.value != nil && item.isSensitive != true) { view in
            view.contextMenu {
                Button("Copy") {
                    PasteboardWriter.copy(item.value!)
                }
                Divider()
                ForEach(TextTransform.allCases, id: \.self) { transform in
                    Button(transform.displayName) {
                        onTransform?(item.value!, transform)
                    }
                }
            }
        }
        .if(item.contentType == .image && ((settingsStore.enableOCR && item.ocrText != nil) || (settingsStore.enableQRDetection && item.detectedBarcode != nil))) { view in
            view.contextMenu {
                if settingsStore.enableOCR, item.ocrText != nil {
                    Button("Copy Text") {
                        PasteboardWriter.copy(item.ocrText!)
                    }
                }
                if settingsStore.enableQRDetection, let barcode = item.detectedBarcode {
                    let isURL = barcode.hasPrefix("http://") || barcode.hasPrefix("https://")
                    Button(isURL ? "Copy Link" : "Copy Code") {
                        PasteboardWriter.copy(barcode)
                    }
                    if isURL {
                        Button("Open in Browser") {
                            if let url = URL(string: barcode) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
        .if((item.contentType == .pdf || (item.contentType == .fileURL && (item.blobFile.map { ($0 as NSString).pathExtension.lowercased() == "pdf" } ?? false))) && settingsStore.enablePDFTextExtraction && item.ocrText != nil) { view in
            view.contextMenu {
                Button("Copy Text") {
                    PasteboardWriter.copy(item.ocrText!)
                }
            }
        }
    }

    @ViewBuilder
    private var historyPreviewContent: some View {
        if item.isSensitive == true {
            Label("Sensitive content", systemImage: "eye.slash")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            switch item.contentType {
            case .image:
                if let blob = item.blobFile, let data = BlobStorage.load(blob),
                   let nsImage = NSImage(data: data) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: showRichPreview && isHovered ? 120 : 32)
                                .animation(.easeInOut(duration: 0.15), value: isHovered)
                            if let name = item.value {
                                Text(name)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .help("Scanning…")
                            }
                        }
                        if settingsStore.enableOCR, let ocrText = item.ocrText {
                            Text(ocrText)
                                .lineLimit(isHovered ? 3 : 1)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if settingsStore.enableQRDetection, let barcode = item.detectedBarcode {
                            let isURL = barcode.hasPrefix("http://") || barcode.hasPrefix("https://")
                            Button {
                                PasteboardWriter.copy(barcode)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isURL ? "link" : "barcode")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(barcode)
                                        .lineLimit(1)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Label(item.value ?? "Image", systemImage: "photo")
                        .lineLimit(1)
                }
            case .pdf:
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Label("PDF Document", systemImage: "doc.richtext")
                            .lineLimit(1)
                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.6)
                                .help("Extracting text…")
                        }
                    }
                    if settingsStore.enablePDFTextExtraction, let text = item.ocrText {
                        Text(text)
                            .lineLimit(isHovered ? 3 : 1)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            case .fileURL:
                if showRichPreview,
                   let blob = item.blobFile,
                   Self.imageExtensions.contains((blob as NSString).pathExtension.lowercased()),
                   let data = BlobStorage.load(blob),
                   let nsImage = NSImage(data: data) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(item.preview, systemImage: "doc")
                            .lineLimit(1)
                        if isHovered {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 120)
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                } else if settingsStore.enablePDFTextExtraction,
                          let blob = item.blobFile,
                          (blob as NSString).pathExtension.lowercased() == "pdf" {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Label(item.preview, systemImage: "doc.richtext")
                                .lineLimit(1)
                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .help("Extracting text…")
                            }
                        }
                        if let text = item.ocrText {
                            Text(text)
                                .lineLimit(isHovered ? 3 : 1)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Label(item.preview, systemImage: "doc")
                        .lineLimit(1)
                }
            case .color:
                if let comps = item.colorComponents, comps.count >= 3 {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: comps[0], green: comps[1], blue: comps[2], opacity: comps.count > 3 ? comps[3] : 1))
                            .frame(width: showRichPreview ? 24 : 16, height: showRichPreview ? 24 : 16)
                        if showRichPreview {
                            Text(hexColorString(comps))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        } else {
                            Text("Color")
                        }
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
}

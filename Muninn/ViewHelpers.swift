import Foundation

/// Filters clips by search text and optional content type.
/// Both name and preview are matched case-insensitively.
func filterClips(_ clips: [Clip], search: String, typeFilter: ClipboardContentType?) -> [Clip] {
    var items = clips
    if let typeFilter {
        items = items.filter { $0.contentType == typeFilter }
    }
    if !search.isEmpty {
        let q = search.lowercased()
        items = items.filter {
            $0.name.lowercased().contains(q) || $0.preview.lowercased().contains(q)
        }
    }
    return items
}

/// Filters history items by search text, optional content type, and optional source app.
/// - Text items are searched by value.
/// - FileURL items are searched by path.
/// - All other types are searched by preview (which includes OCR text for images).
/// - Barcode values are included in search only when `enableQRDetection` is true.
func filterHistoryItems(
    _ items: [HistoryItem],
    search: String,
    typeFilter: ClipboardContentType?,
    appFilter: String? = nil,
    enableQRDetection: Bool
) -> [HistoryItem] {
    var result = items
    if let appFilter {
        result = result.filter { $0.sourceAppBundleID == appFilter }
    }
    if let typeFilter {
        result = result.filter { $0.contentType == typeFilter }
    }
    if !search.isEmpty {
        let q = search.lowercased()
        result = result.filter { item in
            switch item.contentType {
            case .text:
                return item.value?.lowercased().contains(q) ?? false
            case .color:
                if item.contentType.displayName.lowercased().contains(q) { return true }
                guard let components = item.colorComponents else { return false }
                return hexColorString(components).lowercased().contains(q)
            case .fileURL:
                return (item.fileURLs?.contains { $0.lowercased().contains(q) } ?? false)
                    || (item.ocrText?.lowercased().contains(q) ?? false)
            default:
                return item.preview.lowercased().contains(q)
                    || (enableQRDetection && (item.detectedBarcode?.lowercased().contains(q) ?? false))
            }
        }
    }
    return result
}

/// The temporary file URL used when an image is dragged out: always directly inside the temporary
/// directory, with a name that passes `BlobStorage.isValidFilename`.
func dragImageTempURL(value: String?, blobExtension: String) -> URL {
    let fallback = "Image.\(blobExtension)"
    var name = value ?? ""
    if !BlobStorage.isValidFilename(name) {
        name = (name as NSString).lastPathComponent
        name = String(name.unicodeScalars.map { scalar -> Character in
            (scalar.value < 128 && (CharacterSet.alphanumerics.contains(scalar) || "._-".unicodeScalars.contains(scalar)))
                ? Character(scalar) : "-"
        })
        while name.hasPrefix(".") { name.removeFirst() }
    }
    if !BlobStorage.isValidFilename(name) { name = fallback }
    if !BlobStorage.isValidFilename(name) { name = "Image" }
    return FileManager.default.temporaryDirectory.appendingPathComponent(name)
}

/// Converts the first three RGB components (0.0–1.0) to a CSS-style hex color string.
/// Returns `"#000000"` if fewer than three components are provided.
func hexColorString(_ components: [Double]) -> String {
    guard components.count >= 3 else { return "#000000" }
    func byte(_ component: Double) -> Int {
        component.isFinite ? Int((min(max(component, 0), 1) * 255).rounded()) : 0
    }
    return String(format: "#%02X%02X%02X", byte(components[0]), byte(components[1]), byte(components[2]))
}

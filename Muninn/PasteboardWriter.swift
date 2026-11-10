import AppKit

/// Every string Muninn puts on the pasteboard goes through here, so the clipboard monitor
/// knows the change is its own and doesn't record it again.
enum PasteboardWriter {
    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        ClipboardMonitor.noteSelfCopy()
    }
}

/// The pasteboard operations the history-item write path needs, so a test can substitute a fake.
protocol PasteboardTarget: AnyObject {
    @discardableResult func clearContents() -> Int
    @discardableResult func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool
    @discardableResult func setData(_ data: Data?, forType type: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardTarget {}

extension PasteboardWriter {
    /// Writes a history item to `pasteboard`. A masked (sensitive) item leaves the pasteboard untouched.
    /// Returns false (and touches nothing) when the item is masked.
    @discardableResult
    static func write(_ item: HistoryItem, to pasteboard: PasteboardTarget, plainTextOnly: Bool = false) -> Bool {
        guard item.isSensitive != true else { return false }
        write(contentType: item.contentType, value: item.value, blobFile: item.blobFile,
              fileURLs: item.fileURLs, colorComponents: item.colorComponents,
              to: pasteboard, plainTextOnly: plainTextOnly)
        return true
    }

    static func write(
        contentType: ClipboardContentType,
        value: String?,
        blobFile: String?,
        fileURLs: [String]?,
        colorComponents: [Double]?,
        to pasteboard: PasteboardTarget,
        plainTextOnly: Bool = false
    ) {
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
            if let paths = fileURLs, let real = pasteboard as? NSPasteboard {
                real.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
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
    }
}

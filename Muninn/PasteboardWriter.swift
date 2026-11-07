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

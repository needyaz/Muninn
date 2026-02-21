import Foundation

enum ClipboardContentType: String, Codable, CaseIterable {
    case text, image, pdf, fileURL, color

    var displayName: String {
        switch self {
        case .text: return String(localized: "Text")
        case .image: return String(localized: "Images")
        case .pdf: return String(localized: "PDFs")
        case .fileURL: return String(localized: "Files")
        case .color: return String(localized: "Colors")
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "doc.plaintext"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .fileURL: return "doc.on.doc"
        case .color: return "paintpalette"
        }
    }

    var typeDescription: String {
        switch self {
        case .text: return String(localized: "Plain and rich text")
        case .image: return String(localized: "Screenshots and copied images")
        case .pdf: return String(localized: "PDF documents")
        case .fileURL: return String(localized: "Copied files and folders")
        case .color: return String(localized: "Color swatches")
        }
    }
}

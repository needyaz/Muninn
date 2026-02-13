import Foundation

enum ClipboardContentType: String, Codable, CaseIterable {
    case text, image, pdf, fileURL, color

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Images"
        case .pdf: return "PDFs"
        case .fileURL: return "Files"
        case .color: return "Colors"
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
        case .text: return "Plain and rich text"
        case .image: return "Screenshots and copied images"
        case .pdf: return "PDF documents"
        case .fileURL: return "Copied files and folders"
        case .color: return "Color swatches"
        }
    }
}

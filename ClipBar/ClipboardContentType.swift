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
}

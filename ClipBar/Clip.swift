import Foundation

struct Clip: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var value: String?
    var contentType: ClipboardContentType
    var blobFile: String?
    var fileURLs: [String]?
    var colorComponents: [Double]?

    init(
        id: UUID = UUID(),
        name: String,
        value: String? = nil,
        contentType: ClipboardContentType = .text,
        blobFile: String? = nil,
        fileURLs: [String]? = nil,
        colorComponents: [Double]? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.contentType = contentType
        self.blobFile = blobFile
        self.fileURLs = fileURLs
        self.colorComponents = colorComponents
    }

    // Backward-compatible decoder: defaults contentType to .text when missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        contentType = try container.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        blobFile = try container.decodeIfPresent(String.self, forKey: .blobFile)
        fileURLs = try container.decodeIfPresent([String].self, forKey: .fileURLs)
        colorComponents = try container.decodeIfPresent([Double].self, forKey: .colorComponents)
    }

    var preview: String {
        switch contentType {
        case .image:
            return "Image"
        case .pdf:
            return "PDF Document"
        case .fileURL:
            if let urls = fileURLs, let first = urls.first {
                let name = (first as NSString).lastPathComponent
                if urls.count > 1 {
                    return "\(name) and \(urls.count - 1) more"
                }
                return name
            }
            return "File"
        case .color:
            return "Color"
        case .text:
            guard let value else { return "" }
            let single = value.components(separatedBy: .newlines).joined(separator: " ")
            if single.count > 80 {
                return String(single.prefix(80)) + "…"
            }
            return single
        }
    }
}

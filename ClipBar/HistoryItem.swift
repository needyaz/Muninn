import Foundation

struct HistoryItem: Identifiable, Codable, Hashable {
    var id: UUID
    var value: String?
    var timestamp: Date
    var contentType: ClipboardContentType
    var blobFile: String?
    var fileURLs: [String]?
    var colorComponents: [Double]?
    var sourceAppBundleID: String?

    init(
        id: UUID = UUID(),
        value: String? = nil,
        timestamp: Date = Date(),
        contentType: ClipboardContentType = .text,
        blobFile: String? = nil,
        fileURLs: [String]? = nil,
        colorComponents: [Double]? = nil,
        sourceAppBundleID: String? = nil
    ) {
        self.id = id
        self.value = value
        self.timestamp = timestamp
        self.contentType = contentType
        self.blobFile = blobFile
        self.fileURLs = fileURLs
        self.colorComponents = colorComponents
        self.sourceAppBundleID = sourceAppBundleID
    }

    // Backward-compatible decoder: defaults contentType to .text when missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        contentType = try container.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        blobFile = try container.decodeIfPresent(String.self, forKey: .blobFile)
        fileURLs = try container.decodeIfPresent([String].self, forKey: .fileURLs)
        colorComponents = try container.decodeIfPresent([Double].self, forKey: .colorComponents)
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
    }

    var preview: String {
        switch contentType {
        case .image:
            return value ?? "Image"
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

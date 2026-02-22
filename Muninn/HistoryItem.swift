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
    var ocrText: String?
    var detectedBarcode: String?
    var isSensitive: Bool?

    init(
        id: UUID = UUID(),
        value: String? = nil,
        timestamp: Date = Date(),
        contentType: ClipboardContentType = .text,
        blobFile: String? = nil,
        fileURLs: [String]? = nil,
        colorComponents: [Double]? = nil,
        sourceAppBundleID: String? = nil,
        ocrText: String? = nil,
        detectedBarcode: String? = nil,
        isSensitive: Bool? = nil
    ) {
        self.id = id
        self.value = value
        self.timestamp = timestamp
        self.contentType = contentType
        self.blobFile = blobFile
        self.fileURLs = fileURLs
        self.colorComponents = colorComponents
        self.sourceAppBundleID = sourceAppBundleID
        self.ocrText = ocrText
        self.detectedBarcode = detectedBarcode
        self.isSensitive = isSensitive
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
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
        detectedBarcode = try container.decodeIfPresent(String.self, forKey: .detectedBarcode)
        isSensitive = try container.decodeIfPresent(Bool.self, forKey: .isSensitive)
    }

    var preview: String {
        if isSensitive == true {
            return "Sensitive content"
        }
        switch contentType {
        case .image:
            return ocrText ?? value ?? "Image"
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

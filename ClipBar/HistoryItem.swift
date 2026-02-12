import Foundation

struct HistoryItem: Identifiable, Codable, Hashable {
    var id: UUID
    var value: String
    var timestamp: Date

    init(id: UUID = UUID(), value: String, timestamp: Date = Date()) {
        self.id = id
        self.value = value
        self.timestamp = timestamp
    }

    var preview: String {
        let single = value.components(separatedBy: .newlines).joined(separator: " ")
        if single.count > 80 {
            return String(single.prefix(80)) + "…"
        }
        return single
    }
}

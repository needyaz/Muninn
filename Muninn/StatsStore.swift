import Foundation

@Observable
class StatsStore {
    struct DailyCount: Codable, Hashable {
        var date: String   // "yyyy-MM-dd"
        var count: Int
    }

    struct Stats: Codable {
        var totalCopies: Int = 0
        var typeCounts: [String: Int] = [:]
        var appCounts: [String: Int] = [:]
        var dailyCounts: [DailyCount] = []
    }

    var stats = Stats()

    private let fileURL: URL
    /// Day keys ("2026-11-06") must not depend on the user's locale or calendar, or a Buddhist-calendar
    /// Mac would write a different key than the one the heatmap looks up.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(baseURL: URL = StoragePaths.base) {
        self.fileURL = baseURL.appendingPathComponent("stats.json")
        load()
    }

    func recordCapture(contentType: ClipboardContentType, sourceApp: String?) {
        stats.totalCopies += 1
        stats.typeCounts[contentType.rawValue, default: 0] += 1
        if let app = sourceApp {
            stats.appCounts[app, default: 0] += 1
        }

        let today = Self.dayFormatter.string(from: Date())
        if let idx = stats.dailyCounts.firstIndex(where: { $0.date == today }) {
            stats.dailyCounts[idx].count += 1
        } else {
            stats.dailyCounts.append(DailyCount(date: today, count: 1))
        }

        // Keep last 90 days
        if let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) {
            let cutoffStr = Self.dayFormatter.string(from: cutoff)
            stats.dailyCounts.removeAll { $0.date < cutoffStr }
        }

        save()
    }

    func reset() {
        stats = Stats()
        save()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            stats = try JSONDecoder().decode(Stats.self, from: data)
        } catch {
            Log.storage.error("failed to load stats: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(stats)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.storage.error("failed to save stats: \(error.localizedDescription)")
        }
    }
}

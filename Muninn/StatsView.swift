import SwiftUI
import Charts

struct StatsView: View {
    @Environment(StatsStore.self) private var statsStore
    @Environment(SettingsStore.self) private var settingsStore

    @State private var showResetConfirmation = false

    var body: some View {
        if settingsStore.enableStats {
            statsContent
        } else {
            disabledContent
        }
    }

    private var statsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Overview
                HStack {
                    StatBox(title: "Total Copies", value: "\(statsStore.stats.totalCopies)")
                    StatBox(title: "Content Types", value: "\(statsStore.stats.typeCounts.count)")
                    StatBox(title: "Source Apps", value: "\(statsStore.stats.appCounts.count)")
                }

                // Type breakdown
                if !statsStore.stats.typeCounts.isEmpty {
                    Text("By Type")
                        .font(.headline)

                    Chart(typeChartData, id: \.type) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Type", item.type)
                        )
                        .foregroundStyle(item.color)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                        }
                    }
                    .frame(height: CGFloat(max(typeChartData.count, 1)) * 36)
                }

                // Top source apps
                if !statsStore.stats.appCounts.isEmpty {
                    Text("Top Source Apps")
                        .font(.headline)

                    VStack(spacing: 0) {
                        ForEach(topApps.prefix(8), id: \.bundleID) { app in
                            HStack(spacing: 8) {
                                if let icon = AppIconCache.shared.icon(for: app.bundleID) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 18, height: 18)
                                } else {
                                    Image(systemName: "app")
                                        .frame(width: 18, height: 18)
                                }
                                Text(appName(for: app.bundleID))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(app.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Activity heatmap
                Text("Activity")
                    .font(.headline)

                ActivityHeatmap(dailyCounts: statsStore.stats.dailyCounts)

                // Reset
                HStack {
                    Spacer()
                    Button("Reset Stats", role: .destructive) {
                        showResetConfirmation = true
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .alert("Reset Stats?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { statsStore.reset() }
        } message: {
            Text("This will permanently erase all tracked statistics.")
        }
    }

    @ViewBuilder
    private var disabledContent: some View {
        @Bindable var settings = settingsStore
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Stats tracking is disabled")
                .foregroundStyle(.secondary)
            Toggle("Enable stats tracking", isOn: $settings.enableStats)
                .toggleStyle(.switch)
                .fixedSize()
        }
        .frame(width: 500, height: 450)
    }

    // MARK: - Chart data

    private struct TypeChartItem {
        let type: String
        let count: Int
        let color: Color
    }

    private var typeChartData: [TypeChartItem] {
        let colorMap: [String: Color] = [
            "text": .blue,
            "image": .green,
            "pdf": .orange,
            "fileURL": .purple,
            "color": .pink,
        ]
        return statsStore.stats.typeCounts
            .sorted { $0.value > $1.value }
            .map { key, value in
                let displayName = ClipboardContentType(rawValue: key)?.displayName ?? key
                return TypeChartItem(type: displayName, count: value, color: colorMap[key] ?? .gray)
            }
    }

    // MARK: - Top apps

    private struct AppStat: Hashable {
        let bundleID: String
        let count: Int
    }

    private var topApps: [AppStat] {
        statsStore.stats.appCounts
            .sorted { $0.value > $1.value }
            .map { AppStat(bundleID: $0.key, count: $0.value) }
    }

    private func appName(for bundleID: String) -> String {
        AppIconCache.shared.appName(for: bundleID)
    }
}

// MARK: - Stat box

private struct StatBox: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}

// MARK: - Activity heatmap

private struct ActivityHeatmap: View {
    let dailyCounts: [StatsStore.DailyCount]

    private let columns = 13 // weeks
    private let rows = 7     // days of week
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    var body: some View {
        let grid = buildGrid()
        let maxCount = grid.flatMap { $0 }.max() ?? 1

        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let count = grid[row][col]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(count: count, max: maxCount))
                            .frame(width: cellSize, height: cellSize)
                            .help(cellTooltip(row: row, col: col, count: count))
                    }
                }
            }
        }
    }

    private func buildGrid() -> [[Int]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun, 7=Sat

        // Build a lookup from date string to count
        var lookup: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for dc in dailyCounts {
            lookup[dc.date] = dc.count
        }

        // Grid: rows = weekdays (0=Sun..6=Sat), cols = weeks (0=oldest..12=current)
        // The rightmost column's `todayWeekday-1` row is today
        var grid = Array(repeating: Array(repeating: 0, count: columns), count: rows)

        for col in 0..<columns {
            for row in 0..<rows {
                let weeksBack = columns - 1 - col
                let daysBack = weeksBack * 7 + (todayWeekday - 1 - row)
                guard daysBack >= 0, let date = calendar.date(byAdding: .day, value: -daysBack, to: today) else {
                    continue
                }
                let key = formatter.string(from: date)
                grid[row][col] = lookup[key] ?? 0
            }
        }

        return grid
    }

    private func heatColor(count: Int, max: Int) -> Color {
        guard count > 0, max > 0 else {
            return Color.primary.opacity(0.06)
        }
        let intensity = Double(count) / Double(max)
        return Color.green.opacity(0.2 + intensity * 0.8)
    }

    private func cellTooltip(row: Int, col: Int, count: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today)
        let weeksBack = columns - 1 - col
        let daysBack = weeksBack * 7 + (todayWeekday - 1 - row)
        guard daysBack >= 0, let date = calendar.date(byAdding: .day, value: -daysBack, to: today) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)
        if count == 0 {
            return String(localized: "No copies on \(dateStr)")
        }
        return String(localized: "\(count) copies on \(dateStr)")
    }
}

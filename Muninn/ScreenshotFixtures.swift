#if DEBUG
import Foundation

// Made-up data for the App Store screenshots. The screenshot mode never reads the real clipboard, history or
// preferences: it runs the real views against these fixtures, a frozen clock and a private UserDefaults suite.

struct ScreenshotStores {
    let settings: SettingsStore
    let history: HistoryStore
    let clips: ClipStore
    let excludedApps: ExcludedAppsStore
    let excludedTypes: ExcludedTypesStore
    let stats: StatsStore
}

enum ScreenshotFixtures {
    /// The frozen clock every fixture timestamp is relative to: a fixed instant (Tue 2026-03-17 09:48 UTC), so
    /// "2 minutes ago" is the same in every run.
    static let now = Date(timeIntervalSince1970: 1_773_740_880)

    /// Name of the private, non-standard UserDefaults suite used by the screenshot mode.
    static let defaultsSuiteName = "blue.luci.Muninn.screenshots"

    private static func ago(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }

    /// Newest first. Made-up text only: no real people, accounts, numbers or credentials.
    static let historyItems: [HistoryItem] = [
        HistoryItem(value: "https://example.com/blog/hello-world", timestamp: ago(20), contentType: .text, sourceAppBundleID: "com.apple.Safari"),
        HistoryItem(value: "Team lunch on Friday at 12:30. Booking a table for six near the office.", timestamp: ago(95), contentType: .text, sourceAppBundleID: "com.apple.Notes"),
        HistoryItem(value: "4A90E2", timestamp: ago(210), contentType: .color, colorComponents: [0.29, 0.565, 0.886, 1.0], sourceAppBundleID: "com.apple.TextEdit"),
        HistoryItem(value: "func greet(name: String) -> String {\n    \"Hello, \\(name)!\"\n}", timestamp: ago(420), contentType: .text, sourceAppBundleID: "com.apple.dt.Xcode"),
        HistoryItem(value: nil, timestamp: ago(640), contentType: .fileURL, fileURLs: ["/home/jane/Documents/Project Roadmap.pdf"], sourceAppBundleID: "com.apple.finder"),
        HistoryItem(value: "Hi Sam,\n\nThanks for the update. The draft looks great and I have only a few small notes.\n\nBest,\nJane", timestamp: ago(900), contentType: .text, sourceAppBundleID: "com.apple.mail"),
        HistoryItem(value: "jane@example.com", timestamp: ago(1_500), contentType: .text, sourceAppBundleID: "com.apple.mail"),
        HistoryItem(value: "brew install wget", timestamp: ago(2_400), contentType: .text, sourceAppBundleID: "com.apple.Terminal"),
        HistoryItem(value: "The quick brown fox jumps over the lazy dog.", timestamp: ago(3_600), contentType: .text, sourceAppBundleID: "com.apple.Notes"),
        HistoryItem(value: "FF7A59", timestamp: ago(5_400), contentType: .color, colorComponents: [1.0, 0.478, 0.349, 1.0], sourceAppBundleID: "com.apple.TextEdit"),
    ]

    static let clips: [Clip] = [
        Clip(name: "Email signature", value: "Best regards,\nJane Doe"),
        Clip(name: "Home address", value: "12 Example Street, Springfield"),
        Clip(name: "Meeting link", value: "https://example.com/meet/standup"),
        Clip(name: "Thanks reply", value: "Thanks so much, I'll take a look and get back to you shortly."),
        Clip(name: "Support email", value: "support@example.com"),
        Clip(name: "Brand blue", value: "1A3A8F"),
    ]

    /// Preferences as the screenshots show them, in a private suite so the real settings are never touched.
    static func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults.set(true, forKey: "hasSeenOnboarding")  // so the popover doesn't open the welcome window
        defaults.set(360.0, forKey: "popoverWidth")
        defaults.set(470.0, forKey: "popoverHeight")
        return defaults
    }

    /// Builds stores backed by fixture data under `baseURL` (a temporary directory, never `StoragePaths.base`).
    @MainActor
    static func makeStores(baseURL: URL, defaults: UserDefaults) -> ScreenshotStores {
        let settings = SettingsStore(defaults: defaults)
        let history = HistoryStore(settingsStore: settings, baseURL: baseURL)
        history.items = historyItems
        history.save()
        let clipStore = ClipStore(baseURL: baseURL)
        clipStore.clips = clips
        clipStore.save()
        return ScreenshotStores(
            settings: settings,
            history: history,
            clips: clipStore,
            excludedApps: ExcludedAppsStore(baseURL: baseURL),
            excludedTypes: ExcludedTypesStore(baseURL: baseURL),
            stats: StatsStore(baseURL: baseURL)
        )
    }
}
#endif

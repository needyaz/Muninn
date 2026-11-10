import Foundation

@Observable
class SettingsStore {
    /// Where every setting is read from and written to (the standard defaults, or a private suite in tests and screenshots).
    private let defaults: UserDefaults

    var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: "historyLimit") }
    }

    var pasteAsPlainText: Bool {
        didSet { defaults.set(pasteAsPlainText, forKey: "pasteAsPlainText") }
    }

    var enableStats: Bool {
        didSet { defaults.set(enableStats, forKey: "enableStats") }
    }

    var enableRichPreviews: Bool {
        didSet { defaults.set(enableRichPreviews, forKey: "enableRichPreviews") }
    }

    var captureSound: String {
        didSet { defaults.set(captureSound, forKey: "captureSound") }
    }

    var captureScreenshots: Bool {
        didSet { defaults.set(captureScreenshots, forKey: "captureScreenshots") }
    }

    var enableOCR: Bool {
        didSet { defaults.set(enableOCR, forKey: "enableOCR") }
    }

    var enableQRDetection: Bool {
        didSet { defaults.set(enableQRDetection, forKey: "enableQRDetection") }
    }

    var enablePDFTextExtraction: Bool {
        didSet { defaults.set(enablePDFTextExtraction, forKey: "enablePDFTextExtraction") }
    }

    var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: "hasSeenOnboarding") }
    }

    var popoverHeight: Double {
        didSet { defaults.set(popoverHeight, forKey: "popoverHeight") }
    }

    var popoverWidth: Double {
        didSet { defaults.set(popoverWidth, forKey: "popoverWidth") }
    }

    /// "skip" = don't record, "mask" = record but hide preview, "allow" = record normally
    var sensitiveHandling: String {
        didSet { defaults.set(sensitiveHandling, forKey: "sensitiveHandling") }
    }

    var screenshotFolderBookmark: Data? {
        didSet { defaults.set(screenshotFolderBookmark, forKey: "screenshotFolderBookmark") }
    }

    /// Resolves the stored security-scoped bookmark to a URL. Refreshes stale bookmarks automatically.
    var screenshotFolderURL: URL? {
        guard let bookmark = screenshotFolderBookmark else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else { return nil }
        if isStale, let fresh = try? url.bookmarkData(options: .withSecurityScope) {
            screenshotFolderBookmark = fresh
        }
        return url
    }

    /// Marks the onboarding as seen; called on every close path of the onboarding window.
    func markOnboardingSeen() {
        hasSeenOnboarding = true
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "historyLimit": 50,
            "pasteAsPlainText": false,
            "enableStats": true,
            "enableRichPreviews": true,
            "captureSound": "",
            "captureScreenshots": false,
            "enableOCR": false,
            "enableQRDetection": false,
            "enablePDFTextExtraction": false,
            "hasSeenOnboarding": false,
            "popoverHeight": 400.0,
            "popoverWidth": 320.0,
            "sensitiveHandling": "skip",
        ])
        historyLimit = defaults.integer(forKey: "historyLimit")
        pasteAsPlainText = defaults.bool(forKey: "pasteAsPlainText")
        enableStats = defaults.bool(forKey: "enableStats")
        enableRichPreviews = defaults.bool(forKey: "enableRichPreviews")
        captureSound = defaults.string(forKey: "captureSound") ?? ""
        captureScreenshots = defaults.bool(forKey: "captureScreenshots")
        enableOCR = defaults.bool(forKey: "enableOCR")
        enableQRDetection = defaults.bool(forKey: "enableQRDetection")
        enablePDFTextExtraction = defaults.bool(forKey: "enablePDFTextExtraction")
        hasSeenOnboarding = defaults.bool(forKey: "hasSeenOnboarding")
        popoverHeight = defaults.double(forKey: "popoverHeight")
        popoverWidth = defaults.double(forKey: "popoverWidth")
        sensitiveHandling = defaults.string(forKey: "sensitiveHandling") ?? "skip"
        screenshotFolderBookmark = defaults.data(forKey: "screenshotFolderBookmark")
    }
}

import Foundation

@Observable
class SettingsStore {
    var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: "historyLimit") }
    }

    var pasteAsPlainText: Bool {
        didSet { UserDefaults.standard.set(pasteAsPlainText, forKey: "pasteAsPlainText") }
    }

    var enableStats: Bool {
        didSet { UserDefaults.standard.set(enableStats, forKey: "enableStats") }
    }

    var enableRichPreviews: Bool {
        didSet { UserDefaults.standard.set(enableRichPreviews, forKey: "enableRichPreviews") }
    }

    var captureSound: String {
        didSet { UserDefaults.standard.set(captureSound, forKey: "captureSound") }
    }

    var captureScreenshots: Bool {
        didSet { UserDefaults.standard.set(captureScreenshots, forKey: "captureScreenshots") }
    }

    var enableOCR: Bool {
        didSet { UserDefaults.standard.set(enableOCR, forKey: "enableOCR") }
    }

    var enableQRDetection: Bool {
        didSet { UserDefaults.standard.set(enableQRDetection, forKey: "enableQRDetection") }
    }

    var enablePDFTextExtraction: Bool {
        didSet { UserDefaults.standard.set(enablePDFTextExtraction, forKey: "enablePDFTextExtraction") }
    }

    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding") }
    }

    var popoverHeight: Double {
        didSet { UserDefaults.standard.set(popoverHeight, forKey: "popoverHeight") }
    }

    var popoverWidth: Double {
        didSet { UserDefaults.standard.set(popoverWidth, forKey: "popoverWidth") }
    }

    /// "skip" = don't record, "mask" = record but hide preview, "allow" = record normally
    var sensitiveHandling: String {
        didSet { UserDefaults.standard.set(sensitiveHandling, forKey: "sensitiveHandling") }
    }

    init() {
        let defaults = UserDefaults.standard
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
    }
}

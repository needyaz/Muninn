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
        ])
        historyLimit = defaults.integer(forKey: "historyLimit")
        pasteAsPlainText = defaults.bool(forKey: "pasteAsPlainText")
        enableStats = defaults.bool(forKey: "enableStats")
        enableRichPreviews = defaults.bool(forKey: "enableRichPreviews")
        captureSound = defaults.string(forKey: "captureSound") ?? ""
        captureScreenshots = defaults.bool(forKey: "captureScreenshots")
        enableOCR = defaults.bool(forKey: "enableOCR")
    }
}

import Foundation

@Observable
class SettingsStore {
    var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: "historyLimit") }
    }

    var pasteAsPlainText: Bool {
        didSet { UserDefaults.standard.set(pasteAsPlainText, forKey: "pasteAsPlainText") }
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "historyLimit": 50,
            "pasteAsPlainText": false,
        ])
        historyLimit = defaults.integer(forKey: "historyLimit")
        pasteAsPlainText = defaults.bool(forKey: "pasteAsPlainText")
    }
}

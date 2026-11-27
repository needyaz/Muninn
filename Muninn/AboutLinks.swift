import AppKit
import Foundation

/// The links shown in the About tab.
enum AboutLink: CaseIterable {
    case reportProblem
    case suggestIdea
    case website

    var url: URL {
        switch self {
        case .reportProblem:
            URL(string: "https://github.com/needyaz/feedback/issues/new?template=bug.yml&app=Muninn%20%28Mac%29")!
        case .suggestIdea:
            URL(string: "https://github.com/needyaz/feedback/issues/new?template=feature.yml&app=Muninn%20%28Mac%29")!
        case .website:
            URL(string: "https://luci.blue/muninn")!
        }
    }
}

/// Version text and link opening for the About tab.
enum AboutLinks {
    /// Opens a URL; replaceable so tests never launch a browser.
    static var opener: (URL) -> Void = { NSWorkspace.shared.open($0) }

    static func open(_ link: AboutLink) {
        opener(link.url)
    }

    static func versionLine(bundle: Bundle = .main) -> String {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

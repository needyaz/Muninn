import Testing
import Foundation
@testable import Muninn

@Suite(.serialized)
struct AboutLinksTests {
    @Test func linksOpenExactURLsThroughOpener() {
        let saved = AboutLinks.opener
        defer { AboutLinks.opener = saved }
        var opened: [String] = []
        AboutLinks.opener = { opened.append($0.absoluteString) }
        AboutLinks.open(.reportProblem)
        AboutLinks.open(.suggestIdea)
        AboutLinks.open(.website)
        #expect(opened == [
            "https://github.com/needyaz/feedback/issues/new?template=bug.yml&app=Muninn%20%28Mac%29",
            "https://github.com/needyaz/feedback/issues/new?template=feature.yml&app=Muninn%20%28Mac%29",
            "https://luci.blue/muninn",
        ])
    }

    @Test func versionLineUsesBundleValues() {
        #expect(AboutLinks.versionLine(bundle: Bundle.main).hasPrefix("Version "))
    }
}

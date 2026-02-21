import Testing
import Foundation
@testable import ClipBar

@Suite("ClipboardContentType")
struct ClipboardContentTypeTests {

    @Test("allCases count")
    func allCasesCount() {
        #expect(ClipboardContentType.allCases.count == 5)
    }

    @Test("rawValue round-trip", arguments: ClipboardContentType.allCases)
    func rawValueRoundTrip(type: ClipboardContentType) {
        #expect(ClipboardContentType(rawValue: type.rawValue) == type)
    }

    @Test("displayName is non-empty", arguments: ClipboardContentType.allCases)
    func displayNameNonEmpty(type: ClipboardContentType) {
        #expect(!type.displayName.isEmpty)
    }

    @Test("systemImage is non-empty", arguments: ClipboardContentType.allCases)
    func systemImageNonEmpty(type: ClipboardContentType) {
        #expect(!type.systemImage.isEmpty)
    }

    @Test("typeDescription is non-empty", arguments: ClipboardContentType.allCases)
    func typeDescriptionNonEmpty(type: ClipboardContentType) {
        #expect(!type.typeDescription.isEmpty)
    }

    @Test("Codable round-trip", arguments: ClipboardContentType.allCases)
    func codableRoundTrip(type: ClipboardContentType) throws {
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(ClipboardContentType.self, from: data)
        #expect(decoded == type)
    }
}

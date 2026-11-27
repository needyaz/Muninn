import Testing
import Foundation
import CryptoKit

struct BrandLogoTests {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func md5(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @Test func aboutLogoIsTheCurrentBlueMark() throws {
        let dir = Self.root.appendingPathComponent("Muninn/Assets.xcassets/BlueLuciLogo.imageset")
        let pngs = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".png") }
        #expect(pngs == ["BlueLuciLogo.png"])
        let data = try Data(contentsOf: dir.appendingPathComponent("BlueLuciLogo.png"))
        #expect(md5(data) != "6928cdbfd7f79c7e2c65fb9233e0fa3e", "old cream logo")
        #expect(md5(data) == "240168586c9008244ad332aea131d70c")
    }
}

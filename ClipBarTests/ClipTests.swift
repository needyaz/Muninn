import Testing
import Foundation
@testable import ClipBar

@Suite("Clip")
struct ClipTests {

    // MARK: - Preview

    @Test("preview for text clip")
    func previewText() {
        let clip = Clip(name: "Test", value: "Hello world")
        #expect(clip.preview == "Hello world")
    }

    @Test("preview truncates at 80 characters")
    func previewTruncation() {
        let long = String(repeating: "a", count: 100)
        let clip = Clip(name: "Long", value: long)
        #expect(clip.preview.count == 81) // 80 chars + "…"
        #expect(clip.preview.hasSuffix("…"))
    }

    @Test("preview collapses newlines to spaces")
    func previewNewlineCollapsing() {
        let clip = Clip(name: "Multi", value: "line1\nline2\nline3")
        #expect(clip.preview == "line1 line2 line3")
    }

    @Test("preview for image clip")
    func previewImage() {
        let clip = Clip(name: "Img", contentType: .image)
        #expect(clip.preview == "Image")
    }

    @Test("preview for PDF clip")
    func previewPDF() {
        let clip = Clip(name: "Doc", contentType: .pdf)
        #expect(clip.preview == "PDF Document")
    }

    @Test("preview for fileURL clip with single path")
    func previewFileURLSingle() {
        let clip = Clip(name: "File", contentType: .fileURL, fileURLs: ["/Users/test/readme.txt"])
        #expect(clip.preview == "readme.txt")
    }

    @Test("preview for fileURL clip with multiple paths")
    func previewFileURLMultiple() {
        let clip = Clip(name: "Files", contentType: .fileURL, fileURLs: ["/a/file1.txt", "/b/file2.txt"])
        #expect(clip.preview == "file1.txt and 1 more")
    }

    @Test("preview for color clip")
    func previewColor() {
        let clip = Clip(name: "Col", contentType: .color, colorComponents: [1, 0, 0, 1])
        #expect(clip.preview == "Color")
    }

    @Test("preview for text clip with nil value")
    func previewNilValue() {
        let clip = Clip(name: "Empty", value: nil)
        #expect(clip.preview == "")
    }

    // MARK: - Codable

    @Test("JSON encode/decode round-trip")
    func jsonRoundTrip() throws {
        let clip = Clip(name: "Test", value: "hello", contentType: .text,
                        fileURLs: nil, colorComponents: [1, 0, 0, 1])
        let data = try JSONEncoder().encode(clip)
        let decoded = try JSONDecoder().decode(Clip.self, from: data)
        #expect(decoded.id == clip.id)
        #expect(decoded.name == clip.name)
        #expect(decoded.value == clip.value)
        #expect(decoded.contentType == clip.contentType)
        #expect(decoded.colorComponents == clip.colorComponents)
    }

    @Test("backward-compat decode without contentType defaults to text")
    func backwardCompatDecode() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Old","value":"hello"}
        """
        let decoded = try JSONDecoder().decode(Clip.self, from: Data(json.utf8))
        #expect(decoded.contentType == .text)
        #expect(decoded.name == "Old")
        #expect(decoded.value == "hello")
    }
}

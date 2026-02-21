import Testing
import Foundation
@testable import ClipBar

@Suite("HistoryItem")
struct HistoryItemTests {

    // MARK: - Preview

    @Test("preview for sensitive item hides content")
    func previewSensitive() {
        let item = HistoryItem(value: "secret", isSensitive: true)
        #expect(item.preview == "Sensitive content")
    }

    @Test("preview for image with OCR text shows OCR")
    func previewImageOCR() {
        let item = HistoryItem(contentType: .image, ocrText: "recognized text")
        #expect(item.preview == "recognized text")
    }

    @Test("preview for image with value but no OCR shows value")
    func previewImageValue() {
        let item = HistoryItem(value: "photo.png", contentType: .image)
        #expect(item.preview == "photo.png")
    }

    @Test("preview for image with no value or OCR")
    func previewImageFallback() {
        let item = HistoryItem(contentType: .image)
        #expect(item.preview == "Image")
    }

    @Test("preview for PDF")
    func previewPDF() {
        let item = HistoryItem(contentType: .pdf)
        #expect(item.preview == "PDF Document")
    }

    @Test("preview for text")
    func previewText() {
        let item = HistoryItem(value: "hello world")
        #expect(item.preview == "hello world")
    }

    @Test("preview for text truncates long strings")
    func previewTextTruncation() {
        let long = String(repeating: "x", count: 100)
        let item = HistoryItem(value: long)
        #expect(item.preview.count == 81)
        #expect(item.preview.hasSuffix("…"))
    }

    @Test("preview for fileURL with single path")
    func previewFileURLSingle() {
        let item = HistoryItem(contentType: .fileURL, fileURLs: ["/tmp/notes.md"])
        #expect(item.preview == "notes.md")
    }

    @Test("preview for fileURL with multiple paths")
    func previewFileURLMultiple() {
        let item = HistoryItem(contentType: .fileURL, fileURLs: ["/a/f1.txt", "/b/f2.txt", "/c/f3.txt"])
        #expect(item.preview == "f1.txt and 2 more")
    }

    @Test("preview for color")
    func previewColor() {
        let item = HistoryItem(contentType: .color, colorComponents: [0, 0, 1, 1])
        #expect(item.preview == "Color")
    }

    // MARK: - Codable

    @Test("JSON encode/decode round-trip")
    func jsonRoundTrip() throws {
        let item = HistoryItem(value: "test", contentType: .text, sourceAppBundleID: "com.test.app")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(HistoryItem.self, from: data)
        #expect(decoded.id == item.id)
        #expect(decoded.value == item.value)
        #expect(decoded.contentType == item.contentType)
        #expect(decoded.sourceAppBundleID == item.sourceAppBundleID)
    }

    @Test("backward-compat decode without contentType defaults to text")
    func backwardCompatDecode() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000002","value":"old","timestamp":0}
        """
        let decoded = try JSONDecoder().decode(HistoryItem.self, from: Data(json.utf8))
        #expect(decoded.contentType == .text)
        #expect(decoded.value == "old")
    }

    @Test("backward-compat decode without optional fields")
    func backwardCompatDecodeOptionals() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000003","timestamp":0}
        """
        let decoded = try JSONDecoder().decode(HistoryItem.self, from: Data(json.utf8))
        #expect(decoded.ocrText == nil)
        #expect(decoded.detectedBarcode == nil)
        #expect(decoded.isSensitive == nil)
        #expect(decoded.sourceAppBundleID == nil)
    }
}

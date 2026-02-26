import Testing
@testable import Muninn

@Suite("filterClips")
struct FilterClipsTests {

    private func clip(
        name: String,
        value: String? = nil,
        type: ClipboardContentType = .text
    ) -> Clip {
        Clip(name: name, value: value, contentType: type)
    }

    @Test("empty search returns all clips")
    func emptySearchReturnsAll() {
        let clips = [clip(name: "Alpha"), clip(name: "Beta"), clip(name: "Gamma")]
        #expect(filterClips(clips, search: "", typeFilter: nil).count == 3)
    }

    @Test("type filter limits results")
    func typeFilter() {
        let clips = [
            clip(name: "Text clip", type: .text),
            clip(name: "Image clip", type: .image),
        ]
        let result = filterClips(clips, search: "", typeFilter: .text)
        #expect(result.count == 1)
        #expect(result[0].name == "Text clip")
    }

    @Test("search matches clip name case-insensitively")
    func searchByName() {
        let clips = [clip(name: "Hello World"), clip(name: "Goodbye")]
        let result = filterClips(clips, search: "hello", typeFilter: nil)
        #expect(result.count == 1)
        #expect(result[0].name == "Hello World")
    }

    @Test("search matches clip preview case-insensitively")
    func searchByPreview() {
        // For a text clip, preview == value (trimmed to 80 chars)
        let clips = [
            clip(name: "MySnippet", value: "SELECT * FROM users", type: .text),
            clip(name: "Other", value: "nothing special", type: .text),
        ]
        let result = filterClips(clips, search: "SELECT", typeFilter: nil)
        #expect(result.count == 1)
        #expect(result[0].name == "MySnippet")
    }

    @Test("no match returns empty")
    func noMatch() {
        let clips = [clip(name: "Alpha"), clip(name: "Beta")]
        #expect(filterClips(clips, search: "zzz", typeFilter: nil).isEmpty)
    }

    @Test("type filter and search are combined")
    func typeFilterAndSearch() {
        let clips = [
            clip(name: "Alpha", type: .text),
            clip(name: "Alpha", type: .image),
        ]
        let result = filterClips(clips, search: "alpha", typeFilter: .image)
        #expect(result.count == 1)
        #expect(result[0].contentType == .image)
    }

    @Test("empty clip list returns empty")
    func emptyInput() {
        #expect(filterClips([], search: "x", typeFilter: nil).isEmpty)
    }
}

// MARK: -

@Suite("filterHistoryItems")
struct FilterHistoryItemsTests {

    private func textItem(value: String) -> HistoryItem {
        HistoryItem(value: value, contentType: .text)
    }

    private func fileItem(paths: [String]) -> HistoryItem {
        HistoryItem(contentType: .fileURL, fileURLs: paths)
    }

    private func imageItem(ocrText: String? = nil, barcode: String? = nil) -> HistoryItem {
        HistoryItem(contentType: .image, ocrText: ocrText, detectedBarcode: barcode)
    }

    @Test("empty search returns all items")
    func emptySearchReturnsAll() {
        let items = [textItem(value: "a"), textItem(value: "b"), textItem(value: "c")]
        #expect(filterHistoryItems(items, search: "", typeFilter: nil, enableQRDetection: false).count == 3)
    }

    @Test("type filter limits results")
    func typeFilter() {
        let items = [textItem(value: "hello"), imageItem()]
        let result = filterHistoryItems(items, search: "", typeFilter: .text, enableQRDetection: false)
        #expect(result.count == 1)
        #expect(result[0].contentType == .text)
    }

    @Test("text items searched by value case-insensitively")
    func textSearchByValue() {
        let items = [textItem(value: "Hello World"), textItem(value: "Goodbye")]
        let result = filterHistoryItems(items, search: "HELLO", typeFilter: nil, enableQRDetection: false)
        #expect(result.count == 1)
        #expect(result[0].value == "Hello World")
    }

    @Test("text items not matched by search term absent from value")
    func textSearchNoMatch() {
        let items = [textItem(value: "foo bar")]
        #expect(filterHistoryItems(items, search: "baz", typeFilter: nil, enableQRDetection: false).isEmpty)
    }

    @Test("fileURL items searched by path case-insensitively")
    func fileURLSearchByPath() {
        let items = [
            fileItem(paths: ["/Users/nate/Documents/Report.pdf"]),
            fileItem(paths: ["/tmp/scratch.txt"]),
        ]
        let result = filterHistoryItems(items, search: "report", typeFilter: nil, enableQRDetection: false)
        #expect(result.count == 1)
        #expect(result[0].fileURLs?.first?.contains("Report") == true)
    }

    @Test("fileURL with multiple paths matches if any path matches")
    func fileURLMultiplePaths() {
        let items = [fileItem(paths: ["/tmp/a.txt", "/home/foo/README.md"])]
        #expect(filterHistoryItems(items, search: "readme", typeFilter: nil, enableQRDetection: false).count == 1)
    }

    @Test("image items searched by OCR text via preview")
    func imageSearchByOCRText() {
        let items = [
            imageItem(ocrText: "Invoice #12345"),
            imageItem(ocrText: nil),
        ]
        let result = filterHistoryItems(items, search: "invoice", typeFilter: nil, enableQRDetection: false)
        #expect(result.count == 1)
    }

    @Test("barcode matched when enableQRDetection is true")
    func barcodeSearchEnabled() {
        let items = [
            imageItem(barcode: "https://example.com"),
            imageItem(barcode: nil),
        ]
        let result = filterHistoryItems(items, search: "example.com", typeFilter: nil, enableQRDetection: true)
        #expect(result.count == 1)
    }

    @Test("barcode NOT matched when enableQRDetection is false")
    func barcodeSearchDisabled() {
        let items = [imageItem(barcode: "https://example.com")]
        let result = filterHistoryItems(items, search: "example.com", typeFilter: nil, enableQRDetection: false)
        #expect(result.isEmpty)
    }

    @Test("type filter and search combined")
    func typeFilterAndSearch() {
        let items = [textItem(value: "alpha"), imageItem(ocrText: "alpha")]
        let result = filterHistoryItems(items, search: "alpha", typeFilter: .text, enableQRDetection: false)
        #expect(result.count == 1)
        #expect(result[0].contentType == .text)
    }

    @Test("empty item list returns empty")
    func emptyInput() {
        #expect(filterHistoryItems([], search: "x", typeFilter: nil, enableQRDetection: false).isEmpty)
    }

    @Test("fileURL items searched by extracted PDF text")
    func fileURLSearchByOCRText() {
        let items = [
            HistoryItem(contentType: .fileURL, fileURLs: ["/docs/report.pdf"], ocrText: "Annual revenue summary"),
            HistoryItem(contentType: .fileURL, fileURLs: ["/docs/notes.pdf"]),
        ]
        let result = filterHistoryItems(items, search: "revenue", typeFilter: nil, enableQRDetection: false)
        #expect(result.count == 1)
        #expect(result[0].ocrText == "Annual revenue summary")
    }
}

// MARK: -

@Suite("hexColorString")
struct HexColorStringTests {

    @Test("pure red")
    func pureRed() {
        #expect(hexColorString([1.0, 0.0, 0.0]) == "#FF0000")
    }

    @Test("pure green")
    func pureGreen() {
        #expect(hexColorString([0.0, 1.0, 0.0]) == "#00FF00")
    }

    @Test("pure blue")
    func pureBlue() {
        #expect(hexColorString([0.0, 0.0, 1.0]) == "#0000FF")
    }

    @Test("white")
    func white() {
        #expect(hexColorString([1.0, 1.0, 1.0]) == "#FFFFFF")
    }

    @Test("black")
    func black() {
        #expect(hexColorString([0.0, 0.0, 0.0]) == "#000000")
    }

    @Test("fewer than 3 components returns black")
    func tooFewComponents() {
        #expect(hexColorString([]) == "#000000")
        #expect(hexColorString([1.0]) == "#000000")
        #expect(hexColorString([1.0, 0.5]) == "#000000")
    }

    @Test("alpha component is ignored")
    func alphaIgnored() {
        // Function only uses first 3 components
        #expect(hexColorString([1.0, 0.0, 0.0, 0.5]) == "#FF0000")
    }

    @Test("midpoint grey")
    func midGrey() {
        // 0.5 * 255 = 127.5 → Int(127) = 0x7F
        #expect(hexColorString([0.5, 0.5, 0.5]) == "#7F7F7F")
    }
}

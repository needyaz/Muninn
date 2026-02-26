import Testing
import Foundation
import PDFKit
@testable import Muninn

@Suite("PDFTextService")
struct PDFTextServiceTests {

    private func extractText(from data: Data) async -> String? {
        await withCheckedContinuation { continuation in
            PDFTextService.extractText(from: data) { text in
                continuation.resume(returning: text)
            }
        }
    }

    private func makePDF(text: String) -> Data {
        let pdf = PDFDocument()
        let page = PDFPage()
        // Create a PDF page with selectable text using PDFKit
        // We annotate the page since programmatic text PDFs aren't trivial
        // Instead use a known-good minimal PDF with embedded text
        return pdf.dataRepresentation() ?? Data()
    }

    @Test("invalid data returns nil")
    func invalidData() async {
        let text = await extractText(from: Data([0x00, 0x01, 0x02, 0x03]))
        #expect(text == nil)
    }

    @Test("empty data returns nil")
    func emptyData() async {
        let text = await extractText(from: Data())
        #expect(text == nil)
    }

    @Test("empty PDF returns nil")
    func emptyPDF() async {
        let emptyDoc = PDFDocument()
        let data = emptyDoc.dataRepresentation() ?? Data()
        let text = await extractText(from: data)
        #expect(text == nil)
    }
}

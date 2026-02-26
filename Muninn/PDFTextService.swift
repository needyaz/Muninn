import PDFKit

enum PDFTextService {
    static func extractText(from pdfData: Data, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let document = PDFDocument(data: pdfData) else {
                print("Muninn PDFTextService: PDFDocument(data:) returned nil for \(pdfData.count) bytes")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard document.pageCount > 0 else {
                print("Muninn PDFTextService: document has 0 pages")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            var pages: [String] = []
            for i in 0..<document.pageCount {
                if let page = document.page(at: i), let text = page.string, !text.isEmpty {
                    pages.append(text)
                }
            }
            let result = pages
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            print("Muninn PDFTextService: \(document.pageCount) page(s), extracted \(result.count) chars")
            DispatchQueue.main.async { completion(result.isEmpty ? nil : result) }
        }
    }
}

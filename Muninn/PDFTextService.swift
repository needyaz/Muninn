import PDFKit

enum PDFTextService {
    static func extractText(from pdfData: Data, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let document = PDFDocument(data: pdfData) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard document.pageCount > 0 else {
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
            DispatchQueue.main.async { completion(result.isEmpty ? nil : result) }
        }
    }
}

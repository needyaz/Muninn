import Vision
import AppKit

enum OCRService {
    static func extractText(from imageData: Data, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(data: imageData),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // Vision normally reports failure through the handler, but make sure `completion` runs exactly once.
            let finished = OnceFlag()
            let request = VNRecognizeTextRequest { request, _ in
                guard finished.claim() else { return }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async { completion(text?.isEmpty == true ? nil : text) }
            }
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                if finished.claim() { DispatchQueue.main.async { completion(nil) } }
            }
        }
    }
}

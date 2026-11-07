import Vision
import AppKit

enum QRService {
    static func detectBarcode(from imageData: Data, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(data: imageData),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let finished = OnceFlag()
            let request = VNDetectBarcodesRequest { request, _ in
                guard finished.claim() else { return }
                let value = (request.results as? [VNBarcodeObservation])?
                    .first?.payloadStringValue
                DispatchQueue.main.async { completion(value) }
            }
            request.symbologies = [.qr, .ean13, .ean8, .code128, .code39, .upce]
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                if finished.claim() { DispatchQueue.main.async { completion(nil) } }
            }
        }
    }
}

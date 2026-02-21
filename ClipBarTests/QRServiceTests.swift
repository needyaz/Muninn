import Testing
import Foundation
import AppKit
import CoreImage
@testable import ClipBar

@Suite("QRService")
struct QRServiceTests {

    private func generateQRCode(for string: String) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }

        // Scale up so Vision can detect it
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage.tiffRepresentation
    }

    private func detectBarcode(from data: Data) async -> String? {
        await withCheckedContinuation { continuation in
            QRService.detectBarcode(from: data) { value in
                continuation.resume(returning: value)
            }
        }
    }

    @Test("detects QR code value")
    func validQR() async {
        guard let data = generateQRCode(for: "https://example.com") else {
            Issue.record("Could not generate QR code image")
            return
        }
        let value = await detectBarcode(from: data)
        #expect(value == "https://example.com")
    }

    @Test("invalid data returns nil")
    func invalidData() async {
        let value = await detectBarcode(from: Data([0xFF, 0xFE, 0xFD]))
        #expect(value == nil)
    }

    @Test("empty data returns nil")
    func emptyData() async {
        let value = await detectBarcode(from: Data())
        #expect(value == nil)
    }

    @Test("image with no barcode returns nil")
    func noBarcode() async {
        let width = 100, height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Could not create CGContext")
            return
        }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = ctx.makeImage() else {
            Issue.record("Could not make CGImage")
            return
        }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        let data = nsImage.tiffRepresentation!

        let value = await detectBarcode(from: data)
        #expect(value == nil)
    }
}

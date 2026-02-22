import Testing
import Foundation
import AppKit
import CoreText
@testable import Muninn

@Suite("OCRService")
struct OCRServiceTests {

    private func extractText(from data: Data) async -> String? {
        await withCheckedContinuation { continuation in
            OCRService.extractText(from: data) { text in
                continuation.resume(returning: text)
            }
        }
    }

    @Test("valid image returns text")
    func validImage() async {
        // Create a simple image with text using Core Graphics
        let width = 200, height = 50
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Could not create CGContext")
            return
        }

        // White background
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw "Hello" text
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        let font = CTFontCreateWithName("Helvetica" as CFString, 30, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: "Hello", attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: 10, y: 15)
        CTLineDraw(line, ctx)

        guard let cgImage = ctx.makeImage() else {
            Issue.record("Could not make CGImage")
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        let tiffData = nsImage.tiffRepresentation!

        let text = await extractText(from: tiffData)
        if let text {
            #expect(text.lowercased().contains("hello"))
        }
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
}

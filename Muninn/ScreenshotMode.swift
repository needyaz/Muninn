#if DEBUG
import AppKit
import SwiftUI

/// Renders the App Store screenshots from the real views, with fixture data and a frozen clock.
///
/// Debug builds only. `Muninn --screenshots` writes one PNG per scene into the app's temporary directory and quits;
/// `make screenshots` runs it and copies the PNGs into `listing/screenshots/en-US/`. It builds its stores from fixture
/// data under a temporary directory and a private UserDefaults suite, and never creates a clipboard or screenshot
/// monitor, so the real clipboard, history and preferences are never read.

/// Reports itself as the key and main window, so controls draw in their live colors (not dimmed) in the capture.
private final class AlwaysActiveWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}

enum ScreenshotMode {
    static var isRequested: Bool { CommandLine.arguments.contains("--screenshots") }

    /// 2880 × 1800 pixels: 1280 × 800 points drawn at 2.25x.
    static let pixelSize = CGSize(width: 2880, height: 1800)
    static let pointSize = CGSize(width: 1280, height: 800)
    static var scale: CGFloat { pixelSize.width / pointSize.width }

    static var outputDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("shots", isDirectory: true)
    }

    /// A fresh temporary folder for the fixture stores; the real storage folder is never used.
    static func makeFixtureDirectory() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MuninnScreenshotFixtures-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Renders every scene into `outputDirectory`, then exits.
    @MainActor
    static func run(stores: ScreenshotStores) {
        waitUntilActive()
        NSApp.appearance = NSAppearance(named: .aqua)

        let directory = outputDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for old in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            try? FileManager.default.removeItem(at: old)
        }

        for scene in ScreenshotScene.all {
            guard let png = render(scene.view(stores: stores)) else {
                NSLog("Muninn screenshots: could not render \(scene.id)")
                continue
            }
            do { try png.write(to: directory.appendingPathComponent(scene.fileName)) } catch { NSLog("Muninn screenshots: \(scene.id): \(error)") }
        }
        UserDefaults(suiteName: ScreenshotFixtures.defaultsSuiteName)?.removePersistentDomain(forName: ScreenshotFixtures.defaultsSuiteName)
        NSApp.terminate(nil)
    }

    /// Waits while processing real application events (a plain run-loop spin doesn't deliver "the app became active").
    @MainActor
    private static func pump(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if let event = NSApp.nextEvent(matching: .any, until: Date().addingTimeInterval(0.05), inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
    }

    /// Controls draw dimmed unless the app itself is active, and macOS won't activate an app that was started from a
    /// background session. So this shows a small window for `make screenshots` to bring forward (it opens the app a
    /// second time), then waits for the app to become active.
    @MainActor
    private static func waitUntilActive(timeout: TimeInterval = 15) {
        NSApp.setActivationPolicy(.regular)  // a menu bar app can't be brought forward; a regular one can. Only for this run.
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Muninn"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: Text("Preparing screenshots…").padding(28))
        window.center()
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        let deadline = Date().addingTimeInterval(timeout)
        while !NSApp.isActive && Date() < deadline { pump(for: 0.1) }
        if !NSApp.isActive { NSLog("Muninn screenshots: the app never became active, so controls will look dimmed") }
        pump(for: 0.5)  // let the active look settle
    }

    /// Lays the view out in an off-screen window and draws it at `scale`, so controls backed by AppKit are included.
    @MainActor
    static func render<V: View>(_ view: V) -> Data? {
        let host = NSHostingView(rootView: view
            .environment(\.controlActiveState, .key)
            .frame(width: pointSize.width, height: pointSize.height))
        let window = AlwaysActiveWindow(contentRect: NSRect(origin: .zero, size: pointSize), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.setFrameOrigin(NSPoint(x: -30_000, y: -30_000))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        for _ in 0..<3 {  // let SwiftUI finish its layout passes
            host.layoutSubtreeIfNeeded()
            pump(for: 0.25)
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(pixelSize.width), pixelsHigh: Int(pixelSize.height), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = pointSize
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}
#endif

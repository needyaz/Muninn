import Testing
import Foundation
import AppKit
import SwiftUI
@testable import Muninn

@Suite("Onboarding window close path", .serialized)
@MainActor
struct OnboardingWindowCloseTests {
    /// Polls `condition` until it holds or `timeout` seconds pass.
    private func waitFor(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test("MUN-ONB-003 KEEPS: closing the hosted onboarding window sets hasSeenOnboarding")
    func test_MUN_ONB_003_KEEPS_windowCloseMarksSeen() async throws {
        let suiteName = "MuninnOnboardingWindow-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)
        #expect(store.hasSeenOnboarding == false)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView().environment(store))
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(store.hasSeenOnboarding == false)

        window.performClose(nil)
        let marked = await waitFor { store.hasSeenOnboarding }
        #expect(marked)
        #expect(store.hasSeenOnboarding == true)
    }
}

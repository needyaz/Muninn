import Testing
import Foundation
import AppKit
import SwiftUI
@testable import Muninn

@Suite("Onboarding window close path", .serialized)
@MainActor
struct OnboardingWindowCloseTests {
    @Test("MUN-ONB-003: closing the hosted onboarding window sets hasSeenOnboarding")
    func windowCloseMarksSeen() async throws {
        let suiteName = "MuninnOnboardingWindow-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let saved = UserDefaults.standard.object(forKey: "hasSeenOnboarding")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            if let saved { UserDefaults.standard.set(saved, forKey: "hasSeenOnboarding") }
            else { UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding") }
        }
        let store = SettingsStore(defaults: defaults)
        #expect(store.hasSeenOnboarding == false)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView().environment(store))
        window.orderFront(nil)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(store.hasSeenOnboarding == false)

        window.performClose(nil)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(store.hasSeenOnboarding == true)
    }
}

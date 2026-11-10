import Testing
import Foundation
import AppKit
import SwiftUI
@testable import Muninn

@Suite("Onboarding window close path, repeated", .serialized)
@MainActor
struct OnboardingWindowCloseRepeatTests {
    /// Polls `condition` until it holds or `timeout` seconds pass.
    private func waitFor(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    private func showOnboarding(with store: SettingsStore) async throws -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView().environment(store))
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 150_000_000)
        return window
    }

    @Test("MUN-ONB-003 KEEPS: closing the onboarding window 20 times in a row marks it seen every time")
    func test_MUN_ONB_003_KEEPS_twentyClosesAllMarkSeen() async throws {
        let standardBefore = UserDefaults.standard.object(forKey: "hasSeenOnboarding") as? Bool
        var failures: [Int] = []

        for run in 1...20 {
            let suiteName = "MuninnOnboardingRepeat-\(run)-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let store = SettingsStore(defaults: defaults)
            #expect(store.hasSeenOnboarding == false, "run \(run) started already seen")

            let window = try await showOnboarding(with: store)
            #expect(store.hasSeenOnboarding == false, "run \(run) marked seen before close")

            window.performClose(nil)
            let marked = await waitFor { store.hasSeenOnboarding }
            if !marked { failures.append(run) }
            #expect(defaults.bool(forKey: "hasSeenOnboarding") == marked,
                    "run \(run) flag not persisted to its own suite")
        }

        #expect(failures.isEmpty, "close did not mark onboarding seen in runs \(failures)")
        let standardAfter = UserDefaults.standard.object(forKey: "hasSeenOnboarding") as? Bool
        #expect(standardBefore == standardAfter)
    }

    @Test("MUN-ONB-003 KEEPS: the close persists the flag in the test's own suite and leaves UserDefaults.standard alone")
    func test_MUN_ONB_003_KEEPS_persistsToOwnSuiteOnly() async throws {
        let standardBefore = UserDefaults.standard.object(forKey: "hasSeenOnboarding") as? Bool
        let suiteName = "MuninnOnboardingPersist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)

        let window = try await showOnboarding(with: store)
        #expect(store.hasSeenOnboarding == false)
        #expect(defaults.bool(forKey: "hasSeenOnboarding") == false)

        window.performClose(nil)
        let persisted = await waitFor { defaults.bool(forKey: "hasSeenOnboarding") }
        #expect(persisted)
        #expect(SettingsStore(defaults: defaults).hasSeenOnboarding == true)

        let standardAfter = UserDefaults.standard.object(forKey: "hasSeenOnboarding") as? Bool
        #expect(standardBefore == standardAfter)
    }
}

import Testing
import Foundation
@testable import Muninn

@Suite("Onboarding close marks seen", .serialized)
struct OnboardingSeenTests {

    /// Runs `body` with a store read from an isolated defaults suite, and restores the
    /// standard defaults key the store writes through afterwards.
    private func withIsolatedStore(_ body: (SettingsStore) throws -> Void) rethrows {
        let suiteName = "MuninnOnboardingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let saved = UserDefaults.standard.object(forKey: "hasSeenOnboarding")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            if let saved { UserDefaults.standard.set(saved, forKey: "hasSeenOnboarding") }
            else { UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding") }
        }
        try body(SettingsStore(defaults: defaults))
    }

    @Test("MUN-ONB-003: closing the onboarding window marks onboarding as seen")
    func closeMarksSeen() {
        withIsolatedStore { store in
            #expect(store.hasSeenOnboarding == false)
            store.markOnboardingSeen()
            #expect(store.hasSeenOnboarding == true)
        }
    }
}

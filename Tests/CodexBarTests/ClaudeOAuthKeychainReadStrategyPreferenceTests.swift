import Foundation
import Testing
@testable import CodexBarCore

struct ClaudeOAuthKeychainReadStrategyPreferenceTests {
    @Test
    func `experimental security CLI strategy remains selectable`() throws {
        let suiteName = "CodexBarTests.ClaudeOAuthKeychainReadStrategyPreference"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(
            ClaudeOAuthKeychainReadStrategy.securityCLIExperimental.rawValue,
            forKey: "claudeOAuthKeychainReadStrategy")

        #expect(
            ClaudeOAuthKeychainReadStrategyPreference.current(userDefaults: defaults)
                == .securityCLIExperimental)
    }

    @Test
    func `security CLI reader is not blocked by framework foreign-keychain gate`() {
        KeychainAccessGate.withTaskOverrideForTesting(false) {
            #expect(ClaudeOAuthCredentialsStore.securityCLIKeychainAccessAllowed)
        }
    }
}

import Foundation
import Testing
@testable import QuickText

@Suite("Settings")
@MainActor
struct SettingsTests {
    @Test("Non-secret preferences persist")
    func settingsPersist() {
        let suiteName = "QuickTextTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = SettingsStore(defaults: defaults)
        first.settings.provider = .anthropic
        first.settings.model = "test-model"
        first.settings.shortcut = .commandShiftT

        let restored = SettingsStore(defaults: defaults)
        #expect(restored.settings.provider == .anthropic)
        #expect(restored.settings.model == "test-model")
        #expect(restored.settings.shortcut == .commandShiftT)
    }
}

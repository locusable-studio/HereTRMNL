import CoreGraphics
import Foundation
import Testing
@testable import HereTRMNL

@MainActor
struct DisplayManagementTests {
    private func makeSettings() -> (AppSettings, UserDefaults) {
        let suiteName = "HereTRMNL.DisplayManagementTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(
            baseURLString: "",
            deviceID: "",
            accessToken: "",
            defaults: defaults
        )
        return (settings, defaults)
    }

    @Test func selectPositionPersistsPerScreen() {
        let (settings, defaults) = makeSettings()
        settings.selectScreen(42)
        settings.selectPosition(.bottomLeft)

        #expect(settings.windowPosition == .bottomLeft)
        #expect(defaults.string(forKey: "windowPosition") == WindowPosition.bottomLeft.rawValue)
        #expect(defaults.string(forKey: "windowPosition_42") == WindowPosition.bottomLeft.rawValue)
        #expect(settings.preferredScreenID == 42)
    }

    @Test func selectScreenRestoresRememberedPosition() {
        let (settings, _) = makeSettings()
        settings.selectScreen(7)
        settings.selectPosition(.center)

        settings.selectScreen(9)
        settings.selectPosition(.topLeft)

        settings.selectScreen(7)
        #expect(settings.windowPosition == .center)
        #expect(settings.preferredScreenID == 7)

        settings.selectScreen(9)
        #expect(settings.windowPosition == .topLeft)
    }

    @Test func selectScreenWithoutMemorySeedsCurrentPosition() {
        let (settings, defaults) = makeSettings()
        settings.selectPosition(.bottomRight)
        settings.selectScreen(100)

        #expect(settings.windowPosition == .bottomRight)
        #expect(defaults.string(forKey: "windowPosition_100") == WindowPosition.bottomRight.rawValue)
    }

    @Test func preferredScreenIDSurvivesMissingDisplay() {
        let (settings, defaults) = makeSettings()
        settings.selectScreen(55)
        settings.selectPosition(.topLeft)

        // Stale ID stays so a later reconnect can restore preference (Sidefy behavior).
        #expect(settings.preferredScreenID == 55)
        #expect(defaults.integer(forKey: "preferredScreenID") == 55)
        #expect(settings.storedPosition(forScreenID: 55) == .topLeft)
    }
}

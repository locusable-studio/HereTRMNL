@preconcurrency import Sparkle

final class HereTRMNLUpdaterDelegate: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    weak var updater: SPUUpdater?

    func feedURLString(for updater: SPUUpdater) -> String? {
        UpdateChannel.feedURL.absoluteString
    }

    @objc var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        updater?.checkForUpdates()
    }
}

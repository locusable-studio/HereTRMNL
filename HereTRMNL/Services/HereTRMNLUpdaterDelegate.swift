@preconcurrency import Sparkle

final class HereTRMNLUpdaterDelegate: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    nonisolated(unsafe) weak var updater: SPUUpdater?

    func feedURLString(for updater: SPUUpdater) -> String? {
        UpdateChannel.feedURL.absoluteString
    }

    @objc nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        let updater = updater
        Task { @MainActor in
            updater?.checkForUpdates()
        }
    }
}

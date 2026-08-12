@preconcurrency import Sparkle

/// Provides the stable Sparkle feed URL at runtime.
final class HereTRMNLUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        UpdateChannel.feedURL.absoluteString
    }
}

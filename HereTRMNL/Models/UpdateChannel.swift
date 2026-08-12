import Foundation

/// Sparkle update feed. HereTRMNL ships a single stable channel.
enum UpdateChannel {
    static let feedURL = URL(
        string: "https://raw.githubusercontent.com/locusable-studio/HereTRMNL/main/Updates/appcast.xml"
    )!

    static var displayName: String {
        String(localized: "Stable")
    }
}

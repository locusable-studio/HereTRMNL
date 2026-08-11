import CoreGraphics
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let baseURL = "baseURL"
        static let deviceID = "deviceID"
        static let lastContentWidth = "lastContentWidth"
        static let lastContentHeight = "lastContentHeight"
        static let displayTone = "displayTone"
        static let windowOpacity = "windowOpacity"
        static let hideToolbarInFullScreen = "hideToolbarInFullScreen"
    }

    @Published var baseURLString: String
    @Published var deviceID: String
    /// In-memory until `commit()` persists it to the Keychain.
    @Published var accessToken: String
    @Published private(set) var lastKeychainError: String?

    @Published var displayTone: DisplayTone {
        didSet { UserDefaults.standard.set(displayTone.rawValue, forKey: Keys.displayTone) }
    }

    /// 0.2 ... 1.0
    @Published var windowOpacity: Double {
        didSet {
            let clamped = Self.clampOpacity(windowOpacity)
            if clamped != windowOpacity {
                windowOpacity = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Keys.windowOpacity)
        }
    }

    @Published var hideToolbarInFullScreen: Bool {
        didSet { UserDefaults.standard.set(hideToolbarInFullScreen, forKey: Keys.hideToolbarInFullScreen) }
    }

    @Published var launchAtLoginEnabled: Bool
    @Published var launchAtLoginError: String?

    var baseURL: URL? {
        Self.url(from: baseURLString)
    }

    var isConfigured: Bool {
        guard baseURL != nil else { return false }
        let id = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return !id.isEmpty && !token.isEmpty
    }

    var lastDeviceContentSize: CGSize? {
        let width = UserDefaults.standard.double(forKey: Keys.lastContentWidth)
        let height = UserDefaults.standard.double(forKey: Keys.lastContentHeight)
        guard width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    init(
        baseURLString: String? = nil,
        deviceID: String? = nil,
        accessToken: String? = nil
    ) {
        self.baseURLString = baseURLString ?? UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        self.deviceID = deviceID ?? UserDefaults.standard.string(forKey: Keys.deviceID) ?? ""
        self.accessToken = accessToken ?? KeychainStore.loadAccessToken() ?? ""

        if let raw = UserDefaults.standard.string(forKey: Keys.displayTone),
           let tone = DisplayTone(rawValue: raw) {
            displayTone = tone
        } else {
            displayTone = .automatic
        }

        let storedOpacity = UserDefaults.standard.object(forKey: Keys.windowOpacity) as? Double
        windowOpacity = Self.clampOpacity(storedOpacity ?? 1.0)
        hideToolbarInFullScreen = UserDefaults.standard.object(forKey: Keys.hideToolbarInFullScreen) as? Bool ?? true
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    @discardableResult
    func commit() -> Bool {
        lastKeychainError = nil

        baseURLString = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        deviceID = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL)
        UserDefaults.standard.set(deviceID, forKey: Keys.deviceID)

        do {
            if accessToken.isEmpty {
                try KeychainStore.deleteAccessToken()
            } else {
                try KeychainStore.saveAccessToken(accessToken)
            }
            return true
        } catch {
            lastKeychainError = error.localizedDescription
            return false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        } catch {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            launchAtLoginError = error.localizedDescription
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    func rememberDeviceContentSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        UserDefaults.standard.set(Double(size.width), forKey: Keys.lastContentWidth)
        UserDefaults.standard.set(Double(size.height), forKey: Keys.lastContentHeight)
    }

    nonisolated static func url(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private static func clampOpacity(_ value: Double) -> Double {
        min(max(value, 0.2), 1.0)
    }
}

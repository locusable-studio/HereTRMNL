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

    /// Committed server base URL string (persisted).
    @Published private(set) var baseURLString: String
    /// Committed device ID (persisted).
    @Published private(set) var deviceID: String
    /// Committed access token (Keychain).
    @Published private(set) var accessToken: String
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

    /// Host (or full URL string) for summary rows.
    var serverDisplayName: String {
        if let host = baseURL?.host, !host.isEmpty {
            return host
        }
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
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

    /// Persist credentials after a successful live server check.
    @discardableResult
    func applyCredentials(baseURLString: String, deviceID: String, accessToken: String) -> Bool {
        lastKeychainError = nil

        let url = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if token.isEmpty {
                try KeychainStore.deleteAccessToken()
            } else {
                try KeychainStore.saveAccessToken(token)
            }
        } catch {
            lastKeychainError = error.localizedDescription
            return false
        }

        UserDefaults.standard.set(url, forKey: Keys.baseURL)
        UserDefaults.standard.set(id, forKey: Keys.deviceID)
        self.baseURLString = url
        self.deviceID = id
        self.accessToken = token
        return true
    }

    /// Remove saved server credentials and stop using them.
    func clearCredentials() {
        lastKeychainError = nil
        UserDefaults.standard.removeObject(forKey: Keys.baseURL)
        UserDefaults.standard.removeObject(forKey: Keys.deviceID)
        try? KeychainStore.deleteAccessToken()
        baseURLString = ""
        deviceID = ""
        accessToken = ""
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

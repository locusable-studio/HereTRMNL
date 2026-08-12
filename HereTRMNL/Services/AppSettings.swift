import CoreGraphics
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let baseURL = "baseURL"
        static let deviceID = "deviceID"
        static let accessToken = "accessToken"
        static let lastContentWidth = "lastContentWidth"
        static let lastContentHeight = "lastContentHeight"
        static let displayTone = "displayTone"
        static let windowPosition = "windowPosition"
        static let preferredScreenID = "preferredScreenID"
        static let windowDisplaySize = "windowDisplaySize"
    }

    /// Committed server base URL string (persisted).
    @Published private(set) var baseURLString: String
    /// Committed device ID (persisted).
    @Published private(set) var deviceID: String
    /// Committed access token (persisted).
    @Published private(set) var accessToken: String

    @Published var displayTone: DisplayTone {
        didSet { UserDefaults.standard.set(displayTone.rawValue, forKey: Keys.displayTone) }
    }

    @Published var windowPosition: WindowPosition {
        didSet { UserDefaults.standard.set(windowPosition.rawValue, forKey: Keys.windowPosition) }
    }

    @Published var windowDisplaySize: WindowDisplaySize {
        didSet { UserDefaults.standard.set(windowDisplaySize.rawValue, forKey: Keys.windowDisplaySize) }
    }

    /// `CGDirectDisplayID` of the preferred screen; `0` means primary (menu bar) display.
    @Published var preferredScreenID: CGDirectDisplayID {
        didSet { UserDefaults.standard.set(Int(preferredScreenID), forKey: Keys.preferredScreenID) }
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
        self.accessToken = accessToken ?? UserDefaults.standard.string(forKey: Keys.accessToken) ?? ""

        if let raw = UserDefaults.standard.string(forKey: Keys.displayTone),
           let tone = DisplayTone(rawValue: raw) {
            displayTone = tone
        } else {
            displayTone = .automatic
        }

        if let raw = UserDefaults.standard.string(forKey: Keys.windowPosition),
           let position = WindowPosition(rawValue: raw) {
            windowPosition = position
        } else {
            windowPosition = .topRight
        }

        if let raw = UserDefaults.standard.string(forKey: Keys.windowDisplaySize),
           let size = WindowDisplaySize(rawValue: raw) {
            windowDisplaySize = size
        } else {
            windowDisplaySize = .original
        }

        let storedScreenID = UserDefaults.standard.integer(forKey: Keys.preferredScreenID)
        preferredScreenID = storedScreenID > 0 ? CGDirectDisplayID(storedScreenID) : 0

        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    /// Persist credentials after a successful live server check.
    func applyCredentials(baseURLString: String, deviceID: String, accessToken: String) {
        let url = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(url, forKey: Keys.baseURL)
        UserDefaults.standard.set(id, forKey: Keys.deviceID)
        UserDefaults.standard.set(token, forKey: Keys.accessToken)
        self.baseURLString = url
        self.deviceID = id
        self.accessToken = token
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
}

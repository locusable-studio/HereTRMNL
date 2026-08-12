import AppKit
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
        static let windowPosition = "windowPosition"
        static let preferredScreenID = "preferredScreenID"
        static let showOnAllSpaces = "showOnAllSpaces"

        static func windowPosition(forScreenID id: CGDirectDisplayID) -> String {
            "windowPosition_\(id)"
        }
    }

    /// Committed server base URL string (persisted).
    @Published private(set) var baseURLString: String
    /// Committed device ID (persisted).
    @Published private(set) var deviceID: String
    /// Committed access token (persisted).
    @Published private(set) var accessToken: String

    @Published private(set) var windowPosition: WindowPosition

    /// `CGDirectDisplayID` of the preferred screen; `0` means primary (menu bar) display.
    /// Kept even if that display is temporarily unavailable so reconnect can restore it.
    @Published private(set) var preferredScreenID: CGDirectDisplayID

    /// When true, the display window joins every Space (Sidefy-compatible default).
    @Published var showOnAllSpaces: Bool {
        didSet { defaults.set(showOnAllSpaces, forKey: Keys.showOnAllSpaces) }
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
        let width = defaults.double(forKey: Keys.lastContentWidth)
        let height = defaults.double(forKey: Keys.lastContentHeight)
        guard width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    init(
        baseURLString: String? = nil,
        deviceID: String? = nil,
        accessToken: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.baseURLString = baseURLString ?? defaults.string(forKey: Keys.baseURL) ?? ""
        self.deviceID = deviceID ?? defaults.string(forKey: Keys.deviceID) ?? ""
        self.accessToken = accessToken ?? defaults.string(forKey: Keys.accessToken) ?? ""

        if let raw = defaults.string(forKey: Keys.windowPosition),
           let position = WindowPosition(rawValue: raw) {
            windowPosition = position
        } else {
            windowPosition = .topRight
        }

        let storedScreenID = defaults.integer(forKey: Keys.preferredScreenID)
        preferredScreenID = storedScreenID > 0 ? CGDirectDisplayID(storedScreenID) : 0

        if defaults.object(forKey: Keys.showOnAllSpaces) == nil {
            showOnAllSpaces = true
        } else {
            showOnAllSpaces = defaults.bool(forKey: Keys.showOnAllSpaces)
        }

        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    private let defaults: UserDefaults

    /// Persist credentials after a successful live server check.
    func applyCredentials(baseURLString: String, deviceID: String, accessToken: String) {
        let url = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(url, forKey: Keys.baseURL)
        defaults.set(id, forKey: Keys.deviceID)
        defaults.set(token, forKey: Keys.accessToken)
        self.baseURLString = url
        self.deviceID = id
        self.accessToken = token
    }

    /// Prefer this display; restore its remembered corner (or seed current corner onto it).
    func selectScreen(_ id: CGDirectDisplayID) {
        preferredScreenID = id
        defaults.set(Int(id), forKey: Keys.preferredScreenID)

        if id != 0, let saved = storedPosition(forScreenID: id) {
            setWindowPosition(saved)
        } else if id != 0 {
            persistPosition(windowPosition, forScreenID: id)
        }
    }

    /// Update global corner and remember it for the active/resolved display.
    func selectPosition(_ position: WindowPosition) {
        setWindowPosition(position)
        if let screen = DisplayScreen.resolve(preferredID: preferredScreenID) {
            let resolvedID = DisplayScreen.displayID(of: screen)
            persistPosition(position, forScreenID: resolvedID)
        }
        // Keep the explicitly preferred display's memory even while it is offline.
        if preferredScreenID != 0 {
            persistPosition(position, forScreenID: preferredScreenID)
        }
    }

    /// Before placing the window: load the resolved screen's corner, or seed global onto it.
    func syncPositionForResolvedScreen() {
        guard let screen = DisplayScreen.resolve(preferredID: preferredScreenID) else { return }
        let screenID = DisplayScreen.displayID(of: screen)
        guard screenID != 0 else { return }
        if let saved = storedPosition(forScreenID: screenID) {
            setWindowPosition(saved)
        } else {
            persistPosition(windowPosition, forScreenID: screenID)
        }
    }

    func storedPosition(forScreenID id: CGDirectDisplayID) -> WindowPosition? {
        guard id != 0,
              let raw = defaults.string(forKey: Keys.windowPosition(forScreenID: id)),
              let position = WindowPosition(rawValue: raw)
        else {
            return nil
        }
        return position
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
        defaults.set(Double(size.width), forKey: Keys.lastContentWidth)
        defaults.set(Double(size.height), forKey: Keys.lastContentHeight)
    }

    nonisolated static func url(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private func setWindowPosition(_ position: WindowPosition) {
        guard windowPosition != position else { return }
        windowPosition = position
        defaults.set(position.rawValue, forKey: Keys.windowPosition)
    }

    private func persistPosition(_ position: WindowPosition, forScreenID id: CGDirectDisplayID) {
        guard id != 0 else { return }
        defaults.set(position.rawValue, forKey: Keys.windowPosition(forScreenID: id))
    }
}

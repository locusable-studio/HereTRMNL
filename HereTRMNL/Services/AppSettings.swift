import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let baseURL = "baseURL"
        static let deviceID = "deviceID"
    }

    @Published var baseURLString: String {
        didSet { UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL) }
    }

    @Published var deviceID: String {
        didSet { UserDefaults.standard.set(deviceID, forKey: Keys.deviceID) }
    }

    @Published var accessToken: String {
        didSet {
            let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try? KeychainStore.deleteAccessToken()
            } else {
                try? KeychainStore.saveAccessToken(trimmed)
            }
        }
    }

    var baseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    var isConfigured: Bool {
        guard baseURL != nil else { return false }
        let id = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return !id.isEmpty && !token.isEmpty
    }

    private init() {
        baseURLString = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        deviceID = UserDefaults.standard.string(forKey: Keys.deviceID) ?? ""
        accessToken = KeychainStore.loadAccessToken() ?? ""
    }
}

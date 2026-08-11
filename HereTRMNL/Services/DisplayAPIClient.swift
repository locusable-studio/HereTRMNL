import Foundation

enum DisplayAPIError: LocalizedError, Equatable {
    case notConfigured
    case invalidBaseURL
    case invalidResponse
    case decoding(String)
    case server(status: Int, message: String?)
    case http(statusCode: Int)
    case keychain(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "Configure server URL, device ID, and access token in Settings.")
        case .invalidBaseURL:
            return String(localized: "Server URL is invalid.")
        case .invalidResponse:
            return String(localized: "Server returned an unexpected response.")
        case .decoding(let detail):
            return String(localized: "Could not parse display response: \(detail)")
        case .server(let status, let message):
            if let message, !message.isEmpty {
                return String(localized: "Server error \(status): \(message)")
            }
            return String(localized: "Server error \(status).")
        case .http(let statusCode):
            return String(localized: "HTTP \(statusCode).")
        case .keychain(let detail):
            return String(localized: "Could not save access token: \(detail)")
        }
    }
}

struct DisplayAPIClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Official firmware-compatible headers: `ID` + `Access-Token`.
    func fetchDisplay(baseURL: URL, deviceID: String, accessToken: String) async throws -> DisplayResponse {
        let endpoint = baseURL
            .appending(path: "api")
            .appending(path: "display")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(deviceID, forHTTPHeaderField: "ID")
        request.setValue(accessToken, forHTTPHeaderField: "Access-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else {
            throw DisplayAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DisplayAPIError.http(statusCode: http.statusCode)
        }

        let decoded: DisplayResponse
        do {
            decoded = try JSONDecoder().decode(DisplayResponse.self, from: data)
        } catch {
            throw DisplayAPIError.decoding(error.localizedDescription)
        }
        guard decoded.isSuccess else {
            throw DisplayAPIError.server(status: decoded.status ?? -1, message: decoded.error)
        }
        guard decoded.resolvingImageURL(relativeTo: baseURL) != nil else {
            throw DisplayAPIError.invalidResponse
        }
        return decoded
    }

    func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DisplayAPIError.invalidResponse
        }
        return data
    }
}

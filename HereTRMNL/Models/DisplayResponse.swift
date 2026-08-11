import Foundation

/// Response body for `GET /api/display` (TRMNL cloud + LaraPaper).
///
/// Field types differ across servers: TRMNL often sends `refresh_rate` as a string,
/// while LaraPaper sends an integer.
struct DisplayResponse: Decodable, Sendable {
    var status: Int?
    var imageURL: URL?
    var filename: String?
    var imageName: String?
    var refreshRate: Int?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case status
        case imageURL = "image_url"
        case filename
        case imageName = "image_name"
        case refreshRate = "refresh_rate"
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = Self.decodeFlexibleInt(from: container, forKey: .status)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        refreshRate = Self.decodeFlexibleInt(from: container, forKey: .refreshRate)
        error = try container.decodeIfPresent(String.self, forKey: .error)

        if let urlString = try container.decodeIfPresent(String.self, forKey: .imageURL) {
            imageURL = Self.normalizedImageURL(from: urlString)
        } else {
            imageURL = nil
        }
    }

    var changeToken: String? {
        filename ?? imageName
    }

    var refreshSeconds: Int {
        max(refreshRate ?? 900, 15)
    }

    var isSuccess: Bool {
        let code = status ?? 0
        return code == 0 || code == 200
    }

    private static func decodeFlexibleInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    /// LaraPaper may emit `http://` image URLs even when the API is reached over HTTPS.
    private static func normalizedImageURL(from raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else {
            return URL(string: raw)
        }
        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
        }
        return components.url ?? URL(string: raw)
    }
}

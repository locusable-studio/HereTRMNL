import Foundation

/// Response body for `GET /api/display` (TRMNL / LaraPaper compatible).
struct DisplayResponse: Decodable, Sendable {
    var status: Int?
    var imageURL: URL?
    var filename: String?
    var imageName: String?
    var refreshRate: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case status
        case imageURL = "image_url"
        case filename
        case imageName = "image_name"
        case refreshRate = "refresh_rate"
        case error
    }

    var changeToken: String? {
        filename ?? imageName
    }

    var isSuccess: Bool {
        let code = status ?? 0
        return code == 0 || code == 200
    }
}

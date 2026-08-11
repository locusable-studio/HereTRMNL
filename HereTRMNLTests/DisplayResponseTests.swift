import Foundation
import Testing
@testable import HereTRMNL

struct DisplayResponseTests {
    @Test func decodesLaraPaperIntegerRefreshRate() throws {
        let json = """
        {
          "status": 0,
          "image_url": "http://trmnl.example/storage/a.png",
          "filename": "a.png",
          "refresh_rate": 300
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DisplayResponse.self, from: json)
        #expect(response.status == 0)
        #expect(response.refreshRate == 300)
        #expect(response.refreshSeconds == 300)
        #expect(response.filename == "a.png")
    }

    @Test func decodesTRMNLStringRefreshRate() throws {
        let json = """
        {
          "status": 0,
          "image_url": "https://trmnl.example/a.png",
          "image_name": "plugin-1",
          "refresh_rate": "1800"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DisplayResponse.self, from: json)
        #expect(response.refreshRate == 1800)
        #expect(response.changeToken == "plugin-1")
    }

    @Test func upgradesHTTPImageURLOnlyWhenAPIIsHTTPS() throws {
        let json = """
        {
          "status": 0,
          "image_url": "http://trmnl.example/storage/a.png",
          "filename": "a.png",
          "refresh_rate": 300
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DisplayResponse.self, from: json)
        let httpsAPI = URL(string: "https://trmnl.example")!
        let httpAPI = URL(string: "http://trmnl.example")!

        #expect(response.resolvingImageURL(relativeTo: httpsAPI)?.scheme == "https")
        #expect(response.resolvingImageURL(relativeTo: httpAPI)?.scheme == "http")
    }

    @Test func resolvesRelativeImageURLAgainstAPIBase() throws {
        let json = """
        {
          "status": 0,
          "image_url": "/storage/a.png",
          "filename": "a.png",
          "refresh_rate": 300
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DisplayResponse.self, from: json)
        let api = URL(string: "https://trmnl.example")!
        let resolved = response.resolvingImageURL(relativeTo: api)

        #expect(resolved?.absoluteString == "https://trmnl.example/storage/a.png")
    }

    @Test func treatsMissingStatusAsSuccess() throws {
        let json = """
        {
          "image_url": "https://trmnl.example/a.png",
          "filename": "a.png",
          "refresh_rate": 60
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DisplayResponse.self, from: json)
        #expect(response.isSuccess)
        #expect(response.refreshSeconds == 60)
    }

    @Test func parsesBareHostAsHTTPS() {
        #expect(AppSettings.url(from: "  example.com/path ")?.absoluteString == "https://example.com/path")
        #expect(AppSettings.url(from: "https://example.com")?.host == "example.com")
        #expect(AppSettings.url(from: "   ") == nil)
    }
}

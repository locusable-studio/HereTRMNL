import AppKit
import Foundation

@MainActor
final class DisplaySession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var image: NSImage?
    @Published private(set) var filename: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var lastRefreshRateSeconds: Int?

    private let settings = AppSettings.shared
    private let client = DisplayAPIClient()
    private var pollTask: Task<Void, Never>?
    private var lastChangeToken: String?

    init() {
        start()
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func reloadConfiguration() {
        lastChangeToken = nil
        start()
    }

    func refresh(manual: Bool = false) async {
        do {
            try await fetchAndApply(forceImageReload: manual)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func runLoop() async {
        while !Task.isCancelled {
            guard settings.isConfigured else {
                phase = .failed(DisplayAPIError.notConfigured.localizedDescription)
                image = nil
                try? await Task.sleep(for: .seconds(2))
                continue
            }

            do {
                let seconds = try await fetchAndApply(forceImageReload: false)
                nextRefreshAt = Date().addingTimeInterval(TimeInterval(seconds))
                try await Task.sleep(for: .seconds(seconds))
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
                nextRefreshAt = Date().addingTimeInterval(30)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    @discardableResult
    private func fetchAndApply(forceImageReload: Bool) async throws -> Int {
        guard let baseURL = settings.baseURL else {
            throw DisplayAPIError.invalidBaseURL
        }

        let deviceID = settings.deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = settings.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !deviceID.isEmpty, !accessToken.isEmpty else {
            throw DisplayAPIError.notConfigured
        }

        if image == nil {
            phase = .loading
        }

        let response = try await client.fetchDisplay(
            baseURL: baseURL,
            deviceID: deviceID,
            accessToken: accessToken
        )

        guard let imageURL = response.imageURL else {
            throw DisplayAPIError.invalidResponse
        }

        let token = response.changeToken
        let shouldReloadImage = forceImageReload || token == nil || token != lastChangeToken || image == nil
        if shouldReloadImage {
            let data = try await client.downloadImage(from: imageURL)
            guard let nsImage = NSImage(data: data) else {
                throw DisplayAPIError.invalidResponse
            }
            image = nsImage
            lastChangeToken = token
        }

        filename = token
        lastUpdated = Date()
        let seconds = max(Int(response.refreshRate ?? "") ?? 900, 15)
        lastRefreshRateSeconds = seconds
        phase = .ready
        return seconds
    }
}

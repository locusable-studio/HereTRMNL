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
    @Published private(set) var deviceContentSize: CGSize?
    /// True while any display fetch is in flight (poll or manual).
    @Published private(set) var isRefreshing = false

    private let settings: AppSettings
    private let client: DisplayAPIClient
    private var pollTask: Task<Void, Never>?
    private var fetchTail: Task<Int, Error>?
    private var generation = 0
    private var lastChangeToken: String?
    private var refreshDepth = 0

    init(settings: AppSettings = .shared, client: DisplayAPIClient = DisplayAPIClient()) {
        self.settings = settings
        self.client = client
        if let saved = settings.lastDeviceContentSize {
            deviceContentSize = saved
        }
    }

    func start(forceRestart: Bool = false) {
        if pollTask != nil, !forceRestart {
            return
        }
        pollTask?.cancel()
        generation += 1
        let generation = self.generation
        if settings.isConfigured, image == nil {
            phase = .loading
        }
        pollTask = Task { [weak self] in
            await self?.runLoop(generation: generation)
        }
    }

    /// Clears the previous screen and restarts polling after credentials change.
    func reloadConfiguration() {
        fetchTail?.cancel()
        fetchTail = nil
        lastChangeToken = nil
        image = nil
        filename = nil
        lastUpdated = nil
        nextRefreshAt = nil
        lastRefreshRateSeconds = nil
        if settings.isConfigured {
            phase = .loading
        }
        start(forceRestart: true)
    }

    /// Verifies credentials against `/api/display` without mutating session state.
    func verifyConnection(baseURL: URL, deviceID: String, accessToken: String) async throws {
        _ = try await client.fetchDisplay(
            baseURL: baseURL,
            deviceID: deviceID,
            accessToken: accessToken
        )
    }

    func refresh(manual: Bool = false) async {
        let generation = self.generation
        do {
            _ = try await enqueueFetch(forceImageReload: manual, generation: generation)
        } catch is CancellationError {
            return
        } catch {
            applyFailure(error, generation: generation)
        }
    }

    private func runLoop(generation: Int) async {
        while !Task.isCancelled {
            guard generation == self.generation else { return }

            guard settings.isConfigured else {
                applyFailure(DisplayAPIError.notConfigured, generation: generation, clearImage: true)
                try? await Task.sleep(for: .seconds(2))
                continue
            }

            do {
                let seconds = try await enqueueFetch(forceImageReload: false, generation: generation)
                guard generation == self.generation else { return }
                nextRefreshAt = Date().addingTimeInterval(TimeInterval(seconds))
                try await Task.sleep(for: .seconds(seconds))
            } catch is CancellationError {
                return
            } catch {
                applyFailure(error, generation: generation)
                guard generation == self.generation else { return }
                nextRefreshAt = Date().addingTimeInterval(30)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    /// Serializes network work so poll + manual refresh never overlap.
    private func enqueueFetch(forceImageReload: Bool, generation: Int) async throws -> Int {
        beginRefreshing()
        defer { endRefreshing() }

        let previous = fetchTail
        let task = Task<Int, Error> { @MainActor in
            _ = await previous?.result
            guard generation == self.generation else { throw CancellationError() }
            return try await self.fetchAndApply(forceImageReload: forceImageReload, generation: generation)
        }
        fetchTail = task
        return try await task.value
    }

    @discardableResult
    private func fetchAndApply(forceImageReload: Bool, generation: Int) async throws -> Int {
        guard generation == self.generation else { throw CancellationError() }
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
        try Task.checkCancellation()
        guard generation == self.generation else { throw CancellationError() }

        guard let imageURL = response.resolvingImageURL(relativeTo: baseURL) else {
            throw DisplayAPIError.invalidResponse
        }

        let token = response.changeToken
        let shouldReloadImage = forceImageReload || token == nil || token != lastChangeToken || image == nil
        if shouldReloadImage {
            let data = try await client.downloadImage(from: imageURL)
            try Task.checkCancellation()
            guard generation == self.generation else { throw CancellationError() }
            guard let nsImage = NSImage(data: data) else {
                throw DisplayAPIError.invalidResponse
            }
            image = nsImage
            lastChangeToken = token

            let pixelSize = nsImage.devicePixelSize
            deviceContentSize = pixelSize
            settings.rememberDeviceContentSize(pixelSize)
        }

        guard generation == self.generation else { throw CancellationError() }

        filename = token
        lastUpdated = Date()
        let seconds = response.refreshSeconds
        lastRefreshRateSeconds = seconds
        phase = .ready
        return seconds
    }

    /// Keeps the last frame on transient failures; clears only when forced (e.g. not configured).
    private func applyFailure(_ error: Error, generation: Int, clearImage: Bool = false) {
        guard generation == self.generation else { return }

        let mustClear = clearImage
            || (error as? DisplayAPIError) == .notConfigured
            || image == nil

        if mustClear {
            image = nil
            lastChangeToken = nil
            filename = nil
        }

        phase = .failed(error.localizedDescription)
    }

    private func beginRefreshing() {
        refreshDepth += 1
        isRefreshing = true
    }

    private func endRefreshing() {
        refreshDepth = max(0, refreshDepth - 1)
        isRefreshing = refreshDepth > 0
    }
}

@preconcurrency import Sparkle
import SwiftUI

@MainActor
final class CheckForUpdatesViewModel: NSObject, ObservableObject {
    @Published var canCheckForUpdates = false
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.canCheckForUpdates = updater.canCheckForUpdates
        super.init()
        updater.addObserver(
            self,
            forKeyPath: "canCheckForUpdates",
            options: [.new],
            context: nil
        )
    }

    deinit {
        updater.removeObserver(self, forKeyPath: "canCheckForUpdates")
    }

    nonisolated override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "canCheckForUpdates" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        Task { @MainActor in
            canCheckForUpdates = updater.canCheckForUpdates
        }
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button(String(localized: "Check for Updates…"), action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    var body: some View {
        Toggle(String(localized: "Automatically check for updates"), isOn: $automaticallyChecksForUpdates)
            .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                updater.automaticallyChecksForUpdates = newValue
            }

        Toggle(String(localized: "Automatically download updates"), isOn: $automaticallyDownloadsUpdates)
            .disabled(!automaticallyChecksForUpdates)
            .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                updater.automaticallyDownloadsUpdates = newValue
            }
    }
}

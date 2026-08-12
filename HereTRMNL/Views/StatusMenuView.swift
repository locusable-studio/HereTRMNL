import AppKit
@preconcurrency import Sparkle
import SwiftUI

struct StatusMenuView: View {
    @Environment(\.openSettings) private var openSettings
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Divider()

        Section(String(localized: "Updates")) {
            CheckForUpdatesView(updater: updater)
            Menu(String(localized: "Update Settings")) {
                UpdaterSettingsView(updater: updater)
            }
        }

        Divider()

        Button("Quit HereTRMNL") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

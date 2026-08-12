import AppKit
@preconcurrency import Sparkle
import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Group {
            Button("Connection Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            Divider()

            Toggle(
                String(localized: "Launch at Login"),
                isOn: Binding(
                    get: { settings.launchAtLoginEnabled },
                    set: { settings.setLaunchAtLogin($0) }
                )
            )

            Divider()

            Section(String(localized: "Display")) {
                Picker(String(localized: "Display Tone"), selection: $settings.displayTone) {
                    ForEach(DisplayTone.allCases) { tone in
                        Text(tone.title).tag(tone)
                    }
                }
            }

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
        .alert("Launch at Login", isPresented: Binding(
            get: { settings.launchAtLoginError != nil },
            set: { if !$0 { settings.launchAtLoginError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(settings.launchAtLoginError ?? "")
        }
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
        }
    }
}

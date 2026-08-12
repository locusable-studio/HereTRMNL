import AppKit
@preconcurrency import Sparkle
import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var session: DisplaySession
    @Environment(\.openSettings) private var openSettings
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Group {
            Label(connectionStatusText, systemImage: connectionStatusIcon)
                .foregroundStyle(connectionStatusColor)

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

    private var connectionStatusText: String {
        guard settings.isConfigured else {
            return String(localized: "Not Connected")
        }
        if session.isRefreshing {
            return session.image == nil
                ? String(localized: "Connecting…")
                : String(localized: "Updating…")
        }
        switch session.phase {
        case .failed:
            return String(localized: "Connection Issue")
        case .loading:
            return String(localized: "Connecting…")
        case .ready, .idle:
            return "\(String(localized: "Connected")) · \(settings.serverDisplayName)"
        }
    }

    private var connectionStatusIcon: String {
        guard settings.isConfigured else { return "link.badge.plus" }
        switch session.phase {
        case .failed:
            return "exclamationmark.triangle.fill"
        case .loading:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        case .ready, .idle:
            return "checkmark.circle.fill"
        }
    }

    private var connectionStatusColor: Color {
        guard settings.isConfigured else { return .secondary }
        switch session.phase {
        case .failed:
            return .orange
        case .ready:
            return .green
        case .loading, .idle:
            return .secondary
        }
    }
}

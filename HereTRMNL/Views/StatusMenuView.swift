import AppKit
@preconcurrency import Sparkle
import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var session: DisplaySession
    @EnvironmentObject private var windowChrome: WindowChromeController
    @Environment(\.openSettings) private var openSettings
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Group {
            Label(connectionStatusText, systemImage: connectionStatusIcon)
                .foregroundStyle(connectionStatusColor)

            Divider()

            Button("Refresh Now") {
                Task { await session.refresh(manual: true) }
            }
            .keyboardShortcut("r")
            .disabled(!settings.isConfigured || session.isRefreshing)

            Divider()

            Section(String(localized: "Display")) {
                Picker(String(localized: "Screen"), selection: screenSelection) {
                    ForEach(attachedScreens, id: \.id) { screen in
                        Text(screen.name).tag(screen.id)
                    }
                }

                Picker(String(localized: "Position"), selection: positionSelection) {
                    ForEach(WindowPosition.allCases) { position in
                        if let symbol = position.systemImage {
                            Label(position.title, systemImage: symbol)
                                .tag(position)
                        } else {
                            Text(position.title)
                                .tag(position)
                        }
                    }
                }
            }

            Divider()

            Section(String(localized: "General")) {
                Button("Connection Settings…") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",")

                Toggle(
                    String(localized: "Launch at Login"),
                    isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
            }

            Divider()

            Section(String(localized: "Updates")) {
                CheckForUpdatesView(updater: updater)
                Menu(String(localized: "Update Settings")) {
                    UpdaterSettingsView(updater: updater)
                }
            }

            Divider()

            Button("About HereTRMNL") {
                AboutWindowController.shared.openAbout()
            }

            Button("Quit") {
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

    private struct ScreenOption: Identifiable {
        let id: CGDirectDisplayID
        let name: String
    }

    private var attachedScreens: [ScreenOption] {
        NSScreen.screens.enumerated().map { index, screen in
            ScreenOption(
                id: DisplayScreen.displayID(of: screen),
                name: DisplayScreen.localizedName(for: screen, index: index)
            )
        }
    }

    private var screenSelection: Binding<CGDirectDisplayID> {
        Binding(
            get: {
                let preferred = settings.preferredScreenID
                if preferred != 0, DisplayScreen.screen(forDisplayID: preferred) != nil {
                    return preferred
                }
                if let resolved = DisplayScreen.resolve(preferredID: preferred) {
                    return DisplayScreen.displayID(of: resolved)
                }
                return attachedScreens.first?.id ?? 0
            },
            set: { newValue in
                settings.selectScreen(newValue)
                windowChrome.applyPlacement()
            }
        )
    }

    private var positionSelection: Binding<WindowPosition> {
        Binding(
            get: { settings.windowPosition },
            set: { newValue in
                settings.selectPosition(newValue)
                windowChrome.applyPlacement()
            }
        )
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

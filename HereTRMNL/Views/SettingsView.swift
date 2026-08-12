@preconcurrency import Sparkle
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: DisplaySession
    @EnvironmentObject private var settings: AppSettings

    private let updater: SPUUpdater

    @State private var isShowingConnectionSheet = false
    @State private var draftBaseURL = ""
    @State private var draftDeviceID = ""
    @State private var draftAccessToken = ""
    @State private var isConnecting = false
    @State private var connectError: String?

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Form {
            Section {
                if settings.isConfigured {
                    connectionSummary
                } else {
                    ContentUnavailableView {
                        Label("Set Up Connection", systemImage: "link")
                    } description: {
                        Text("Add your LaraPaper server to start showing screens.")
                    } actions: {
                        Button("Connect…") {
                            openConnectionSheet(prefill: false)
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            } header: {
                Text("Connection")
            } footer: {
                Text(connectionFooter)
            }

            Section {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )

                Picker("Display Tone", selection: $settings.displayTone) {
                    ForEach(DisplayTone.allCases) { tone in
                        Text(tone.title).tag(tone)
                    }
                }

                LabeledContent("Opacity") {
                    HStack(spacing: 12) {
                        Slider(value: $settings.windowOpacity, in: 0.2...1.0, step: 0.05)
                        Text(opacityLabel)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                }

                Toggle("Hide Toolbar in Full Screen", isOn: $settings.hideToolbarInFullScreen)
            } header: {
                Text("Display")
            } footer: {
                Text("Display tone inverts the fetched screen for dark presentation. Automatic follows the system appearance.")
            }

            Section {
                LabeledContent("Version") {
                    Text(versionLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                LabeledContent("Channel") {
                    Text(UpdateChannel.displayName)
                        .foregroundStyle(.secondary)
                }

                CheckForUpdatesView(updater: updater)

                UpdaterSettingsView(updater: updater)
            } header: {
                Text("Updates")
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .sheet(isPresented: $isShowingConnectionSheet) {
            connectionSheet
        }
        .alert("Could Not Connect", isPresented: Binding(
            get: { connectError != nil },
            set: { if !$0 { connectError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectError ?? "")
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
            if !settings.isConfigured {
                openConnectionSheet(prefill: false)
            }
        }
    }

    @ViewBuilder
    private var connectionSummary: some View {
        LabeledContent("Server") {
            Text(settings.serverDisplayName)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }

        LabeledContent("Device ID") {
            Text(settings.deviceID)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .monospaced()
        }

        LabeledContent("Access Token") {
            Text("••••••••")
                .foregroundStyle(.secondary)
        }

        LabeledContent("Status") {
            Text(connectionStatusText)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }

        Button("Edit Connection…") {
            openConnectionSheet(prefill: true)
        }
    }

    private var connectionSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Server URL",
                        text: $draftBaseURL,
                        prompt: Text("https://example.com")
                    )
                    .textContentType(.URL)
                    .autocorrectionDisabled()

                    TextField(
                        "Device ID",
                        text: $draftDeviceID,
                        prompt: Text("AA:BB:CC:DD:EE:FF")
                    )
                    .autocorrectionDisabled()

                    SecureField(
                        "Access Token",
                        text: $draftAccessToken
                    )
                } footer: {
                    Text("Credentials are verified with the server before they are saved. Uses official TRMNL headers ID and Access-Token.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(settings.isConfigured ? "Edit Connection" : "Connect")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isShowingConnectionSheet = false
                        connectError = nil
                    }
                    .disabled(isConnecting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(settings.isConfigured ? "Save" : "Connect") {
                            Task { await connect() }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!draftLooksComplete)
                    }
                }
            }
        }
        .frame(width: 420, height: 280)
        .interactiveDismissDisabled(isConnecting)
    }

    private var connectionFooter: String {
        if settings.isConfigured {
            String(localized: "This Mac acts as one LaraPaper device. Edit the connection to change server details.")
        } else {
            String(localized: "Connect to a LaraPaper server to use this Mac as a display device.")
        }
    }

    private var connectionStatusText: String {
        if session.isRefreshing {
            return String(localized: "Updating…")
        }
        switch session.phase {
        case .ready:
            return String(localized: "Connected")
        case .loading:
            return String(localized: "Connecting…")
        case .failed(let message):
            return message
        case .idle:
            return String(localized: "Idle")
        }
    }

    private var draftLooksComplete: Bool {
        AppSettings.url(from: draftBaseURL) != nil
            && !draftDeviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var opacityLabel: String {
        "\(Int((settings.windowOpacity * 100).rounded()))%"
    }

    private var versionLabel: String {
        let version = Bundle.main.releaseVersionNumber ?? "—"
        let build = Bundle.main.buildVersionNumber ?? "—"
        return "\(version) (\(build))"
    }

    private func openConnectionSheet(prefill: Bool) {
        if prefill {
            draftBaseURL = settings.baseURLString
            draftDeviceID = settings.deviceID
            draftAccessToken = settings.accessToken
        } else {
            draftBaseURL = ""
            draftDeviceID = ""
            draftAccessToken = ""
        }
        connectError = nil
        isShowingConnectionSheet = true
    }

    private func connect() async {
        connectError = nil
        isConnecting = true
        defer { isConnecting = false }

        let trimmedURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = draftDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = draftAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let baseURL = AppSettings.url(from: trimmedURL) else {
            connectError = String(localized: "Server URL is invalid.")
            return
        }

        do {
            try await session.verifyConnection(
                baseURL: baseURL,
                deviceID: trimmedID,
                accessToken: trimmedToken
            )
        } catch {
            connectError = error.localizedDescription
            return
        }

        guard settings.applyCredentials(
            baseURLString: trimmedURL,
            deviceID: trimmedID,
            accessToken: trimmedToken
        ) else {
            connectError = settings.lastKeychainError
                ?? String(localized: "Unknown Keychain error.")
            return
        }

        isShowingConnectionSheet = false
        session.reloadConfiguration()
    }
}

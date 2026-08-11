import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: DisplaySession
    @EnvironmentObject private var settings: AppSettings

    @State private var isEditing = false
    @State private var draftBaseURL = ""
    @State private var draftDeviceID = ""
    @State private var draftAccessToken = ""
    @State private var isConnecting = false
    @State private var connectError: String?

    private var showsEditor: Bool {
        !settings.isConfigured || isEditing
    }

    var body: some View {
        Form {
            Section {
                if showsEditor {
                    connectionEditor
                } else {
                    connectionSummary
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
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .disabled(isConnecting)
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
                beginEditing(prefill: false)
            }
        }
    }

    @ViewBuilder
    private var connectionEditor: some View {
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

        Button {
            Task { await connect() }
        } label: {
            if isConnecting {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else {
                Text(settings.isConfigured ? "Save Connection" : "Connect")
                    .frame(maxWidth: .infinity)
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(isConnecting || !draftLooksComplete)

        if isEditing, settings.isConfigured {
            Button("Cancel", role: .cancel) {
                isEditing = false
                connectError = nil
            }
            .disabled(isConnecting)
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

        Button("Edit Connection") {
            beginEditing(prefill: true)
        }
    }

    private var connectionFooter: String {
        if showsEditor {
            String(localized: "Credentials are verified with the server before they are saved. Uses official TRMNL headers ID and Access-Token.")
        } else {
            String(localized: "This Mac acts as one LaraPaper device. Edit the connection to change server details.")
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

    private func beginEditing(prefill: Bool) {
        if prefill {
            draftBaseURL = settings.baseURLString
            draftDeviceID = settings.deviceID
            draftAccessToken = settings.accessToken
        } else if !isEditing {
            draftBaseURL = ""
            draftDeviceID = ""
            draftAccessToken = ""
        }
        isEditing = settings.isConfigured
        connectError = nil
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

        isEditing = false
        session.reloadConfiguration()
    }
}

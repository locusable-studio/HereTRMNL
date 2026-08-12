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

    var body: some View {
        Form {
            if settings.isConfigured, !isEditing {
                connectionSummary
            } else {
                connectionEditor
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .navigationTitle("Connection Settings")
        .onAppear {
            if !settings.isConfigured {
                prepareEditor(prefill: false)
            }
        }
    }

    @ViewBuilder
    private var connectionSummary: some View {
        Section {
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
                Text("Saved")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Status") {
                Label(connectionStatusText, systemImage: connectionStatusIcon)
                    .foregroundStyle(connectionStatusColor)
                    .lineLimit(2)
            }

            if let lastUpdated = session.lastUpdated {
                LabeledContent("Last Updated") {
                    Text(lastUpdated, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Edit Connection…") {
                prepareEditor(prefill: true)
            }
        } header: {
            Text("Connection")
        } footer: {
            Text(connectionFooter)
        }
    }

    private var connectionEditor: some View {
        Section {
            TextField(
                "Server URL",
                text: $draftBaseURL,
                prompt: Text("https://example.com")
            )
            .textContentType(.URL)
            .autocorrectionDisabled()
            .disabled(isConnecting)

            TextField(
                "Device ID",
                text: $draftDeviceID,
                prompt: Text("AA:BB:CC:DD:EE:FF")
            )
            .autocorrectionDisabled()
            .disabled(isConnecting)

            SecureField(
                "Access Token",
                text: $draftAccessToken,
                prompt: Text(settings.isConfigured
                    ? String(localized: "Leave blank to keep saved token")
                    : String(localized: "Required"))
            )
            .disabled(isConnecting)

            if let connectError {
                Label(connectError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if settings.isConfigured {
                    Button("Cancel") {
                        isEditing = false
                        connectError = nil
                    }
                    .disabled(isConnecting)
                }

                Spacer()

                Button {
                    Task { await connect() }
                } label: {
                    if isConnecting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Verifying…")
                        }
                    } else {
                        Text(settings.isConfigured
                            ? String(localized: "Verify and Save")
                            : String(localized: "Connect"))
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draftLooksComplete || isConnecting)
            }
        } header: {
            Text(settings.isConfigured
                ? String(localized: "Edit Connection")
                : String(localized: "Set Up Connection"))
        } footer: {
            Text("Credentials are verified before saving.")
        }
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

    private var connectionStatusIcon: String {
        switch session.phase {
        case .ready:
            "checkmark.circle.fill"
        case .loading:
            "arrow.trianglehead.2.clockwise.rotate.90"
        case .failed:
            "exclamationmark.triangle.fill"
        case .idle:
            "circle"
        }
    }

    private var connectionStatusColor: Color {
        switch session.phase {
        case .ready:
            .green
        case .failed:
            .orange
        case .loading, .idle:
            .secondary
        }
    }

    private var draftLooksComplete: Bool {
        AppSettings.url(from: draftBaseURL) != nil
            && !draftDeviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (settings.isConfigured
                || !draftAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func prepareEditor(prefill: Bool) {
        if prefill {
            draftBaseURL = settings.baseURLString
            draftDeviceID = settings.deviceID
        } else {
            draftBaseURL = ""
            draftDeviceID = ""
        }
        draftAccessToken = ""
        connectError = nil
        isEditing = true
    }

    private func connect() async {
        connectError = nil
        isConnecting = true
        defer { isConnecting = false }

        let trimmedURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedID = draftDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let newToken = draftAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = newToken.isEmpty ? settings.accessToken : newToken

        guard let baseURL = AppSettings.url(from: trimmedURL) else {
            connectError = String(localized: "Server URL is invalid.")
            return
        }

        do {
            try await session.verifyConnection(
                baseURL: baseURL,
                deviceID: trimmedID,
                accessToken: token
            )
        } catch {
            connectError = error.localizedDescription
            return
        }

        settings.applyCredentials(
            baseURLString: trimmedURL,
            deviceID: trimmedID,
            accessToken: token
        )

        isEditing = false
        draftAccessToken = ""
        session.reloadConfiguration()
    }
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: DisplaySession
    @EnvironmentObject private var settings: AppSettings
    @State private var saveError: String?

    var body: some View {
        Form {
            Section {
                TextField(
                    "Server URL",
                    text: $settings.baseURLString,
                    prompt: Text("https://example.com")
                )
                .textContentType(.URL)
                .autocorrectionDisabled()

                TextField(
                    "Device ID",
                    text: $settings.deviceID,
                    prompt: Text("AA:BB:CC:DD:EE:FF")
                )
                .autocorrectionDisabled()

                SecureField(
                    "Access Token",
                    text: $settings.accessToken
                )

                LabeledContent("Status") {
                    Text(settings.isConfigured ? "Ready" : "Incomplete")
                        .foregroundStyle(.secondary)
                }

                Button("Connect") {
                    connect()
                }
                .keyboardShortcut(.defaultAction)
            } header: {
                Text("Connection")
            } footer: {
                Text("Uses official TRMNL headers ID and Access-Token. Enter only the LaraPaper base URL. Credentials are saved when you connect.")
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
        .frame(width: 320)
        .alert("Could Not Save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
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

    private var opacityLabel: String {
        "\(Int((settings.windowOpacity * 100).rounded()))%"
    }

    private func connect() {
        guard settings.commit() else {
            saveError = settings.lastKeychainError ?? String(localized: "Unknown Keychain error.")
            return
        }
        session.reloadConfiguration()
    }
}

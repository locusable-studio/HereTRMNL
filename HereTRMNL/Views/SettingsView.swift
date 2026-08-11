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

                TextField(
                    "Device ID",
                    text: $settings.deviceID,
                    prompt: Text("AA:BB:CC:DD:EE:FF")
                )

                SecureField(
                    "Access Token",
                    text: $settings.accessToken,
                    prompt: Text("Access Token")
                )
            } header: {
                Text("Connection")
            } footer: {
                Text("Uses the official TRMNL headers ID and Access-Token. Enter only the LaraPaper base URL. Credentials are saved when you connect.")
            }

            Section {
                Button("Connect") {
                    connect()
                }
                .keyboardShortcut(.defaultAction)

                LabeledContent("Status") {
                    Text(settings.isConfigured ? "Ready" : "Incomplete")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .alert("Could Not Save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func connect() {
        guard settings.commit() else {
            saveError = settings.lastKeychainError ?? "Unknown Keychain error."
            return
        }
        session.reloadConfiguration()
    }
}

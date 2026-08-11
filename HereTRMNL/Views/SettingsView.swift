import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: DisplaySession
    @ObservedObject private var settings = AppSettings.shared

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
                Text("Uses the official TRMNL headers ID and Access-Token. Enter only the LaraPaper base URL.")
            }

            Section {
                Button("Connect") {
                    session.reloadConfiguration()
                }
                .keyboardShortcut(.defaultAction)

                LabeledContent("Status") {
                    Text(settings.isConfigured ? "Ready" : "Incomplete")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}

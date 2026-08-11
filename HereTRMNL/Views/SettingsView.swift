import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: DisplaySession
    @ObservedObject private var settings = AppSettings.shared

    @State private var draftBaseURL = ""
    @State private var draftDeviceID = ""
    @State private var draftAccessToken = ""
    @State private var didLoad = false

    var body: some View {
        Form {
            Section {
                TextField("https://your-larapaper.example", text: $draftBaseURL)
                    .textContentType(.URL)
                Text("LaraPaper / TRMNL BYOS base URL. Do not include `/api/display`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Server")
            }

            Section {
                TextField("AA:BB:CC:DD:EE:FF", text: $draftDeviceID)
                SecureField("Access token", text: $draftAccessToken)
                Text("Sent as official firmware headers: `ID` and `Access-Token`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Device")
            }

            Section {
                Button("Save & Connect") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
        .onAppear {
            guard !didLoad else { return }
            draftBaseURL = settings.baseURLString
            draftDeviceID = settings.deviceID
            draftAccessToken = settings.accessToken
            didLoad = true
        }
    }

    private func save() {
        settings.baseURLString = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.deviceID = draftDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.accessToken = draftAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        session.reloadConfiguration()
    }
}

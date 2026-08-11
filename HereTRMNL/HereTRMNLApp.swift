import SwiftUI

@main
struct HereTRMNLApp: App {
    @StateObject private var displaySession = DisplaySession()

    var body: some Scene {
        Window("HereTRMNL", id: "display") {
            DisplayView()
                .environmentObject(displaySession)
                .frame(minWidth: 480, minHeight: 320)
        }
        .defaultSize(width: 800, height: 480)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Refresh Now") {
                    Task { await displaySession.refresh(manual: true) }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(displaySession)
                .frame(width: 440, height: 360)
        }
    }
}

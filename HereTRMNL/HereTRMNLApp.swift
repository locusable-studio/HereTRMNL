import SwiftUI

@main
struct HereTRMNLApp: App {
    @StateObject private var displaySession = DisplaySession()
    @StateObject private var windowChrome = WindowChromeController()

    var body: some Scene {
        Window("HereTRMNL", id: "display") {
            DisplayView()
                .environmentObject(displaySession)
                .environmentObject(windowChrome)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(
            width: WindowChromeController.defaultContentSize.width,
            height: WindowChromeController.defaultContentSize.height
        )
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Refresh Now") {
                    Task { await displaySession.refresh(manual: true) }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button(windowChrome.isPinned ? "Unpin" : "Keep on Top") {
                    windowChrome.isPinned.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(displaySession)
        }
    }
}

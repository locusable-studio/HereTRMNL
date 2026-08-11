import AppKit
import SwiftUI

@main
struct HereTRMNLApp: App {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var displaySession: DisplaySession
    @StateObject private var windowChrome: WindowChromeController

    init() {
        let settings = AppSettings.shared
        _displaySession = StateObject(wrappedValue: DisplaySession(settings: settings))

        let initialSize: NSSize
        if let saved = settings.lastDeviceContentSize {
            initialSize = NSSize(width: saved.width, height: saved.height)
        } else {
            initialSize = WindowChromeController.defaultContentSize
        }
        _windowChrome = StateObject(wrappedValue: WindowChromeController(initialContentSize: initialSize))
    }

    var body: some Scene {
        Window("HereTRMNL", id: "display") {
            DisplayView()
                .environmentObject(displaySession)
                .environmentObject(windowChrome)
                .environmentObject(settings)
                .task {
                    guard !AppRuntime.isRunningTests else { return }
                    displaySession.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(
            width: windowChrome.contentSize.width,
            height: windowChrome.contentSize.height
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
                .environmentObject(settings)
        }
    }
}

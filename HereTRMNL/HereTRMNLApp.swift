import AppKit
import SwiftUI

@main
struct HereTRMNLApp: App {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var displaySession: DisplaySession
    @StateObject private var windowChrome: WindowChromeController

    init() {
        SingleInstanceGuard.ensureSingleInstance()

        let settings = AppSettings.shared
        let session = DisplaySession(settings: settings)
        _displaySession = StateObject(wrappedValue: session)

        let initialSize: NSSize
        if let saved = settings.lastDeviceContentSize {
            initialSize = NSSize(width: saved.width, height: saved.height)
        } else {
            initialSize = WindowChromeController.defaultContentSize
        }
        _windowChrome = StateObject(wrappedValue: WindowChromeController(initialContentSize: initialSize))

        // Start polling as soon as the app launches — don't wait for the first view pass.
        if !AppRuntime.isRunningTests {
            session.start()
        }
    }

    var body: some Scene {
        MenuBarExtra("HereTRMNL", systemImage: "photo.on.rectangle") {
            StatusMenuView()
        }

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
            CommandGroup(replacing: .appTermination) {}
            CommandGroup(after: .toolbar) {
                Button("Refresh Now") {
                    Task { await displaySession.refresh(manual: true) }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!settings.isConfigured || displaySession.isRefreshing)

                Button(windowChrome.isPinned ? "Unpin" : "Keep on Top") {
                    windowChrome.isPinned.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Standard Size") {
                    windowChrome.restoreStandardSize()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }

            CommandMenu("Options") {
                Button("Quit HereTRMNL") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(displaySession)
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 540, height: 520)
    }
}

import AppKit
@preconcurrency import Sparkle
import SwiftUI

@main
struct HereTRMNLApp: App {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var displaySession: DisplaySession
    @StateObject private var windowChrome: WindowChromeController

    private let updaterController: SPUStandardUpdaterController
    private let updaterDelegate = HereTRMNLUpdaterDelegate()

    init() {
        SingleInstanceGuard.ensureSingleInstance()

        updaterController = SPUStandardUpdaterController(
            startingUpdater: !AppRuntime.isRunningTests,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )

        let settings = AppSettings.shared
        let session = DisplaySession(settings: settings)
        _displaySession = StateObject(wrappedValue: session)

        let initialSize: NSSize
        if let saved = settings.lastDeviceContentSize {
            initialSize = NSSize(width: saved.width, height: saved.height)
        } else {
            initialSize = WindowChromeController.defaultContentSize
        }
        _windowChrome = StateObject(wrappedValue: WindowChromeController(
            initialContentSize: initialSize,
            settings: settings
        ))

        // Start polling as soon as the app launches — don't wait for the first view pass.
        if !AppRuntime.isRunningTests {
            session.start()
        }

        if !AppRuntime.isRunningTests,
           updaterController.updater.automaticallyChecksForUpdates {
            updaterController.updater.checkForUpdatesInBackground()
        }
    }

    var body: some Scene {
        MenuBarExtra("HereTRMNL", systemImage: "photo.on.rectangle") {
            StatusMenuView(updater: updaterController.updater)
                .environmentObject(settings)
                .environmentObject(displaySession)
                .environmentObject(windowChrome)
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
        .defaultLaunchBehavior(.presented)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowBackgroundDragBehavior(.disabled)
        .windowResizability(.contentSize)
        .defaultSize(
            width: windowChrome.contentSize.width,
            height: windowChrome.contentSize.height
        )
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appTermination) {}
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh Now") {
                    Task { await displaySession.refresh(manual: true) }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!settings.isConfigured || displaySession.isRefreshing)
            }

            CommandMenu("Options") {
                Button("Quit") {
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
    }
}

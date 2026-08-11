import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit HereTRMNL") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = String(localized: "About HereTRMNL")
        window.minSize = NSSize(width: 420, height: 390)
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.managed, .participatesInCycle]
        window.hidesOnDeactivate = false
        window.identifier = NSUserInterfaceItemIdentifier("HereTRMNLAboutWindow")
        window.contentView = NSHostingView(rootView: AboutView())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func openAbout() {
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

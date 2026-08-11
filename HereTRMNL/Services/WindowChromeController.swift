import AppKit
import SwiftUI

@MainActor
final class WindowChromeController: ObservableObject {
    /// TRMNL OG default; updated from the registered device's rendered screen.
    static let defaultContentSize = NSSize(width: 800, height: 480)

    @Published var isPinned = false {
        didSet { applyPin() }
    }

    @Published private(set) var contentSize = WindowChromeController.defaultContentSize

    private weak var window: NSWindow?

    func attach(to window: NSWindow) {
        self.window = window
        applyChrome()
        applyPin()
        applyAspectRatio(resize: false)
    }

    func lockAspect(to size: NSSize) {
        guard size.width > 0, size.height > 0 else { return }
        let changed = abs(contentSize.width - size.width) > 0.5
            || abs(contentSize.height - size.height) > 0.5
        contentSize = size
        applyAspectRatio(resize: changed)
    }

    func lockAspect(to image: NSImage) {
        lockAspect(to: image.devicePixelSize)
    }

    private func applyChrome() {
        guard let window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
    }

    private func applyPin() {
        window?.level = isPinned ? .floating : .normal
    }

    private func applyAspectRatio(resize: Bool) {
        guard let window else { return }

        let size = contentSize
        window.contentAspectRatio = size
        window.aspectRatio = size
        window.contentMinSize = NSSize(
            width: max(320, size.width * 0.4),
            height: max(192, size.height * 0.4)
        )

        guard resize else { return }

        var frame = window.frame
        let newHeight = frame.width * size.height / size.width
        frame.origin.y += frame.height - newHeight
        frame.size.height = newHeight
        window.setFrame(frame, display: true, animate: true)
    }
}

extension NSImage {
    var devicePixelSize: NSSize {
        if let rep = representations.first(where: { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }) {
            return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return size
    }
}

/// Hooks the SwiftUI window so we can configure NSWindow chrome.
struct WindowChromeInstaller: NSViewRepresentable {
    @ObservedObject var controller: WindowChromeController

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                controller.attach(to: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if controller !== context.coordinator.attachedController || window !== context.coordinator.attachedWindow {
                context.coordinator.attachedController = controller
                context.coordinator.attachedWindow = window
                controller.attach(to: window)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var attachedController: WindowChromeController?
        weak var attachedWindow: NSWindow?
    }
}

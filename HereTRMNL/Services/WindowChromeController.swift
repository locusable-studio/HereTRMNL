import AppKit
import SwiftUI

@MainActor
final class WindowChromeController: ObservableObject {
    /// TRMNL OG default; overridden by last remembered device size when available.
    static let defaultContentSize = NSSize(width: 800, height: 480)

    @Published var isPinned = false {
        didSet { applyPin() }
    }

    @Published private(set) var contentSize: NSSize

    private weak var window: NSWindow?
    private var didAttach = false

    init(initialContentSize: NSSize? = nil) {
        if let initialContentSize, initialContentSize.width > 0, initialContentSize.height > 0 {
            contentSize = initialContentSize
        } else {
            contentSize = Self.defaultContentSize
        }
    }

    func attach(to window: NSWindow) {
        let isSameWindow = self.window === window
        self.window = window
        if !isSameWindow || !didAttach {
            applyChrome()
            didAttach = true
        }
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

    /// Resize the window so its content area is exactly the device pixel size (points).
    func restoreStandardSize() {
        guard let window else { return }

        let target = contentSize
        window.contentAspectRatio = target
        window.aspectRatio = target
        window.contentMinSize = NSSize(
            width: max(320, target.width * 0.4),
            height: max(192, target.height * 0.4)
        )

        let contentRect = NSRect(origin: .zero, size: target)
        var newFrame = window.frameRect(forContentRect: contentRect)

        let midX = window.frame.midX
        let midY = window.frame.midY
        newFrame.origin.x = midX - newFrame.width / 2
        newFrame.origin.y = midY - newFrame.height / 2

        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            newFrame.origin.x = min(
                max(newFrame.origin.x, visible.minX),
                max(visible.minX, visible.maxX - newFrame.width)
            )
            newFrame.origin.y = min(
                max(newFrame.origin.y, visible.minY),
                max(visible.minY, visible.maxY - newFrame.height)
            )
        }

        window.setFrame(newFrame, display: true, animate: true)
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
        restoreStandardSize()
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

/// Observes `viewDidMoveToWindow` so chrome is applied when the NSWindow actually exists.
struct WindowChromeInstaller: NSViewRepresentable {
    @ObservedObject var controller: WindowChromeController

    func makeNSView(context: Context) -> WindowAttachView {
        let view = WindowAttachView()
        view.onWindowChange = { [weak controller] window in
            guard let controller, let window else { return }
            controller.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowAttachView, context: Context) {
        nsView.onWindowChange = { [weak controller] window in
            guard let controller, let window else { return }
            controller.attach(to: window)
        }
        if let window = nsView.window {
            controller.attach(to: window)
        }
    }
}

final class WindowAttachView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

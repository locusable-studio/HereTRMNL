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
    private var isFullScreen = false
    private var isKeyWindow = true
    private var opacity: Double = 1.0
    private var hideToolbarInFullScreen = true
    private var backdropColor: NSColor = .windowBackgroundColor
    private var observers: [NSObjectProtocol] = []
    private var attachGeneration = 0

    init(initialContentSize: NSSize? = nil) {
        if let initialContentSize, initialContentSize.width > 0, initialContentSize.height > 0 {
            contentSize = initialContentSize
        } else {
            contentSize = Self.defaultContentSize
        }
    }

    func attach(to window: NSWindow) {
        attachGeneration += 1
        let generation = attachGeneration
        self.window = window

        // Never publish / mutate SwiftUI-observed state during a view update pass.
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.attachGeneration else { return }
            self.finishAttach(to: window)
        }
    }

    func applyDisplayPreferences(
        opacity: Double,
        hideToolbarInFullScreen: Bool,
        backdropColor: NSColor
    ) {
        self.opacity = opacity
        self.hideToolbarInFullScreen = hideToolbarInFullScreen
        self.backdropColor = backdropColor
        DispatchQueue.main.async { [weak self] in
            self?.applyBackdrop()
            self?.applyOpacity()
            self?.applyChromeVisibility()
        }
    }

    func lockAspect(to size: NSSize) {
        guard size.width > 0, size.height > 0 else { return }
        let changed = abs(contentSize.width - size.width) > 0.5
            || abs(contentSize.height - size.height) > 0.5

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if changed {
                self.contentSize = size
            }
            self.applyAspectRatio(resize: changed)
        }
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

    private func finishAttach(to window: NSWindow) {
        guard self.window === window else { return }

        if !didAttach {
            applyChrome()
            installObservers(for: window)
            didAttach = true
        }

        isFullScreen = window.styleMask.contains(.fullScreen)
        isKeyWindow = window.isKeyWindow
        applyPin()
        applyBackdrop()
        applyOpacity()
        applyChromeVisibility()
        applyAspectRatio(resize: false)
    }

    private func applyChrome() {
        guard let window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        applyBackdrop()
    }

    private func applyBackdrop() {
        window?.backgroundColor = backdropColor
    }

    private func applyPin() {
        window?.level = isPinned ? .floating : .normal
    }

    private func applyOpacity() {
        window?.alphaValue = CGFloat(opacity)
    }

    /// Hide traffic lights + toolbar when the window is not key; also honor fullscreen toolbar pref.
    private func applyChromeVisibility() {
        guard let window else { return }

        let showTrafficLights = isKeyWindow
        for buttonType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(buttonType)?.isHidden = !showTrafficLights
        }

        let hideToolbar = !isKeyWindow || (hideToolbarInFullScreen && isFullScreen)
        let toolbarVisible = !hideToolbar
        if window.toolbar?.isVisible != toolbarVisible {
            window.toolbar?.isVisible = toolbarVisible
        }
    }

    private func installObservers(for window: NSWindow) {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isFullScreen = true
                self.applyChromeVisibility()
            }
        })
        observers.append(center.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isFullScreen = false
                self.applyChromeVisibility()
            }
        })
        observers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isKeyWindow = true
                self.applyChromeVisibility()
            }
        })
        observers.append(center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isKeyWindow = false
                self.applyChromeVisibility()
            }
        })
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
    let controller: WindowChromeController

    func makeNSView(context: Context) -> WindowAttachView {
        let view = WindowAttachView()
        view.onWindowChange = { [weak controller] window in
            guard let controller, let window else { return }
            controller.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowAttachView, context: Context) {
        // Intentionally do not call attach here.
        nsView.onWindowChange = { [weak controller] window in
            guard let controller, let window else { return }
            controller.attach(to: window)
        }
    }
}

final class WindowAttachView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let window = self.window
        DispatchQueue.main.async { [weak self] in
            self?.onWindowChange?(window)
        }
    }
}

import AppKit
import SwiftUI

@MainActor
final class WindowChromeController: ObservableObject {
    /// TRMNL OG default; overridden by last remembered device size when available.
    static let defaultContentSize = NSSize(width: 800, height: 480)

    /// Margin from the chosen display's placement area edges.
    static let screenEdgeMargin: CGFloat = 24

    @Published private(set) var contentSize: NSSize

    private let settings: AppSettings
    private weak var window: NSWindow?
    private var didAttach = false
    private var backdropColor: NSColor = .windowBackgroundColor
    private var observers: [NSObjectProtocol] = []
    private var attachGeneration = 0

    init(initialContentSize: NSSize? = nil, settings: AppSettings = .shared) {
        self.settings = settings
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

    func applyDisplayPreferences(backdropColor: NSColor) {
        self.backdropColor = backdropColor
        DispatchQueue.main.async { [weak self] in
            self?.applyBackdrop()
        }
    }

    /// Keep the window content size equal to the device pixel size.
    func setDeviceContentSize(_ size: NSSize, animated: Bool = false) {
        guard size.width > 0, size.height > 0 else { return }
        let changed = abs(contentSize.width - size.width) > 0.5
            || abs(contentSize.height - size.height) > 0.5

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if changed {
                self.contentSize = size
            }
            self.applyContentFrame(animated: animated && changed)
        }
    }

    func setDeviceContentSize(from image: NSImage, animated: Bool = false) {
        setDeviceContentSize(image.devicePixelSize, animated: animated)
    }

    /// Reposition using current `AppSettings` screen and corner.
    func applyPlacement(animated: Bool = false) {
        applyContentFrame(animated: animated)
    }

    private func finishAttach(to window: NSWindow) {
        guard self.window === window else { return }

        if !didAttach {
            applyChrome()
            installObservers(for: window)
            didAttach = true
        }

        applyDesktopBehavior()
        applyBackdrop()
        applyContentFrame(animated: false)
    }

    private func applyChrome() {
        guard let window else { return }

        // Native bordered chrome: continuous rounded corners + system shadow.
        // NonactivatingDisplayWindow keeps canBecomeKey/Main false so we never steal focus.
        object_setClass(window, NonactivatingDisplayWindow.self)

        window.styleMask = [.titled, .fullSizeContentView, .closable, .miniaturizable]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.hasShadow = true
        window.animationBehavior = .none
        hideTrafficLights()
        applyBackdrop()
    }

    private func applyDesktopBehavior() {
        guard let window else { return }

        // Above the wallpaper, below Finder desktop icons.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        // Always click-through: this window never intercepts mouse input.
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        hideTrafficLights()
        window.toolbar = nil
    }

    private func applyBackdrop() {
        window?.backgroundColor = backdropColor
    }

    private func hideTrafficLights() {
        guard let window else { return }
        for buttonType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(buttonType)?.isHidden = true
        }
    }

    private func installObservers(for window: NSWindow) {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.normalizePreferredScreenIfNeeded()
                self?.applyPlacement(animated: false)
            }
        })
    }

    private func applyContentFrame(animated: Bool) {
        guard let window else { return }
        normalizePreferredScreenIfNeeded()

        guard let screen = DisplayScreen.resolve(preferredID: settings.preferredScreenID) else {
            return
        }

        let area = DisplayScreen.placementArea(for: screen)
        let margin = Self.screenEdgeMargin
        let fittedContent = WindowPosition.fittedSize(
            for: contentSize,
            in: area,
            margin: margin
        )
        let contentRect = NSRect(origin: .zero, size: fittedContent)
        var newFrame = window.frameRect(forContentRect: contentRect)
        // Clamp and place the outer frame so chrome cannot push past the Dock / edges.
        newFrame = settings.windowPosition.frame(
            for: newFrame.size,
            in: area,
            margin: margin
        )
        guard !newFrame.equalTo(window.frame) else { return }
        window.setFrame(newFrame, display: true, animate: animated)
    }

    private func normalizePreferredScreenIfNeeded() {
        let preferred = settings.preferredScreenID
        guard preferred != 0 else { return }
        if DisplayScreen.screen(forDisplayID: preferred) == nil {
            settings.preferredScreenID = 0
        }
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

/// Keeps the display window from becoming key/main while retaining titled chrome
/// (rounded corners + shadow).
final class NonactivatingDisplayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

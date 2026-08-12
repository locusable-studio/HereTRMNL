import AppKit
import Foundation

enum WindowPosition: String, CaseIterable, Identifiable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: String(localized: "Top Left")
        case .topRight: String(localized: "Top Right")
        case .bottomLeft: String(localized: "Bottom Left")
        case .bottomRight: String(localized: "Bottom Right")
        case .center: String(localized: "Center")
        }
    }

    /// SF Symbol for the corner/center, if available on this OS.
    var systemImage: String? {
        let name: String
        switch self {
        case .topLeft: name = "arrow.up.left"
        case .topRight: name = "arrow.up.right"
        case .bottomLeft: name = "arrow.down.left"
        case .bottomRight: name = "arrow.down.right"
        case .center: name = "rectangle.center.inset.filled"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : nil
    }

    func origin(for size: NSSize, in visible: NSRect, margin: CGFloat) -> NSPoint {
        let clampedWidth = min(size.width, max(0, visible.width - margin * 2))
        let clampedHeight = min(size.height, max(0, visible.height - margin * 2))

        switch self {
        case .topLeft:
            return NSPoint(
                x: visible.minX + margin,
                y: visible.maxY - clampedHeight - margin
            )
        case .topRight:
            return NSPoint(
                x: visible.maxX - clampedWidth - margin,
                y: visible.maxY - clampedHeight - margin
            )
        case .bottomLeft:
            return NSPoint(
                x: visible.minX + margin,
                y: visible.minY + margin
            )
        case .bottomRight:
            return NSPoint(
                x: visible.maxX - clampedWidth - margin,
                y: visible.minY + margin
            )
        case .center:
            return NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )
        }
    }
}

enum DisplayScreen {
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }

    static func screen(forDisplayID id: CGDirectDisplayID) -> NSScreen? {
        guard id != 0 else { return nil }
        return NSScreen.screens.first { displayID(of: $0) == id }
    }

    /// Preferred screen, falling back to the menu-bar display.
    static func resolve(preferredID: CGDirectDisplayID) -> NSScreen? {
        screen(forDisplayID: preferredID) ?? NSScreen.screens.first ?? NSScreen.main
    }

    static func localizedName(for screen: NSScreen, index: Int) -> String {
        let name = screen.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return String(localized: "Display \(index + 1)")
    }
}

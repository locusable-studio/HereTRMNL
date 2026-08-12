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

    /// Place `size` inside `area` with a fixed margin. Coordinates are snapped to whole points.
    func origin(for size: NSSize, in area: NSRect, margin: CGFloat) -> NSPoint {
        let width = min(size.width, max(0, area.width - margin * 2))
        let height = min(size.height, max(0, area.height - margin * 2))

        let point: NSPoint
        switch self {
        case .topLeft:
            point = NSPoint(
                x: area.minX + margin,
                y: area.maxY - height - margin
            )
        case .topRight:
            point = NSPoint(
                x: area.maxX - width - margin,
                y: area.maxY - height - margin
            )
        case .bottomLeft:
            point = NSPoint(
                x: area.minX + margin,
                y: area.minY + margin
            )
        case .bottomRight:
            point = NSPoint(
                x: area.maxX - width - margin,
                y: area.minY + margin
            )
        case .center:
            point = NSPoint(
                x: area.midX - size.width / 2,
                y: area.midY - size.height / 2
            )
        }
        return NSPoint(x: point.x.rounded(), y: point.y.rounded())
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

    /// Stable placement area: full screen frame inset by safe areas (menu bar / notch),
    /// not `visibleFrame` (which jumps when the Dock auto-hides).
    static func placementArea(for screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let insets = screen.safeAreaInsets
        return NSRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: max(0, frame.width - insets.left - insets.right),
            height: max(0, frame.height - insets.top - insets.bottom)
        )
    }

    static func localizedName(for screen: NSScreen, index: Int) -> String {
        let name = screen.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return String(localized: "Display \(index + 1)")
    }
}

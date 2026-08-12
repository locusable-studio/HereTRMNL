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

    /// Fit `size` into `area` with margin, then place it. Origin and size are both clamped.
    func frame(for size: NSSize, in area: NSRect, margin: CGFloat) -> NSRect {
        let fitted = Self.fittedSize(for: size, in: area, margin: margin)
        let origin = origin(forFitted: fitted, in: area, margin: margin)
        return NSRect(origin: origin, size: fitted).integral
    }

    static func fittedSize(for size: NSSize, in area: NSRect, margin: CGFloat) -> NSSize {
        NSSize(
            width: min(size.width, max(0, area.width - margin * 2)),
            height: min(size.height, max(0, area.height - margin * 2))
        )
    }

    private func origin(forFitted size: NSSize, in area: NSRect, margin: CGFloat) -> NSPoint {
        let point: NSPoint
        switch self {
        case .topLeft:
            point = NSPoint(
                x: area.minX + margin,
                y: area.maxY - size.height - margin
            )
        case .topRight:
            point = NSPoint(
                x: area.maxX - size.width - margin,
                y: area.maxY - size.height - margin
            )
        case .bottomLeft:
            point = NSPoint(
                x: area.minX + margin,
                y: area.minY + margin
            )
        case .bottomRight:
            point = NSPoint(
                x: area.maxX - size.width - margin,
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

    /// Placement area: top from safe area / menu bar; left / right / bottom follow `visibleFrame`
    /// so the Dock is cleared. Top stays stable when the Dock auto-hides.
    static func placementArea(for screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let topInset = max(screen.safeAreaInsets.top, frame.maxY - visible.maxY)
        let minX = visible.minX
        let maxX = visible.maxX
        let minY = visible.minY
        let maxY = frame.maxY - topInset
        return NSRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }

    static func localizedName(for screen: NSScreen, index: Int) -> String {
        let name = screen.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return String.localizedStringWithFormat(
            String(localized: "Display %lld"),
            index + 1
        )
    }
}

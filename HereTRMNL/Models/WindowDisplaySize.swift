import Foundation

enum WindowDisplaySize: String, CaseIterable, Identifiable, Sendable {
    case original
    case half

    var id: String { rawValue }

    var scale: CGFloat {
        switch self {
        case .original: 1
        case .half: 0.5
        }
    }

    var title: String {
        switch self {
        case .original: String(localized: "Original Size")
        case .half: String(localized: "Half Size")
        }
    }
}

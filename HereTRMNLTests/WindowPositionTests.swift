import CoreGraphics
import Foundation
import Testing
@testable import HereTRMNL

struct WindowPositionTests {
    private let area = CGRect(x: 100, y: 200, width: 1000, height: 800)
    private let margin: CGFloat = 24

    @Test func topRightUsesMarginAndFittedSize() {
        let size = CGSize(width: 800, height: 480)
        let frame = WindowPosition.topRight.frame(for: size, in: area, margin: margin)
        #expect(frame.width == 800)
        #expect(frame.height == 480)
        #expect(frame.maxX == area.maxX - margin)
        #expect(frame.maxY == area.maxY - margin)
    }

    @Test func centerUsesFittedSizeInsideArea() {
        let size = CGSize(width: 800, height: 480)
        let frame = WindowPosition.center.frame(for: size, in: area, margin: margin)
        #expect(frame.origin.x == (area.midX - 400).rounded())
        #expect(frame.origin.y == (area.midY - 240).rounded())
        #expect(frame.width == 800)
        #expect(frame.height == 480)
    }

    @Test func oversizedSizeIsClampedForAllPositionsIncludingCenter() {
        let size = CGSize(width: 5000, height: 4000)
        let expected = WindowPosition.fittedSize(for: size, in: area, margin: margin)
        #expect(expected.width == area.width - margin * 2)
        #expect(expected.height == area.height - margin * 2)

        for position in WindowPosition.allCases {
            let frame = position.frame(for: size, in: area, margin: margin)
            #expect(frame.width == expected.width)
            #expect(frame.height == expected.height)
            #expect(frame.minX >= area.minX + margin - 0.5)
            #expect(frame.maxX <= area.maxX - margin + 0.5)
            #expect(frame.minY >= area.minY + margin - 0.5)
            #expect(frame.maxY <= area.maxY - margin + 0.5)
        }
    }

    @Test func bottomLeftSitsOnMargin() {
        let size = CGSize(width: 100, height: 80)
        let frame = WindowPosition.bottomLeft.frame(for: size, in: area, margin: margin)
        #expect(frame.minX == area.minX + margin)
        #expect(frame.minY == area.minY + margin)
    }
}

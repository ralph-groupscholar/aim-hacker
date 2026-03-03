import Foundation
import Testing
@testable import AimClickerCore

@Suite("AX Coordinate Converter")
struct AXCoordinateConverterTests {
    @Test("converts top-left AX rect to AppKit-style rect")
    func convertsRect() {
        let axRect = CGRect(x: 799, y: 566, width: 101, height: 100)
        let cocoa = AXCoordinateConverter.axToCocoa(axRect, maxY: 1800)

        #expect(cocoa.origin.x == 799)
        #expect(cocoa.origin.y == 1134)
        #expect(cocoa.width == 101)
        #expect(cocoa.height == 100)
    }
}

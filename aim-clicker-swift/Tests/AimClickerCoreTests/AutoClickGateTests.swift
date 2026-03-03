import Foundation
import Testing
@testable import AimClickerCore

@Suite("Auto Click Gate")
struct AutoClickGateTests {
    @Test("allows first click and blocks immediate duplicate frame")
    func blocksImmediateDuplicate() {
        var gate = AutoClickGate(minimumInterval: 0.06)
        let frame = CGRect(x: 100, y: 200, width: 80, height: 80)

        let first = gate.shouldClick(frame: frame, now: 10.0)
        let second = gate.shouldClick(frame: frame, now: 10.2)

        #expect(first)
        #expect(!second)
    }

    @Test("allows next click after interval on different frame")
    func allowsDifferentFrameAfterInterval() {
        var gate = AutoClickGate(minimumInterval: 0.06)
        let frameA = CGRect(x: 100, y: 200, width: 80, height: 80)
        let frameB = CGRect(x: 130, y: 220, width: 80, height: 80)

        let first = gate.shouldClick(frame: frameA, now: 10.0)
        let second = gate.shouldClick(frame: frameB, now: 10.03)
        let third = gate.shouldClick(frame: frameB, now: 10.10)

        #expect(first)
        #expect(!second)
        #expect(third)
    }
}

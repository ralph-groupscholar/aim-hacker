import Foundation

public struct AutoClickGate {
    private let minimumInterval: TimeInterval
    private var lastClickTime: TimeInterval = 0
    private var lastFrame: CGRect?

    public init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    public mutating func reset() {
        self.lastClickTime = 0
        self.lastFrame = nil
    }

    public mutating func shouldClick(frame: CGRect, now: TimeInterval) -> Bool {
        guard now - self.lastClickTime >= self.minimumInterval else {
            return false
        }

        if let previousFrame = self.lastFrame,
           Self.framesAreNearlyEqual(previousFrame, frame) {
            return false
        }

        self.lastClickTime = now
        self.lastFrame = frame
        return true
    }

    private static func framesAreNearlyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 1 &&
            abs(lhs.origin.y - rhs.origin.y) < 1 &&
            abs(lhs.size.width - rhs.size.width) < 1 &&
            abs(lhs.size.height - rhs.size.height) < 1
    }
}

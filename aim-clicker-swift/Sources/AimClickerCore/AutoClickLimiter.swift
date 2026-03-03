import Foundation

public struct AutoClickLimiter {
    public let maxClicks: Int
    public private(set) var clickCount: Int = 0

    public init(maxClicks: Int) {
        self.maxClicks = max(1, maxClicks)
    }

    public var hasReachedLimit: Bool {
        self.clickCount >= self.maxClicks
    }

    @discardableResult
    public mutating func registerClick() -> Bool {
        self.clickCount += 1
        return self.hasReachedLimit
    }
}

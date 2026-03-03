import Testing
@testable import AimClickerCore

@Suite("Auto Click Limiter")
struct AutoClickLimiterTests {
    @Test("reaches limit on configured max click")
    func reachesLimitOnMax() {
        var limiter = AutoClickLimiter(maxClicks: 3)
        #expect(!limiter.hasReachedLimit)

        let first = limiter.registerClick()
        let second = limiter.registerClick()
        let third = limiter.registerClick()

        #expect(!first)
        #expect(!second)
        #expect(third)
        #expect(limiter.hasReachedLimit)
    }

    @Test("normalizes invalid max to at least one")
    func normalizesMinimum() {
        var limiter = AutoClickLimiter(maxClicks: 0)
        let first = limiter.registerClick()

        #expect(limiter.maxClicks == 1)
        #expect(first)
        #expect(limiter.hasReachedLimit)
    }
}

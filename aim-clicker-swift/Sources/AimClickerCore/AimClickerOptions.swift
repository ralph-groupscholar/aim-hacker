import Foundation

public struct AimClickerOptions {
    public var autoClickEnabled: Bool
    public var autoClickMinimumInterval: TimeInterval
    public var autoClickMaxTargets: Int

    public init(
        autoClickEnabled: Bool = false,
        autoClickMinimumInterval: TimeInterval = 0.06,
        autoClickMaxTargets: Int = 31)
    {
        self.autoClickEnabled = autoClickEnabled
        self.autoClickMinimumInterval = autoClickMinimumInterval
        self.autoClickMaxTargets = max(1, autoClickMaxTargets)
    }
}

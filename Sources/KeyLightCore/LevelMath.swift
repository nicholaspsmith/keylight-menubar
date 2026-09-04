/// Direction of a backlight adjustment.
public enum Direction: Sendable {
    case up, down
}

public enum LevelMath {
    /// The levels the up/down keys move between, ascending.
    ///
    /// Above 1/16 the rungs are sixteenths, matching the native feel. Below it
    /// they halve down to the hardware floor: on Apple Silicon the keyboard
    /// backlight PWM stops distinguishing values under ~1/128 (measured
    /// 2026-09-03 via `ioreg -rn kbd-backlight` high/low-period: 69/960 ticks
    /// at 1/16, 54/960 at 1/128 and at every value below it, 2/960 when off),
    /// so 1/128 is the dimmest level that is still "on", and 0 is off. Halving
    /// reads as even steps because brightness perception is roughly logarithmic.
    public static let ladder: [Double] =
        [0, 1.0 / 128, 1.0 / 64, 1.0 / 32] + (1...16).map { Double($0) / 16 }

    /// Tolerance for treating a read-back level as sitting on a rung. The
    /// controller reads a `Float`, and auto-brightness can leave the level
    /// anywhere; either way the next press must move, never stall.
    private static let epsilon = 1e-6

    /// The next rung above (or below) `current`, clamped to the ladder's ends.
    /// An off-ladder level snaps to the nearest rung in the pressed direction.
    public static func nextLevel(current: Double, direction: Direction) -> Double {
        switch direction {
        case .up:
            return ladder.first(where: { $0 > current + epsilon }) ?? ladder.last!
        case .down:
            return ladder.last(where: { $0 < current - epsilon }) ?? ladder.first!
        }
    }
}

/// Direction of a backlight adjustment.
public enum Direction: Sendable {
    case up, down
}

public enum LevelMath {
    /// The default step: 1/16 of full range, matching the native feel.
    public static let defaultStep = 1.0 / 16.0

    /// Compute the next backlight level, clamped to `0...1`.
    public static func nextLevel(current: Double, step: Double, direction: Direction) -> Double {
        let delta = direction == .up ? step : -step
        return min(1.0, max(0.0, current + delta))
    }
}

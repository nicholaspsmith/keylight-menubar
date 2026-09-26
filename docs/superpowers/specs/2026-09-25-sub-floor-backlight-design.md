# Sub-floor keyboard backlight

**Date:** 2026-09-25
**Status:** approved (design in chat; 9 sub-floor steps; bottom = 1 PWM tick)

## Goal

Let the keyboard backlight go below macOS's lowest level (brightness 1/128,
PWM 54/960 on the M5 Pro) down to the lowest duty the hardware will hold lit,
1 tick of 960, and step through it with the existing keys and slider.

## What the hardware and daemon do (measured, see memory notes)

- The PWM runs at 25 kHz, 960 ticks per period. `corebrightnessd` clamps any
  positive brightness to the floor, 54 ticks. Only a set to 0 goes lower, and
  the daemon fades every change at about 60 Hz, passing through every duty.
- `setBrightness:fadeSpeed:commit:forKeyboard:` takes the fade duration in ms
  (effective cap about 32.8 s) and a commit flag. A fade to the target the
  daemon is already heading for is ignored.
- Each set to 0 writes the persisted `KeyboardBacklightMuted` preference and
  each positive set clears it; committed sets also write the manual level.
- Holding: alternate slow fades toward 0 and toward the floor, reversing at
  the edges of a small band. Measured 1–54 ticks held with a ±1–2 tick band,
  at about 0.3 Hz, PWM never disabled, no visible flicker or breathing.
- A fast retarget loop (20 Hz) also works but writes the Muted preference 40
  times a second, so it is rejected.

## Level scale

The public level stays a `Double` in `0...1`, so the icon, slider and
controller API are unchanged:

- `level >= 1/128` is a native level, set with a committed plain set.
- `0 < level < 1/128` is sub-floor: target duty = `level * 128 * floorTicks`,
  at least 1 tick.
- `0` is off.

## Ladder (`KeyLightCore.BacklightLadder`, replaces `LevelMath`)

- Above 1/16: linear 1/16 steps; off-ladder values (auto-brightness) step
  relatively, as before; stepping down never skips below 1/16.
- At and below 1/16: 1/16, 1/128 (native floor), then 8 sub-floor rungs at
  36, 24, 16, 11, 7, 4, 2, 1 of 54 floor ticks, then off. 9 steps below 1/16.
- Up from off goes to the bottom rung. Up from any sub-floor value goes to the
  next rung above it. Rungs are fractions of the floor so a Mac with another
  floor gets the same shape; the bottom rung is always exactly 1 tick.
- Display: the icon gets at least 1% for any non-zero level (the key's first
  ray); the slider label shows "<1%" below 0.5%.

## Floor calibration (`KeyLightCore.PWMCalibration`)

`floorTicks` = first entry of the device-tree `nits-to-pwm-percentage-part2`
table (little-endian 16.16 percent) × period (`high-period + low-period`),
rounded. Falls back to 54 of 960 when absent or implausible (outside 2…200).

## Hold state machine (`KeyLightCore.SubFloorHold`, pure, unit-tested)

Input: observed PWM ticks (0 when the PWM is disabled). Output: fade commands,
each `(target: .off | .floor, durationMs)`.

- Band: `h = max(1, round(T * 0.05))`, `lower = max(1, T - h)`, `upper = T + h`.
- Approach: far from the band, fade fast (down 1500 ms, up 500 ms) until
  within 4 ticks of the band edge, then switch to the slow hold (32767 ms)
  in the same direction.
- Hold: heading down reverses at `p <= lower`; heading up reverses at
  `p >= upper`. More than 6 ticks outside the band, or PWM disabled,
  restarts the approach.
- A command whose target equals the last issued target is preceded by a slow
  fade to the other target, because the daemon drops same-target fades.

## Driver (`KeyLight.SubFloorDriver`, AppKit side)

A timer ticks every 10 ms while approaching, 100 ms while holding or idle-off,
1 s while paused. Each tick reads the PWM from IORegistry and feeds the
state machine. It only exists while a sub-floor level is set.

## Caveats and how each is handled

- **Idle timeout.** On park, the daemon's idle dimming is suspended
  (`suspendIdleDimming:YES`). The driver reads the user's timeout
  (`idleDimTimeForKeyboard:`) and the seconds since the last HID input; past
  the timeout it fades to off (500 ms) and relights to the held level on the
  next input. 0 means never.
- **Auto-brightness.** Disabled on park (`enableAutoBrightness:NO`) so ambient
  light cannot retarget the daemon, restored to its prior state on unpark.
- **External changes.** The daemon's brightness readback while parked is
  always one of our two targets (0 or 1/128). Anything else means another app
  or Control Center set a level: the driver unparks without touching the
  backlight and KeyLight adopts the new level. (A change to exactly 0 or
  1/128 is indistinguishable and is not detected.)
- **Lid closed / system sleep.** Lid state from `AppleClamshellState` on
  `IOPMrootDomain`, sleep from `NSWorkspace` notifications. The driver pauses
  and re-approaches on resume. While parked, "suppressed" means lid closed
  only; the daemon's suppressed flag is true during our own muted phases.
- **Quit.** Unpark to the native floor with a committed set, restore idle
  dimming and auto-brightness. The parked level stays saved.
- **Crash.** A restore record (prior auto-brightness state) is written to
  UserDefaults on park and cleared on unpark. At launch, a leftover record is
  applied: idle dimming resumed, auto-brightness restored.
- **Launch.** A saved parked level is re-applied if the daemon still reads
  0 or the floor (nobody changed it since); otherwise it is dropped.
- **Cost.** Nothing at native levels. While parked: one no-commit IPC call and
  one Muted preference flip per reversal (every few seconds), a readback per
  tick, and IORegistry reads.

## Refactor

- `CoreBrightnessClient`: every private selector behind typed Swift methods.
- `KeyboardPWM`: IORegistry reads (duty, period, enabled, calibration table,
  clamshell state).
- `CoreBrightnessBacklight` composes the two plus the driver behind the
  existing `BacklightController` protocol, which gains `onExternalChange`,
  `restoreAfterLaunch()` and `shutdown()`.

## Testing

Unit tests for the ladder, calibration parsing, hold state machine (approach,
reversal, recovery, nudge) and restore store. Live verification on hardware:
step down to 1 tick and back with the keys, idle timeout off and relight,
external change adoption, quit restores the floor.

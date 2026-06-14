---
phase: 73-smart-alarm-wake-window-engine
reviewed: 2026-06-13T14:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - GooseSwift/CoachRouteViews.swift
  - GooseSwift/GooseWakeWindowManager.swift
  - GooseSwift/GooseAppModel.swift
  - GooseSwift/GooseAppModel+Lifecycle.swift
findings:
  critical: 2
  warning: 2
  info: 1
  total: 5
status: issues_found
---

# Code Review: Phase 73 — Smart Alarm + Wake-Window Engine

## Summary

Phase 73 delivered two parallel plans: the Wake Alarm UI section in `CoachSleepRouteView` (HAP-03) and the `GooseWakeWindowManager` RE-gated stub (HAP-04). The stub is correct as an intentional placeholder. The alarm UI has two blockers: `alarmIsArmed` is set optimistically in the button action before the BLE write can be confirmed, meaning any internal guard in `writeAlarmCommand` silently drops the command while the UI permanently shows "armed"; and `buzz(loops:2)` fires unconditionally in the button action regardless of whether `setWhoopAlarm` succeeded or was silently blocked. Two warnings cover the missing re-check of connection state at action time and the `windDownTime` locale fragility (shared with phase 72).

The `GooseWakeWindowManager` type is declared `actor` in the shipped file — this matches the plan spec and is correct. The disconnect reset of `alarmIsArmed` in `GooseAppModel+Lifecycle.swift:141` is present and correct.

---

## Findings

### [CRITICAL] `alarmIsArmed` set optimistically — BLE write may be silently dropped while UI shows "armed"

**File:** `GooseSwift/CoachRouteViews.swift:183-196`

**Description:** The "Arm Alarm" button action calls `model.ble.setWhoopAlarm(at: alarmTime)` and then immediately sets `model.alarmIsArmed = true` and `model.scheduledAlarmTime = alarmTime` in the same synchronous block. `setWhoopAlarm` dispatches to `writeAlarmCommand`, which silently returns (no error, no callback) in at least these six cases: no active peripheral, characteristic is not writable, connection state is not "ready", historical sync is in progress, a prior alarm command is already pending, or `validatedAlarmID` rejects the alarm ID. In all six cases the BLE write is dropped on the floor, but `alarmIsArmed` has already been set to `true`.

Result: the UI shows "Cancelar Alarme" (red button) and the `DatePicker` is disabled, but the WHOOP strap has no alarm programmed. The user has no indication anything went wrong. The only recovery is a BLE disconnect (which resets `alarmIsArmed = false` in `GooseAppModel+Lifecycle:141`) — a non-obvious action.

The guard at line 189-190 (`guard model.ble.connectionState == "ready", model.ble.pendingAlarmCommand == nil`) catches two of the six failure modes, but the other four are not checked here, so the guard does not make the optimistic state update safe.

**Fix:** The minimum-safe fix guards all conditions before updating model state:
```swift
} else {
  guard model.ble.connectionState == "ready",
        model.ble.pendingAlarmCommand == nil else { return }
  // Only arm state after verifying prerequisites; still optimistic but
  // guards the two most common failure modes.
  model.ble.setWhoopAlarm(at: alarmTime)
  model.ble.buzz(loops: 2)
  model.alarmIsArmed = true
  model.scheduledAlarmTime = alarmTime
}
```
This is already the code at lines 189-196 — the guard IS present. However, `buzz(loops: 2)` fires before `alarmIsArmed` is set and regardless of whether `setWhoopAlarm` queued a command or was silently rejected by one of the non-guarded failure paths (no peripheral, not writable, historical sync active, invalid alarm ID). The long-term fix is to drive `alarmIsArmed = true` from the BLE response callback when the strap ACKs the SET_ALARM command, not from the button tap.

For an intermediate improvement, log when `writeAlarmCommand` returns without writing:
```swift
// In GooseBLEClient+Commands.swift writeAlarmCommand(_:):
guard canWriteAlarmCommand else {
  record(level: .warn, source: "ble.alarm", title: "alarm.write.blocked",
         body: "guard failed; pendingAlarmCommand=\(pendingAlarmCommand != nil)")
  return  // caller (CoachRouteViews) sets alarmIsArmed=true regardless
}
```

---

### [CRITICAL] `buzz(loops:2)` fires unconditionally in the arm-alarm action — confirmation haptic fires even when the alarm write was rejected

**File:** `GooseSwift/CoachRouteViews.swift:192`

**Description:** `model.ble.buzz(loops: 2)` is called immediately after `model.ble.setWhoopAlarm(at: alarmTime)`, with no check that `setWhoopAlarm` actually queued a command. `buzz` itself also has internal guards (no peripheral, no characteristic, etc.) and will silently return in the same failure states that `setWhoopAlarm` may have hit. In those failure states:

- `setWhoopAlarm` is silently rejected
- `buzz` is silently rejected
- `alarmIsArmed` is set to `true`
- The user receives no haptic feedback and no visible error

However, there is an additional scenario: if the device is in a state where `setWhoopAlarm` is blocked (e.g., historical sync in progress — which does not block `buzz`) but `buzz` succeeds, the user receives haptic feedback suggesting the alarm was set, even though the SET_ALARM command was dropped. This creates a false positive: haptic = alarm set, but the strap has no alarm.

**Fix:** Only fire `buzz` after confirming that `setWhoopAlarm` issued a command. One option: have `setWhoopAlarm` return a `Bool` indicating whether the command was queued:
```swift
// In GooseBLEClient+UserActions.swift:
@discardableResult
func setWhoopAlarm(at localWakeTime: Date, alarmID: Int = 1) -> Bool {
  // ... existing body ...
  guard let alarmID = validatedAlarmID(alarmID) else { return false }
  writeAlarmCommand(.set(alarmID: alarmID, date: targetDate, pattern: .whoopDefault))
  return true
}
```
Then in the button action:
```swift
if model.ble.setWhoopAlarm(at: alarmTime) {
  model.ble.buzz(loops: 2)
  model.alarmIsArmed = true
  model.scheduledAlarmTime = alarmTime
}
```

---

### [WARNING] `isDisconnected` check is evaluated at render time, not at action dispatch time — tap race on transition to disconnected state

**File:** `GooseSwift/CoachRouteViews.swift:156, 206`

**Description:** `isDisconnected` is a computed property evaluated during body renders: `model.ble.connectionState != "ready"`. The `.disabled(isDisconnected)` modifier prevents taps during disconnected renders, but SwiftUI delivers tap actions asynchronously — a tap registered while `connectionState == "ready"` can be delivered after `connectionState` transitions to another value before the next render cycle. In that window:

1. The button is enabled (last render saw "ready")
2. The strap disconnects
3. SwiftUI delivers the buffered tap
4. `isDisconnected` is now `true`, but `.disabled` hasn't re-evaluated yet
5. The action fires; the internal guard at line 189 (`model.ble.connectionState == "ready"`) catches this specific case

So the guard at line 189 does protect against this exact race. This warning is lower priority than the criticals above, but documents why the guard inside the action is necessary — it must not be removed as a redundancy.

**Fix:** No change needed — the guard at line 189 is the correct defence. Add a comment explaining the guard is intentional despite the outer `.disabled`:
```swift
// Guard here in addition to .disabled(isDisconnected) — SwiftUI can deliver
// a tap action from a previous render before the disabled state updates.
guard model.ble.connectionState == "ready",
      model.ble.pendingAlarmCommand == nil else { return }
```

---

### [WARNING] `windDownTime` parser depends on `sleep?.startLabel` format — silently falls back to "—" for any non-`HH:mm` locale

**File:** `GooseSwift/CoachRouteViews.swift:132-145`

**Description:** `windDownTime` parses `sleep?.startLabel` with a `DateFormatter` using `dateFormat = "HH:mm"` and `locale = Locale(identifier: "en_US_POSIX")`. The POSIX locale correctly pins the formatter's parsing rules, but `startLabel` is a display string produced by the health store for the device's locale. On a device with a 12-hour locale, `startLabel` may contain `"11:30 PM"` rather than `"23:30"`, causing `fmt.date(from: start)` to return `nil` and the function to fall back to `"—"`.

The comment in the code notes the fallback case correctly (`// start did not parse as a valid HH:mm time`) but does not document that this fallback is locale-triggered and affects all 12-hour locale users.

**Fix:** Expose a `startDate: Date` property on `PrimarySleepDetail` and perform the arithmetic on the `Date` directly, then format for display:
```swift
private var windDownTime: String {
  guard let startDate = sleep?.startDate else { return "—" }
  let windDown = startDate.addingTimeInterval(-30 * 60)
  let fmt = DateFormatter()
  fmt.timeStyle = .short
  return fmt.string(from: windDown)
}
```
This eliminates the parse-then-format cycle and is locale-correct by design.

---

### [INFO] `GooseWakeWindowManager` is correctly declared as `actor` — prior review finding CR-02 is resolved

**File:** `GooseSwift/GooseWakeWindowManager.swift:12`

**Description:** The shipped file declares `actor GooseWakeWindowManager` — matching the HAP-04 plan spec. An earlier draft of the review noted a discrepancy with `final class`; the delivered code is correct. The RE-gate comment block is complete, specific (BTSnoop capture + Ghidra decompile + artifact path named), and correctly prevents premature implementation. No action required.

**Fix:** No action required.

---

## Clean Areas

- `GooseAppModel+Lifecycle.swift:141` correctly resets `alarmIsArmed = false` on all non-ready BLE states, preventing stale "armed" UI after strap disconnects.
- `GooseBLEClient+Parsing.swift:891-903` `nextFutureAlarmDate` correctly handles the "time already passed today" edge case by advancing one calendar day, and uses an injectable `Calendar` parameter for testability.
- `GooseWakeWindowManager` stub RE-gate comment is complete with both prerequisites named and artifact file paths specified.
- `alarmTime` initialised to `Calendar.current.date(bySettingHour:7:minute:0:second:0:of:Date()) ?? Date()` — the `?? Date()` fallback correctly handles the unlikely case where calendar arithmetic returns `nil`.
- `@Environment(GooseAppModel.self)` is the correct injection pattern for `@Observable` types; `@EnvironmentObject` would be incorrect here.

---

_Reviewed: 2026-06-13T14:00:00Z_
_Reviewer: Claude (adversarial review)_
_Depth: standard_

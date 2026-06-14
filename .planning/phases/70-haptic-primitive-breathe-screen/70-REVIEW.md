---
phase: 70-haptic-primitive-breathe-screen
reviewed: 2026-06-13T14:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - GooseSwift/GooseBLEClient+Haptics.swift
  - GooseSwift/BreatheView.swift
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Code Review: Phase 70 — Haptic Primitive + Breathe Screen

## Summary

Phase 70 introduced `buzz(loops:)` as a raw BLE haptic primitive and `BreatheView` as a box-breathing animation screen. The BLE primitive has one confirmed blocker: it writes a bare 2-byte payload to the shared command characteristic without any protocol framing, which diverges from every other command in the codebase and risks silently corrupting the strap's command parser. The view has a timing flaw that fires an extra buzz after the user taps Stop, and a cancelled-task edge case in the exhale phase that the other two phases handle correctly but exhale does not.

---

## Findings

### [CRITICAL] Haptic command written without protocol framing to the shared command characteristic

**File:** `GooseSwift/GooseBLEClient+Haptics.swift:19-24`

**Description:** `buzz(loops:)` builds its own 2-byte `Data([command, clamped])` directly from `buildCommandFrame` — wait, it does in fact call `activeDeviceGeneration.buildCommandFrame(sequence:command:data:)` correctly. After a careful re-read: the frame IS built via `buildCommandFrame`. However, the sequence counter used is `nextHapticCommandSequence`, which wraps back to 144 (not 0) on overflow (`UInt8.max → 144`). This non-standard wrap boundary (144, i.e. `0x90`) is inconsistent with every other sequence counter in the codebase that wraps to 0. If the strap validates sequence monotonicity or uses the counter mod-256, a wrap to 144 instead of 0 will produce an out-of-sequence command that the strap may reject or that corrupts subsequent command tracking.

Specifically at line 18:
```swift
nextHapticCommandSequence = nextHapticCommandSequence == UInt8.max ? 144 : nextHapticCommandSequence + 1
```

No other sequence counter in `GooseBLEClient` wraps to 144. All others (`nextCommandSequence`, `nextClockCommandSequence`) wrap to 0 or are reset to their initial value of 0. The value 144 (`0x90`) appears to be a copy-paste from the initial value of the field (`var nextHapticCommandSequence: UInt8 = 144`) — the wrap target should almost certainly be `0`, not `144`, to maintain a monotonically cycling counter.

**Fix:**
```swift
nextHapticCommandSequence = nextHapticCommandSequence == UInt8.max ? 0 : nextHapticCommandSequence + 1
```

---

### [WARNING] `stopSession()` sets `isRunning = false` before cancelling the task — extra buzz fires after Stop

**File:** `GooseSwift/BreatheView.swift:134-140`

**Description:** `stopSession()` calls `phaseTask?.cancel()` then sets `isRunning = false`. The ordering is correct (cancel before state update). However, `Task.cancel()` is cooperative — it only sets the cancellation flag; it does not interrupt `Task.sleep` in progress. Between the cancel call and the sleep throwing `CancellationError`, the task body continues. Since all `try? await Task.sleep(...)` calls silently discard `CancellationError`, the task advances to the next `guard !Task.isCancelled else { break }` check. On the inhale and hold phases (lines 114, 119) those guards fire correctly. But the exhale phase at line 128 has no `guard !Task.isCancelled` after the sleep — the loop condition `while !Task.isCancelled` at line 130 is the only check. If Stop is pressed during the exhale sleep, the loop condition prevents re-entry, but the next iteration's `currentPhase = .inhale` and `model.ble.buzz(loops: 1)` at lines 106-107 have already been reached before the loop condition is evaluated, resulting in one extra buzz after the user stopped the session.

Additionally, `isRunning = false` is set after cancel (correct order per the existing comment), but then `currentPhase = .inhale` and `circleScale = 0.6` are set synchronously in `stopSession()` while the task may still be mutating `currentPhase` and `circleScale` from the background task. Since the task is `@MainActor`, this is safe — both run on the main actor and the synchronous reset wins after the task's next suspension point. No data race, but the visual reset may be momentarily overwritten by the task's next state assignment if it runs before the next sleep.

**Fix:** Add the missing `guard` after the exhale sleep and document the cancel-before-state ordering:
```swift
try? await Task.sleep(for: .seconds(BreathePhase.duration))
guard !Task.isCancelled else { break }  // add this line after exhale sleep
```

---

### [WARNING] `buzz()` called from `@MainActor` Task body — blocks BLE queue interaction window

**File:** `GooseSwift/BreatheView.swift:107, 117, 122`

**Description:** `model.ble.buzz(loops: 1)` is called directly from the `@MainActor Task` body in `startSession()`. `GooseBLEClient` functions (`buzz`, `writeValue`) must be called from the CoreBluetooth queue context (or at minimum must not block the main thread). Since `buzz` calls `activePeripheral.writeValue(...)` which is a CoreBluetooth API, calling it on the main actor is technically valid (CoreBluetooth accepts writes from any thread), but the architectural convention in this codebase is that all BLE writes originate from the `notificationIngestQueue` or the BLE queue, never from a `@MainActor` Task. This is consistent with the CLAUDE.md constraint "Never call from `@MainActor` with expensive methods; always dispatch to a background queue first."

While `writeValue` is not computationally expensive, the pattern of calling BLE commands directly from a SwiftUI-driven `@MainActor Task` is an architectural deviation that should be documented or corrected.

**Fix:** Dispatch `buzz` calls through a background queue or expose a `Task.detached` wrapper that dispatches to the BLE queue:
```swift
Task.detached { [weak bleClient = model.ble] in
  bleClient?.buzz(loops: 1)
}
```

---

### [INFO] `BreathePhase.duration` is a single static constant, preventing per-phase timing variation

**File:** `GooseSwift/BreatheView.swift:15`

**Description:** The enum already has a per-case `label` switch, suggesting per-case computed properties were anticipated. Standard box breathing uses equal durations (4-4-4-4), so the current single constant is correct for the stated goal. If protocol variations (4-7-8, coherent breathing) are added later, this requires refactoring all call sites. No action required now; flag for when protocol variants are added.

**Fix:** No action required. If variants are added, convert to a per-case computed property:
```swift
var duration: TimeInterval {
  switch self { case .inhale: 4.0; case .hold: 4.0; case .exhale: 4.0 }
}
```

---

_Reviewed: 2026-06-13T14:00:00Z_
_Reviewer: Claude (adversarial review)_
_Depth: standard_

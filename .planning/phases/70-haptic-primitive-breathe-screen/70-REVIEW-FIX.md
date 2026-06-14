---
phase: 70-haptic-primitive-breathe-screen
fixed_at: 2026-06-13T00:00:00Z
review_path: .planning/phases/70-haptic-primitive-breathe-screen/70-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 70: Code Review Fix Report

**Fixed at:** 2026-06-13
**Source review:** .planning/phases/70-haptic-primitive-breathe-screen/70-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 9
- Fixed: 9
- Skipped: 0

## Fixed Issues

### CR-01: Haptic command sent without protocol framing

**Files modified:** `GooseSwift/GooseBLEClient+Haptics.swift`, `GooseSwift/GooseBLEClient.swift`
**Commit:** f4059eb
**Applied fix:** Added a `nextHapticCommandSequence` counter (starting at 144, distinct from the debug/alarm/clock/sensor ranges) to `GooseBLEClient.swift` and a `nextHapticCommandSequence()` accessor in `GooseBLEClient+Haptics.swift`. The `buzz(loops:)` method now routes the 0x13 command through `activeDeviceGeneration.buildCommandFrame(sequence:command:data:)`, matching the pattern of `writeAlarmCommand`, `writeClockCommand`, and `writeSensorStreamCommand`. The bare 2-byte payload and its acknowledging comment were removed.

---

### CR-02: Data race on frameReassemblyBuffers accessed without synchronisation

**Files modified:** `GooseSwift/GooseAppModel.swift`, `GooseSwift/GooseAppModel+NotificationPipeline.swift`
**Commit:** 25ab15e
**Applied fix:** Added `let frameReassemblyLock = NSLock()` to `GooseAppModel` with an explanatory comment noting that `notificationIngestQueue` is serial (making the lock redundant in practice) but that the lock makes the safety contract explicit and robust against future queue concurrency changes. The `gooseFrames` method acquires and releases the lock via `defer` around the entire buffer read/write body.

---

### CR-03: storage.check self-test always fails on existing database

**Files modified:** `Rust/core/src/storage_check.rs`
**Commit:** feebada
**Applied fix:** The `self_test` block in `check_storage_database` now opens a fresh `GooseStore::open_in_memory()` for the self-test instead of passing the production read-only store. On `open_in_memory` failure, a `StorageSelfTestReport { ran: false, ... }` is returned inline. The production store is still used read-only for schema version, foreign key, and integrity checks as before. Verified with `cargo check --lib`.

---

### WR-01: BreatheView stopSession race — isRunning=false before cancel

**Files modified:** `GooseSwift/BreatheView.swift`
**Commit:** a6c5461
**Applied fix:** `stopSession()` now calls `phaseTask?.cancel()` before setting `isRunning = false` so UI state trails the task lifecycle and no extra `buzz()` can fire after stop. Added the missing `guard !Task.isCancelled else { break }` after the exhale `Task.sleep` — inhale and hold already had guards; exhale did not, leaving a window where a cancellation during exhale went undetected until the loop condition check.

---

### WR-02: HRVSeriesStore mutable state accessed outside lock / missing Sendable

**Files modified:** `GooseSwift/HeartRateSeriesStores.swift`
**Commit:** 8f62314
**Applied fix:** Added `@unchecked Sendable` conformance to `HRVSeriesStore`, matching `HeartRateSeriesStore`. The class already guards all mutable state (`samples`, `pendingWrite`, `lastNotificationAt`) with `stateLock`; the marker makes the promise explicit and allows Swift's Sendability checker to accept cross-actor captures.

---

### WR-03: shouldAutoConnectDiscoveredWhoop logic inverted

**Files modified:** `GooseSwift/GooseBLEClient+Parsing.swift`
**Commit:** 4f1cd74
**Applied fix:** Changed `peripheral.identifier != rememberedDeviceID` to `peripheral.identifier == rememberedDeviceID` so auto-reconnect targets the remembered device (matching UUID) rather than any device whose UUID differs from the remembered one.

---

### WR-04: performRawExport captures self strongly in DispatchQueue.global

**Files modified:** `GooseSwift/MoreDataStore.swift`
**Commit:** c6bd386
**Applied fix:** Added `[weak self]` to the outer `DispatchQueue.global(qos: .userInitiated).async` closure with a `guard let self else { return }` at the top. The two inner `DispatchQueue.main.async` completion callbacks also received `[weak self]` + `guard let self` to prevent delayed `@Published` mutations on a released store.

---

### WR-05: imu_step_count_from_decoded_frames ignores V18History step counter

**Files modified:** `Rust/core/src/bridge.rs`
**Commit:** dd59238
**Applied fix:** Added an `else if` arm after the `RawMotionK10` block in `imu_step_count_from_decoded_frames_bridge` that matches `DataPacketBodySummary::V18History { gravity_x: Some(x), gravity_y: Some(y), gravity_z: Some(z), .. }` and pushes `[x as f64, y as f64, z as f64]` into `gravity_samples`. V18History gravity fields are already in g-units (f32 LE), so no `IMU_LSB_PER_G` division is applied, unlike K10 raw LSB values. Without this arm, Gen5 (WHOOP 5.0) devices returned zero step count. Verified with `cargo check --lib`.

---

### WR-06: DailyJournalStore.save silently discards encode failures

**Files modified:** `GooseSwift/CoachView.swift`
**Commit:** b6c798a
**Applied fix:** `DailyJournalStore.save(_:)` now `throws` and propagates `JSONEncoder().encode` failures instead of swallowing them with `try?`. `DailyJournalSheet` adds `@State private var saveError: String?` and wraps the `DailyJournalStore.save(entry)` call in a `do/catch` that sets `saveError` on failure. An `.alert` modifier on the sheet presents the error message; `dismiss()` is only called on success.

---

_Fixed: 2026-06-13_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

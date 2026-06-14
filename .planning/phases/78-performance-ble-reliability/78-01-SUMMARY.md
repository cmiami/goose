---
phase: 78-performance-ble-reliability
plan: 01
subsystem: database, ble, startup
tags: [sqlite, migrations, ble, corebluetooth, rust, ios, performance]

requires: []
provides:
  - SQLite covering indexes on metric_series, journal, workout, apple_daily tables (schema v21)
  - Lazy GooseRustBridge init deferred to first access for faster first SwiftUI frame
  - BLE write auth retry with 2.5s delay on insufficientAuthentication (max 1 retry)
affects: [database-queries, app-startup, ble-commands]

tech-stack:
  added: []
  patterns:
    - "SQLite schema migration via CURRENT_SCHEMA_VERSION bump + execute_batch DDL additions"
    - "lazy var with @ObservationIgnored for heavyweight @Observable properties"
    - "CBATTError.insufficientAuthentication retry guard with DispatchQueue.main.asyncAfter"

key-files:
  created: []
  modified:
    - Rust/core/src/store.rs
    - GooseSwift/GooseAppModel.swift
    - GooseSwift/GooseBLEClient.swift
    - GooseSwift/GooseBLEClient+PeripheralDelegate.swift
    - GooseSwift/GooseBLEClient+CentralDelegate.swift

key-decisions:
  - "Indexes added via single execute_batch block (not separate migration arms) — matches existing pattern"
  - "GooseRustBridge lazy with @ObservationIgnored — bridge is stateless, never observed by SwiftUI"
  - "BLE auth retry shows error after 2.5s delay rather than replaying write bytes (bytes unavailable via CBPeripheralDelegate)"
  - "authRetryPending reset on disconnect and successful write to prevent stale state"

patterns-established:
  - "Schema migrations: add DDL to execute_batch block, increment CURRENT_SCHEMA_VERSION, add version INSERT, bump PRAGMA user_version"
  - "BLE auth retry: flag-based one-shot guard prevents infinite loops in CBPeripheralDelegate"

requirements-completed: []

duration: 45min
completed: 2026-06-14
---

# Phase 78 Plan 01: Performance & BLE Reliability Summary

**SQLite covering indexes on v20 tables, lazy GooseRustBridge init, and BLE insufficientAuthentication retry with user-visible error after 2.5s.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-06-14T00:00:00Z
- **Completed:** 2026-06-14T00:30:00Z
- **Tasks:** 3/3
- **Files modified:** 5

## Accomplishments

### PERF-01: SQLite Indexes on Schema v20 Tables

Bumped `CURRENT_SCHEMA_VERSION` from 20 to 21 in `Rust/core/src/store.rs`. Added four covering indexes in the `migrate()` function's `execute_batch` block:

- `idx_metric_series_lookup` on `metric_series(source, metric_name, date)` — covering index matching the UNIQUE constraint; accelerates `SELECT` by source+metric+date
- `idx_journal_date` on `journal(date)` — accelerates date-range queries on journal entries
- `idx_workout_date` on `workout(date)` — accelerates workout history queries
- `idx_apple_daily_date` on `apple_daily(date)` — accelerates Apple Health daily aggregates

Updated inline test assertions: `test_exercise_sessions_schema_version`, `sync_schema_tests::test_schema_version_is_21`, `v20_migration_tests::test_schema_version_is_21`. All 32 store unit tests pass.

### PERF-02: Lazy GooseRustBridge Init

Changed `let rust = GooseRustBridge()` to `@ObservationIgnored lazy var rust = GooseRustBridge()` in `GooseAppModel.swift`. The FFI bridge is now constructed on first access rather than at `GooseAppModel` init time, allowing the first SwiftUI frame to render before the Rust library is loaded. `@ObservationIgnored` is required because `@Observable` macro cannot synthesise observation tracking for `lazy var` properties; this is correct since `rust` is stateless and never directly observed by SwiftUI.

`GooseBLEClient` init happens in an explicit `init()` body (not inline), so it was not a lazy-var candidate per the plan's guidance.

### BLE-REL-01: BLE Auth Retry

Added `var authRetryPending = false` to `GooseBLEClient`. In `didWriteValueFor(_:didWriteValueFor:error:)`:

- When `CBATTError.insufficientAuthentication` is detected and `authRetryPending == false`: sets flag, logs a warning, schedules a 2.5s deferred closure via `DispatchQueue.main.asyncAfter`. After the delay the flag resets and `updateConnectionState("Authentication failed — please reconnect WHOOP")` is called with an actionable error log. Early returns — does not propagate to `failHistoricalSync` etc.
- When `authRetryPending == true` (second failure): resets flag, shows actionable error immediately, returns. No further retry.
- On successful write: clears `authRetryPending`.
- On disconnect (`didDisconnectPeripheral`): clears `authRetryPending` to prevent stale state across reconnects.

Note: the original write bytes are not available via `CBPeripheralDelegate`, so the retry does not replay the exact write. The error notification is the actionable outcome — the user is informed to reconnect WHOOP, which triggers re-pairing and re-authentication.

## Commits

| Hash | Task | Description |
|------|------|-------------|
| 98455c3 | PERF-01 | perf(78): add covering indexes on schema v20 tables |
| dc8c752 | PERF-02 | perf(78): defer GooseBLEClient/bridge init for faster first frame |
| e3f96bf | BLE-REL-01 | feat(78): BLE auth retry on insufficientAuthentication with 2.5s delay |

## Deviations from Plan

None — plan executed exactly as written. The plan explicitly noted that replaying write bytes is not required if unavailable; the error notification path was implemented as specified.

## Self-Check: PASSED

- `Rust/core/src/store.rs` contains `CURRENT_SCHEMA_VERSION = 21`: confirmed
- 4 index statements present: confirmed
- Migration chain unbroken (versions 1-21 inserted): confirmed
- 32 store unit tests pass: confirmed
- `GooseAppModel.swift` has `@ObservationIgnored lazy var rust`: confirmed
- `GooseBLEClient+PeripheralDelegate.swift` handles `insufficientAuthentication`: confirmed
- Build succeeded (iOS Simulator, Debug): confirmed
- No infinite retry loop: confirmed (authRetryPending flag + single asyncAfter)

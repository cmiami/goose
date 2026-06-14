---
focus: concerns
last_mapped: 2026-06-13
---

# Codebase Concerns

**Analysis Date:** 2026-06-13

---

## Concurrency Risks

### `GooseRustBridge` declared `@unchecked Sendable` without internal locking

- **Risk:** `GooseRustBridge` (`GooseSwift/GooseRustBridge.swift:22`) is `final class GooseRustBridge: @unchecked Sendable`. The Rust FFI call `goose_bridge_handle_json` is synchronous and blocking. A comment in `GooseAppModel+SleepSync.swift:60` explicitly warns: *"GooseRustBridge is @unchecked Sendable with unguarded mutable state"*. In practice each consumer (`GooseAppModel`, `HealthDataStore`, `OvernightSQLiteMirrorQueue`, `CaptureFrameWriteQueue`) holds its own instance, so no shared-instance race exists today — but the compiler cannot enforce this.
- **Files:** `GooseSwift/GooseRustBridge.swift`, `GooseSwift/GooseAppModel+SleepSync.swift`
- **Impact:** A future developer sharing a bridge instance across queues will produce a silent data race with no compiler warning.
- **Fix approach:** Document the one-instance-per-component invariant at the class declaration, or add an `NSLock` guard around the mutable timing state inside `GooseRustBridge`. Enforce in Phase 78.

### `GooseBLEClient` and series stores declare `@unchecked Sendable` — no Swift 6 enforcement

- **Risk:** `GooseBLEClient` (`GooseSwift/GooseBLEClient.swift:7`) is `@Observable final class GooseBLEClient: NSObject, @unchecked Sendable`. `HeartRateSeriesStore` and `HRVSeriesStore` (`GooseSwift/HeartRateSeriesStores.swift:60,371`) are also `@unchecked Sendable`. BLE state properties (e.g., `connectionState`, `historicalSyncStatus`) are set from background queues via `DispatchQueue.main.async` closures, not from `@MainActor` directly. `NSLock`/`nonisolated(unsafe)` guards cover specific counters and reassembly buffers but not all `@Observable`-observed properties.
- **Files:** `GooseSwift/GooseBLEClient.swift`, `GooseSwift/HeartRateSeriesStores.swift`
- **Impact:** Properties mutated from a non-main queue without explicit dispatch introduce data races with SwiftUI observation.
- **Fix approach:** Enable `SWIFT_STRICT_CONCURRENCY = complete` in Xcode build settings (currently all four configurations use `SWIFT_VERSION = 5.0` — see `project.pbxproj` lines 1303, 1346, 1375, 1403, 1429, 1456) to surface violations. Target Phase 78.

### `nonisolated(unsafe)` on mutable shared state — correctness depends on developer discipline

- **Risk:** Three `nonisolated(unsafe)` mutable vars in `GooseAppModel` (`captureFrameRowBuildQueueDepth`, `captureFrameRowBuildQueueHighWatermark`, `frameReassemblyBuffers` — `GooseSwift/GooseAppModel.swift:156-172`). `heartRateSeriesUpdateObserver` in `HealthDataStore` (`GooseSwift/HealthDataStore.swift:80`). `pendingAPNSToken` static in `GooseAppDelegate` (`GooseSwift/GooseAppDelegate.swift:9`). Each requires external queue discipline. `frameReassemblyBuffers` is guarded by `frameReassemblyLock`; the others rely on informal discipline only.
- **Files:** `GooseSwift/GooseAppModel.swift`, `GooseSwift/HealthDataStore.swift`, `GooseSwift/GooseAppDelegate.swift`
- **Impact:** If a new caller forgets queue discipline, silent data race.
- **Fix approach:** Convert `pendingAPNSToken` to an actor-isolated property. Add inline `// guarded by X` comment on all three `GooseAppModel` vars.

### `ChatGPTCoachProvider` has no actor annotation or `Sendable` conformance

- **Risk:** `ChatGPTCoachProvider` (`GooseSwift/ChatGPTCoachProvider.swift:5`) is a plain `final class` with no actor annotation, no `@MainActor`, and no `Sendable` or `@unchecked Sendable` declaration. It is instantiated in `CoachProviderProtocol.swift:24` and used directly from `CoachSettingsSheet.swift:129,168`. URLSession callbacks can arrive on background threads and mutate provider state.
- **Files:** `GooseSwift/ChatGPTCoachProvider.swift`, `GooseSwift/CoachProviderProtocol.swift`, `GooseSwift/CoachSettingsSheet.swift`
- **Impact:** Potential data race on mutable coach state if provider callbacks arrive off the main thread.
- **Fix approach:** Annotate `@MainActor` if all access is from UI, or add actor wrapper.

### `GooseUploadService` and queue-protected types declared `@unchecked Sendable` without documented locks

- **Risk:** `GooseUploadService` (`GooseSwift/GooseUploadService.swift:24`), `PacketUIStateAggregator` (`GooseSwift/PacketUIStateAggregator.swift:24`), and `OvernightSQLiteMirrorQueue` (`GooseSwift/OvernightSQLiteMirrorQueue.swift:25`) all suppress Sendable checking. Mutable retry state (backoff counters, watermarks) in `GooseUploadService` is mutated from `Task.detached` closures without explicit lock documentation.
- **Files:** `GooseSwift/GooseUploadService.swift`, `GooseSwift/PacketUIStateAggregator.swift`, `GooseSwift/OvernightSQLiteMirrorQueue.swift`
- **Impact:** Queue discipline violations produce silent data races.

---

## Hardware-Gated Features (blocked — no ETA)

### CAPSENSE-01 — On-Wrist Detection (Phase 66)

- **Status:** Indefinitely blocked; requires a real WHOOP 5.x device with Cap Sense hardware. Deferred since v9.0.
- **Tracking:** `STATE.md` Deferred Items, `hardware_gate` category.
- **Impact:** Feature cannot be tested or shipped without hardware. No simulator path.

### HAP-04 — Wake-Window Engine (Phase 73)

- **Status:** RE-gated. `GooseWakeWindowManager.swift` (`GooseSwift/GooseWakeWindowManager.swift`) exists as an empty stub registered at all 4 pbxproj locations (PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase). Implementation is blocked on: (1) BTSnoop capture of `STRAP_DRIVEN_ALARM_EXECUTED` BLE packet and (2) Ghidra decompile of `SetAlarmInfoCommandPacketRev4`.
- **Files:** `GooseSwift/GooseWakeWindowManager.swift`, `.planning/phases/73-smart-alarm-wake-window-engine/`
- **Impact:** Stub compiles cleanly (no build risk) but delivers nothing. Will confuse future contributors if RE gate is not tracked.
- **Fix approach:** Do not modify `GooseWakeWindowManager.swift` until both RE artifacts are delivered. Assigned to Phase 78/79 planning.

### ALG-HRV-04, ALG-SLP-04, SLP-SYNC — Real-Device Algorithm Validation

- **Status:** Deferred since v5.0. Require ≥5 real WHOOP sessions to validate RMSSD parity (Phase 22) and 4-class sleep staging (Phase 26).
- **Impact:** Algorithm correctness against real WHOOP data is unconfirmed. Simulator testing cannot substitute.

---

## Unverified BLE State Machine Behavior

### Historical sync end-to-end (Phase 68, `human_needed` — BLOCKED on live device)

- **Status:** `68-VERIFICATION.md` test 2 result: `BLOCKED — requires live BLE device`. The `GooseBLEHistoricalManager` state machine transitions (beginSync → syncing → synced/failed) are verified by static analysis only. Stale-callback guard (`historicalSyncRunID == runID`) is confirmed in code but runtime correctness through CoreBluetooth callbacks on a real WHOOP device is unconfirmed.
- **Files:** `GooseSwift/GooseBLEHistoricalManager.swift`, `GooseSwift/GooseBLEClient+HistoricalHandlers.swift`

### Wake alarm BLE state machine (Phase 73, UAT partial — 3/5 tests blocked)

- **Status:** `73-UAT.md` — arm alarm, cancel alarm, disconnect clears armed state — all three blocked pending physical WHOOP.
- **Files:** `GooseSwift/GooseAppModel.swift` (`alarmIsArmed`), `GooseSwift/GooseBLEClient+Commands.swift` (`writeAlarmCommand`)

### Breathe screen haptic pacing (Phase 70, `human_needed` — BLOCKED on live device)

- **Status:** `70-VERIFICATION.md` — actual WHOOP strap vibration (cmd `0x13` via `buzz(loops:)`) and back-navigation zombie-task prevention require OSLog streaming on a real device.
- **Files:** `GooseSwift/BreatheView.swift`, `GooseSwift/GooseBLEClient+Haptics.swift`

### BLE API misuse / state restore debug session

- **Status:** Deferred since v8.0, `awaiting_human_verify` (`STATE.md` line 93). An unresolved CoreBluetooth state-restore API misuse may affect reconnection behavior after backgrounding/foregrounding.

---

## Build System Fragility

### Rust static libraries are gitignored — CI must compile from source every run

- **Risk:** `Rust/iphoneos/libgoose_core.a` and `Rust/iphonesimulator/libgoose_core.a` are produced by `Scripts/build_ios_rust.sh` as an Xcode build phase and excluded from the repository. Every `swift-build.yml` CI run must install a Rust toolchain and cross-compile the full crate, adding ~3–5 min and a dependency on Cargo crate availability.
- **Files:** `.github/workflows/swift-build.yml`, `Scripts/build_ios_rust.sh`
- **Impact:** If a dependency is yanked from crates.io, the Swift CI build breaks with a Rust error rather than a Swift error. Existing `cargo cache` step mitigates rebuild time but not yanked deps.
- **Fix approach:** Add `cargo audit` to `rust-core.yml` to surface yanked/vulnerable crates before they affect the Swift build.

### `project.pbxproj` 4-location file registration is fully manual — no enforcement in CI

- **Risk:** Every new Swift source file requires registration at exactly 4 locations in `GooseSwift.xcodeproj/project.pbxproj` (PBXBuildFile, PBXFileReference, PBXGroup children, PBXSourcesBuildPhase). Missing any location causes a silent linker error. This is enforced only by post-edit `grep -c 'File.swift' project.pbxproj` convention. Past phases have needed review-fix passes for pbxproj issues (`68-REVIEW-FIX.md`, `72-REVIEW-FIX.md`).
- **Files:** `GooseSwift.xcodeproj/project.pbxproj`
- **Fix approach:** Add a CI lint step that greps each `.swift` file under `GooseSwift/` and asserts it appears exactly 4 times in `project.pbxproj`.

### `SWIFT_VERSION = 5.0` in all build configurations — strict concurrency not enforced at compile time

- **Risk:** All six build configuration blocks in `project.pbxproj` (lines 1303, 1346, 1375, 1403, 1429, 1456) set `SWIFT_VERSION = 5.0`. Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete` or `targeted`) is not configured. The 7+ `@unchecked Sendable` declarations in the codebase suppress all actor isolation checking.
- **Impact:** Upgrading to Swift 6 mode will surface a large number of latent concurrency warnings that are currently invisible.
- **Fix approach:** Enable `SWIFT_STRICT_CONCURRENCY = targeted` in Phase 78 and triage findings incrementally.

---

## CI Gaps

### Rust `cargo clippy` is advisory-only (`continue-on-error: true`)

- **Risk:** `rust-core.yml` clippy job (line 76) uses `continue-on-error: true` with a comment: *"the crate currently emits ~120 clippy warnings"*. New warnings from new Rust code are invisible at merge time.
- **Files:** `.github/workflows/rust-core.yml`
- **Fix approach:** Clear the ~120 warning backlog in Phase 78; flip `continue-on-error` to `false`.

### Rust integration tests in `Rust/core/tests/` do not run in CI

- **Risk:** `rust-core.yml` runs `cargo test --lib` only. The 40+ integration test files under `Rust/core/tests/` (which test bridge dispatch, SQLite schema, metric algorithms end-to-end) are never executed in CI.
- **Files:** `.github/workflows/rust-core.yml`, `Rust/core/tests/` (40+ files)
- **Impact:** Integration-level regressions in the Rust bridge, SQLite schema, or metric algorithms can merge undetected.
- **Fix approach:** Replace `cargo test --lib` with `cargo test` (default runs both lib and integration tests). Confirm tests have no network/device dependency first.

### Linux Rust test failures — deferred, status `investigating`

- **Status:** `STATE.md` Deferred Items: `rust-ci-linux-test-failures`, status `investigating` since v10.0 close. The `build-test` matrix runs on `ubuntu-latest` and `macos-15` with `fail-fast: false`, so Linux failures do not block the gate if macOS passes.
- **Files:** `.github/workflows/rust-core.yml`
- **Impact:** Linux-platform Rust test failures can merge silently if the macOS matrix leg passes.

### `paths:` filters removed from push triggers — all PRs run all CI jobs regardless of changed files

- **Risk:** Swift build and Rust CI run on every PR regardless of which files changed (no `paths:` filter on `pull_request:` triggers). This is intentional (branch ruleset requires consistent gate completion) but increases CI minute cost per PR.
- **Files:** `.github/workflows/swift-build.yml`, `.github/workflows/rust-core.yml`
- **Impact:** Low-risk concern; tradeoff accepted for branch ruleset compatibility.

---

## Tech Debt

### `GooseBLEDataValidator` is `final class` instead of specified `struct`

- **Issue:** Phase 68 CONTEXT.md and plan specified `struct GooseBLEDataValidator`; implementation uses `final class` (`GooseSwift/GooseBLEDataValidator.swift:9`) to allow `let dataValidator` ownership on `GooseBLEClient` while keeping a mutable `onInvalidFrame` closure. Accepted via override in `68-VERIFICATION.md`.
- **Files:** `GooseSwift/GooseBLEDataValidator.swift`, `GooseSwift/GooseBLEClient.swift:101`
- **Fix approach:** Change `let dataValidator` to `var dataValidator` on `GooseBLEClient` and convert to `struct` in a future refactor pass. No functional urgency.

### Quick tasks with missing tracking artifacts

- **Status:** `STATE.md` Deferred Items lists `historical-sync-direct-write` and `fix-imu-step-count` as `quick_task / missing`. `fix-imu-step-count` was partially addressed as PR #145 (OOM crash fix in Raw Export), but the original quick task artifact is absent, making it hard to verify completeness.
- **Files:** `.planning/quick/20260611-historical-sync-direct-write/`, `.planning/quick/260613-2eo-fix-imu-step-count-to-read-from-decoded-/`

### `supportsV5*` naming misnomer in `GooseBLEClient+Commands.swift`

- **Issue:** After Gen4 support was added, `supportsV5HistoricalSync`, `supportsV5AlarmCommands`, `supportsV5ClockCommands` misleadingly imply Gen5-only. Noted in previous audits; not yet renamed.
- **Files:** `GooseSwift/GooseBLEClient+Commands.swift` lines 147–165

### Large Rust files — incremental compilation and navigation impact

- **Files:** `Rust/core/src/bridge.rs` (8804 lines, 80+ dispatched methods in a single `match`), `Rust/core/src/export.rs` (8226 lines), `Rust/core/src/store.rs` (7594 lines), `Rust/core/src/metric_features.rs` (6436 lines), `Rust/core/src/sleep_validation.rs` (6334 lines)
- **Impact:** Slow incremental compilation on large files; navigation difficulty.
- **Fix approach:** Split `bridge.rs` into per-domain submodules (e.g., `bridge/upload.rs`, `bridge/metrics.rs`). Planned for Phase 78.

### Force unwraps in HealthKit importers

- **Files:** `GooseSwift/HealthKitFullImporter.swift:146`, `GooseSwift/HealthKitSleepImporter.swift:178`
- **Issue:** `current.last!` inside a loop guarded by `current = [asleep[0]]` initialization. Low risk given loop structure but should use safe unwrap.

### Placeholder Swift packages with no source

- **Files:** `Packages/WhoopProtocol/Package.swift`, `Packages/WhoopStore/Package.swift`
- **Issue:** Contain only `.swiftpm` metadata; no source files. May confuse future contributors.

---

## Deferred Items from STATE.md

| Category | Item | Status | Deferred Since |
|---|---|---|---|
| debug_session | ble-api-misuse-state-restore | awaiting_human_verify | v8.0 close |
| debug_session | rust-ci-linux-test-failures | investigating | v10.0 close |
| hardware_gate | Phase 51 — VAL-HRV-01, VAL-SLP-01, SLP-SYNC real-device | blocked | v7.0 close |
| hardware_gate | Phase 66 — CAPSENSE-01 on-wrist detection | blocked | v9.0 close |
| re_gate | Phase 73 — HAP-04 wake-window engine | re_required | v10.0 roadmap |
| verification_gap | Phase 22 — ALG-HRV-04 RMSSD parity (≥5 real sessions) | human_needed | v5.0 close |
| verification_gap | Phase 26 — ALG-SLP-04 4-class staging validation | human_needed | v5.0 close |
| uat_gap | Phase 73 — 73-UAT.md | partial (2/5) | v10.0 close |
| verification_gap | Phase 68 — 68-VERIFICATION.md (historical sync BLE) | human_needed | v10.0 close |
| verification_gap | Phase 70 — 70-VERIFICATION.md (haptic/breathe) | human_needed | v10.0 close |
| quick_task | historical-sync-direct-write | missing artifact | v10.0 close |
| quick_task | fix-imu-step-count | missing artifact | v10.0 close |

---

## Test Coverage Gaps

| Untested Area | Files | Risk | Priority |
|---|---|---|---|
| `GooseBLEHistoricalManager` state machine | `GooseSwift/GooseBLEHistoricalManager.swift` | BLE sync regressions undetected | High |
| `GooseRustBridge` JSON serialisation round-trip | `GooseSwift/GooseRustBridge.swift` | Bridge protocol drift | High |
| Rust integration tests (40+ files in `tests/`) | `Rust/core/tests/` | Bridge/SQLite algorithm regressions | High (CI gap) |
| `GooseBLEDataValidator` invariant enforcement | `GooseSwift/GooseBLEDataValidator.swift` | Invalid frames reaching Rust | Medium |
| `HealthDataStore` bridge query methods | `GooseSwift/HealthDataStore.swift` | Metric query regressions | Medium |
| `GooseAppModel` lifecycle (background/foreground) | `GooseSwift/GooseAppModel+Lifecycle.swift` | State machine correctness | Medium |
| `BreatheView` session loop + task cancellation | `GooseSwift/BreatheView.swift` | Zombie buzz calls after navigation | Low |
| `OvernightSQLiteMirrorQueue` batching | `GooseSwift/OvernightSQLiteMirrorQueue.swift` | Overnight data loss scenarios | Medium |

Note: `GooseSwiftTests/` contains 16 test files covering coach provider registration, BLE type helpers, initial HR monitor state, historical range parsing, upload payload construction, workout attributes, temperature formatting, keychain, and trends fetch. All core BLE, Rust bridge, and pipeline code is untested.

---

## Observability Gaps

### No production crash reporting

- Severity: MEDIUM — no Sentry, Crashlytics, or equivalent. Errors surface only through OSLog (device-local) or UI status strings in `GooseAppModel` and `HealthDataStore`.

### Upload failures are silent after 3-retry exhaustion

- **File:** `GooseSwift/GooseUploadService.swift:122`
- Severity: MEDIUM — 3-retry exhaustion produces only a `logger.debug` message; no user-visible indicator; no persistent retry queue; data is silently discarded.

### Rust bridge errors surface only as free-form UI status strings

- **Files:** `GooseSwift/HealthDataStore.swift`, `GooseSwift/GooseAppModel.swift`
- Bridge errors set `catalogStatus`, `overnightGuardWarning`, etc. as human-readable strings. No machine-readable error log exists.

---

*Concerns audit: 2026-06-13*

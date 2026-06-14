---
phase: 72-screens-on-new-foundation-service-layer
fixed_at: 2026-06-13T12:30:00Z
review_path: .planning/phases/72-screens-on-new-foundation-service-layer/72-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 8
skipped: 3
status: partial
---

# Phase 72: Code Review Fix Report

**Fixed at:** 2026-06-13T12:30:00Z
**Source review:** .planning/phases/72-screens-on-new-foundation-service-layer/72-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (CR-01 through CR-04, WR-01 through WR-07)
- Fixed: 8
- Skipped: 3

## Fixed Issues

### CR-01: Data race on `frameReassemblyBuffers`

**Files modified:** none (pre-existing fix detected)
**Commit:** skipped — see Skipped section
**Applied fix:** `frameReassemblyLock = NSLock()` and `nonisolated(unsafe) var frameReassemblyBuffers` were already present in `GooseAppModel.swift` (lines 167–172). The phase 70 fix was already applied. No changes needed.

### CR-02: MockHealthStore.fetchTrendsSeries always returns []

**Files modified:** `GooseSwiftTests/MockHealthStore.swift`
**Commit:** `0b9c4c1`
**Applied fix:** Changed `_ = try await bridge.requestAsync(...)` to capture the result, then decode `result["rows"]` as `[[String: Any]]` and map each row to `(date: String, value: Double)` tuples — matching the real `HealthDataStore.fetchTrendsSeries` logic. The mock now returns actual stubbed data instead of hardcoded `[]`.

### CR-03: WorkoutEntryViewModel error message discards real error detail

**Files modified:** `GooseSwift/ManualWorkoutEntryViews.swift`
**Commit:** `9caec7f`
**Applied fix:** Added `print("[WorkoutEntryViewModel] submitWorkout failed: \(error)")` before the user-facing `errorMessage` assignment in the catch block, preserving full error detail in logs while keeping the brief user message.

### CR-04: HealthRouteDetailView creates isolated HealthDataStore per navigation

**Files modified:** `GooseSwift/HealthDashboardViews.swift`
**Commit:** `4ddeb8f`
**Applied fix:** Added a production `init(route:store:)` that accepts an external `HealthDataStore`. The original `init(route:previewState:)` that creates a fresh isolated store is now gated under `#if DEBUG` with a comment warning against use in production code paths. `HealthPreviewRouteHost` in `HealthPreviews.swift` continues to use the preview-only init without changes.

### WR-02: HealthDataStoring protocol missing default for `days:` parameter

**Files modified:** `GooseSwift/HealthDataStoring.swift`
**Commit:** `83ecb61`
**Applied fix:** Added a protocol extension with a convenience overload `fetchTrendsSeries(metricName:)` that calls through to `fetchTrendsSeries(metricName:days:7)`, matching the concrete store's default. Callers using only the protocol type no longer need to repeat `days: 7`.

### WR-03: TrendsDashboardView.loadTrends() silently swallows bridge errors

**Files modified:** `GooseSwift/TrendsDashboardViews.swift`
**Commit:** `8e2327a`
**Applied fix:** Added `@State private var loadError: String? = nil`. Rewrote `loadTrends()` to use a `do/catch` block — errors are captured in `loadError` instead of discarded via `try?`. The view body now shows a "Could not load trends: …" message when `loadError` is set.

### WR-05: ManualWorkoutEntrySheet.init takes concrete HealthDataStore

**Files modified:** `GooseSwift/ManualWorkoutEntryViews.swift`, `GooseSwift/HealthView.swift`
**Commit:** `0fa447b`
**Applied fix:** Changed `ManualWorkoutEntrySheet.init(store: HealthDataStore)` to `init(bridge: any GooseRustBridging, databasePath: String)`. Updated the call site in `HealthView` to `ManualWorkoutEntrySheet(bridge: store.bridge, databasePath: store.databasePath)`. The sheet no longer holds a hard dependency on the concrete `HealthDataStore` type.

### WR-06: Duplicate test in TrendsFetchTests

**Files modified:** `GooseSwiftTests/TrendsFetchTests.swift`
**Commit:** `d0b0117`
**Applied fix:** Removed `test_workout_entry_calls_workout_upsert` from `TrendsFetchTests`. The identical test (with more thorough arg assertions) already exists in `WorkoutEntryTests`.

## Skipped Issues

### CR-01 / WR-07: Data race on `frameReassemblyBuffers` (and `notificationIngestResult` caller)

**File:** `GooseSwift/GooseAppModel+NotificationPipeline.swift`
**Reason:** Already fixed in a prior phase. `GooseAppModel.swift` lines 167–172 already declare `let frameReassemblyLock = NSLock()` and `@ObservationIgnored nonisolated(unsafe) var frameReassemblyBuffers: [String: Data] = [:]`. The `gooseFrames()` function at line 802 already calls `frameReassemblyLock.lock()` / `defer { frameReassemblyLock.unlock() }`. No code changes needed.

### WR-01: GooseBLEManaging protocol surface too narrow to be useful

**File:** `GooseSwift/GooseBLEManaging.swift`
**Reason:** Skipped — extending the protocol to cover `liveHeartRateBPM`, `liveHeartRateSource`, `record(...)`, `activeDeviceName`, etc. requires also changing `GooseAppModel` to type its `ble` property as `GooseBLEManaging` instead of the concrete `GooseBLEClient`. That is a multi-file architectural change (GooseAppModel.swift + all GooseAppModel+*.swift extensions + GooseBLEClient+*.swift) with significant refactoring risk beyond the scope of an atomic review fix. Left for a dedicated phase. The protocol comment "extend as test coverage grows" documents the intent.

### WR-04: DailyJournalStore — synchronous UserDefaults JSON encode/decode on main thread

**File:** `GooseSwift/CoachView.swift:782-800`
**Reason:** Skipped — moving `load()` and `save(_:)` off the main thread requires introducing async/await or a background `DispatchQueue` with a main-actor dispatch back, restructuring the `@State` update flow in `View.onAppear` / `sheet.onDismiss`, and adding a retention cap (365 entries). This is a correctness-improvement refactor, not a critical data-race, and carries meaningful UI state management risk. Better addressed as a dedicated task with UAT.

---

_Fixed: 2026-06-13T12:30:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

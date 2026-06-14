---
phase: 82
status: passed
build: passed
---
# Phase 82: HealthKit Import Persistence — Verification

## Build Status
BUILD SUCCEEDED — Xcode simulator build SUCCEEDED (pre-existing ChatGPT warning only)

## BUG-HK-01: HealthKit Import Persistence ✅

**Changes in `HealthDataStore+Sleep.swift`:**
- `importAllFromHealthKit()` now calls `persistHealthKitToSQLite(result)` after
  setting in-memory properties
- `persistHealthKitToSQLite()`: upserts scalars (resting HR, HRV SDNN, resp rate,
  SpO2, skin temp, steps, active kcal) for today's date, plus 90-day history for
  resting HR and HRV, via `metric_series.upsert` Rust bridge calls
- `loadPersistedHealthKitData()`: queries `metric_series.query_range` for all
  8 metric names on init; populates in-memory properties only when nil/empty
  (avoids overwriting fresher live data)

**Change in `HealthDataStore.swift`:**
- `init()` adds `Task { await self.loadPersistedHealthKitData() }` alongside
  existing `refreshHeartRateTimeline` task

**Evidence:**
- After import, scalars written to `metric_series` table with `source=apple.health`
- On app relaunch, `loadPersistedHealthKitData` restores values from SQLite
- `hkImportStatus` set to "Restored from local DB" when data found on launch
- INSERT OR IGNORE semantics ensure historical data is idempotent (no re-import churn)
- Closes #150

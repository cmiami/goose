---
phase: 75
status: human_needed
build: passed
simulator_tested: 2026-06-13
---
# Verification: Phase 75 — Fork PR Integration BLE, Sync & Home

## Build Status
✅ Build SUCCEEDED — 0 errors, 1 warning (ChatGPT provider conformance — pre-existing from Phase 74)

## Must-Haves Verified

### PR-INT-02 — BLE firmware recovery ✅ (code) ⚠️ human_needed (device)
- `metadataReadRetriesRemaining` counter added to GooseBLEClient ✅
- Device Information characteristic retry logic implemented ✅
- End-to-end test with real firmware update: hardware gate — requires physical WHOOP device

### PR-INT-06 — Home warm-up progress + honest vitals ✅
- `BaselineProgressModel` + `HomeBaselineProgressViews.swift` added ✅
- `HomeHealthMonitorViews` no longer shows success checkmark on no-data vitals ✅
- Coach overview has friendly headlines ✅
- 106-line BaselineProgressTests.swift with model coverage ✅

### PR-INT-07 — Historical sync live donut ✅
- `historicalSyncPagesTotal`, `historicalSyncBurstsCompleted`, `historicalSyncFraction` added to GooseBLEClient ✅
- Protocol-driven completion (not timer) ✅
- `usesImperialUnits` in WorkoutLiveActivityAttributes.ContentState ✅
- HistoricalRangeParsingTests + WorkoutLiveActivityAttributesTests added ✅

## Human Verification Required

### HV-01: BLE firmware recovery (PR-INT-02) — hardware gate
- Requires physical WHOOP device + firmware update
- Verify: after firmware update, app re-reads device-info; no sync failure dialog
- **Status:** Deferred — hardware gate

### HV-02: Home warm-up progress (PR-INT-06) ✅ VERIFIED in simulator
- "Building your baseline" card visible on Home screen with "0 of 9 ready" ✅
- Individual metric progress (HRV 0/1, Sleep 1/5, Strain 0/5, Recovery 0/9, etc.) ✅
- Coach section shows friendly copy: "0 of 9 scores ready. Keep wearing your strap and the rest will fill in." ✅
- No unexplained empty dials — warm-up state is explicit and informative ✅
- **Status:** PASSED (simulator 2026-06-13)

### HV-03: Historical sync donut (PR-INT-07)
- Requires BLE connection + historical sync trigger
- Verify: live donut ring visible in HomeDashboardView during sync
- **Status:** Deferred — requires real device / simulated sync event

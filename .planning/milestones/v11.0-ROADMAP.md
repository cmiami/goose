# Roadmap: Goose

## Milestones

- ✅ **v1.0 Remote Server + Upstream PRs** — Phases 1-5 (shipped 2026-06-03)
- ✅ **v2.0 Multi-Device & Platform Foundations** — Phases 6-8+8.1 (shipped 2026-06-04)
- ✅ **v3.0 Wearable UX, CI Hardening & RTC Sync** — Phases 9-15 (shipped 2026-06-05)
- ✅ **v4.0 Security, Performance & Coach Expansion** — Phases 16-19 (shipped 2026-06-06)
- ✅ **v5.0 Metrics Accuracy, IMU & Upstream Fixes** — Phases 20-35 (shipped 2026-06-08)
- ✅ **v6.0 UI Wiring, Algorithm Alignment & Parity Validation** — Phases 36-45 (shipped 2026-06-09)
- ✅ **v7.0 Sync Correctness, Async & Sleep Sync** — Phases 46-50 (shipped 2026-06-10)
- ✅ **v8.0 Quality, Completeness & Backlog Clearance** — Phases 51-59+60 (shipped 2026-06-11)
- ✅ **v9.0 BLE Reliability & Protocol Parity** — Phases 61-65+66 (shipped 2026-06-11)
- ✅ **v10.0 Protocol Parity, Haptics & Feature Completeness** — Phases 67-73 (shipped 2026-06-13)
- **v11.0 PR Integration, Code Health & App Polish** — Phases 74-82 (active)

## Phases

<details>
<summary>✅ v1.0 Remote Server + Upstream PRs (Phases 1-5) — SHIPPED 2026-06-03</summary>

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v2.0 Multi-Device & Platform Foundations (Phases 6-8+8.1) — SHIPPED 2026-06-04</summary>

Full details: `.planning/milestones/v2.0-ROADMAP.md`

Known deferred: WEAR-02 scan UI (v3.0), CR-02 per-row filter (v3.0), hardware BLE tests (no device)

</details>

<details>
<summary>✅ v3.0 Wearable UX, CI Hardening & RTC Sync (Phases 9-15) — SHIPPED 2026-06-05</summary>

Full details: `.planning/milestones/v3.0-ROADMAP.md`

</details>

<details>
<summary>✅ v4.0 Security, Performance & Coach Expansion (Phases 16-19) — SHIPPED 2026-06-06</summary>

Full details: `.planning/milestones/v4.0-ROADMAP.md`

Known deferred: COACH-06 device migration test, 4 streaming provider runtime tests, 3 localisation device tests

</details>

<details>
<summary>✅ v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-35) — SHIPPED 2026-06-08</summary>

Full details: `.planning/milestones/v5.0-ROADMAP.md`

Key: HRV accuracy, Sleep staging (Cole-Kripke + 4-class), Strain/Calories (Ghidra-confirmed coefficients), V24 biometric decode, Exercise detection, Upload sync infrastructure, Readiness engine, Protocol corrections, Codebase audit (9 HIGH fixed), Cross-project review.

Known deferred: ALG-HRV-04, ALG-SLP-04, VAL-01 (human gates — require real WHOOP device data)

</details>

<details>
<summary>✅ v6.0 UI Wiring, Algorithm Alignment & Parity Validation (Phases 36-45) — SHIPPED 2026-06-09</summary>

Full details: `.planning/milestones/v6.0-ROADMAP.md`

Known deferred: ALG-HRV-04 real overnight cross-validation (v7.0), ALG-SLP-04 real overnight concordance (v7.0)

</details>

<details>
<summary>✅ v7.0 Sync Correctness, Async & Sleep Sync (Phases 46-50) — SHIPPED 2026-06-10</summary>

Full details: `.planning/milestones/v7.0-ROADMAP.md`

Key: Upload round-trip (POST /v1/ingest-frames + GET export), device_uuid end-to-end, upload sync race fix, HealthDataStore full async migration (60+ calls), morning band sleep sync (gravity K18/K24 → Cole-Kripke → external_sleep_sessions).

Known deferred: Phase 51 (VAL-HRV-01, VAL-SLP-01, SLP-SYNC real-device validation) — hardware gate, requires WHOOP + ≥5 overnight sessions

</details>

<details>
<summary>✅ v8.0 Quality, Completeness & Backlog Clearance (Phases 51-59+60) — SHIPPED 2026-06-11</summary>

Full details: `.planning/milestones/v8.0-ROADMAP.md`

- [x] Phase 51: Bug Audit — 3 HIGH + 6 MEDIUM bugs fixed in v6.0–v7.0 code
- [x] Phase 52: Quick Tasks & Surface Cleanup — BT Settings, CodeQL CI, HealthKit importer, #if DEBUG gating
- [x] Phase 53: Home Dashboard Completion — Device Status Card, Tools Grid, Evidence Footer
- [x] Phase 54: Coach Score Summaries & Journal — metric highlight grid, daily journal with persistence
- [x] Phase 55: Coach Routes — Sleep Coach, Recovery Insights, Strain Guidance, Stress Guidance views
- [x] Phase 56: Biometrics & Activity — fabricated 55.0 bpm eliminated; exercise-masked stress
- [x] Phase 57: Persistence & Calibration — energy_daily_rollup to SQLite; real train/holdout calibration
- [x] Phase 58: More Tab, Previews & Health Algorithms — MorePrivacyView, #Preview macros, algorithmPreferences
- [x] Phase 59: Band Sleep Import — bandSleepImportStatus replaces static "not available" UI
- [x] Phase 60: Band-First Sync — overnight poll loop removed; foreground-trigger + BGAppRefreshTask

Known deferred: ble-api-misuse-state-restore debug session (awaiting_human_verify); hardware gates (VAL-HRV-01, VAL-SLP-01, SLP-SYNC)

</details>

<details>
<summary>✅ v9.0 BLE Reliability & Protocol Parity (Phases 61-65+66) — SHIPPED 2026-06-11</summary>

Full details: `.planning/milestones/v9.0-ROADMAP.md`

- [x] Phase 61: BLE Bonding State Machine — 5-state GooseBLEBondingManager (WHPBLEBondingManager parity)
- [x] Phase 62: Upload Watermark per Sensor — per-type watermarks (rawFrames + decodedStreams)
- [x] Phase 63: Network Monitor & Upload Gating — NWPathMonitor gate + exponential backoff
- [x] Phase 64: HR Data Sanitizer — 25-220 BPM filter at BLE parsing chokepoint
- [x] Phase 65: Generic BLE State Machine — StateMachine<State: Hashable, Event> struct
- [ ] Phase 66: Cap Sense / On-Wrist Detection — DEFERRED (GATT UUID hardware-gated; 11500X series candidates documented)

Known deferred: CAPSENSE-01 hardware gate (requires real WHOOP 5.x device for UUID identification)

</details>

<details>
<summary>✅ v10.0 Protocol Parity, Haptics & Feature Completeness (Phases 67-73) — SHIPPED 2026-06-13</summary>

Full details: `.planning/milestones/v10.0-ROADMAP.md`

- [x] Phase 67: WHOOP 5.0 Protocol Fixes — R22 realtime + v18 per-second historical (pure Rust) (completed 2026-06-12)
- [x] Phase 68: BLE Manager Refactor + Data Validator — GooseBLEHistoricalManager + GooseBLEDataValidator (completed 2026-06-12)
- [x] Phase 69: Data Foundation — 4 SQLite tables (schema v20) + strain accumulator (completed 2026-06-12)
- [x] Phase 70: Haptic Primitive + Breathe Screen — buzz(loops:) cmd 0x13 + BreatheView (completed 2026-06-12)
- [x] Phase 71: Coach VOW + NoopApp + Notifications + HR Decimation — VOW nudges, Interval Timer, Metric Explorer, NotificationScheduler (completed 2026-06-12)
- [x] Phase 72: Screens on New Foundation + Service Layer — Stress/ANS, Trends dashboard, Manual Workout Entry, protocol mocks (completed 2026-06-12)
- [x] Phase 73: Smart Alarm + Wake-Window Engine — HAP-03 alarm UI + HAP-04 RE-gated stub (completed 2026-06-12)

Known deferred: BLE5-01/02 (hardware-gated, real WHOOP 5.0 device), HAP-04 (RE-gated, BTSnoop capture needed), HAP-02/DATA-02 (promoted to v11.0 as DEF-01/DEF-02)

</details>

### v11.0 PR Integration, Code Health & App Polish

- [x] **Phase 74: Fork PR Integration — UX, i18n & Auth** - Integrate tigercraft4 PRs #132–#136 (units, localisation, UUIDs, ChatGPT auth)
- [x] **Phase 75: Fork PR Integration — BLE, Sync & Home** - Integrate tigercraft4 PRs #131, #135, #137 (firmware recovery, warm-up state, sync progress)
- [x] **Phase 76: Upstream PR Integration** - Cherry-pick upstream b-nnett/goose PRs #4, #12, #29, #31 (main-thread safety, scroll jitter)
- [x] **Phase 77: Codebase Audit** - Full codebase map + deep review of phases 67-73 + fix all critical findings
- [x] **Phase 78: Performance & BLE Reliability** - SQLite query optimisation, startup lazy-init, BLE auth retry (SEED-001)
- [x] **Phase 79: Polish & Deferred Features** - Debug tab 3-tabs, Support rename, Breathe haptics, live strain accumulator
- [x] **Phase 80: Resting HR Floor Filter** - Fix anomalously low resting HR values from historical sync (issue #130)
- [x] **Phase 81: Battery Level Fix** - Fix battery always showing 100% for Gen4/Gen5 devices (issue #149, SEED-002)
- [x] **Phase 82: HealthKit Import Persistence** - Persist HealthKit imported data to SQLite (issue #150)

## Phase Details

### Phase 74: Fork PR Integration — UX, i18n & Auth
**Goal**: Users experience a correct, localised, and privacy-respecting app — units match device preference, advanced UUIDs are hidden from primary views, ChatGPT sign-in works, and all UI strings are properly localised with English as source language
**Depends on**: Phase 73
**Requirements**: PR-INT-01, PR-INT-03, PR-INT-04, PR-INT-05
**Success Criteria** (what must be TRUE):
  1. Technical identifiers (UUIDs, raw values, sequence IDs) are visible only in advanced/debug sections — not on main Health, Home, or Sleep views
  2. Temperature, distance, pace, and elevation display in the user's preferred unit system (imperial or metric) — switching the device setting updates the app without restart
  3. All UI strings that previously showed raw localisation keys now display translated text; English is the source language with zero visible key strings in the app
  4. The ChatGPT sign-in flow in Coach settings completes without an authentication error on a fresh sign-in attempt
**Plans**: TBD
**UI hint**: yes

### Phase 75: Fork PR Integration — BLE, Sync & Home
**Goal**: The app recovers gracefully from firmware-induced device-info invalidation, the Home screen shows honest warm-up and vitals state, and historical sync communicates its progress to the user via a real-time donut and completion protocol
**Depends on**: Phase 73
**Requirements**: PR-INT-02, PR-INT-06, PR-INT-07
**Success Criteria** (what must be TRUE):
  1. After a firmware update, the app re-reads device-info via BLE retry — no sync failure dialog or crash is shown to the user
  2. The Home screen warm-up progress indicator reflects the actual baseline accumulation state (honest progress, not a static placeholder); vitals display the real BLE-received state
  3. Historical sync shows a live donut progress indicator that updates as packets arrive; the completion event is driven by a protocol-level signal (not a timer)
**Plans**: TBD
**UI hint**: yes

### Phase 76: Upstream PR Integration
**Goal**: Performance improvements from b-nnett/goose upstream (main-thread offload, non-blocking FFI bridge calls, display-safety filtering) are integrated, eliminating frame drops and scroll jitter on the Home and Health tabs
**Depends on**: Phase 74
**Requirements**: PR-UP-01, PR-UP-02, PR-UP-03
**Success Criteria** (what must be TRUE):
  1. Heavy operations previously running on the main thread are dispatched to background queues — the Home and Health tabs render without frame drops during BLE activity
  2. All blocking FFI bridge calls execute on a background thread; the main thread is never blocked by a bridge call during normal app operation
  3. Scrolling through the Home and Health views is smooth with no visible jitter; the display-safety filter on notification ingest prevents mid-render data mutations
**Plans**: TBD

### Phase 77: Codebase Audit
**Goal**: The codebase is fully mapped across architecture, tech stack, quality, and cross-cutting concerns; phases 67-73 have been deeply reviewed; and all critical findings from that review are resolved and committed
**Depends on**: Phase 76
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03
**Success Criteria** (what must be TRUE):
  1. A codebase map covering architecture, tech stack, quality dimensions, and cross-cutting concerns is committed under `.planning/codebase/` and describes every major subsystem accurately
  2. A REVIEW.md file exists for each of phases 67-73 in `.planning/phases/`, documenting all critical and warning-level findings identified during deep code review
  3. Every finding rated CRITICAL in any phase REVIEW.md is resolved — the fix is committed and the REVIEW.md updated to mark it as resolved
  4. No new HIGH-severity issues are introduced by the fixes (verified by a second-pass review of the fix commits)
**Plans**: TBD

### Phase 78: Performance & BLE Reliability
**Goal**: SQLite queries on the v20 schema are indexed and validated, app startup renders the first frame before BLE initialisation completes, and the BLE auth retry (SEED-001) silently recovers from insufficientAuthentication without user intervention
**Depends on**: Phase 77
**Requirements**: PERF-01, PERF-02, BLE-REL-01
**Success Criteria** (what must be TRUE):
  1. The four schema-v20 tables (metricSeries, journal, workout, appleDaily) have covering indexes on their query-critical columns; EXPLAIN QUERY PLAN confirms index usage for the hot paths
  2. The app's first SwiftUI frame is rendered before GooseBLEClient and GooseRustBridge are fully initialised — heavy init is deferred via lazy or async patterns
  3. When `didWriteValueFor` receives `CBATTError.insufficientAuthentication`, the app automatically retries the write after 2.5 seconds; if the retry also fails, the user sees an actionable error message (not a silent failure)
  4. A second `insufficientAuthentication` on retry does not cause a crash or infinite retry loop
**Plans**: TBD

### Phase 79: Polish & Deferred Features
**Goal**: The Debug tab is restructured into three focused tabs eliminating the duplicate Connection row, the Support group is renamed and reorganised, the Breathe screen delivers full haptic pacing at each breath phase, and the live workout strain tile updates in real time from the signal pipeline
**Depends on**: Phase 78
**Requirements**: POL-01, POL-02, DEF-01, DEF-02
**Success Criteria** (what must be TRUE):
  1. More > Debug is organised into three tabs (Status / Capture / Research); the Connection row appears exactly once; the previously monolithic 612-line section is split into focused child views
  2. The "Support" entry in MoreView is renamed "Logs & Export" and placed in the Developer hub group; the Support group contains only "About"
  3. During a Breathe session, the WHOOP strap vibrates at the start of each inhale, hold, and exhale phase via `buzz(loops:1)` — the haptic is absent when no device is connected
  4. The strain tile on the active workout screen updates every few seconds with the current session strain computed live from HR samples delivered by `WhoopDataSignalPipeline`
**Plans**: TBD
**UI hint**: yes

### Phase 80: Resting HR Floor Filter
**Goal**: Fix anomalously low resting HR values (e.g. 32 bpm) produced by historical sync by adding a physiological plausibility floor to the resting HR estimation pipeline
**Depends on**: Phase 77
**Requirements**: BUG-HR-01
**Success Criteria** (what must be TRUE):
  1. Resting HR values below 30 bpm are rejected from the estimation pipeline in `Rust/core/src/metric_features.rs`; EXPLAIN with: the existing filter at line ~4494 allows 25 bpm through — tighten to 30 bpm minimum consistent with WHOOP's documented range
  2. Historical sync that previously produced 32 bpm now produces a plausible value (or no value if insufficient data)
**Plans**: TBD

### Phase 81: Battery Level Fix
**Goal**: Fix battery level always showing 100% for Gen4/Gen5 WHOOP devices by correctly parsing the battery byte from BLE notifications
**Depends on**: Phase 77
**Requirements**: BUG-BAT-01
**Success Criteria** (what must be TRUE):
  1. Battery percentage from BLE R22/realtime notifications is correctly decoded and displayed — not always 100%
  2. Both Gen4 and Gen5 device battery levels reflect the actual charge state
**Plans**: TBD

### Phase 82: HealthKit Import Persistence
**Goal**: Persist HealthKit imported data (resting HR, HRV, workouts, sleep) to SQLite so it survives app relaunch
**Depends on**: Phase 69
**Requirements**: BUG-HK-01
**Success Criteria** (what must be TRUE):
  1. After "Import from Apple Health" and app relaunch, HealthKit-sourced metrics are visible in Health views — no re-import required
  2. HealthKit data is written to the appropriate SQLite tables (apple_daily or metric_series) via the Rust bridge
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1–45 | v1.0–v6.0 | ✓ | Complete | 2026-06-03 to 2026-06-09 |
| 46–50 | v7.0 | 18/18 | Complete | 2026-06-10 |
| 51. Bug Audit | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 52. Quick Tasks & Surface Cleanup | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 53. Home Dashboard Completion | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 54. Coach Score Summaries & Journal | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 55. Coach Routes | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 56. Biometrics & Activity | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 57. Persistence & Calibration | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 58. More Tab, Previews & Health Algorithms | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 59. Band Sleep Import | v8.0 | 0/TBD | Complete | 2026-06-11 |
| 60. Band-First Sync | v8.0–v9.0 | 3/3 | Complete | 2026-06-11 |
| 61. BLE Bonding State Machine | v9.0 | 3/3 | Complete | 2026-06-11 |
| 62. Upload Watermark per Sensor | v9.0 | 2/2 | Complete | 2026-06-11 |
| 63. Network Monitor & Upload Gating | v9.0 | 2/2 | Complete | 2026-06-11 |
| 64. HR Data Sanitizer | v9.0 | 2/2 | Complete | 2026-06-11 |
| 65. Generic BLE State Machine | v9.0 | 1/1 | Complete | 2026-06-11 |
| 66. Cap Sense / On-Wrist Detection | v9.0 | 0/TBD | Not started | - |
| 67–73. v10.0 Phases | v10.0 | 17/17 | Complete | 2026-06-13 |
| 74. Fork PR Integration — UX, i18n & Auth | v11.0 | 5/5 | Complete | 2026-06-13 |
| 75. Fork PR Integration — BLE, Sync & Home | v11.0 | 3/3 | Complete | 2026-06-13 |
| 76. Upstream PR Integration | v11.0 | 1/1 | Complete | 2026-06-13 |
| 77. Codebase Audit | v11.0 | 3/3 | Complete | 2026-06-14 |
| 78. Performance & BLE Reliability | v11.0 | 3/3 | Complete | 2026-06-14 |
| 79. Polish & Deferred Features | v11.0 | 4/4 | Complete | 2026-06-14 |
| 80. Resting HR Floor Filter | v11.0 | 1/1 | Complete | 2026-06-14 |
| 81. Battery Level Fix | v11.0 | 1/1 | Complete | 2026-06-14 |
| 82. HealthKit Import Persistence | v11.0 | 1/1 | Complete | 2026-06-14 |

## Backlog

#### Archived phase 999.5 — GooseAppModel @Observable Migration (promoted to Phase 17 — v4.0)

Promoted to Phase 17: @Observable Migration.

---

#### Archived phase 999.4 — Recovery V2 Completion (promoted to Phase 13 — v3.0)

Promoted to Phase 13: Recovery V2 Dashboard.

---

#### Archived phase 999.3 — Apply upstream PR #15 (promoted to Phase 16 — v4.0)

Promoted to Phase 16: Deep Link Security.

---

#### Archived phase 999.2 — Multi-Language Support (promoted to Phase 14 — v3.0)

Promoted to Phase 14: pt-PT Localisation.

---

#### Archived phase 999.1 — Coach Multi-Provider & Custom Endpoint (promoted to Phase 18 — v4.0)

Promoted to Phase 18: Coach Multi-Provider.

#### Archived phase 60 — Band-First Sync

**Goal:** Align Goose's BLE sync architecture with the WHOOP app's band-first model, eliminating the need for continuous overnight BLE capture. The band stores data onboard; the app fetches it opportunistically on foreground and via silent push, exactly as WHOOP does.

**Depends on:** Phase 59
**Plans:** 2/2 plans complete
Plans:
**Wave 1**

- [x] 60-01-PLAN.md — Delete overnight guard subsystem core (3 files + GooseAppModel state + overnight struct types)
- [x] 60-02-PLAN.md — Add band-first sync: BandFirstSync.swift (foreground trigger + BGAppRefreshTask handler), BGTask registration, Info.plist keys

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 60-03-PLAN.md — Wire foreground trigger + clean secondary overnight references; build clean (wave 2)

#### Archived phase 61 — BLE Bonding State Machine

**Goal:** Replace the implicit OS bonding path with a formal bonding manager that tracks bond state through distinct steps, matching the `WHPBLEBondingManager` pattern from WHOOP (NotStarted → Started → Subscribed → Completed/Cancelled).

**Depends on:** Phase 60
**Requirements:** BLE-BOND-01
**Success Criteria** (what must be TRUE):

1. A `GooseBLEBondingManager` type exists with the 5 formal states; bonding progress is observable from `GooseAppModel`
2. On BT reset or iOS reboot, the app detects bond loss, re-enters the bonding flow, and reconnects without user action
3. Bonding state is persisted across app restarts so the app can resume from the last known state
4. The existing string-based `connectionState` is replaced with the formal state machine output for the bonding portion

**Plans:** 3/3 plans complete

- [x] 61-01-PLAN.md — Foundation: GooseBLEBondingState enum + GooseBLEBondingManager class + localized strings
- [x] 61-02-PLAN.md — Integration: wire bonding manager into GooseBLEClient/delegate/commands + GooseAppModel observability + bond-loss detection
- [x] 61-03-PLAN.md — Human-verify checkpoint: bond-loss recovery + persistence across restart

---

#### Archived phase 62 — Upload Watermark per Sensor

**Goal:** Track the last successfully uploaded timestamp per data type (raw frames, processed metrics) so restarts and partial uploads never re-send data already in TimescaleDB.

**Depends on:** Phase 61
**Requirements:** UPLOAD-WM-01
**Plans:** 2/2 plans complete

- [x] 62-01-PLAN.md — Create GooseUploadWatermark store (UserDefaults, per-type Date, clearAllWatermarks)
- [x] 62-02-PLAN.md — Wire watermark into upload pipeline (gated sinceTimestamp, atomic write on 2xx, reset path)

---

#### Archived phase 63 — Network Monitor & Upload Gating

**Goal:** Gate all outbound uploads on network reachability and implement exponential-backoff retry.

**Depends on:** Phase 62
**Requirements:** NET-MON-01
**Plans:** 2/2 plans complete

- [x] 63-01-PLAN.md — Create GooseNetworkMonitor (NWPathMonitor wrapper) + wire isNetworkReachable into GooseAppModel
- [x] 63-02-PLAN.md — Reachability + APNs-token upload gating, connectivity-return retry, 5xx exponential backoff

---

#### Archived phase 64 — HR Data Sanitizer

**Goal:** Add a Swift-side heart rate sanitization step between raw BLE notification bytes and HeartRateSeriesStore.

**Depends on:** Phase 60
**Requirements:** HR-SAN-01
**Plans:** 2/2 plans complete

- [x] 64-01-PLAN.md — GooseHRSanitizer (struct + static let 25/220 thresholds), wire at recordLiveHeartRate chokepoint
- [x] 64-02-PLAN.md — Human-verify checkpoint

---

#### Archived phase 65 — Generic BLE State Machine

**Goal:** Extract a lightweight reusable StateMachine<State, Event> type and migrate BLE connection/bonding state.

**Depends on:** Phase 61
**Requirements:** SM-01
**Plans:** 1/1 plans complete

- [x] 65-01-PLAN.md — Add generic StateMachine<State, Event> struct + migrate GooseBLEBondingManager onto it

---

#### Archived phase 66 — Cap Sense / On-Wrist Detection

**Goal:** Identify the GATT characteristic for WHOOP's capacitive skin-contact sensor via Ghidra and implement on-wrist detection.

**Depends on:** Phase 60
**Requirements:** CAPSENSE-01
**Note:** GATT characteristic UUID for cap sense is not yet identified. Phase deferred — hardware gate.
**Plans:** 0 plans

---

#### Archived phase 999.6 — body_hex Storage Optimization (absorbed into Phase 20 — v5.0)

Absorbed into Phase 20: Upstream Fixes & Storage (as PERF-05).

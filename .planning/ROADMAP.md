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
- ✅ **v11.0 PR Integration, Code Health & App Polish** — Phases 74-82 (shipped 2026-06-14)
- **v12.0 TBD** — (next milestone, not yet defined)

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

<details>
<summary>✅ v11.0 PR Integration, Code Health & App Polish (Phases 74-82) — SHIPPED 2026-06-14</summary>

Full details: `.planning/milestones/v11.0-ROADMAP.md`

- [x] Phase 74: Fork PR UX/i18n/Auth — units, localisation, UUID hiding, ChatGPT auth (#132–136)
- [x] Phase 75: Fork PR BLE/Sync/Home — firmware recovery, warm-up state, sync donut (#131,135,137)
- [x] Phase 76: Upstream PR Integration — main-thread offload, FFI async, scroll jitter (#4,12,29,31)
- [x] Phase 77: Codebase Audit — 7-doc map + deep review phases 67-73 + all CRITICAL fixed
- [x] Phase 78: Performance & BLE Reliability — schema v21 indexes, lazy init, auth retry (SEED-001)
- [x] Phase 79: Polish & Deferred — Debug 3-tabs, Logs & Export, Breathe haptics, live strain
- [x] Phase 80: Resting HR Floor Filter — 30 bpm minimum in metric_features.rs (#130)
- [x] Phase 81: Battery Level Fix — R22 battery_pct to Swift; Gen4 0xFF guard (#149)
- [x] Phase 82: HealthKit Import Persistence — persist to metric_series SQLite (#150)

Known deferred: Ph74/75 physical-device BLE tests (hardware gate); ble-api-misuse-state-restore (resolved/acknowledged); CAPSENSE-01, HAP-04, BLE5-01/02 hardware gates

</details>

### v12.0 TBD

Next milestone scope not yet defined.

## Progress

| Phase | Milestone | Status | Completed |
|-------|-----------|--------|-----------|
| 1–45 | v1.0–v6.0 | Complete | 2026-06-03 to 2026-06-09 |
| 46–50 | v7.0 | Complete | 2026-06-10 |
| 51–60 | v8.0 | Complete | 2026-06-11 |
| 61–65 | v9.0 | Complete | 2026-06-11 |
| 67–73 | v10.0 | Complete | 2026-06-13 |
| 74–82 | v11.0 | Complete | 2026-06-14 |

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

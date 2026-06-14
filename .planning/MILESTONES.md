# Milestones

## v10.0 Protocol Parity, Haptics & Feature Completeness (Shipped: 2026-06-13)

**Phases completed:** 7 phases, 17 plans, 16 tasks

**Key accomplishments:**

- buzz(loops:) BLE command extension on GooseBLEClient — writes Data([0x13, N]) directly to commandCharacteristic with UInt8 clamping and nil-guard, no frame sequence
- BreatheView with 4s/4s/4s box-breathing loop (circle 0.6→1.0→0.6 scaleEffect), buzz(loops:1) at each phase start, Wellness section in MoreView, full navigation wiring via MoreRoute.breathe
- CoachVOWNudge priority enum (4 cases) + CoachVOWCard dismissable view inserted between CoachJournalCard and CoachRoutesSection in CoachOverviewScreen, computing urgency from existing healthStore snapshots with nil-safe Double() parse
- IntervalTimerView
- NotificationScheduler actor encapsulating all UNUserNotificationCenter calls, wired to three event sites: sleep sync completion, passive workout detection, and WHOOP battery ≤ 20%
- 1. [Rule 1 - Bug] Typo in TrendsDashboardViews.swift stroke style
- GooseAppModel.swift
- GooseWakeWindowManager.swift RE-gated stub — empty compilable class with BTSnoop/Ghidra prerequisite doc comment, registered at 4 pbxproj locations, xcodebuild succeeds

---

## v8.0 Quality, Completeness & Backlog Clearance (Shipped: 2026-06-11)

**Phases completed:** 9 phases (51–59) + Phase 60 (Band-First Sync, v9.0 start)
**Plans:** 9 autonomous + 3 (Phase 60) = 12 plans
**Requirements shipped:** 22/22
**Known deferred items at close:** 1 (see STATE.md Deferred Items — ble-api-misuse-state-restore debug session)

**Key accomplishments:**

- Bug audit (Phase 51): 3 HIGH + 6 MEDIUM bugs fixed in v6.0–v7.0 code; data race on GooseRustBridge NSLock eliminated; main-thread FFI safety net added
- Quick tasks & surface cleanup (Phase 52): BT Settings button wired; CodeQL CI confirmed; HealthKit importer confirmed; previewMissingData gated in #if DEBUG
- Home dashboard (Phase 53): Device Status Card (live name/state/battery/HR/sync), Tools Grid (Coach/Activity/Journal/Calibration), Evidence Footer (Rust version, store path, provenance)
- Coach content (Phases 54–55): Score summaries grid; daily journal with UserDefaults persistence; 4 route views (Sleep, Recovery, Strain, Stress) populated from bridge data
- Biometrics & activity (Phase 56): Fabricated 55.0 bpm RHR baseline eliminated; non-activity stress computation now excludes exercise session windows
- Persistence & calibration (Phase 57): Energy daily rollup persisted to SQLite; calibration pipeline uses real train/holdout splits from bridge
- More tab, previews & health algorithms (Phase 58): MorePrivacyView with export/deletion; #Preview macros for Home and More; algorithmPreferences wired to bridge catalog
- Band sleep import (Phase 59): bandSleepImportStatus replaces static "not available" UI; pipeline was already complete since Phase 50
- Band-first sync (Phase 60): Overnight poll loop removed; foreground-trigger + BGAppRefreshTask added; aligned with WHOOP's WHPBLEHistoricalDataManager pattern

---

## v6.0 : UI Wiring, Algorithm Alignment & Parity Validation (Backfilled: 2026-06-11)

**Note:** Synthesized from archive snapshot by `/gsd-health --backfill`. Original completion date unknown.

---

## v7.0 Sync Correctness, Async & Sleep Sync (Shipped: 2026-06-10)

**Phases completed:** 5 phases (46-50), 18 plans
**Known deferred:** Phase 51 (VAL-HRV-01, VAL-SLP-01, SLP-SYNC real-device) — hardware gate

**Key accomplishments:**

- Upload round-trip completo: POST /v1/ingest-frames + GET /v1/export/frames com cursor pagination e autenticação Bearer (ROUTE-01, ROUTE-02)
- device_uuid end-to-end: coluna nullable adicionada a raw_evidence + decoded_frames, CoreBluetooth UUID mapeado em ligação BLE, propagado até servidor (DEVID-01, DEVID-02)
- Upload sync race fix: captureAllPendingRowIDs pré-HTTP, markStreamsSynced apenas após 2xx — elimina blind-marking (SYNCR-01)
- HealthDataStore async migration: 60+ bridge calls migrados de GCD para async/await; GCD queues removidos; zero sync calls na @MainActor scope (ASYNC-01, ASYNC-02)
- Morning band sleep sync: gravity K18/K24 V24History wired, syncBandSleepHistory() com SQLite-first check, "A aguardar sincronização" confirmado no simulador (SLP-SYNC-01/02/03 parcial)

---

## v5.0 Metrics Accuracy, IMU & Upstream Fixes (Phases 20-26) — PLANNED

**Phases:** 7 (Phases 20–26)
**Requirements:** 26 (SYNC-01–05, PERF-05, IMU-01–04, ALG-HRV-01–04, ALG-STR-01–03, ALG-CAL-01–02, ALG-SLP-01–02, ALG-REC-01–03, ALG-SLP-03–04)

**Goal:** Port validated algorithms from `my-whoop` into the Rust core — confirmed against WHOOP 5.37.0 IPA via Ghidra and peer-reviewed literature — so each metric (HRV, Recovery, Strain, Calories, Sleep) produces values aligned with WHOOP from the same raw data.

---

## v4.0 Security, Performance & Coach Expansion (Shipped: 2026-06-06)

**Phases completed:** 4 phases (16-19), 12 plans
**Known deferred items at close:** 6 (see STATE.md Deferred Items)

**Key accomplishments:**

- Deep link security: `allowsRemoteInvocation` guard blocks state-changing BLE commands from external `gooseswift://` invocations (SEC-01, upstream PR #15)
- Full `@Observable` migration: GooseAppModel + HealthDataStore + GooseBLEClient — 68 `@Published` removed; NavigationRequestObserver warning eliminated (PERF-01, PERF-02, PERF-03)
- Coach multi-provider: four AI backends (ChatGPT, Claude, Custom endpoint, Gemini OAuth PKCE); `CoachProvider` protocol; `CoachProviderRegistry`; provider picker UI in settings (COACH-01–06)
- pt-PT localisation complete: 128 strings covering all v4.0 UI additions including Coach settings, provider config, model preset names; onboarding skip button; startup non-blocking (L10N-03, PERF-04, UX-01)

---

## v3.0 Wearable UX, CI Hardening & RTC Sync (Shipped: 2026-06-05)

**Phases completed:** 8 phases (9–15 + 10.1), 17 plans

**Key accomplishments:**

- BLE stability: FFI catch_unwind + panic=unwind; 24 MB storage cap; exponential reconnect backoff (1s/60s) for WHOOP and HR monitor; per-row device_id in capture sessions
- HR monitor scan/connect UI: live scan list with RSSI, connect sheet, connected panel, wired into More tab Device section
- BLE main-thread publishing fix: all @Published mutations dispatched to main thread; eliminates background-thread CoreBluetooth warnings
- HR monitor independent capture: .hrMonitor mode; startHRMonitorCapture/stopHRMonitorCapture not gated on WHOOP session
- WHOOP 4.0 RTC clock sync: silent drift correction via BLE after connection
- Recovery V2 dashboard: hero score, HRV, RHR from bridge; 7-day trend
- pt-PT localisation infrastructure: Localizable.xcstrings, 650+ strings, dynamic status strings via LocalizedStatusStrings.swift
- Recovery formula SDNN accuracy: rmssd_segment_aware, hkHRVSDNNMs rename, baseline normalization

---

## v2.0 Multi-Device & Platform Foundations (Shipped: 2026-06-04)

**Phases completed:** 8 phases, 13 plans, 19 tasks

**Key accomplishments:**

- Duration:
- Duration:
- Duration:
- One-liner:
- WearableDescriptor.genericHRMonitor descriptor, empty-prefix guard, normalized HR_MONITOR rustDeviceType, and dedicated 0x180D BLE scan/connect/notify flow with background-queue dispatch — completing the WEAR-02 iOS acquisition path
- One-liner:
- Pure buildUploadPayload function extracted from performUpload plus 6-test GooseUploadServiceTests suite locking the WEAR-03 device taxonomy (GEN4/GOOSE/HR_MONITOR) behind regression tests — resolves cross-AI review HIGH-3.
- Root cause fix (capture_import.rs):
- `bridge_hr_monitor_upload_stream_contains_bpm_and_rr`

---

## v1.0 Servidor Remoto + PRs Upstream (Shipped: 2026-06-03)

**Phases completed:** 5 phases, 12 plans, 6 tasks

**Key accomplishments:**

- (none recorded)

---

---
phase: 79
plan: "01"
subsystem: more-nav, debug-view, breathe, workout-strain
tags: [polish, navigation, debug, haptics, strain]
requires: []
provides: [debug-3tab-view, logs-export-nav, breathe-haptics, live-strain]
affects: [MoreView, MoreDebugViews, MoreRouteModels, BreatheView, FitnessLiveWorkoutViews]
tech-stack:
  added: []
  patterns: [TabView-split, route-grouping]
key-files:
  created: []
  modified:
    - GooseSwift/MoreDebugViews.swift
    - GooseSwift/MoreRouteModels.swift
    - GooseSwift/MoreView.swift
decisions:
  - "Split MoreDebugView body into three private sub-structs (MoreDebugStatusTab, MoreDebugCaptureTab, MoreDebugResearchTab) to avoid passing properties through TabView — keeps each tab self-contained"
  - "Connection row placed exclusively in Status tab; removed from Capture and Research to satisfy the 'appears exactly once' constraint"
  - "Renamed MoreRoute.support title to 'Logs & Export' rather than adding a new route case — avoids architectural change, preserves existing navigation and destination wiring"
  - "DEF-01 (BreatheView haptics) was already implemented in a prior commit — verified buzz(loops:1) calls at each phase transition"
  - "DEF-02 (live workout strain tile) was already implemented — GooseAppModel updates liveWorkoutStrain every 3 seconds from GooseStrainAccumulator; FitnessLiveWorkoutViews reads it directly"
metrics:
  duration: "~10 minutes"
  completed: "2026-06-13T23:39:11Z"
  tasks_completed: 4
  files_changed: 3
---

# Phase 79 Plan 01: Polish & Deferred Features Summary

MoreDebugView refactored into a 3-tab layout (Status/Capture/Research); More navigation reorganised so Logs & Export lives in the Developer hub with About remaining under Support; BreatheView haptics and live workout strain confirmed already wired.

## Tasks

### POL-01: Debug tab into 3 focused tabs
**Status:** Complete  
**Commit:** a31c353

Restructured `MoreDebugView` (previously a monolithic 644-line List) into a `TabView` with three private sub-views:
- **Status** — connection state, HR sanitizer, Rust/parser info, data provenance, debug session
- **Capture** — health packet capture, movement test, WHOOP event signals, command shortcuts, protected controls
- **Research** — research BT commands, diagnostics, command evidence, developer tools (DEBUG)

The Connst and Research BT Commands sections were removed.

### POL-02: Rename Support → Logs & Export, move to Developer hub
**Status:** Complete  
**Commit:** 1ec92c0

Changes made:
- `MoreRoute.support` title changed from "Support" to "Logs & Export"
- `MoreRoute.support` subtitle updated to "Logs, export bundles, and troubleshooting"
- `MoreRoute.supportRoutes` reduced to `[.about]` (Support section now shows only About)
- `MoreRoute.developerRoutes` expanded to `[.support, .developer]` (Developer hub now shows Logs & Export + Developer)
- `MoreView.swift` call site corrected to pass `healthStore` to `MoreDebugView`

### DEF-01: BreatheView haptic pacing
**Status:** Already implemented (no code change needed)

Verified in `BreatheView.swift` that `model.ble.buzz(loops: 1)` is called at the start of each breathing phase transition (inhale at line 107, hold at line 117, exhale at line 122). The implementation was complete in a prior phase.

### DEF-02: Live workout strain tile from signal pipeline
**Status:** Already implemented (no code change needed)

Verified:
- `GooseAppModel.swift` (line 324-326): `strainAccumulator.ingest(bpm:date:)` called on each live HR sample; `pollIfReady` publishes to `liveWorkoutStrain` every 3 seconds
- `GooseAppModel+ActivityRecording.swift` (line 77): `strainAccumulator.reset()` on workout start; line 188: `freeze()` on stop
- `FitnessLiveWorkoutViews.swift` (line 245-246): strain tile renders `model.liveWorkoutStrain` when > 0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Missing healthStore argument in MoreView call site**
- **Found during:** POL-01 build verification
- **Issue:** The worktree copy of `MoreView.swift` had `MoreDebugView(store: store)` without the `healthStore:` argument, causing a build error after the new `MoreDebugView` init was established
- **Fix:** Added `healthStore: healthStore` to the call site in `MoreView.swift`
- **Files modified:** `GooseSwift/MoreView.swift`
- **Commit:** 1ec92c0 (included in POL-02 commit)

## Self-Check

Files created/modified:
- [x] GooseSwift/MoreDebugViews.swift — exists, restructured with TabView
- [x] GooseSwift/MoreRouteModels.swift — route title and grouping updated
- [x] GooseSwift/MoreView.swift — call site fixed

Commits:
- [x] a31c353 — feat(79): split More > Debug into Status/Capture/Research tabs (POL-01)
- [x] 1ec92c0 — feat(79): rename Support to Logs & Export, reorganise More nav (POL-02)

## Self-Check: PASSED

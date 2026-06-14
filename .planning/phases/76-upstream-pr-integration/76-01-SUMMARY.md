---
plan: 76-01
status: complete
requirements: PR-UP-01, PR-UP-02, PR-UP-03
duration: integrated via cherry-pick from upstream b-nnett/goose
files_modified: 8
---
# Summary: Upstream PR Integration

## PRs integrated
- PR #4, #12: already in main (no action)
- PR #29: `perf: reduce main-thread load` + `perf(ActivitySessionModel): decouple 60 Hz sampling from SwiftUI publishes`
- PR #31: `Filter display-safety once at ingestion, not per render`

## Key changes
- GooseAppModel+Lifecycle.swift: equality guard on HR timeline snapshot to prevent spurious re-renders
- HomeDashboardView.swift: `landingSnapshots` computed property (compute once per render); `scoreSnapshots(using:)` takes cached result
- ActivitySessionModel.swift: private `tick*` backing stores updated at 60 Hz; `@Published` properties flushed at 4 Hz via `uiPublishInterval`
- HealthDataStore+Snapshots.swift: display-safety filter at ingestion point (not per render)
- Fix applied: upstream `_*` variable naming conflicted with `@Observable` synthesized storage; renamed to `tick*`

## Acceptance criteria met
- [x] PR-UP-01/02/03 perf improvements applied (main-thread load reduced, 60 Hz decoupled from SwiftUI)
- [x] Build passes
- [x] @Observable naming conflict resolved

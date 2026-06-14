---
plan: 75-03
status: complete
requirements: PR-INT-07
duration: integrated via cherry-pick from PR #137
files_modified: 15 (including new HistoricalRangeParsingTests.swift, WorkoutLiveActivityAttributesTests.swift)
---
# Summary: Historical Sync Live Donut (PR-INT-07)

Integrated PR #137 (cmiami:pr/sync-progress-and-completion) — 3 commits:
- `feat(sync): show live donut progress while the strap syncs` — GooseBLEClient gains historicalSyncPagesTotal + historicalSyncBurstsCompleted + historicalSyncFraction; HomeDashboardView shows live donut
- `fix(sync): make empty historical syncs protocol-driven` — completion driven by protocol signal not timer; GooseBLEHistoricalManager updated
- `fix(sync): harden historical sync progress and move unit pref into ContentState` — WorkoutLiveActivityAttributes.ContentState gains usesImperialUnits; hardened progress tracking; HistoricalRangeParsingTests + WorkoutLiveActivityAttributesTests added

## Acceptance criteria met
- [x] Historical sync shows live donut progress ring while syncing
- [x] Completion is protocol-driven (not timer)
- [x] Unit preference in Live Activity ContentState
- [x] Test coverage added
- [x] Build passes

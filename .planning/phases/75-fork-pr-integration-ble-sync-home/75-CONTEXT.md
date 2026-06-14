# Phase 75: Fork PR Integration — BLE, Sync & Home - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Mode:** Auto-generated (PR integration — same pattern as Phase 74)

<domain>
## Phase Boundary

Integrate 3 tigercraft4/goose fork PRs into main:
- PR-INT-02 (#131): BLE firmware recovery — recover device-info reads after strap firmware updates; drop unused sync-state callback capture
- PR-INT-06 (#135): Home warm-up progress — show baseline warm-up progress instead of empty dials; honest vitals state; friendly coach copy
- PR-INT-07 (#137): Historical sync live donut progress + protocol-driven completion signal

</domain>

<decisions>
## Implementation Decisions

### Integration Approach
- Same cherry-pick pattern as Phase 74: fetch PR branches, cherry-pick oldest→newest, resolve xcstrings conflicts with `--theirs`
- Order: #131 (BLE, smallest) → #135 (Home, medium) → #137 (Sync, medium)

### PR-INT-02 (#131)
- 2 commits: firmware recovery BLE read retry + remove unused callback
- Pure BLE layer — no UI changes expected

### PR-INT-06 (#135)
- 6 commits: baseline progress model, test coverage, coach copy improvements
- UI phase with home screen changes — verify with simulator

### PR-INT-07 (#137)
- 3 commits: live donut, protocol-driven empty sync, harden progress + unit pref in ContentState
- UI phase with sync progress view changes

### Claude's Discretion
- Conflict resolution strategy: xcstrings → `--theirs` (PR has authoritative state); Swift view conflicts → manual merge preserving both changes

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Same cherry-pick + conflict resolution pattern from Phase 74 is the template
- `OnboardingStorage.unitSystem` already reactive (Phase 74)
- Historical sync managed by `GooseBLEHistoricalManager` (Phase 68)

### Integration Points
- BLE device-info: `GooseBLEClient+HistoricalCommands.swift` or similar
- Home screen warm-up: `HomeDashboardView.swift`
- Historical sync progress: `GooseBLEHistoricalManager.swift`, `GooseAppModel+SleepSync.swift`

</code_context>

<specifics>
## Specific Ideas
- HV-01 (BLE firmware recovery): requires physical device with firmware update — `human_needed`
- HV-02 (Home warm-up): testable in simulator (no WHOOP = shows warm-up state correctly)
- HV-03 (Historical sync donut): testable in simulator if sync is triggered

</specifics>

<deferred>
## Deferred Ideas
None — all 3 PRs are in scope.
</deferred>

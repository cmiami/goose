# Phase 78: Performance & BLE Reliability - Context

**Gathered:** 2026-06-14
**Status:** Ready for execution
**Mode:** Auto-generated (requirements fully specified)

<domain>
## Phase Boundary

Three targeted improvements:
1. **PERF-01**: SQLite indexes on schema v20 tables (metricSeries, journal, workout, appleDaily) via Rust bridge migration
2. **PERF-02**: App startup lazy-init — defer GooseBLEClient and GooseRustBridge construction so first SwiftUI frame renders before heavy init
3. **BLE-REL-01**: BLE auth retry — on `CBATTError.insufficientAuthentication` in `didWriteValueFor`, automatically retry the write after 2.5s; if retry also fails, show actionable error message (no silent failure, no crash, no infinite loop)

</domain>

<decisions>
## Implementation Decisions

### PERF-01: SQLite indexes
- Add indexes in a new Rust migration (schema version 21 or via ALTER TABLE CREATE INDEX)
- Indexes needed: `metricSeries(source, metric_name, date)`, `journal(date)`, `workout(date)`, `appleDaily(date)`
- Validate with EXPLAIN QUERY PLAN for hot paths

### PERF-02: Lazy startup
- GooseBLEClient and GooseRustBridge are the heavy initialisers
- Use lazy var or defer initialisation to after first frame renders
- Do not break existing data flow — callbacks and observers must still wire up correctly

### BLE-REL-01: Auth retry
- Intercept `didWriteValueFor` in `GooseBLEClient+PeripheralDelegate.swift`
- On `.insufficientAuthentication`: schedule a 2.5s retry (DispatchQueue, not Timer) for the same write
- If the second attempt also fails with `.insufficientAuthentication`: post a user-visible error on `@MainActor` (e.g. update `connectionState` with actionable message)
- Max 1 automatic retry — no infinite loop
- SEED-001 from .planning/seeds/ documents this pattern

### Claude's Discretion
- Rust migration numbering: use next available schema version
- Lazy-init approach: lazy var on the class is simplest and safest
- Error message text for BLE auth failure: "Authentication failed — please reconnect WHOOP"

</decisions>

<code_context>
## Existing Code Insights

### PERF-01
- Schema migrations in `Rust/core/src/store.rs` — find `CURRENT_SCHEMA_VERSION` (20) and add migration case 21
- metricSeries, journal, workout, appleDaily tables were added in Phase 69
- Rust `conn.execute("CREATE INDEX IF NOT EXISTS ...")` pattern

### PERF-02
- `GooseSwiftApp.swift` creates GooseAppModel as `@StateObject` at app launch
- GooseAppModel init creates GooseBLEClient and GooseRustBridge immediately
- Target: make these `lazy` in GooseAppModel or defer to `onAppear`

### BLE-REL-01
- `GooseBLEClient+PeripheralDelegate.swift` has `peripheral(_:didWriteValueFor:error:)` delegate method
- `GooseBLEClient.swift` has `@Published var connectionState` for user-visible status
- Pattern: store the last write attempt, retry once after 2.5s delay

</code_context>

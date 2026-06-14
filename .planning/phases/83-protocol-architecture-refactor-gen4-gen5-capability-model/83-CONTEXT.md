# Phase 83: Protocol Architecture Refactor — Gen4/Gen5 Capability Model - Context

**Gathered:** 2026-06-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Separate device identity (DeviceKind) from wire protocol (WireProtocol) from device capabilities (DeviceCapabilities) in the Rust core and Swift client. Eliminate 17 string comparisons in Swift (`rustDeviceType == "GEN4"`) and 8 `activeDeviceGeneration == .gen4` guards scattered across extension files. Move frame reassembly decision authority to Rust. Normalise DB device_type values by migrating MAVERICK/PUFFIN rows to GOOSE.

Out of scope: battery feature UI, HealthKit persistence, new BLE protocol features, changing the Gen4 historical sync state machine logic (only the guard style changes).

</domain>

<decisions>
## Implementation Decisions

### Rust/Swift Boundary

- **D-01:** Frame reassembly buffer stays in Swift (preserves stateless Rust bridge invariant documented in CLAUDE.md). Swift accumulates bytes and detects frame boundaries.
- **D-02:** Swift replaces `rustDeviceType` computed property (returns hardcoded `"GEN4"`/`"HR_MONITOR"`/`"GOOSE"` strings) with a `WireProtocol` Swift enum derived from `WhoopGeneration`. String comparisons in the reassembly loop replaced by `wireProtocol == .gen4` enum checks.
- **D-03:** `rustDeviceType` string is still sent to Rust for frame parsing (Rust needs `device_kind` to select header format). The string payload changes from `"GOOSE"` to a canonical `DeviceKind` identifier — but the Rust `parse_device_type` still accepts it.
- **D-04:** No new stateful bridge methods for reassembly. Rust receives complete frame bytes and parses them — no change to the FFI boundary shape.

### DeviceCapabilities Shape

- **D-05:** `DeviceCapabilities` is defined in Rust and exposed via a new bridge method `device.capabilities(device_kind)` that returns JSON. Rust is the single source of truth — future clients (Android, etc.) inherit automatically.
- **D-06:** Capabilities include both existing guards AND upcoming battery/R22 features (not deferred):
  ```
  wire_protocol:          "gen4" | "gen5"
  historical_sync:        "page_sequence" | "stream"   // replaces gen4 guards
  battery_via_r22:        bool  // Whoop5 only
  battery_via_event48:    bool  // both Gen4 and Gen5
  battery_via_cmd26:      bool  // both Gen4 and Gen5
  r22_realtime:           bool  // Whoop5 only
  ```
- **D-07:** Swift calls `device.capabilities` immediately after GATT discovery (when `WhoopGeneration` is detected from characteristic UUID prefix). Result cached in `connectedCapabilities: DeviceCapabilities?` on `GooseBLEClient`. Nil = not connected.
- **D-08:** `activeDeviceGeneration: WhoopGeneration = .gen5` replaced by `connectedCapabilities: DeviceCapabilities?`. All 8 `if activeDeviceGeneration == .gen4` guards in HistoricalHandlers/HistoricalCommands replaced by `capabilities.historicalSync == .pageSequence`.

### DB Migration

- **D-09:** Automatic migration runs in the Rust SQLite init sequence:
  ```sql
  UPDATE decoded_frames SET device_type = 'GOOSE'
  WHERE device_type IN ('MAVERICK', 'PUFFIN');
  ```
  Idempotent, one-time, transparent to the user.
- **D-10:** After migration, `parse_device_type("MAVERICK")` and `parse_device_type("PUFFIN")` return an error — deprecated and rejected. This affects replay of old diagnostic logs; acceptable because logs are human-readable and the DB rows are already migrated.
- **D-11:** New rows written after this phase only ever use `"GEN4"`, `"GOOSE"`, or `"HR_MONITOR"` as `device_type` values.

### Rust Type Changes

- **D-12:** Add `WireProtocol` enum to `protocol.rs` with two variants: `Gen4` and `Gen5`. All match arms in `parse_frame()` that currently pattern-match `DeviceType::Maverick | Puffin | Goose | HrMonitor` delegate to `device_type.wire_protocol() == WireProtocol::Gen4`.
- **D-13:** Add `DeviceKind` enum with three variants: `Whoop4`, `Whoop5`, `HrMonitor`. `DeviceType` is kept as-is (DB compat) but gains `wire_protocol() -> WireProtocol` and `device_kind() -> DeviceKind` methods.
- **D-14:** Add `DeviceCapabilities` struct to bridge.rs or a new `capabilities.rs` module, derived from `DeviceKind`.
- **D-15:** `is_gen5_family()` helper method added to `DeviceType` as an interim cleanup — reduces the repeated `Maverick | Puffin | Goose | HrMonitor` arms without changing semantics.
- **D-16:** `Puffin` variant: document as "hardware code name with no known generation mapping — likely unshipped. Parses as Gen5-family wire format." `Puffin` maps to `DeviceKind::Whoop5` via `device_kind()`.

### Testing

- **D-17:** Rust unit tests required for: `DeviceCapabilities` values per `DeviceKind`, `WireProtocol` dispatch, `is_gen5_family()`, DB migration idempotency, and `parse_device_type` rejection of MAVERICK/PUFFIN post-migration.
- **D-18:** `cargo test --locked` must pass clean. iOS build must compile without new warnings.
- **D-19:** No manual simulator verification required for this phase (pure refactor — no visible behaviour change for the user).

### Claude's Discretion

- Buffer state architecture: decided to keep in Swift (preserves stateless bridge).
- Module placement for `DeviceCapabilities`: either `bridge.rs` inline or new `capabilities.rs` — researcher/planner decide based on file size.
- Whether `WireProtocol` lives in `protocol.rs` or a new `wire.rs` — researcher/planner decide.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture Constraints
- `CLAUDE.md` §Architecture Constraints — "Rust bridge is synchronous" and "Multiple bridge instances" and "The Rust library is stateless from Swift's perspective" — these constraints forbid adding buffer state to Rust
- `docs/architecture/gen4-historical-sync.md` — Wire-level differences Gen4 vs Gen5, state machine, implementation map for Swift code

### Key Source Files (Rust)
- `Rust/core/src/protocol.rs:27-68` — `DeviceType` enum and `header_len`/`expected_frame_len` methods — this is where `WireProtocol` and `DeviceKind` are added
- `Rust/core/src/bridge.rs:9510-9523` — `parse_device_type()` — add rejection of MAVERICK/PUFFIN here
- `Rust/core/src/store.rs:8918-8924` — `device_type_name()` — serialises DeviceType back to DB strings
- `Rust/core/src/openwhoop_reference.rs:166-175` — `whoop_generation_from_device_type()` — already has `Gen4`/`Gen5` concept; new `DeviceCapabilities` should align with this

### Key Source Files (Swift)
- `GooseSwift/GooseBLETypes.swift:75-88` — `rustDeviceType` computed property — replace with `WireProtocol` enum
- `GooseSwift/GooseBLETypes.swift:209-270` — `WhoopGeneration` enum — `WireProtocol` derives from this
- `GooseSwift/GooseBLEClient.swift:275` — `activeDeviceGeneration: WhoopGeneration = .gen5` — replace with `connectedCapabilities: DeviceCapabilities?`
- `GooseSwift/GooseAppModel+NotificationPipeline.swift:823-835` — frame reassembly string comparisons — primary cleanup site (17 occurrences)
- `GooseSwift/GooseBLEClient+HistoricalHandlers.swift` — 6 of the 8 `activeDeviceGeneration == .gen4` guards
- `GooseSwift/GooseBLEClient+HistoricalCommands.swift` — remaining 2 `activeDeviceGeneration == .gen4` guards

### Related Seeds
- `.planning/seeds/SEED-002-battery-level-gen4-gen5.md` — battery protocol offsets from noop/PostHooks.swift; `battery_via_event48` and `battery_via_cmd26` capabilities defined here should align with Phase 81 implementation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WhoopGeneration` enum (Swift) — already has `detect(from:)` and `buildCommandFrame()` per generation; `WireProtocol` enum derives from it, not replaces it
- `whoop_generation_from_device_type()` in `openwhoop_reference.rs` — already maps DeviceType → Gen4/Gen5; `DeviceKind` and `DeviceCapabilities` build on this
- `HrMonitor` special path in `capture_import.rs:661` — bypasses 0xAA frame parser; this path is preserved unchanged

### Established Patterns
- Stateless Rust bridge: every bridge method is stateless (no in-memory state between calls). `device.capabilities` follows this — computes from `device_kind` arg, no stored state.
- Multiple bridge instances: `GooseAppModel`, `HealthDataStore`, `OvernightSQLiteMirrorQueue`, `CaptureFrameWriteQueue` each own a `GooseRustBridge` instance. `device.capabilities` can be called from any of them.
- SQLite migration sequence in `store.rs` — new migration step follows existing pattern

### Integration Points
- `processDiscoveredCharacteristics` in `GooseBLEClient+Commands.swift:986` — where `activeDeviceGeneration` is set today; this becomes the call site for `device.capabilities`
- Frame reassembly in `GooseAppModel+NotificationPipeline.swift:815-875` — primary target for string comparison removal
- `GooseBLEClient+HistoricalHandlers.swift` and `GooseBLEClient+HistoricalCommands.swift` — 8 guard sites to replace with capability checks

</code_context>

<specifics>
## Specific Ideas

- The `Puffin` variant gets a doc comment in the enum: "Hardware code name with no known generation mapping — likely unshipped. Parses as Gen5-family wire format (8-byte header)."
- `connectedCapabilities` is `nil` when disconnected — removes the silent `.gen5` default that could mask Gen4 detection failures.
- DB migration runs as a numbered step in the Rust migration sequence — same pattern as existing schema migrations.

</specifics>

<deferred>
## Deferred Ideas

- Battery feature UI (showing real battery % in the app) — Phase 81
- HealthKit persistence — Phase 82
- Gen6 / third-party device support — future milestone
- Moving frame reassembly to Rust entirely (stateful bridge) — deferred; would require architectural discussion about bridge statefulness

</deferred>

---

*Phase: 83-Protocol Architecture Refactor — Gen4/Gen5 Capability Model*
*Context gathered: 2026-06-14*

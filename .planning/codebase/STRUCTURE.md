---
focus: arch
last_mapped: 2026-06-13
---
# Codebase Structure

**Analysis Date:** 2026-06-13

## Directory Layout

```
goose/
├── GooseSwift/                     # iOS app source (177 .swift files)
│   ├── GooseSwiftApp.swift         # @main entry point
│   ├── GooseAppModel.swift         # Central coordinator (+ 9 extension files)
│   ├── GooseBLEClient.swift        # BLE central manager (+ 11 extension files)
│   ├── GooseRustBridge.swift       # C FFI bridge wrapper
│   ├── HealthDataStore.swift       # Metric query layer (+ 18 extension files)
│   ├── AppRouter.swift             # Navigation state
│   ├── RootView.swift              # Onboarding gate
│   ├── AppShellView.swift          # Tab bar shell
│   ├── Assets.xcassets/            # Image/color assets
│   ├── GooseSwift-Bridging-Header.h # Exposes goose_core_bridge.h to Swift
│   ├── GooseSwift.entitlements     # HealthKit, push, Keychain entitlements
│   ├── Info.plist                  # Bundle config, URL scheme, BT/location modes
│   └── Localizable.xcstrings       # Localisation strings
├── GooseSwiftTests/                # Swift unit tests (20 test files + 3 mocks)
│   ├── MockRustBridge.swift        # Mock conforming to GooseRustBridging
│   ├── MockBLEClient.swift         # Mock conforming to GooseBLEManaging
│   ├── MockHealthStore.swift       # Mock conforming to HealthDataStoring
│   ├── WorkoutEntryTests.swift     # Unit tests — workout upsert bridge method
│   └── TrendsFetchTests.swift      # Unit tests — metric_series query_range
├── GooseWorkoutLiveActivityExtension/
│   ├── GooseWorkoutLiveActivityWidget.swift   # ActivityKit + WidgetKit extension
│   └── Info.plist
├── Rust/
│   └── core/
│       ├── src/
│       │   ├── bridge.rs           # FFI entry; 10 847 lines; 58+ method dispatches
│       │   ├── lib.rs              # Crate root; public exports
│       │   ├── protocol.rs         # WHOOP BLE packet parsing
│       │   ├── metric_features.rs  # HRV, HR, sleep, strain feature extraction
│       │   ├── sleep_staging.rs    # Sleep stage classification
│       │   ├── historical_sync.rs  # Historical sync dry-run + validation
│       │   ├── capture_import.rs   # Batch BLE frame import to SQLite
│       │   ├── export.rs           # Raw data export (zip bundle)
│       │   ├── step_counter.rs     # IMU step counting
│       │   └── [68 more .rs files]
│       ├── tests/                  # Integration tests (40+ test files)
│       │   ├── bridge_tests.rs
│       │   ├── protocol_tests.rs   # 21 protocol tests pass
│       │   └── [38 more test files]
│       ├── include/
│       │   └── goose_core_bridge.h # C header: goose_bridge_handle_json / goose_bridge_free_string
│       ├── Cargo.toml
│       └── Cargo.lock              # Committed
├── Scripts/
│   └── build_ios_rust.sh           # Cross-compile Rust → .a; invoked as Xcode build phase
├── Rust/
│   ├── iphoneos/
│   │   └── libgoose_core.a         # Pre-built ARM64 device static lib (gitignored; CI rebuilds)
│   └── iphonesimulator/
│       └── libgoose_core.a         # Pre-built ARM64+x86_64 sim static lib
├── Packages/
│   ├── WhoopProtocol/              # Placeholder SPM package — no source files
│   └── WhoopStore/                 # Placeholder SPM package — no source files
├── GooseSwift.xcodeproj/           # Xcode project; manages all build phases + targets
├── .planning/                      # GSD planning artifacts (committed)
│   ├── codebase/                   # This directory — codebase map docs
│   ├── milestones/                 # Per-milestone phase directories
│   ├── phases/                     # Active phase plans
│   ├── quick/                      # Quick-fix plans
│   ├── research/                   # RE findings, feature analysis
│   └── seeds/                      # Seed documents from RE / NOOP analysis
└── .agents/                        # Agent skills directory
    └── skills/
        ├── code-review/
        └── security-review/
```

## Directory Purposes

**`GooseSwift/` — iOS App Source:**
- The entire SwiftUI application, BLE stack, FFI bridge, and upload client
- 177 `.swift` files; no subdirectory organisation — all files at flat level
- Key naming patterns:
  - `*Models.swift` — data model types
  - `*Types.swift` — enum/struct type definitions
  - `*Views.swift` — multiple related SwiftUI views in one file
  - `*View.swift` — single SwiftUI view
  - `GooseBLEClient+*.swift` — BLE concern-split extensions
  - `GooseAppModel+*.swift` — coordinator concern-split extensions
  - `HealthDataStore+*.swift` — metric domain extensions

**`GooseSwiftTests/` — Swift Unit Tests:**
- Co-located with source project; separate test target in `GooseSwift.xcodeproj`
- 3 mock files implement the testability protocols from Phase 72
- Test files match `*Tests.swift` naming; no subdirectory organisation
- No Swift snapshot or UI test targets detected

**`Rust/core/src/` — Rust Core Library:**
- 76 `.rs` modules; all at flat level inside `src/`
- `bridge.rs` is the FFI entry point and dispatch table (10 847 lines)
- Domain split: `protocol.rs` (BLE packet parsing), `metric_features.rs` (algorithms), `sleep_staging.rs`, `historical_sync.rs`, `capture_import.rs`, `export.rs`, `step_counter.rs`, `energy_rollup.rs`, `baselines.rs`, `calibration.rs`, etc.

**`Rust/core/tests/` — Rust Integration Tests:**
- 40+ test files following `*_tests.rs` naming
- Run via `cargo test` from `Rust/core/`
- Protocol tests: 21 tests in `protocol_tests.rs`

## Key File Locations

**Entry Points:**
- `GooseSwift/GooseSwiftApp.swift` — iOS `@main`
- `GooseWorkoutLiveActivityExtension/GooseWorkoutLiveActivityWidget.swift` — WidgetKit extension
- `Rust/core/src/lib.rs` — Rust crate root
- `Rust/core/src/bridge.rs` — FFI dispatch table

**Coordinator & State:**
- `GooseSwift/GooseAppModel.swift` — central coordinator definition + stored properties
- `GooseSwift/GooseAppModel+Lifecycle.swift` — BLE connect/disconnect, app lifecycle
- `GooseSwift/GooseAppModel+NotificationPipeline.swift` — BLE → SQLite data pipeline
- `GooseSwift/GooseAppModel+Upload.swift` — upload orchestration
- `GooseSwift/GooseAppModel+SleepSync.swift` — sleep history sync trigger
- `GooseSwift/GooseAppModel+ActivityRecording.swift` — workout session lifecycle
- `GooseSwift/AppRouter.swift` — navigation paths

**BLE Layer:**
- `GooseSwift/GooseBLEClient.swift` — `@Observable` BLE state; `CBCentralManagerDelegate`
- `GooseSwift/GooseBLEClient+CentralDelegate.swift` — scan/connect state machine
- `GooseSwift/GooseBLEClient+PeripheralDelegate.swift` — GATT characteristic callbacks
- `GooseSwift/GooseBLEClient+Commands.swift` — command frame builders (WHOOP protocol)
- `GooseSwift/GooseBLEClient+HistoricalCommands.swift` — GET_DATA_RANGE / burst commands
- `GooseSwift/GooseBLEClient+Haptics.swift` — `buzz(loops:)` — sends `Data([0x13, n])` to commandCharacteristic
- `GooseSwift/GooseBLEClient+HRMonitor.swift` — HR-monitor peripheral (non-WHOOP)
- `GooseSwift/GooseBLETypes.swift` — enums, structs for BLE state

**FFI Bridge:**
- `GooseSwift/GooseRustBridge.swift` — bridge class + timing
- `GooseSwift/GooseRustBridging.swift` — testability protocol
- `GooseSwift/GooseBLEManaging.swift` — BLE testability protocol
- `GooseSwift/GooseSwift-Bridging-Header.h` — exposes C symbols to Swift
- `Rust/core/include/goose_core_bridge.h` — C header

**Metric Layer:**
- `GooseSwift/HealthDataStore.swift` — `@Observable` state; `let bridge = GooseRustBridge()`
- `GooseSwift/HealthDataStore+Recovery.swift` — recovery score queries
- `GooseSwift/HealthDataStore+Sleep.swift` — sleep metric queries
- `GooseSwift/HealthDataStore+Cardio.swift` — HR / HRV queries
- `GooseSwift/HealthDataStore+PacketInputs.swift` — raw packet input report queries
- `GooseSwift/HealthDataStore+Trends.swift` — metric_series trend queries (Phase 72)
- `GooseSwift/HealthDataStore+Utilities.swift` — `defaultDatabasePath()` static method

**Upload & Network:**
- `GooseSwift/GooseUploadService.swift` — URLSession upload client
- `GooseSwift/GooseNetworkMonitor.swift` — NWPathMonitor reachability wrapper

**Pipelines & Actors:**
- `GooseSwift/CaptureFrameWriteQueue.swift` — batched BLE frame → SQLite writes
- `GooseSwift/OvernightSQLiteMirrorQueue.swift` — notification row mirror queue
- `GooseSwift/GooseStrainAccumulator.swift` — Swift `actor` for live strain
- `GooseSwift/NotificationFrameParsing.swift` — BLE → Rust frame reassembly
- `GooseSwift/PassiveActivityDetector.swift` — heuristic workout detection pipeline
- `GooseSwift/HeartRateSamplePipeline.swift` — HR sample aggregation pipeline

**Configuration:**
- `GooseSwift.xcodeproj/project.pbxproj` — all build phases, target membership, UUIDs
- `Scripts/build_ios_rust.sh` — Rust cross-compilation; reads `PLATFORM_NAME`, `CONFIGURATION`, `CURRENT_ARCH` from Xcode environment
- `GooseSwift/Info.plist` — bundle ID `com.goose.app`, URL scheme `gooseswift://`, background modes
- `GooseSwift/GooseSwift.entitlements` — `com.apple.developer.healthkit`, push, Keychain

**Rust Core Key Files:**
- `Rust/core/src/bridge.rs` — 58+ method dispatch branches; 10 847 lines
- `Rust/core/src/protocol.rs` — WHOOP 5.0 R22 packet parsing (handle 0x0022, 0x0027); v18 historical decode
- `Rust/core/src/metric_features.rs` — HRV, resting HR, sleep, strain, stress feature extraction
- `Rust/core/src/sleep_staging.rs` — sleep stage classification algorithms
- `Rust/core/src/historical_sync.rs` — historical sync dry-run validation
- `Rust/core/src/capture_import.rs` — `import_captured_frame_batch_with_output_options`
- `Rust/core/src/export.rs` — raw export (OOM risk: avoid `includeRawBytes`)
- `Rust/core/Cargo.toml` — dependency manifest; `rusqlite = { version = "0.37", features = ["bundled"] }`

## Naming Conventions

**Swift Files:**
- `PascalCase` matching the primary type: `GooseBLEClient.swift`, `HealthDataStore.swift`
- Extensions use `+` suffix: `GooseAppModel+SleepSync.swift`, `HealthDataStore+Recovery.swift`
- Multiple related views: `HealthDashboardViews.swift`, `SleepV2BevelTrendViews.swift`
- Type defs: `GooseBLETypes.swift`, `CoachChatTypes.swift`
- Models: `ActivityModels.swift`, `HealthModels.swift`

**Swift Types:**
- Classes/structs/enums: `PascalCase` — `GooseAppModel`, `GooseBLEClient`, `ActivityTimelineItem`
- Enum cases: `camelCase` — `case poweredOn`, `case healthMonitor`
- Error types: `PascalCase` + `Error` suffix — `GooseRustBridgeError`
- Protocols: `PascalCase` + role suffix — `GooseRustBridging`, `GooseBLEManaging`, `HealthDataStoring`

**Rust Files:**
- `snake_case` matching the module name: `bridge.rs`, `metric_features.rs`, `sleep_staging.rs`
- Test files: `*_tests.rs` — `protocol_tests.rs`, `bridge_tests.rs`

## Where to Add New Code

**New SwiftUI View:**
- Implementation: `GooseSwift/<FeatureName>View.swift` or `GooseSwift/<FeatureName>Views.swift`
- Register in `GooseSwift.xcodeproj/project.pbxproj` at exactly 4 locations (PBXBuildFile, PBXFileReference, PBXGroup children, PBXSourcesBuildPhase)
- Wire navigation route in `AppRouter.swift` or the relevant route enum (e.g., `MoreRoute`, `HealthRoute`)

**New GooseAppModel Concern:**
- Create `GooseSwift/GooseAppModel+<Concern>.swift`
- Register in `project.pbxproj` (4 locations)
- Keep the extension focused on one behavioural slice; all shared state lives on `GooseAppModel` itself

**New HealthDataStore Domain:**
- Create `GooseSwift/HealthDataStore+<Domain>.swift`
- Each method calls `bridge.requestAsync(method: "metrics.<name>", args: ["database_path": ...])` on a detached task, then updates `@Observable` state on `@MainActor`

**New BLE Feature:**
- Add to the appropriate existing extension or create `GooseSwift/GooseBLEClient+<Concern>.swift`
- BLE callbacks always run on `DispatchQueue.main` after CoreBluetooth delivers them; publishing state changes is safe without extra dispatch

**New Rust Bridge Method:**
- Add handler branch in `Rust/core/src/bridge.rs` matching `method == "<namespace>.<name>"`
- Add corresponding Rust logic in the relevant module under `Rust/core/src/`
- Add integration test in `Rust/core/tests/bridge_tests.rs` or a domain-specific `*_tests.rs` file
- Call from Swift via `bridge.requestAsync(method: "<namespace>.<name>", args: [...])`

**New Swift Unit Test:**
- Add `GooseSwiftTests/<FeatureName>Tests.swift`
- Use `MockRustBridge`, `MockBLEClient`, or `MockHealthStore` for isolation
- Register in `project.pbxproj` test target (4 locations)

**Utilities / Shared Helpers:**
- Pure value-type utilities: add to the nearest relevant `+Utilities.swift` extension or a new `<Domain>Utilities.swift`
- Shared constants: `static let` on the owning type (not free-floating globals)

## Special Directories

**`.planning/`:**
- Purpose: All GSD workflow planning artifacts
- Generated: Partially (GSD commands write docs); partly human-authored
- Committed: Yes (`commit_docs: true`)

**`Rust/iphoneos/` and `Rust/iphonesimulator/`:**
- Purpose: Pre-built static libraries (`libgoose_core.a`) linked by Xcode
- Generated: Yes (by `Scripts/build_ios_rust.sh`)
- Committed: No (gitignored); CI rebuilds via the script

**`Packages/WhoopProtocol/` and `Packages/WhoopStore/`:**
- Purpose: Placeholder SPM packages — contain only `.swiftpm` metadata, no source
- Committed: Yes; not active in the build

**`.claude/worktrees/`:**
- Purpose: Git worktrees used by GSD agent threads
- Committed: No (worktree-local)

---

*Structure analysis: 2026-06-13*

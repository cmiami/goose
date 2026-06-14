---
focus: tech
last_mapped: 2026-06-13
---
# External Integrations

**Analysis Date:** 2026-06-13

## BLE — WHOOP Device (CoreBluetooth)

**Protocol:** Proprietary WHOOP GATT over BLE
- Client: `GooseSwift/GooseBLEClient.swift` + `GooseBLEClient+Commands.swift`, `GooseBLEClient+HistoricalCommands.swift`, `GooseBLEClient+Parsing.swift`, `GooseBLEClient+PeripheralDelegate.swift`
- Framework: CoreBluetooth (`CBCentralManager`, `CBPeripheral`)
- Auth: None — device pairing via standard BLE bonding
- Background mode: `bluetooth-central` in `UIBackgroundModes`
- Data path: BLE bytes → `notificationIngestQueue` → `NotificationFrameParser` (`GooseSwift/NotificationFrameParsing.swift`) → Rust bridge → SQLite
- Write queue: `GooseSwift/CaptureFrameWriteQueue.swift` — batched SQLite inserts via Rust bridge
- BLE queue label: `"com.goose.swift.corebluetooth"`

**WHOOP GATT streams decoded:**
- HR (heart rate, bpm)
- RR intervals (ms)
- Battery (SoC %, mV, charging flag)
- Events
- SpO2 (raw ADC)
- Skin temperature (raw ADC)
- Respiration (raw ADC)
- Gravity / accelerometer (g)

## HealthKit

**Purpose:** Autofill body mass from Apple Health for calorie calculation
- Files: `GooseSwift/GooseAppModel+HealthKit.swift` (primary), 11 files total import HealthKit
- Entitlement: `com.apple.developer.healthkit` in `GooseSwift/GooseSwift.entitlements`
- Data read: body mass (`HKQuantityTypeIdentifier.bodyMass`)
- Auth: user-prompted permission request during onboarding (`GooseSwift/OnboardingPermissions.swift`)
- Write: None detected

## Self-Hosted Server (URLSession → FastAPI)

**Architecture:** iOS uploads decoded biometric streams + raw BLE frames to a self-hosted FastAPI server backed by TimescaleDB.

**iOS upload client:**
- Upload service: `GooseSwift/GooseUploadService.swift` — `URLSessionConfiguration.ephemeral`, 15s request timeout, exponential backoff on 5xx, abort on 4xx
- Upload coordinator: `GooseSwift/GooseAppModel+Upload.swift`
- Network gating: `GooseSwift/GooseNetworkMonitor.swift` — `NWPathMonitor` tracks reachability; upload deferred if offline
- Background sync: `BGTaskScheduler` schedules deferred uploads (`GooseSwift/GooseSwiftApp.swift`, `GooseSwift/GooseAppModel+BandFirstSync.swift`)
- Upload watermark: `GooseSwift/GooseUploadWatermark.swift` — tracks last-synced timestamp to avoid duplicate uploads

**Server endpoints consumed by iOS:**

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/healthz` | Connectivity check before upload |
| GET | `/v1/devices` | List known devices (historical import) |
| POST | `/v1/ingest-decoded` | Upload decoded HR/RR/battery/event/SpO2/temp/resp/gravity streams |
| POST | `/v1/ingest-frames` | Upload raw BLE frames (hex); idempotent |
| GET | `/v1/export/frames/{deviceID}` | Download historical raw frames for local import on fresh install |

**Auth:** Bearer token — `GOOSE_API_KEY` env var on server; sent as `Authorization: Bearer <key>` header from iOS.

**Server stack:**
- FastAPI 0.136.3 + uvicorn 0.49.0 (`server/ingest/app/main.py`)
- TimescaleDB 2.17.2-pg16 via psycopg 3.3.4 (`server/ingest/app/db.py`, `server/ingest/app/store.py`)
- Docker Compose: `server/docker-compose.yml` — `goose-db` (TimescaleDB) + `goose-ingest` (FastAPI)
- Named volumes: `goose-db-data` (PostgreSQL data), `goose-raw-data` (raw archive)
- Daily metric computation: neurokit2 sleep staging + scipy/scikit-learn (`server/ingest/app/analysis/daily.py`); throttled to once per 120s per (device, day)
- Schema bootstrap: `server/db/init.sql` (first-init) + idempotent bootstrap on ingest startup

**Dashboard:**
- Static SPA served at `/` from `server/ingest/app/static/`; reads read-only `/v1` endpoints
- No credentials required for dashboard HTML (auth gates all `/v1` data routes)

## ActivityKit / Dynamic Island

**Purpose:** Real-time workout metrics on lock screen and Dynamic Island
- Controller: `GooseSwift/WorkoutLiveActivityController.swift` — manages `ActivityKit` live activity lifecycle (start/update/end)
- Widget extension: `GooseWorkoutLiveActivityExtension/GooseWorkoutLiveActivityWidget.swift`
- Shared contract: `GooseSwift/WorkoutLiveActivityAttributes.swift` — `ActivityAttributes` conformance; `ContentState` carries live HR, calories, duration
- Trigger: workout recording start/stop in `GooseSwift/GooseAppModel+ActivityRecording.swift`

## AI Health Coach (Multiple Providers)

**Architecture:** Protocol-based `CoachProvider`; provider chosen in settings; all use `URLSession` with streaming SSE.

**Providers:**

| Provider | File | API | Auth storage |
|----------|------|-----|--------------|
| Claude (Anthropic) | `GooseSwift/ClaudeCoachProvider.swift` | Anthropic Messages API (SSE) | iOS Keychain (`ClaudeKeychain`) |
| Gemini (Google) | `GooseSwift/GeminiCoachProvider.swift` | Gemini API (SSE) | `URLSessionConfiguration.ephemeral` |
| OpenAI / Codex | `GooseSwift/CodexEmbeddedAuth.swift` | OpenAI API | Keychain + OAuth (`gooseswift://` callback) |
| Custom endpoint | `GooseSwift/CustomEndpointCoachProvider.swift` | User-defined (SSE) | Configurable |

All providers use `URLSession.shared.bytes(for:)` for streaming SSE responses. No third-party SDKs — all HTTP calls made directly with `URLRequest`.

## APNS (Apple Push Notification Service)

**Purpose:** Gate for deferred upload — upload is triggered after APNs registration confirms network capability.
- Registration: `GooseSwift/GooseSwiftApp.swift` via `UIApplication.registerForRemoteNotifications()`
- Token handler: `GooseSwift/GooseAppModel+Upload.swift` → `setAPNSDeviceToken(_:)` — stores token, triggers pending upload if network available
- Actual push messages: none sent to device; APNs token used purely as a connectivity signal

## GPS / Location

**Purpose:** Outdoor workout tracking
- Framework: CoreLocation + MapKit
- 12 files import CoreLocation, 9 import MapKit
- Background mode: `location` in `UIBackgroundModes`

## Debug WebSocket (Local only)

**Purpose:** Local debug sessions for raw frame inspection
- Server: `tungstenite 0.29` in Rust (`Rust/core/src/`); binds `ws://127.0.0.1:8765`
- Swift client: connects only when debug WebSocket mode enabled
- `NSAllowsLocalNetworking: true` required in `Info.plist`
- Not used in production

## Data Storage

**On-device (iOS):**
- SQLite via Rust bridge: `ApplicationSupport/GooseSwift/goose.sqlite` — all health/packet data
- UserDefaults: onboarding state, device identity, HR estimates; keys namespaced as `"goose.swift.*"` and `"goose.coach.*"`
- Keychain: API keys for AI coach providers
- Documents/GooseSwift/: user-accessible exports (zip bundles)

**Server:**
- TimescaleDB (PostgreSQL 16 + timescaledb extension) — hypertables for time-series biometric streams
- Named Docker volume `goose-db-data` for persistence
- Named Docker volume `goose-raw-data` for raw frame archives

## Environment Configuration

**Required server env vars:**
- `GOOSE_DB_PASSWORD` — PostgreSQL password (no default; must be set)
- `GOOSE_API_KEY` — Bearer token for all `/v1` API routes
- `GOOSE_DB_NAME` — database name (default: `goose`)
- `GOOSE_DB_USER` — database user (default: `goose`)
- `GOOSE_DB_DSN` — full connection string (constructed in docker-compose)
- `GOOSE_INGEST_PORT` — host port (default: `8770`)

**iOS configuration:** No `.env` files. Server URL configured at runtime via app settings; stored in `UserDefaults`.

---

*Integration audit: 2026-06-13*

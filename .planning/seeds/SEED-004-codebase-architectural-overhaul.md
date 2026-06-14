---
id: SEED-004
status: dormant
planted: 2026-06-14
planted_during: v11.0 — PR Integration, Code Health & App Polish
trigger_when: next milestone with code health / architecture focus (v12.0+)
scope: large
---

# SEED-004: Codebase Architectural Overhaul — Rust God Files + Swift Ownership + BLE Concurrency

## Why This Matters

Revisão independente feita por três modelos (Claude Opus, Gemini 2.5 Pro, Codex gpt-5.5)
identificou os mesmos problemas estruturais sem coordenação prévia. Consenso de 3 AIs
é sinal forte. O codebase vai atingir um tecto de manutenibilidade sem estas mudanças.

## When to Surface

**Trigger:** próximo milestone com foco em code health, BLE reliability, ou preparação
para contribuidores externos. Surface também se:
- bridge.rs causar merge conflicts em PRs simultâneos
- Crash report aparecer com stack trace no Rust sem context útil (unwrap panic cross-ABI)
- Contribuidor externo tentar adicionar um subsistema (GooseAppModel é intratável para newcomers)

## Scope Estimate

**Large** — 4-5 sprints. Melhor feito como milestone próprio (v12.0 Code Health).
Pode ser dividido em 3 fases independentes:
- **Fase A:** Rust god files (bridge + store) — sem impacto Swift
- **Fase B:** Crash safety (unwrap → Result) — sem impacto visível
- **Fase C:** Swift restructuring (ownership + concurrency + ViewModels)

## Findings Source

Revisão cross-AI com o mesmo prompt, independente, 2026-06-14:
- Claude Opus 4.8
- Gemini 2.5 Pro (via `gemini` CLI)
- Codex gpt-5.5 (via Siemens SDC LLM Gateway, `codex review`)

---

## Problemas identificados (consenso dos 3 modelos)

### 1. bridge.rs — 509-arm god dispatcher (Crítico — Rust)

**Ficheiro:** `Rust/core/src/bridge.rs` — 10.852 linhas
**Problema:** Um único `match request.method.as_str()` com 509 arms. Qualquer
mudança num domínio (metrics, sleep, capture, sync) toca neste ficheiro.
Merge conflicts garantidos. Impossível de navegar.

**Fix (todos concordam):**
```rust
// Antes — match com 509 arms num ficheiro único

// Depois — BridgeRouter trait + handlers por domínio
trait BridgeRouter {
    fn methods(&self) -> &[&str];
    fn handle(&self, method: &str, args: &Value, store: &GooseStore) -> BridgeResult;
}

// bridge/metrics.rs, bridge/sleep.rs, bridge/capture.rs, bridge/activity.rs
// bridge.rs reduz para ~100 linhas de routing

const ROUTERS: &[&dyn BridgeRouter] = &[
    &MetricsRouter,
    &SleepRouter,
    &CaptureRouter,
    &ActivityRouter,
    &DebugRouter,
];
```

**Referência de ficheiros:**
- `Rust/core/src/bridge.rs:2239` — início do match dispatcher
- Criar: `Rust/core/src/bridge/mod.rs`, `metrics.rs`, `sleep.rs`, `capture.rs`, `activity.rs`, `debug.rs`

---

### 2. store.rs — 9.790 linhas, 140 métodos públicos (Crítico — Rust)

**Ficheiro:** `Rust/core/src/store.rs`
**Problema:** Schema DDL, migrations, queries, e business logic numa única struct
`GooseStore` com 140 métodos. Dois impl blocks (linha 1055 e 7089).
Sem schema validation ao abrir a DB — se schema drift ocorrer, falha silenciosa.

**Fix:**
```rust
// Antes — impl GooseStore { 140 métodos }

// Depois — domain stores partilhando uma Connection
struct GooseStore { conn: Arc<Connection> }

impl GooseStore {
    fn sleep(&self) -> SleepStore { SleepStore(&self.conn) }
    fn capture(&self) -> CaptureStore { CaptureStore(&self.conn) }
    fn metrics(&self) -> MetricsStore { MetricsStore(&self.conn) }
    fn activity(&self) -> ActivityStore { ActivityStore(&self.conn) }
}

// store/schema.rs — DDL + migrations
// store/sleep.rs  — SleepStore queries
// store/capture.rs — CaptureStore queries
// store/metrics.rs — MetricsStore queries

// Runtime schema validation ao abrir:
fn validate_schema(conn: &Connection) -> GooseResult<()> {
    let version: u32 = conn.pragma_query_value(None, "user_version", |r| r.get(0))?;
    if version != CURRENT_SCHEMA_VERSION {
        return Err(GooseError::schema_mismatch(version, CURRENT_SCHEMA_VERSION));
    }
    Ok(())
}
```

**Referências:**
- `Rust/core/src/store.rs:1133` — schema DDL inline
- `Rust/core/src/store.rs:8918` — `device_type_name()`
- Criar: `Rust/core/src/store/mod.rs`, `schema.rs`, `migrations.rs`, `sleep.rs`, `capture.rs`, `metrics.rs`

---

### 3. 133 `.unwrap()` em código de produção (Crítico — Rust)

**Ficheiros:** bridge.rs (71 ocorrências), store.rs (62 ocorrências)
**Problema:** Rust panic através do FFI boundary = crash iOS sem stack trace útil.
Qualquer frame BLE malformado, row inesperado na DB, ou edge case numérico derruba a app.

**Fix (Codex insight — o mais elegante):**
```rust
// Compilador rejeita unwrap() em código não-teste:
#[cfg_attr(not(test), deny(clippy::unwrap_used))]
mod production_core {}

// Antes:
finite.sort_by(|a, b| a.partial_cmp(b).unwrap());
let score = recovery_score.unwrap() * 0.5;

// Depois:
finite.sort_by(|a, b| a.total_cmp(b));  // f64::total_cmp não falha

fn required<T>(value: Option<T>, field: &'static str) -> GooseResult<T> {
    value.ok_or_else(|| GooseError::invalid_data(format!("{field} is required")))
}
let score = required(recovery_score, "recovery_score")? * 0.5;
```

**Opus insight adicional:**
```rust
// Bridge endpoint wraps dispatch em catch_unwind como safety net temporária:
let result = std::panic::catch_unwind(|| dispatch(req))
    .unwrap_or_else(|_| bridge_error(&id, "panic", "internal error"));
```

---

### 4. HealthDataStore ownership invertida (Importante — Swift)

**Ficheiro:** `GooseSwift/AppShellView.swift:22`
**Problema:** `HealthDataStore` é criado como `@StateObject` numa SwiftUI View.
`GooseAppModel` tem uma `weak var healthStore` de volta — circular ownership.
SwiftUI views são transientes e podem ser recriadas, destruindo a store.

**Fix (consenso dos 3):**
```swift
// Antes:
struct AppShellView: View {
    @StateObject private var healthStore = HealthDataStore()
    // GooseAppModel tem weak var de volta para isto
}

// Depois:
@main struct GooseSwiftApp: App {
    @StateObject var model = GooseAppModel()
    // model.healthStore é a única instância, owned pelo coordinator

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.healthStore)
        }
    }
}

final class GooseAppModel: ObservableObject {
    let healthStore = HealthDataStore()  // strong, single owner
    // sem weak ref, sem callback closures circulares
}
```

**Referências:**
- `GooseSwift/GooseBLEClient.swift:275` — `activeDeviceGeneration: WhoopGeneration = .gen5`
- `GooseSwift/AppShellView.swift` — onde HealthDataStore é criado hoje

---

### 5. GooseBLEClient → actor + AsyncStream + DeviceCatalog (Codex — o mais moderno)

**Ficheiro:** `GooseSwift/GooseBLEClient.swift` + extensões — 1.065 linhas, sem protocolo
**Problema:** Callbacks CoreBluetooth, histórico sync, HR monitor, battery inference,
command sequencing, reconnect logic — tudo numa classe sem boundary. Inestável para testes.

**Fix (insight único do Codex — structured concurrency iOS 26):**
```swift
// Protocolo limpo para transporte BLE:
protocol BLETransport {
    var events: AsyncStream<BLEEvent> { get }
    func scan() async throws
    func connect(_ device: BLEDeviceID) async throws
    func write(_ command: BLECommand, to: BLECharacteristicID) async throws
}

// Actor que coordena a sessão (thread-safe por design):
actor BLESessionCoordinator {
    private let transport: BLETransport
    private let deviceCatalog: DeviceCatalog

    func run() async {
        for await event in transport.events {
            let profile = deviceCatalog.profile(for: event)
            await route(event, using: profile)
        }
    }
}

// DeviceCatalog — ÚNICO lugar onde Gen4/Gen5 é conhecido:
struct DeviceProfile {
    let generation: DeviceGeneration    // .gen4 | .gen5 | .hrMonitor
    let frameHeaderLength: Int          // 4 ou 8
    let historicalSync: HistoricalSyncProtocol
    let capabilities: DeviceCapabilities
}

struct DeviceCatalog {
    func profile(for event: BLEEvent) -> DeviceProfile { ... }
}
// Nenhum outro código sabe que gerações existem
```

**Nota:** Esta abordagem alinha-se com SEED-003 (DeviceCapabilities) e complementa-a.
A `DeviceCatalog` aqui é equivalente ao `device.capabilities` bridge method do SEED-003.

**Target shape:**
- `CoreBluetoothBLETransport` — só fala com CoreBluetooth
- `BLESessionCoordinator` (actor) — connection/reconnect/session policy
- `HistoricalSyncCoordinator` — histórico sync state machine
- `LiveVitalsCoordinator` — HR/HRV realtime pipeline
- `DeviceCatalog` — todo o branching Gen4/Gen5 centralizado

---

### 6. GooseAppModel → domain ViewModels (Gemini — perf win)

**Problema:** 180+ `@Published` properties num único `@Observable` class.
Qualquer update (heart rate a cada segundo) invalida TODAS as views que observam GooseAppModel.

**Fix:**
```swift
// Antes — todas as views re-renderizam em cada BLE update
class GooseAppModel: ObservableObject {
    @Published var currentHeartRate: Int = 0
    @Published var dailySleepScore: Int = 0
    @Published var isUploadingToServer: Bool = false
    // ... 177 mais
}

// Depois — re-renders isolados por domínio:
@Observable class BLEState     { var currentHeartRate: Int = 0 }
@Observable class SyncState    { var isUploading: Bool = false }
@Observable class HealthState  { var dailySleepScore: Int = 0 }

// GooseAppModel torna-se coordinator thin:
@Observable class GooseAppModel {
    let ble = BLEState()
    let sync = SyncState()
    let health = HealthState()
}
// Views observam apenas o domínio relevante — sem re-renders desnecessários
```

---

## Ordem de execução sugerida

```
Sprint 1 (segurança, sem impacto UX):
  ↳ #[deny(clippy::unwrap_used)] + catch_unwind no bridge
  ↳ Runtime schema validation ao abrir SQLite

Sprint 2 (Rust — sem toque no Swift):
  ↳ bridge.rs → BridgeRouter trait + handlers por domínio
  ↳ store.rs → domain stores + migrations module

Sprint 3 (Swift ownership):
  ↳ HealthDataStore → owned por GooseAppModel
  ↳ Remove weak ref + callbacks circulares

Sprint 4 (Swift concurrency + perf):
  ↳ GooseBLEClient → BLETransport + BLESessionCoordinator (actor)
  ↳ DeviceCatalog (alinha com SEED-003)

Sprint 5 (Swift ViewModels):
  ↳ GooseAppModel → domain @Observable objects
  ↳ Views observam só o domínio relevante
```

## Seeds relacionadas

- `SEED-003` — Gen4/Gen5 protocol refactor; DeviceCatalog (#5 aqui) complementa DeviceCapabilities do SEED-003
- `SEED-002` — battery level; beneficia de DeviceCatalog (capability `battery_via_r22`)

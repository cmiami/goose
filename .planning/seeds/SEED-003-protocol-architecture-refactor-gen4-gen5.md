---
id: SEED-003
status: dormant
planted: 2026-06-14
planted_during: v11.0 — PR Integration, Code Health & App Polish
trigger_when: next major milestone (v12.0+) focused on code health or BLE reliability
scope: medium
---

# SEED-003: Protocol Architecture Refactor — Gen4/Gen5 Capability Model

## Why This Matters

O codebase mistura identidade de dispositivo (Maverick, Puffin, Goose), família de protocolo wire (Gen4 vs Gen5) e capabilities de feature num único `DeviceType` enum. Isto resulta em:
- 17 string comparisons `rustDeviceType == "GEN4"` espalhadas pelo Swift
- 8 guards `activeDeviceGeneration == .gen4` em 6 ficheiros de extensão
- Frame reassembly duplicado (Swift faz o mesmo que o Rust)
- Sem forma de expressar "esta feature existe neste dispositivo" sem olhar para a geração

A fix é clean, não tem impacto visível para o utilizador, e desbloqueia a adição de features futuras (bateria, R22) de forma declarativa.

## When to Surface

**Trigger:** next milestone focused on code health, BLE reliability, or protocol features (v12.0+)

Surface também quando:
- For adicionada suporte para um novo dispositivo/geração
- For implementada a bateria (Phase 81 / SEED-002) — a `DeviceCapabilities` struct aqui definida é o lugar certo para `battery_via_r22` e `battery_via_event48`
- Qualquer contribuidor externo tentar adicionar Gen6 ou terceiro fabricante

## Scope Estimate

**Medium** — ~2-3 dias de trabalho focado, 3 PRs incrementais:
1. Rust types (`WireProtocol`, `DeviceKind`, `DeviceCapabilities`, `is_gen5_family()`)
2. DB migration + bridge method `device.capabilities`
3. Swift cleanup (substituir string comparisons e guards)

## Decisions Already Made

Esta seed tem contexto completo de uma sessão de discuss-phase. Ver:
- `.planning/phases/83-protocol-architecture-refactor-gen4-gen5-capability-model/83-CONTEXT.md` — todas as decisões de implementação
- `.planning/phases/83-protocol-architecture-refactor-gen4-gen5-capability-model/83-DISCUSSION-LOG.md` — alternativas consideradas

### Decisões chave (resumo):

**Fronteira Rust/Swift:**
- Buffer de frame reassembly fica em Swift (preserva stateless bridge invariant)
- `rustDeviceType` computed property substituído por `WireProtocol` Swift enum
- Swift substitui string comparisons por `wireProtocol == .gen4` checks

**DeviceCapabilities:**
- Definido em Rust, exposto via bridge method `device.capabilities(device_kind)`
- Inclui capabilities actuais E futuras: `historicalSync`, `battery_via_r22`, `battery_via_event48`, `battery_via_cmd26`, `r22_realtime`
- Chamado logo após GATT discovery; cached em `connectedCapabilities: DeviceCapabilities?` (nil = desligado)
- `activeDeviceGeneration: WhoopGeneration = .gen5` substituído por `connectedCapabilities`

**DB Migration:**
- Automática no init SQLite: `UPDATE decoded_frames SET device_type = 'GOOSE' WHERE device_type IN ('MAVERICK', 'PUFFIN')`
- `parse_device_type("MAVERICK"/"PUFFIN")` passa a rejeitar com erro (breaking, intencional)

**Novos tipos Rust:**
- `WireProtocol { Gen4, Gen5 }` — conduz parsing decisions
- `DeviceKind { Whoop4, Whoop5, HrMonitor }` — identidade/DB/logs
- `DeviceCapabilities` struct derivada de `DeviceKind`
- `is_gen5_family()` método em `DeviceType` como cleanup interim
- `Puffin` documentado como "hardware code name, unshipped, parses as Gen5"

**Testes:**
- Unit tests Rust para `DeviceCapabilities`, `WireProtocol`, migration idempotency
- `cargo test --locked` clean; iOS build sem novos warnings
- Sem verificação manual no simulador (zero impacto UX)

## Breadcrumbs

**Análise completa em:**
- `.planning/phases/83-protocol-architecture-refactor-gen4-gen5-capability-model/83-CONTEXT.md`
- `docs/architecture/gen4-historical-sync.md` — wire-level differences documentadas

**Ficheiros Rust a alterar:**
- `Rust/core/src/protocol.rs:27-68` — onde `WireProtocol` e `DeviceKind` são adicionados
- `Rust/core/src/bridge.rs:9510-9523` — `parse_device_type()` rejeita MAVERICK/PUFFIN
- `Rust/core/src/store.rs:8918-8924` — `device_type_name()` serialização DB
- `Rust/core/src/openwhoop_reference.rs:166-175` — `whoop_generation_from_device_type()` alinha com DeviceCapabilities

**Ficheiros Swift a alterar:**
- `GooseSwift/GooseBLETypes.swift:75-88` — `rustDeviceType` → `WireProtocol` enum
- `GooseSwift/GooseBLETypes.swift:209-270` — `WhoopGeneration` base para `WireProtocol`
- `GooseSwift/GooseBLEClient.swift:275` — `activeDeviceGeneration` → `connectedCapabilities`
- `GooseSwift/GooseAppModel+NotificationPipeline.swift:823-835` — 17 string comparisons
- `GooseSwift/GooseBLEClient+HistoricalHandlers.swift` — 6 guards
- `GooseSwift/GooseBLEClient+HistoricalCommands.swift` — 2 guards

**Seeds relacionadas:**
- `SEED-002` — battery protocol offsets; `DeviceCapabilities` aqui é o lugar certo para as battery capabilities

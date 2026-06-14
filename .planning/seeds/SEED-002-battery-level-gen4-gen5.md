---
id: SEED-002
status: dormant
planted: 2026-06-14
planted_during: v11.0 — PR Integration, Code Health & App Polish
trigger_when: when relevant
scope: unknown
---

# SEED-002: Battery level Gen4+Gen5 — protocolo reverse-engineered no noop/PostHooks.swift

## Why This Matters

O WHOOP 4.0 reporta sempre 100% na característica GATT standard `0x2A19`. O nível real de
bateria está disponível via protocolo proprietário WHOOP, já completamente reverse-engineered
no repo `tigercraft4/noop`. O Rust core do goose também já parseia `battery_pct` de pacotes
R22 (Gen5), mas o bridge ignora o campo. Fix relativamente pequeno com grande impacto de UX.

## When to Surface

**Trigger:** when relevant

Este seed deve surfaçar num milestone focado em BLE/protocol, device health, ou melhorias de UX
para utilizadores Gen4.

## Scope Estimate

**Unknown** — estimativa inicial: Small-Medium.
- Gen5 fix: ~2 linhas no bridge (trivial)
- Gen4 fix: ~30-50 linhas Rust no protocol.rs/bridge.rs + Swift handler

## Breadcrumbs

**Protocolo documentado em:**
- `tigercraft4/noop` — `Packages/WhoopProtocol/Sources/WhoopProtocol/PostHooks.swift`

**Rust core (goose) — onde implementar:**
- `Rust/core/src/protocol.rs:660` — `battery_pct` já parseado em R22Whoop5Hr (Gen5)
- `Rust/core/src/bridge.rs:3697` — R22Whoop5Hr handler ignora battery_pct com `..`
- `Rust/core/src/bridge.rs:3512` — array `battery` declarado sem `mut`, nunca populado

**Swift (goose) — onde consumir:**
- `GooseSwift/GooseBLEClient+Parsing.swift:26` — `applyBatteryLevel(_:capturedAt:sourceTitle:)`

**Issue relacionado:** tigercraft4/goose#149 — "Battery always 100%" (Gen4, reportado por Chopin85)

## Offsets do protocolo (de noop/PostHooks.swift, verificados empiricamente)

### Path 1 — Evento BATTERY_LEVEL (evento 48, emitido ~a cada 8 min automaticamente)
```
soc%     = u16 @ offset 17 / 10   (guard raw <= 1100)
mV       = u16 @ offset 21        (guard 3000...4300)
charging = u8  @ offset 26, bit0  (guard ch <= 1)
```

### Path 2 — Resposta ao comando GET_BATTERY_LEVEL (cmd 26)
```
battery_pct = u16(pay[2] | pay[3] << 8) / 10   (guard pay.count >= 4)
```

### Path 3 — Resposta ao GET_EXTENDED_BATTERY_INFO
```
battery_mV = u16(pay[7] | pay[8] << 8)          (guard pay.count >= 9)
```

### Gen5 — R22 realtime packet (já parseable, só falta expor)
```rust
// protocol.rs:660 — já existe:
let battery_pct = payload[1];
// bridge.rs:3697 — ignorado:
DataPacketBodySummary::R22Whoop5Hr { hr_bpm, .. } => { ... }
// Fix: extrair battery_pct e popular o array `battery`
```

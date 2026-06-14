# Phase 83: Protocol Architecture Refactor — Gen4/Gen5 Capability Model - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-14
**Phase:** 83-Protocol Architecture Refactor — Gen4/Gen5 Capability Model
**Areas discussed:** Fronteira Rust/Swift, DeviceCapabilities shape, Migração da DB, Testes e verificação

---

## Fronteira Rust/Swift

| Option | Description | Selected |
|--------|-------------|----------|
| Tudo para Rust | Swift envia raw bytes, Rust faz reassembly + parse completo | ✓ |
| Só limpar strings | Manter reassembly em Swift, substituir strings por WireProtocol enum | |
| Híbrido | Mover reassembly para Rust agora, guards activeDeviceGeneration depois | |

**User's choice:** Tudo para Rust (swift envia raw bytes)

| Option | Description | Selected |
|--------|-------------|----------|
| Buffer no Rust (stateful bridge) | Rust mantém buffer por characteristic UUID | |
| Buffer no Swift, parse no Rust | Swift acumula, Rust parseia frames completos | |
| Você decide | Decisão arquitectural delegada a Claude | ✓ |

**Claude's decision on buffer:** Buffer fica em Swift — preserva o invariante de stateless bridge documentado no CLAUDE.md. Swift detecta frame boundaries, Rust parseia.

| Option | Description | Selected |
|--------|-------------|----------|
| WireProtocol enum em Swift | Substituir computed property por enum derivado de WhoopGeneration | ✓ |
| Manter rustDeviceType mas tipar | Duas fontes de verdade temporárias | |

**User's choice:** WireProtocol enum em Swift

---

## DeviceCapabilities Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Só o que substitui guards existentes | historicalSyncProtocol e wireProtocol apenas | |
| Incluir battery e R22 já | batteryViaR22, batteryViaEvent48, r22Realtime incluídos agora | ✓ |
| Você decide | Pragmático | |

**User's choice:** Incluir battery e R22 já — evita segunda passagem

| Option | Description | Selected |
|--------|-------------|----------|
| Definido em Rust, exposto via bridge | `device.capabilities(device_kind)` retorna JSON | ✓ |
| Definido em Swift | Swift conhece capabilities por geração | |

**User's choice:** Definido em Rust — fonte única de verdade, Android herda

| Option | Description | Selected |
|--------|-------------|----------|
| Logo após GATT discovery | Chamado quando WhoopGeneration é detectado, cached em connectedCapabilities | ✓ |
| Na primeira notificação BLE | Lazy — race condition possível | |

**User's choice:** Logo após GATT discovery

---

## Migração da DB

| Option | Description | Selected |
|--------|-------------|----------|
| Migration automática no init SQLite | UPDATE decoded_frames SET device_type = 'GOOSE' WHERE device_type IN ('MAVERICK', 'PUFFIN') | ✓ |
| Script manual separado | SQL para o utilizador correr manualmente | |

**User's choice:** Migration automática no init SQLite — idempotente, transparente

| Option | Description | Selected |
|--------|-------------|----------|
| Manter compat, mapear para GOOSE | parse_device_type("MAVERICK") continua a funcionar | |
| Deprecar e rejeitar | parse_device_type rejeita MAVERICK/PUFFIN com erro | ✓ |

**User's choice:** Deprecar e rejeitar — mais limpo; logs antigos são human-readable

---

## Testes e Verificação

| Option | Description | Selected |
|--------|-------------|----------|
| Cargo test passa + testes novos para capabilities | Unit tests Rust para DeviceCapabilities, WireProtocol, migration | ✓ |
| Só cargo test passa | Sem testes novos | |
| Testes completos incluindo integração Swift | Rust + iOS build + simulador manual | |

**User's choice:** Cargo test + testes novos para capabilities e migration

---

## Claude's Discretion

- Buffer state location: Swift (preserva stateless bridge invariant)
- Module placement de DeviceCapabilities: bridge.rs ou novo capabilities.rs — a cargo do planner
- Localização de WireProtocol: protocol.rs ou novo wire.rs — a cargo do planner

## Deferred Ideas

- Battery feature UI (mostrar % real na app) → Phase 81
- HealthKit persistence → Phase 82
- Mover frame reassembly totalmente para Rust (stateful bridge) → discussão futura sobre statefulness
- Gen6 / third-party device support → milestone futuro

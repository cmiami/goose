---
id: SEED-005
status: dormant
planted: 2026-06-14
planted_during: v11.0 — PR Integration, Code Health & App Polish
trigger_when: milestone de code health (v12.0+), idealmente após SEED-004 splits estarem feitos
scope: small
---

# SEED-005: Targeted Code Comments — WHY not WHAT

## Why This Matters

O codebase tem zero `///` doc comments e comentários esparsos. Após os refactors estruturais
(SEED-003, SEED-004), os ficheiros vão ser mais pequenos e mais fáceis de anotar.
Comentários no lugar certo evitam que o próximo contribuidor quebre invariantes silenciosos.

## Regra — o que comentar

**Comentar apenas quando:** remover o comentário deixaria o código confuso para um leitor
competente que não estava presente quando foi escrito.

**Não comentar:** o que o código já diz por nomes. Zero comentários tipo `// Parse battery`.

## Targets de alta prioridade

### 1. Offsets de protocolo WHOOP (empíricos — contexto perdido sem comentário)

```rust
// BATTERY_LEVEL event (type 48) payload layout — empirically verified against
// captured frames from WHOOP 4.0 and 5.0. Emitted ~every 8 min automatically.
//   offset 17: soc% as u16 little-endian, divide by 10. Guard: raw <= 1100.
//   offset 21: mV  as u16 little-endian. Guard: 3000..=4300.
//   offset 26: charging as u8, bit0 only. Guard: ch <= 1.
// Source: tigercraft4/noop — PostHooks.swift, verified 2026-06-14.
let battery_pct = u16::from_le_bytes([frame[17], frame[18]]) as f64 / 10.0;
```

```rust
// GET_BATTERY_LEVEL (cmd 26) command response layout:
//   payload[2..4]: battery_pct as u16 LE / 10. Guard: pay.count >= 4.
// GET_EXTENDED_BATTERY_INFO response:
//   payload[7..9]: battery_mV as u16 LE. Guard: pay.count >= 9.
```

### 2. Invariantes de threading (consequências reais se violados)

```swift
// GooseRustBridge is synchronous and blocks the calling thread.
// Never call from @MainActor — always dispatch to a background queue first.
// Multiple instances are intentional: each coordinator owns one.
// The Rust side is stateless; all state lives in SQLite.
```

```swift
// Frame reassembly buffer is guarded by frameReassemblyLock (NSLock).
// CoreBluetooth callbacks arrive on coreBluetoothQueue (serial).
// Side effects that touch @Published state must be dispatched to @MainActor.
```

### 3. Guard conditions não óbvios no protocolo

```swift
// Gen4 cmd 22 replies with `[echoed_seq, 0x02, 0x0b, 0x00, 0x00]`.
// The 0x02 in the result-code slot is a Gen4 success ack — NOT the Gen5
// PENDING code. Short-circuit here instead of waiting for the data stream.
if activeDeviceGeneration == .gen4 && pending.kind == .sendHistoricalData {
```

```rust
// R22 packets (WHOOP 5.0 BLE handle 0x0022) carry battery_pct at payload[1].
// This field is ignored here intentionally — it feeds the battery stream,
// not the HR stream. See bridge/battery.rs for the battery path.
DataPacketBodySummary::R22Whoop5Hr { hr_bpm, .. } => {
```

### 4. FFI safety contracts

```rust
/// # Safety
///
/// - `request_json` must be a valid, null-terminated UTF-8 C string.
/// - The pointer must remain valid for the duration of this call.
/// - The returned pointer is owned by the caller and must be freed via
///   `goose_bridge_free_string`. Do NOT pass to `free(3)` — the Rust
///   allocator backing `CString` may differ from the host allocator.
pub unsafe extern "C" fn goose_bridge_handle_json(request_json: *const c_char) -> *mut c_char {
```

### 5. Algoritmos com coeficientes empíricos

```rust
// Banister eTRIMP: HR reserve fraction per sample with gender-specific
// exponential weight. Coefficients: 1.92 (male) / 1.67 (female).
// Calibrated to WHOOP's 0–21 strain scale via regression on reference data.
// Reference: Banister et al. 1991; WHOOP internal scaling confirmed via
// Ghidra analysis of WHP* classes (2026-06-14).
let weight = if is_male { 1.92 } else { 1.67 };
```

## O que NÃO comentar

- Nomes de métodos que se explicam: `applyBatteryLevel`, `handleHistoricalSync`
- Loops e condições simples
- Código que já tem doc em `docs/architecture/`
- Anything that would be obvious to a competent Rust or Swift engineer

## Execução sugerida

Fazer em paralelo com SEED-004 (Fase A — Rust splits), porque:
- Ao partir bridge.rs em handlers por domínio, é o momento natural para anotar cada handler
- Ao partir store.rs em domain stores, é o momento de documentar o schema e as queries não óbvias
- Não faz sentido comentar 10K linhas num único ficheiro — faz sentido comentar módulos de 200-400 linhas

## Seeds relacionadas

- `SEED-003` — protocol arch refactor; os offsets de protocolo do ponto 1 acima são implementados nessa fase
- `SEED-004` — architectural overhaul; os splits do bridge/store são o trigger natural para esta seed

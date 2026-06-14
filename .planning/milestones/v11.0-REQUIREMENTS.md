# v11.0 Requirements — PR Integration, Code Health & App Polish

## PR-INT — Fork PRs (tigercraft4/goose)

- [ ] **PR-INT-01**: Utilizador vê os identificadores técnicos (UUIDs, raw values, sequence IDs) em secções avançadas em vez de nas vistas principais (#136)
- [ ] **PR-INT-02**: Home mostra baseline warm-up progress honesto e vitals state real em vez de estados estáticos (#135)
- [ ] **PR-INT-03**: App respeita preferência imperial/métrico para temperatura, distância, pace e elevação (#134)
- [ ] **PR-INT-04**: Inglês é a source language; todas as strings restantes da UI estão localizadas sem keys visíveis (#133)
- [ ] **PR-INT-05**: ChatGPT sign-in funciona correctamente a partir das Coach settings sem erro de autenticação (#132)
- [ ] **PR-INT-06**: App recupera leituras de device-info após firmware updates sem sync failure ou crash (#131)
- [ ] **PR-INT-07**: Utilizador vê progresso visual em tempo real do histórico sync como donut + completion protocol-driven (#137)

## PR-UP — Upstream PRs (b-nnett/goose)

- [ ] **PR-UP-01**: Operações pesadas na main thread são movidas para background queues; frame drops na Home e Health eliminados (#29)
- [ ] **PR-UP-02**: Chamadas FFI bridge bloqueantes são executadas em background thread; main thread nunca bloqueia em bridge calls (#12)
- [ ] **PR-UP-03**: Scroll em Home e Health views corre sem jitter; display-safety filter aplicado na ingestão (#4, #31)

## AUDIT — Análise do Codebase

- [ ] **AUDIT-01**: Mapa completo do codebase em 4 dimensões (arquitectura, tech stack, qualidade, concerns) produzido por agentes paralelos e commitado em `.planning/codebase/`
- [ ] **AUDIT-02**: Code review profundo (--depth=deep) nas fases 67-73 com todos os findings críticos e warnings documentados em REVIEW.md por fase
- [ ] **AUDIT-03**: Todos os findings críticos do AUDIT-02 resolvidos e commitados atomicamente

## PERF — Performance

- [ ] **PERF-01**: Queries SQLite do schema v20 (metricSeries, journal, workout, appleDaily) optimizadas com índices e query plans validados
- [ ] **PERF-02**: App startup time melhorado via lazy initialization dos componentes pesados (bridge, BLE client); primeiro frame renderizado antes de conexão BLE

## POLISH — App Polish

- [ ] **POL-01**: MoreDebugViews reorganizado em 3 tabs (Status / Capture / Research); Connection row aparece uma única vez; secções de 612 linhas divididas em child views
- [ ] **POL-02**: "Support" renomeado para "Logs & Export" e movido do grupo Support para Developer hub em MoreView; grupo Support contém apenas "About"

## BLE-REL — BLE Reliability

- [ ] **BLE-REL-01**: App faz retry automático de escrita BLE 2.5s após `CBATTError.insufficientAuthentication` em `didWriteValueFor`; se o retry também falhar, apresenta mensagem de erro accionável (issue #117, SEED-001)

## DEF — Deferred v10.0

- [ ] **DEF-01**: BreatheView chama `buzz(loops:1)` em cada transição de fase (inhale/hold/exhale) via `GooseBLEClient+Haptics`; sessão completamente paceada por haptic (HAP-02)
- [ ] **DEF-02**: `GooseStrainAccumulator` Swift-side publica `liveWorkoutStrain` em tempo real durante sessão activa a partir de amostras HR do `WhoopDataSignalPipeline`; tile de strain atualiza durante workout (DATA-02)

## Future Requirements

### Hardware Gate
- BLE5-01: WHOOP 5.0 R22 realtime metrics — requer device WHOOP 5.0 físico para validação
- BLE5-02: V18 per-second historical decode — requer device WHOOP 5.0 físico
- HAP-04: Wake-window engine — RE-gated (BTSnoop STRAP_DRIVEN_ALARM_EXECUTED + Ghidra decompile SetAlarmInfoCommandPacketRev4)
- CAPSENSE-01: Cap sense / on-wrist detection — hardware gate GATT UUID não identificado

## BUG — Bugs adicionados ao backlog (issues #130, #149, #150)

- [ ] **BUG-HR-01**: Resting HR não mostra valores implausíveis (< 30 bpm) originados por historical sync — filtro fisiológico aplicado em `metric_features.rs` (#130)
- [ ] **BUG-BAT-01**: Nível de bateria reflecte o estado real (não sempre 100%) em dispositivos Gen4/Gen5 (#149)
- [ ] **BUG-HK-01**: Dados importados via "Import from Apple Health" são persistidos em SQLite e sobrevivem ao relaunch (#150)

### Out of Scope (v11.0)
- Server-side dashboard / analytics
- Full Android app
- Background URLSession para uploads suspensos
- OAuth / 2FA
- Sync data to Apple Home / Bevel integration (#109)

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PR-INT-01 | Phase 74 | Pending |
| PR-INT-02 | Phase 75 | Pending |
| PR-INT-03 | Phase 74 | Pending |
| PR-INT-04 | Phase 74 | Pending |
| PR-INT-05 | Phase 74 | Pending |
| PR-INT-06 | Phase 75 | Pending |
| PR-INT-07 | Phase 75 | Pending |
| PR-UP-01 | Phase 76 | Pending |
| PR-UP-02 | Phase 76 | Pending |
| PR-UP-03 | Phase 76 | Pending |
| AUDIT-01 | Phase 77 | Pending |
| AUDIT-02 | Phase 77 | Pending |
| AUDIT-03 | Phase 77 | Pending |
| PERF-01 | Phase 78 | Pending |
| PERF-02 | Phase 78 | Pending |
| BLE-REL-01 | Phase 78 | Pending |
| POL-01 | Phase 79 | Pending |
| POL-02 | Phase 79 | Pending |
| DEF-01 | Phase 79 | Pending |
| DEF-02 | Phase 79 | Pending |
| BUG-HR-01 | Phase 80 | Pending |
| BUG-BAT-01 | Phase 81 | Pending |
| BUG-HK-01 | Phase 82 | Pending |

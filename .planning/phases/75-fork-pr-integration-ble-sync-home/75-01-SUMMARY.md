---
plan: 75-01
status: complete
requirements: PR-INT-02
duration: integrated via cherry-pick from PR #131
files_modified: 4
---
# Summary: BLE Firmware Recovery (PR-INT-02)

Integrated PR #131 (cmiami:pr/ble-robustness) — 2 commits:
- `fix(ble): recover device-info reads after strap firmware updates` — adds `metadataReadRetriesRemaining` counter; GATT Device Information service characteristics retried when iOS serves stale attribute cache after firmware update
- `fix(ble): remove unused sync-state callback capture` — removes noop `onSyncStateChange` closure

## Acceptance criteria met
- [x] App re-reads device-info via BLE retry after firmware updates
- [x] No crash or sync failure dialog shown
- [x] Build passes
- [ ] End-to-end test with real firmware update — human_needed (hardware gate)

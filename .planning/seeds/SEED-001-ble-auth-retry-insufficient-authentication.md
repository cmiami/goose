---
id: SEED-001
status: resolved
implemented_in: Phase 78 (BLE auth retry, BLE-REL-01)
planted: 2026-06-13
planted_during: v10.0 / Phase 68 shipped
trigger_when: when fixing issue #117 authentication error or any BLE write reliability work
scope: Small
---

# SEED-001: BLE auth retry on insufficientAuthentication (issue #117 RC2 follow-up)

## Why This Matters

When CoreBluetooth delivers `CBATTError.insufficientAuthentication` to `didWriteValueFor`,
iOS may have already initiated BLE pairing in the background. If the device accepts the
pairing request, the link becomes encrypted — but CoreBluetooth does NOT automatically
retry the failed write. Without a manual retry, the user sees a sync failure even though
pairing succeeded a few seconds later.

A one-shot 2.5 s retry covers this race at negligible cost (one extra write attempt).
If the retry also fails, fall through to the actionable error message (already planned as
the immediate fix for issue #117).

## When to Surface

**Trigger:** when fixing issue #117 or any BLE write reliability work

This is a direct follow-up to the immediate fix (actionable error message). It should be
implemented in the same PR or immediately after.

## Scope Estimate

**Small** — targeted change to `didWriteValueFor` and `GooseBLEHistoricalManager`.

Implementation outline:
1. Add `authRetryAttempted: Bool = false` to the historical manager (same pattern as
   `historicalRangeRetryCount` already present).
2. In `peripheral(_:didWriteValueFor:error:)`, when `isBondLossError(error)` is true and
   `!historicalManager.authRetryAttempted`:
   - Set `historicalManager.authRetryAttempted = true`
   - Delay 2.5 s via `DispatchQueue.main.asyncAfter`
   - Resend `historicalManager.pendingHistoricalCommand` without calling `failHistoricalSync`
3. On the second auth error (or if `pendingHistoricalCommand` is nil at retry time),
   call `failHistoricalSync` with the actionable message.
4. Reset `authRetryAttempted = false` inside `failHistoricalSync` and
   `completeHistoricalSync` so the flag is clean for the next sync.

## Breadcrumbs

- `GooseSwift/GooseBLEClient+PeripheralDelegate.swift:318` — `didWriteValueFor` handler;
  where the retry logic goes
- `GooseSwift/GooseBLEClient+CentralDelegate.swift:248` — `isBondLossError()` definition
  (already covers `CBATTError.insufficientAuthentication`)
- `GooseSwift/GooseBLEClient+CentralDelegate.swift:290` — only current call site of
  `isBondLossError()` (wrong event — misses the write path entirely)
- `GooseSwift/GooseBLEClient+HistoricalHandlers.swift:748` — `failHistoricalSync()`
  implementation; reset `authRetryAttempted` here
- Issue #117: https://github.com/tigercraft4/goose/issues/117

## Notes

The seed for the RC1 state machine fix (no public API to detect link encryption) is
captured separately as SEED-002. That one is larger and optional; this one is small and
should follow the immediate fix closely.

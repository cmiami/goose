---
phase: 68-ble-manager-refactor-data-validator
fixed_at: 2026-06-13T00:00:00Z
review_path: .planning/phases/68-ble-manager-refactor-data-validator/68-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 1
skipped: 6
status: partial
---

# Phase 68: Code Review Fix Report

**Fixed at:** 2026-06-13
**Source review:** .planning/phases/68-ble-manager-refactor-data-validator/68-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (CR-01, CR-02, CR-03, WR-01, WR-02, WR-03, WR-04)
- Fixed: 1
- Skipped: 6 (already fixed in codebase prior to this run)

---

## Fixed

### WR-01 — Accepted/rejected frame count not logged after validator filter

**Commit:** `5dfced6`
**File:** `GooseSwift/GooseAppModel+NotificationPipeline.swift`

Added `dataValidator.validate(frameHex:deviceID:)` filter inside `notificationParseQueue.async` before `parseBatch`. Invalid frames are excluded from `frameHexes`. When `rejectedCount > 0`, logs via `ble.record(level: .warn, source: "ble.validator", title: "frame.validator.rejected", body: "rejected=N accepted=M total=T")`.

---

## Skipped (already fixed in codebase)

### CR-01 — GooseBLEHistoricalManager NSLock
`GooseBLEHistoricalManager.swift` has no `NSLock`. The `beginSync`/`completeSync`/`failSync` methods call callbacks directly. A main-thread-only contract comment is present. **Already fixed.**

### CR-02 — dataValidator struct mutation semantics
`dataValidator` is already declared as `let` (line 102 of `GooseBLEClient.swift`). `GooseBLEDataValidator` is already a `final class` (reference semantics), so callback wiring is stable on reassignment. **Already fixed.**

### CR-03 — onInvalidFrame uses Task { @MainActor } fire-and-forget
The callback already uses `DispatchQueue.main.async { self?.invalidFrameCount += 1 }`. No `Task { @MainActor in }` present. **Already fixed.**

### WR-02 — historicalPacketCount reset bypasses manager
`beginHistoricalSync` no longer has a direct `historicalPacketCount = 0`. It calls `publishHistoricalPacketCountIfNeeded(force: true)` after resetting `historicalManager.historicalPacketsReceivedThisSync = 0`. **Already fixed.**

### WR-03 — historicalDataResultPayload off-by-one guard
Guard already uses `>= 21` (line 884 of `GooseBLEClient+Parsing.swift`). **Already fixed.**

### WR-04 — ISO8601DateFormatter allocated per historical packet
Line 45 of `GooseBLEClient+HistoricalHandlers.swift` already uses `GooseBLEClient.diagnosticLogFormatterLock.withLock { GooseBLEClient.diagnosticLogFormatter.string(from: Date()) }`. **Already fixed.**

---

_Reviewer: Claude (gsd-code-fixer)_
_Depth: standard_

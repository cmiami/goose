---
phase: 68
status: issues_found
critical_count: 0
warning_count: 3
---
# Code Review: Phase 68 — BLE Manager Refactor + Data Validator

## Summary

Phase 68 extracts historical sync bookkeeping into `GooseBLEHistoricalManager` and adds `GooseBLEDataValidator` as a structural frame gate before the Rust bridge. The separation of concerns is clean and the validator's hex-decode loop is correct. However, three warnings are found: a planning/code discrepancy (`struct` in SUMMARY vs `final class` in code), a double-dispatch in `publishPacketCount`, and an inconsistency in how `invalidFrameCount` is incremented relative to the codebase's established `@Observable` mutation pattern. No critical bugs found.

> Note: An earlier review (2026-06-12) exists with different findings. This pass is an independent adversarial review of the same files.

---

## Findings

### [WARNING] `GooseBLEDataValidator` is `final class` in code but `struct` in SUMMARY — `let` storage inconsistency

**File:** `GooseSwift/GooseBLEDataValidator.swift:9` and `GooseSwift/GooseBLEClient.swift:123`

**Description:**
The phase-68-02 SUMMARY states "Type: `struct GooseBLEDataValidator` (value type per CONTEXT.md)". The actual implementation at line 9 is `final class GooseBLEDataValidator`. The plan's reasoning — that a `struct` requires `var` storage on the owner — is correct. However, the implementation correctly used `final class`, which allows `let` ownership at the call site. Despite that, `GooseBLEClient` line 123 declares it as `let dataValidator = GooseBLEDataValidator()`, which works correctly for a class.

The discrepancy matters for two reasons:

1. The SUMMARY documentation is wrong, creating a maintenance hazard for any future refactor guided by that document.
2. Any future agent reading the SUMMARY would try to reason about struct-copy semantics (e.g., "the closure captures a copy of the struct") — which is incorrect for the actual class implementation. An agent that followed the SUMMARY and converted the implementation to `struct` would silently lose the `onInvalidFrame` wiring unless `GooseBLEClient` changed `let` to `var`.

**Fix:** No code change needed — the `final class` declaration is correct. Update the SUMMARY to reflect the actual type:

```
Type: `final class GooseBLEDataValidator` (reference type — required to hold the mutable onInvalidFrame closure without forcing var ownership on GooseBLEClient)
```

---

### [WARNING] `publishPacketCount` double-dispatches to main — callback already hops inside wiring site

**File:** `GooseSwift/GooseBLEHistoricalManager.swift:108–112` and `GooseSwift/GooseBLEClient.swift:1030–1035`

**Description:**
`publishPacketCount` wraps `onPacketCountChange?()` in `DispatchQueue.main.async`:

```swift
func publishPacketCount(_ count: Int) {
  DispatchQueue.main.async { [weak self] in
    self?.onPacketCountChange?(count)
  }
}
```

But the wiring in `GooseBLEClient.init` (lines 1030–1034) already hops to the main actor before mutating `historicalPacketCount`:

```swift
historicalManager.onPacketCountChange = { [weak self] count in
  guard let self else { return }
  Task { @MainActor in
    self.historicalPacketCount = count
  }
}
```

The `DispatchQueue.main.async` inside `publishPacketCount` therefore creates an unnecessary double-hop: `DispatchQueue.main.async { self?.onPacketCountChange?(count) }` fires the callback on main, which then immediately enqueues a `Task { @MainActor in }` — another async hop. On the main thread, `Task { @MainActor in }` queues through the Swift cooperative executor, not synchronously. The increment of `historicalPacketCount` is thus deferred one extra turn of the cooperative loop beyond where the caller expects it.

Also, the `[weak self]` capture in `publishPacketCount`'s dispatch block captures the *manager* (not the client). If the manager is released between the dispatch and the callback execution, the `onPacketCountChange` call is silently dropped.

**Fix:** Remove the dispatch wrapper from `publishPacketCount` and call the callback directly. The caller (or the wiring site in `GooseBLEClient`) is responsible for the main-thread hop:

```swift
func publishPacketCount(_ count: Int) {
  onPacketCountChange?(count)
}
```

The class comment already states "All mutation methods and callbacks must be called on the main thread" — so callers are already on main, making the async dispatch both redundant and semantically inconsistent.

---

### [WARNING] `invalidFrameCount` incremented via `DispatchQueue.main.async` — inconsistent with `Task { @MainActor }` used three lines above

**File:** `GooseSwift/GooseBLEClient.swift:1036–1039`

**Description:**
The `onInvalidFrame` callback uses `DispatchQueue.main.async`:

```swift
dataValidator.onInvalidFrame = { [weak self] in
  DispatchQueue.main.async {
    self?.invalidFrameCount += 1
  }
}
```

Three lines above (lines 1030–1034), the `onPacketCountChange` callback uses `Task { @MainActor in ... }`. The inconsistency is minor functionally — both ultimately execute on the main thread — but it creates ambiguity about the project's intended pattern for `@Observable` state mutations from background closures. In Swift 6 strict concurrency, mixing `DispatchQueue.main.async` and `Task { @MainActor }` for the same class's state updates can produce unexpected ordering under the cooperative scheduler (GCD tasks run on the main *thread*; Swift actors run on the main *actor executor*, which is distinct).

More concretely: `GooseBLEClient` is `@Observable`. In a strict concurrency context, mutating `invalidFrameCount` via `DispatchQueue.main.async` does not cross an actor boundary — it posts to a GCD queue, not to the actor executor — which may trigger a compiler warning under Swift 6 strict concurrency (`@Observable` properties should be mutated on the main actor).

**Fix:** Use `Task { @MainActor [weak self] in ... }` to match the established pattern and satisfy strict concurrency:

```swift
dataValidator.onInvalidFrame = { [weak self] in
  Task { @MainActor [weak self] in
    self?.invalidFrameCount += 1
  }
}
```

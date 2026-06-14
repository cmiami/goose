---
phase: 69
status: issues_found
critical_count: 0
warning_count: 2
---
# Code Review: Phase 69 — Data Foundation (GooseStrainAccumulator)

## Summary

Phase 69 introduces `actor GooseStrainAccumulator` and wires it into the live heart-rate callback pipeline in `GooseAppModel`. The actor design is correct and thread-safe by construction. The Edwards Zone Load zone multipliers and the `maxSampleGap` guard are sound. Two warnings are found: (1) a timing race where `activeActivityPersistence` is set before the async `reset()` completes, allowing a transient HR sample to be ingested then wiped, producing a silent strain discontinuity at workout start; and (2) `setMaxHR(_:)` is defined but never called anywhere in the codebase — the accumulator always runs at the hardcoded `defaultMaxHR = 190`, making personalized strain impossible without a future wiring step.

---

## Findings

### [WARNING] `reset()` is queued asynchronously *after* `activeActivityPersistence` is set — first HR sample(s) can be ingested then wiped

**File:** `GooseSwift/GooseAppModel+ActivityRecording.swift:68–77` and `GooseSwift/GooseAppModel.swift:319–325`

**Description:**
In `beginActivityRecording`, the sequence is:

```swift
activeActivityPersistence = ActiveActivityPersistence(...)  // line 68 — sets non-nil synchronously
// ... more setup ...
Task { await self.strainAccumulator.reset() }               // line 77 — async, fires later
```

In `GooseAppModel.swift`, the `onLiveHeartRate` closure runs inside a `Task { [weak self] in }` from a background BLE callback:

```swift
Task { [weak self] in
  guard let self, self.activeActivityPersistence != nil else { return }  // line 320
  await self.strainAccumulator.ingest(bpm: bpm, date: capturedAt)        // line 321
  ...
}
```

After `activeActivityPersistence` is set on the main actor (line 68), the guard at line 320 passes for any HR sample that arrives before the `reset()` Task executes. Because both the `ingest()` task and the `reset()` task are scheduled on the actor's executor, their ordering depends on scheduling — but `reset()` is created *after* `ingest()` if a HR sample arrives in the window between line 68 and line 77.

Concrete failure sequence:
1. `beginActivityRecording` executes line 68: `activeActivityPersistence = ...` (non-nil, main actor).
2. BLE fires an HR callback. Its `Task` enqueues `ingest(bpm:date:)` on the strain actor.
3. `beginActivityRecording` reaches line 77: `Task { await strainAccumulator.reset() }` — enqueued after `ingest`.
4. Actor executes in order: `ingest()` accumulates load, then `reset()` clears it.
5. The workout starts with `accumulatedLoad = 0`, silently discarding the first sample's contribution.

While this represents at most a few seconds of missed strain (minor in absolute terms), it produces a silent discontinuity: `liveWorkoutStrain` will publish a non-zero value (from `pollIfReady` if triggered between `ingest` and `reset`), then jump back to zero, causing the UI tile to flash.

**Fix:** Call `reset()` synchronously before setting `activeActivityPersistence`, or use `await` to ensure the reset completes before the guard can pass:

```swift
// Option A: reset before activating the guard
await strainAccumulator.reset()
activeActivityPersistence = ActiveActivityPersistence(...)
```

Since `beginActivityRecording` is called from `@MainActor` context, wrapping the whole call site in an `async` function is the cleanest approach. If that's not feasible, reverse the order:

```swift
// Option B: set persistence AFTER the reset Task is guaranteed to have run
Task {
  await self.strainAccumulator.reset()
  await MainActor.run {
    self.activeActivityPersistence = ActiveActivityPersistence(...)
    // ... rest of setup ...
  }
}
```

---

### [WARNING] `setMaxHR(_:)` is defined but never called — accumulator always uses hardcoded 190 BPM max

**File:** `GooseSwift/GooseStrainAccumulator.swift:58–60` and `GooseSwift/GooseAppModel.swift`

**Description:**
`GooseStrainAccumulator` provides a `setMaxHR(_ bpm: Double)` method intended to personalise zone boundaries based on the user's actual maximum heart rate:

```swift
func setMaxHR(_ bpm: Double) {
  maxHR = bpm
}
```

A search across the entire `GooseSwift/` directory finds zero call sites for `setMaxHR`. The accumulator always uses `defaultMaxHR = 190`. This means:

- For a 35-year-old with an age-predicted max HR of 185, zone 5 starts at `0.9 × 190 = 171 bpm` — but physiologically zone 5 starts at `0.9 × 185 = 167 bpm`. The wrong threshold inflates zone multipliers.
- For a high-performance athlete with an actual max HR of 210, zone 5 starts at `0.9 × 190 = 171 bpm` instead of `0.9 × 210 = 189 bpm` — understating strain in a VO2max effort.

`HealthDataStore+Snapshots.swift` already computes a personalised max HR estimate (`let maxHR = 220 - ageBestGuess`, lines 999 and 1119) and uses it for the HRR (Heart Rate Reserve) calculations. The same estimate is available and should be fed to `setMaxHR` when a resting HR and age estimate are known.

The impact scales with session length: a 90-minute workout at the wrong zone threshold can misclassify a significant fraction of total strain load.

**Fix:** Wire the personalised max HR into `GooseStrainAccumulator` at two points:

1. At workout start in `beginActivityRecording`, after `reset()`:

```swift
if let estimatedMaxHR = healthDataStore.estimatedMaxHR {
  Task { await strainAccumulator.setMaxHR(estimatedMaxHR) }
}
```

2. When the restingHR or age estimate is updated (in `GooseBLEClient+VitalsAndLogging.swift` where `restingHeartRateEstimate` is persisted), propagate to the accumulator if a session is active:

```swift
if activeActivityPersistence != nil, let newMax = updatedMaxHR {
  Task { await strainAccumulator.setMaxHR(newMax) }
}
```

Until `setMaxHR` is called, the hardcoded 190 is a reasonable population-average default but should be documented as such with a `// TODO: personalise from user age/max HR estimate` comment.

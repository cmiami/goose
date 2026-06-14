---
phase: 71-coach-vow-noopapp-notifications-hr-decimation
reviewed: 2026-06-13T14:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - GooseSwift/CoachView.swift
  - GooseSwift/NotificationScheduler.swift
  - GooseSwift/HeartRateSeriesStores.swift
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Code Review: Phase 71 — Coach VOW + Notifications + HR Decimation

## Summary

Phase 71 added the VOW (Voice of Warning) nudge card in `CoachView`, `NotificationScheduler` (actor-based UNUserNotifications wrapper), and the HR decimation path in `HeartRateSeriesStores`. Two blockers were found: `NotificationScheduler.schedule()` escapes from actor isolation into a `getNotificationSettings` completion handler that runs on an arbitrary queue, then calls `UNUserNotificationCenter.add(_:)` and mutates `UNMutableNotifierContent` from that uncontrolled queue — all while the actor's re-entrancy has been abandoned. The `DailyJournalStore.save` encodes the entire journal dictionary (unbounded in size) but the function signature is `throws`-correct while the call site discards errors silently. The VOW nudge resolve logic uses sequential `if let` guards that produce a correct priority ordering but the `lowRecovery` case fires for scores that already matched `criticalRecovery` in a hypothetical refactor — currently safe but brittle.

---

## Findings

### [CRITICAL] `NotificationScheduler.schedule()` exits actor isolation inside `getNotificationSettings` callback — reentrancy abandoned, callback queue unknown

**File:** `GooseSwift/NotificationScheduler.swift:12-21`

**Description:** `NotificationScheduler` is declared as `actor`. Its private `schedule(title:body:identifier:)` method calls `UNUserNotificationCenter.current().getNotificationSettings { settings in ... }`. The closure passed to `getNotificationSettings` is called on an arbitrary internal UNUserNotifications queue, **not** on the actor's executor. Inside that closure (lines 14-20), `UNMutableNotificationContent` is mutated and `center.add(request)` is called. None of these operations are protected by the actor. Specifically:

1. The `settings` check and the `content`/`trigger`/`request` construction at lines 15-19 happen on the UNUserNotifications internal queue — not the actor queue.
2. `center.add(request)` at line 20 is called from the foreign queue. If `center.add` internally calls back into any actor-isolated state, there is a re-entrancy hazard.
3. `@preconcurrency import UserNotifications` suppresses the Sendability warning for the callback but does not fix the isolation gap — it is a temporary migration aid, not a correctness guarantee.

While `UNMutableNotificationContent` and `UNUserNotificationCenter` are themselves thread-safe Apple classes, the actor pattern's entire purpose is to serialise access. The current code runs notification scheduling logic outside the actor's serialisation guarantee, defeating the design intent and making any future state additions to the actor (e.g., a "last notification sent" timestamp) subject to races.

**Fix:** Use `Task { @actor_isolated }` or `await` the completion inside the actor's async context:
```swift
private func schedule(title: String, body: String, identifier: String) async {
  let center = UNUserNotificationCenter.current()
  let settings = await center.notificationSettings()
  guard settings.authorizationStatus == .authorized else { return }
  let content = UNMutableNotificationContent()
  content.title = title
  content.body = body
  content.sound = .default
  let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
  let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
  try? await center.add(request)
}
```
`UNUserNotificationCenter.notificationSettings()` and `UNUserNotificationCenter.add(_:)` both have async variants on iOS 14+ (iOS 26.0 deployment target — both are available). Using async/await keeps all logic on the actor's executor with no callback escape.

---

### [CRITICAL] `DailyJournalStore.save` — call site in `DailyJournalSheet` silently discards encode failures, user loses journal entry

**File:** `GooseSwift/CoachView.swift:888-900`

**Description:** `DailyJournalStore.save(_:)` is correctly declared `throws` and the implementation propagates `JSONEncoder.encode` failures. The call site at `DailyJournalSheet.save()` (lines 893-900) correctly wraps the call in `do/catch` and sets `saveError` on failure. This is handled correctly.

However, `DailyJournalStore.load()` at line 778-785 is called synchronously on the main thread every time `save()` is called, and again on every `onAppear` and `onDismiss` in the view. As the journal grows (one entry per calendar day, stored indefinitely with no eviction policy), the `JSONDecoder().decode([String: DailyJournalEntry].self, from: data)` call will block the main thread proportionally. A year of entries already amounts to 365 decode-encode cycles per save. There is no upper bound on stored entries.

The separate `DailyJournalStore.save` issue is that the entire dictionary (potentially hundreds of entries) is re-encoded on every single save of one entry. This is an unbounded write amplification: saving one new entry encodes the full history.

**Fix:** Add a retention limit and load/save on a background queue:
```swift
static let maxEntries = 365

static func save(_ entry: DailyJournalEntry) throws {
  var all = load()
  all[entry.dateKey] = entry
  // Evict oldest entries beyond the limit
  if all.count > maxEntries {
    let sorted = all.keys.sorted()
    sorted.prefix(all.count - maxEntries).forEach { all.removeValue(forKey: $0) }
  }
  let data = try JSONEncoder().encode(all)
  UserDefaults.standard.set(data, forKey: key)
}
```

---

### [WARNING] `CoachVOWNudge.resolve` — `lowRecovery` body text claims "below 66%" but the `< 33` case is already caught above; range overlap creates misleading copy if ordering ever changes

**File:** `GooseSwift/CoachView.swift:910-919`

**Description:** The sequential `if let` chain is evaluated top-to-bottom, so a score of 25 (below 33) correctly returns `.criticalRecovery` and never reaches `.lowRecovery`. The logic is currently correct. However, the body string for `.lowRecovery` at line 934 says "Recovery is below 66%", but `.lowRecovery` is only returned for scores in [33, 66) — never for scores below 33. The body text is technically imprecise (should say "between 33% and 66%") and would become incorrect if the guard ordering were ever reversed. Additionally, if `recoveryValue` is an empty string (no data yet), both `Double(recoveryValue)` calls return `nil` and neither case fires — which is the correct silent fallback, but is not documented.

**Fix:** Tighten the body text and add a clarifying comment:
```swift
// priority order matters: criticalRecovery catches r < 33 first
if let r = Double(recoveryValue), r < 33 { return .criticalRecovery(r) }
if let r = Double(recoveryValue), r >= 33, r < 66 { return .lowRecovery(r) }
```
And update the body string:
```swift
case .lowRecovery: "Recovery is between 33–66%. Consider light training only."
```

---

### [WARNING] `NotificationScheduler` — `scheduleBatteryLow` uses a static identifier, but the actor provides no rate-limiting state — the comment relies on an undocumented Bool gate that does not exist in this file

**File:** `GooseSwift/NotificationScheduler.swift:52-57`

**Description:** The comment at line 51 says "Bool gate prevents duplicates per session." No such Bool gate exists in `NotificationScheduler`. The deduplication relies entirely on `UNUserNotificationCenter` replacing a pending request when the same `identifier` is re-added. This works for notifications that have not yet been delivered, but once the "WHOOP battery low" notification has been delivered and cleared, a subsequent `scheduleBatteryLow` call will schedule a new one. If the caller fires `scheduleBatteryLow` rapidly (e.g., on every BLE packet that contains battery ≤ threshold), the user will receive repeated battery notifications across sessions.

The comment references a "Bool gate" that must be in the caller — but without enforcement in the scheduler, a future caller that doesn't implement the gate will cause notification spam.

**Fix:** Add the rate-limit gate inside the actor where it belongs:
```swift
actor NotificationScheduler {
  private var batteryLowFiredThisSession = false

  func scheduleBatteryLow(percent: Int) {
    guard !batteryLowFiredThisSession else { return }
    batteryLowFiredThisSession = true
    schedule(
      title: "WHOOP battery low",
      body: String(format: "Battery at %d%%. Charge your device.", percent),
      identifier: "goose.battery.low"
    )
  }
}
```

---

### [WARNING] `DailyJournalStore.todayKey()` creates a new `DateFormatter` on every call — called on every save and on every `onAppear`

**File:** `GooseSwift/CoachView.swift:772-776`

**Description:** `todayKey()` instantiates a `DateFormatter` every time it is called. `DateFormatter` is expensive to create (locale/calendar initialisation). It is called from `today()`, `save()`, and `DailyJournalSheet.init`. While not a correctness issue, this is a quality defect in a function called repeatedly from the main thread.

**Fix:** Use a static cached formatter:
```swift
private static let dateKeyFormatter: DateFormatter = {
  let fmt = DateFormatter()
  fmt.locale = Locale(identifier: "en_US_POSIX")
  fmt.dateFormat = "yyyy-MM-dd"
  return fmt
}()

static func todayKey() -> String {
  dateKeyFormatter.string(from: Date())
}
```

---

### [INFO] `CoachVOWNudge` — VOW card is dismissed with `@State private var vowDismissed` on `CoachOverviewScreen`, which is a private struct recreated on each navigation

**File:** `GooseSwift/CoachView.swift:444`

**Description:** `vowDismissed` is `@State` on `CoachOverviewScreen`, which is a private struct created inside `CoachView.body`. When the user navigates away and back, `CoachOverviewScreen` is reconstructed and `vowDismissed` resets to `false`, so the dismissed nudge reappears. This is likely unintentional — the nudge was dismissed for a reason (critical recovery, high strain) and re-appearing on re-navigation is annoying.

**Fix:** Lift `vowDismissed` to `CoachView` (which persists across navigation), or persist the dismissed state in `UserDefaults` keyed by today's date.

---

### [INFO] `DailyJournalSheet` alert message is hardcoded in Portuguese (`"Não foi possível guardar"`) inconsistently with the rest of the codebase

**File:** `GooseSwift/CoachView.swift:872`

**Description:** The error alert title is a hardcoded Portuguese string literal, not wrapped in `String(localized:)`. All other user-visible strings in `CoachView` use either `String(localized:)` or plain literals for single-language strings. This is inconsistent and would not be caught by Xcode's localization export tools.

**Fix:** Wrap in `String(localized:)`:
```swift
.alert(String(localized: "Could not save"), isPresented: ...)
```

---

_Reviewed: 2026-06-13T14:00:00Z_
_Reviewer: Claude (adversarial review)_
_Depth: standard_

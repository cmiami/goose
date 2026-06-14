---
phase: 72-screens-on-new-foundation-service-layer
reviewed: 2026-06-13T14:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - GooseSwift/GooseRustBridging.swift
  - GooseSwift/GooseBLEManaging.swift
  - GooseSwift/HealthDataStoring.swift
  - GooseSwift/CoachRouteViews.swift
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Code Review: Phase 72 — Screens on New Foundation / Service Layer

## Summary

Phase 72 introduced three protocol abstractions (`GooseRustBridging`, `GooseBLEManaging`, `HealthDataStoring`) intended for dependency injection and testability, and surfaced four Coach route views (`CoachSleepRouteView`, `CoachRecoveryRouteView`, `CoachStrainRouteView`, `CoachStressRouteView`) in `CoachRouteViews.swift`. The protocol files are thin stubs without immediate bugs, but each carries a design defect that limits its usefulness. The Coach route views have a locale-sensitive parsing issue in `windDownTime` and a missing `String(localized:)` on section titles.

No critical bugs were found in this specific file set. The most significant finding (WR-01) concerns `GooseBLEManaging`'s surface area being too narrow to enable the test injection it was designed for.

---

## Findings

### [WARNING] `GooseBLEManaging` protocol surface is insufficient for any real test use — the abstraction is dead weight

**File:** `GooseSwift/GooseBLEManaging.swift:5-10`

**Description:** The protocol exposes only `connectionState`, `isScanning`, `startScanning()`, and `stopScanning()`. `GooseAppModel` and `CoachRouteViews` access at least `liveHeartRateBPM`, `liveHeartRateSource`, `liveHeartRateUpdatedAt`, `pendingAlarmCommand`, `setWhoopAlarm(at:)`, `buzz(loops:)`, and `disableWhoopAlarms()` on `ble`. None of these are on the protocol. A mock implementing only `GooseBLEManaging` cannot substitute for `GooseBLEClient` in any view or model test. `GooseAppModel.ble` is still typed as `GooseBLEClient` (concrete), so the protocol is not used at any injection site today.

The file comment says "extend as test coverage grows" — but the protocol can only be extended when there are callers. Currently there are no callers. An unused, too-narrow abstraction adds file count and reading overhead with zero benefit.

**Fix:** Either extend the protocol to the actual surface needed by `CoachRouteViews` and `GooseAppModel`:
```swift
protocol GooseBLEManaging: AnyObject {
  var connectionState: String { get }
  var isScanning: Bool { get }
  var liveHeartRateBPM: Int? { get }
  var liveHeartRateSource: String { get }
  var liveHeartRateUpdatedAt: Date? { get }
  var pendingAlarmCommand: PendingAlarmCommand? { get }
  func startScanning()
  func stopScanning()
  func buzz(loops: Int)
  func setWhoopAlarm(at: Date, alarmID: Int)
  func disableWhoopAlarms()
}
```
Or remove the file until there is an actual injection site that requires it.

---

### [WARNING] `HealthDataStoring.fetchTrendsSeries` default parameter is in an extension, not the protocol requirement — conforming types are not required to honour it

**File:** `GooseSwift/HealthDataStoring.swift:10-15`

**Description:** The protocol requires `fetchTrendsSeries(metricName:days:)`. The convenience overload with `days:` defaulting to 7 lives in a `protocol extension`. Swift protocol extensions provide a default implementation, but conforming types can (and typically do) satisfy the requirement with their own implementation — the extension default only fires when calling through the protocol type. If a type conforms to `HealthDataStoring` and provides only a `fetchTrendsSeries(metricName:days:)` implementation, the zero-argument convenience form works correctly via the extension. This is fine for the current usage.

The actual defect: the protocol extension's convenience overload hardcodes `days: 7` as the default without naming the constant. "7 days" is a magic number. If the chart period changes to 14 days, there is no single constant to update.

**Fix:**
```swift
extension HealthDataStoring {
  static let defaultTrendDays = 7

  func fetchTrendsSeries(metricName: String) async throws -> [(date: String, value: Double)] {
    try await fetchTrendsSeries(metricName: metricName, days: Self.defaultTrendDays)
  }
}
```

---

### [WARNING] `CoachSleepRouteView.windDownTime` uses a `DateFormatter` without a fixed locale — silently returns "—" on 12-hour locales

**File:** `GooseSwift/CoachRouteViews.swift:133-145`

**Description:** `windDownTime` creates a `DateFormatter` with `dateFormat = "HH:mm"` and `locale = Locale(identifier: "en_US_POSIX")` — the POSIX locale is set correctly. However, `sleep?.startLabel` is produced by the health store, which formats times using the device's current locale and calendar. On a device with a 12-hour locale, `startLabel` will be a string like `"11:30 PM"`, which `HH:mm` cannot parse. `fmt.date(from: start)` returns `nil`, and the function falls back to `"—"`. The user sees a dash instead of a computed wind-down time.

The `DateFormatter` chain (locale-dependent source → locale-fixed parser) is inherently fragile. The POSIX locale guard on the formatter helps when the source is also POSIX-formatted, but `startLabel` is not guaranteed to be POSIX-formatted.

**Fix:** Either ensure `startLabel` is always produced in `HH:mm` 24h format (fix at the source in `PrimarySleepDetail`), or parse using the same locale/format that produced it. The safest fix is to produce `startDate: Date` in `PrimarySleepDetail` and do the `addingTimeInterval(-30 * 60)` on the `Date` directly:
```swift
private var windDownTime: String {
  guard let startDate = sleep?.startDate else { return "—" }
  let windDown = startDate.addingTimeInterval(-30 * 60)
  let fmt = DateFormatter()
  fmt.timeStyle = .short
  return fmt.string(from: windDown)
}
```

---

### [INFO] `GooseRustBridging` protocol covers only two methods — `GooseRustBridge` has 10+ public methods used by callers

**File:** `GooseSwift/GooseRustBridging.swift:6-9`

**Description:** The protocol comment says it covers "the two methods used by WorkoutEntryViewModel and TrendsDashboardView." This is an honest scope statement, but it means the protocol cannot be used to mock `GooseRustBridge` for testing any other bridge consumer (`HealthDataStore`, `GooseAppModel`, `CaptureFrameWriteQueue`, `OvernightSQLiteMirrorQueue`). As a minimal footprint for the current test targets, this is acceptable. Flag for expansion as test coverage grows.

**Fix:** No action required now. Add to the protocol as each new test consumer is added.

---

### [INFO] `CoachRouteViews.swift` section titles in `wakeAlarmSection` are hardcoded Portuguese strings without `String(localized:)`

**File:** `GooseSwift/CoachRouteViews.swift:160, 164, 179, 197`

**Description:** Strings like `"ALARME DE DESPERTAR"`, `"Hora de acordar"`, `"Conecta o WHOOP para usar o alarme"`, `"Cancelar Alarme"`, and `"Armar Alarme"` are raw string literals. The rest of `CoachSleepRouteView` uses `String(localized:)` consistently (lines 95, 103, 104, 105, etc.). The inconsistency means these strings will not appear in Xcode's localization export and cannot be translated.

**Fix:** Wrap all user-visible strings in `String(localized:)`:
```swift
CoachInfoGroup(title: String(localized: "WAKE ALARM")) {
  DatePicker(
    String(localized: "Wake time"),
    selection: $alarmTime,
    displayedComponents: .hourAndMinute
  )
  // ...
  Text(model.alarmIsArmed
    ? String(localized: "Cancel Alarm")
    : String(localized: "Arm Alarm"))
```

---

_Reviewed: 2026-06-13T14:00:00Z_
_Reviewer: Claude (adversarial review)_
_Depth: standard_

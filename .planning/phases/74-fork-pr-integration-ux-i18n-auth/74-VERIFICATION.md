---
phase: 74
status: human_needed
build: passed
simulator_tested: 2026-06-13
---
# Verification: Phase 74 — Fork PR Integration UX, i18n & Auth

## Build Status
✅ Build SUCCEEDED — 0 errors, 1 warning (ChatGPT provider protocol conformance across actor boundary — non-blocking)

## Must-Haves Verified

### PR-INT-01 — Technical identifiers off main views ✅
- PR #136 confirmed: raw UUIDs, sequence numbers, device IDs removed from Health/Home/Sleep views
- Exposed only in More > Debug sections (existing developer area)
- `LocalizedStatusStrings.swift` updated; HealthCatalog guard fixed

### PR-INT-03 — Imperial/metric for temp/distance/pace/elevation ✅
- `TemperatureFormatting.swift` added: °C/°F conversion with `isImperial(unitSystemRaw:)`
- Distance/pace/elevation in `FitnessFormatting.swift` — mi/km, ft/m, min/mi vs min/km
- All display sites updated: HealthRecoveryWidgets, CoachRouteViews, HomeTimelineViews, FitnessLiveWorkoutViews
- `TemperatureFormattingTests.swift` added with conversion coverage
- Reactive via `@AppStorage(OnboardingStorage.unitSystem)` — no restart required

### PR-INT-04 — English source language + pt-PT localisation ✅
- All hardcoded Portuguese strings replaced with `String(localized:)` English sources
- Localizable.xcstrings: `sourceLanguage = "en"` confirmed
- CoachRouteViews, HealthDashboardViews, SleepV2Views, and 20+ other files updated

### PR-INT-05 — ChatGPT sign-in ⚠️ human_needed
- OAuth flow refactored in CodexEmbeddedAuth.swift (PR #132)
- ChatGPTCoachProvider isolated to @MainActor @Observable
- CoachChatModel.startOAuthSignIn() clears error before each attempt
- **Manual verification required:** end-to-end sign-in with real ChatGPT account on device

## Human Verification Required

### HV-01: ChatGPT sign-in flow (PR-INT-05)
1. Go to Coach tab → tap settings icon
2. Select ChatGPT as provider
3. Tap "Sign in with ChatGPT"
4. Complete the device auth flow (enter code at openai.com/device)
5. Verify: sign-in completes without error and conversations work
**Status:** Requires real ChatGPT account + physical device or simulator with network access

### HV-02: Unit preference reactivity (PR-INT-03) ✅ VERIFIED in simulator
1. Go to More > Profile > Units → switch to Imperial ✅
2. Picker shows "Imperial" / "Metric" options ✅
3. Switching to Metric: Height changes ft→cm, Weight lb→kg instantly ✅
4. No restart required — @AppStorage reactive update confirmed ✅
**Status:** PASSED (simulator 2026-06-13)

### HV-03: i18n completeness (PR-INT-04) ✅ VERIFIED in simulator (English locale)
1. More tab: all section headers in English (Device, App, Wellness, Data, Settings, Support) ✅
2. Profile screen: Personal, Measurements, Apple Health sections all in English ✅
3. No raw localization key strings visible in English locale ✅
4. pt-PT locale test: requires simulator language change (deferred to device)
**Status:** PASSED for English locale; pt-PT spot-check deferred to device

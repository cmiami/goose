---
plan: 74-03
status: complete
requirements: PR-INT-03
duration: integrated via cherry-pick from PR #134
files_modified: 21 (including new TemperatureFormatting.swift + TemperatureFormattingTests.swift)
---
# Summary: Units — Imperial/metric for temperature, distance, pace, elevation

Integrated PR #134 (cmiami:pr/units-imperial-metric) — 6 commits:
- Adds `TemperatureFormatting.swift` — `isImperial(unitSystemRaw:)`, `displayText(celsius:imperial:)`, `deltaText(celsiusDelta:imperial:)`, `skinTempText(imperial:)` on V24BiometricsResult
- Extends `FitnessFormatting.swift` — distance/pace/elevation aware of imperial preference
- Updates all display sites: `HealthRecoveryWidgets`, `CoachRouteViews`, `HomeTimelineViews`, `FitnessLiveWorkoutViews`
- Adds `TemperatureFormattingTests.swift` with unit conversion coverage
- Registers new files in `project.pbxproj`

## Acceptance criteria met
- [x] Skin temperature shows °F when imperial preference set
- [x] Distance/pace/elevation show imperial units when preference set
- [x] Reactive — changing unitSystem in More > Profile updates displays without restart
- [x] No new UserDefaults keys (reuses OnboardingStorage.unitSystem)
- [x] Build passes

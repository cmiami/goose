# Phase 74: Fork PR Integration — UX, i18n & Auth - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Integrate 4 tigercraft4/goose fork PRs (#132–#136) into main:
- PR-INT-01 (#136): Hide technical identifiers (UUIDs, raw values, sequence IDs) from primary views — move to More > Debug/Advanced sections only
- PR-INT-03 (#134): Extend existing imperial/metric unit system to temperature (skin temp), distance/pace/elevation (GPS exercise) — no new preference key
- PR-INT-04 (#133): Audit Localizable.xcstrings; translate 16 `state: "new"` pt-PT strings; confirm English as source language
- PR-INT-05 (#132): Fix ChatGPT sign-in auth endpoint in CodexEmbeddedAuth.swift — patch minimum to restore device auth flow

</domain>

<decisions>
## Implementation Decisions

### Technical Identifier Hiding (PR-INT-01)
- Audit Health, Home, Sleep views via grep for `.deviceUUID`, `.serialNumber`, raw hex strings in Text() and label contexts
- Move any found identifiers to More > Debug > Status tab (being restructured in Phase 79); add "Device Identifiers" card there
- Identifiers are relocated (always visible in Debug, never on main cards) — not hidden behind toggle
- If audit finds no UUIDs in main views today: document as negative audit with a confirming code comment; PR-INT-01 satisfied

### Unit System Extension (PR-INT-03)
- Reuse `@AppStorage(OnboardingStorage.unitSystem)` imperial/metric — no new preference key
- Measurements to convert: skin temperature (V24 biometrics view), GPS distance/pace/elevation (exercise sessions view)
- Conversion applied at display layer only (View or formatting helper) — stored values never mutated
- `@AppStorage` is reactive; views re-render on change with no restart required

### Localisation Completeness (PR-INT-04)
- `sourceLanguage: "en"` already set in Localizable.xcstrings — no migration needed
- 16 strings with `state: "new"`: add pt-PT translations for UI strings; mark technical strings (URLs, codes, format specifiers) as `shouldTranslate: false`
- Audit triggered by examining each `"new"` entry in context — no wholesale retranslation

### ChatGPT Auth Fix (PR-INT-05)
- Patch `CodexEmbeddedAuth.swift` device auth endpoint path to match current OpenAI device auth spec
- Patch is minimal — update URL path and/or expected response fields; do not rewrite the flow
- Add unit test with mock HTTP response; mark manual sign-in verification as `human_needed`

### Claude's Discretion
- Order of PRs to apply: PR-INT-04 (localization — lowest risk, no behaviour change), then PR-INT-03 (unit formatting), then PR-INT-01 (identifier audit/move), then PR-INT-05 (auth fix with test)
- If PR-INT-01 audit reveals identifiers in views added in phases 67-73, inline-fix them in this phase

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `@AppStorage(OnboardingStorage.unitSystem)` — existing imperial/metric preference key shared across MoreView and MoreProfileViews
- `MoreProfileFormatting` — existing formatting helpers for height/weight; extend pattern for temp/distance/pace/elevation
- `CodexEmbeddedAuth.swift` — full device auth flow already implemented; only endpoint patch needed
- `Localizable.xcstrings` — xcstrings format with `sourceLanguage: "en"`, 8934 lines; pt-PT locale present

### Established Patterns
- Unit conversion at display layer: `MoreProfileFormatting.heightText(millimeters:unitSystemRaw:)` pattern — replicate for temperature and GPS metrics
- `@AppStorage` reactive updates: `MoreProfileViews` uses `.onChange(of: unitSystemRaw)` — same pattern for display views
- Localisation: all UI strings use `NSLocalizedString` / String Catalog; `LocalizedStatusStrings.swift` for dynamic status strings

### Integration Points
- V24 biometrics skin temperature display: `HealthDataStore+V24Biometrics.swift` + view in `HealthDashboardViews.swift`
- Exercise GPS metrics: `HealthDataStore+ActivitySnapshots.swift` + activity views
- Coach ChatGPT: `CodexEmbeddedAuth.swift` → `ChatGPTCoachProvider.swift` → `CoachSettingsSheet.swift`
- Debug section: `MoreView.swift` (to be restructured Phase 79; for now, add to existing Debug group)

</code_context>

<specifics>
## Specific Ideas

- PR-INT-04 first: safest change, sets clean baseline before touching behaviour
- PR-INT-03: add a `GooseUnitFormatting.swift` helper (or extend MoreProfileFormatting) — keeps conversion logic in one place
- PR-INT-01: grep scope = main tabs only (Home, Health, Sleep, Coach, More); NOT the existing Debug/MoreRawExport views (those are already "advanced")
- PR-INT-05: check OpenAI developer docs for current device auth endpoint before patching

</specifics>

<deferred>
## Deferred Ideas

- Full imperial/metric coverage for all health metrics (HRV in ms stays as-is; no request to convert) — only the 4 fields named in PR-INT-03
- Rewriting CoachSettingsSheet UI for ChatGPT auth — only the auth endpoint is in scope
- Adding new locale beyond pt-PT — out of scope for this milestone

</deferred>

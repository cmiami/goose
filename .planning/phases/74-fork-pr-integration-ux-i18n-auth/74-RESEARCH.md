# Phase 74: Fork PR Integration — UX, i18n & Auth - Research

**Researched:** 2026-06-13
**Domain:** SwiftUI iOS — localisation (xcstrings), unit formatting, ChatGPT OAuth device flow, technical identifier audit
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- PR-INT-01 (#136): Audit Health, Home, Sleep views via grep for `.deviceUUID`, `.serialNumber`, raw hex strings in Text() and label contexts. Move any found identifiers to More > Debug > Status tab (Phase 79 restructuring). Identifiers are relocated, not hidden behind toggle. If audit finds no UUIDs in main views today: document as negative audit with confirming code comment.
- PR-INT-03 (#134): Reuse `@AppStorage(OnboardingStorage.unitSystem)` imperial/metric — no new preference key. Convert skin temperature (V24 biometrics view), GPS distance/pace/elevation (live workout view). Conversion at display layer only — stored values never mutated.
- PR-INT-04 (#133): `sourceLanguage: "en"` already set — no migration needed. 16 strings with `state: "new"` — add pt-PT translations for UI strings; mark technical strings as `shouldTranslate: false`. Audit per "new" entry.
- PR-INT-05 (#132): Patch `CodexEmbeddedAuth.swift` device auth endpoint path to match current OpenAI device auth spec. Minimal patch — update URL path and/or expected response fields. Add unit test with mock HTTP response; manual sign-in verification as `human_needed`.

### Claude's Discretion
- Order of PRs to apply: PR-INT-04 (localization — lowest risk), PR-INT-03 (unit formatting), PR-INT-01 (identifier audit/move), PR-INT-05 (auth fix with test).
- If PR-INT-01 audit reveals identifiers in views added in phases 67-73, inline-fix them in this phase.

### Deferred Ideas (OUT OF SCOPE)
- Full imperial/metric coverage for all health metrics (HRV in ms stays as-is).
- Rewriting CoachSettingsSheet UI for ChatGPT auth — only the auth endpoint is in scope.
- Adding new locale beyond pt-PT.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PR-INT-01 | Hide technical identifiers (UUIDs, raw values, sequence IDs) from primary views — move to More > Debug/Advanced sections only | Audit complete: negative result confirmed — no UUIDs in main tab views. No implementation work beyond code comment. |
| PR-INT-03 | Extend existing imperial/metric unit system to temperature (skin temp), distance/pace/elevation (GPS exercise) | `skinTempText` in `V24BiometricsResult` hardcodes `°C`. `fitnessDistanceParts` hardcodes KM/M. Elevation hardcodes `"M"`. `formatDistance` in `HomeTimelineViews` hardcodes km/m. Four concrete sites found. |
| PR-INT-04 | Audit Localizable.xcstrings; translate `state: "new"` pt-PT strings; English as source | Zero strings have `state: "new"`. 63 strings are missing pt-PT entirely (no state key, no localization entry). 5 are format specifier strings that should be `shouldTranslate: false`. 58 are genuine UI strings needing translations. |
| PR-INT-05 | Fix ChatGPT sign-in auth endpoint in CodexEmbeddedAuth.swift — patch minimum to restore device auth flow | Current endpoints are custom/non-standard OpenAI internal paths. Standard OAuth 2.0 device flow endpoints confirmed via auth0.openai.com OpenID Configuration. Concrete patch identified. |
</phase_requirements>

---

## Summary

Phase 74 integrates four fork PRs that improve user experience without touching BLE or data pipelines. The research was done exclusively by reading the codebase — no external library dependencies are introduced by any of the four PRs.

**PR-INT-01 (identifier hiding):** The codebase audit is a negative result. Grepping all main-tab view files (HealthDashboardViews, HomeDashboardView, HomeHealthMonitorViews, HomeScoreViews, HomeTimelineViews, SleepV2BevelTrendViews) for `uuid`, `UUID`, `serialNumber`, `deviceID`, `peripheral.identifier`, `hexString`, `seqNum`, `sequence_id`, and `raw_frame` found zero UI display sites. UUID references only appear in BLE internals (GooseBLEClient, GooseBLETypes), log strings, and GooseUploadService JSON payloads — none in Text() or Label() on main tabs. PR-INT-01 is satisfied by a confirming negative-audit code comment placed at the top of each audited view file.

**PR-INT-03 (unit formatting):** Four concrete sites need conversion. The existing `MoreProfileFormatting` pattern (switch on unitSystem, return formatted string with unit suffix) is the exact model to replicate. The new helper should live in `FitnessFormatting.swift` for distance/pace/elevation and extend `V24BiometricsResult` for skin temperature. `@AppStorage(OnboardingStorage.unitSystem)` is reactive — views re-render automatically when the device changes the setting; no `.onChange` restart needed.

**PR-INT-04 (localisation):** The CONTEXT.md assumption of "16 strings with state: new" is incorrect as of the current codebase. There are **zero** strings with `state: "new"` in Localizable.xcstrings. However, there are **63 strings missing pt-PT entirely** (no localization entry at all). Of these, 5 are format specifier/accessibility strings that should be marked `shouldTranslate: false`. The remaining 58 genuine UI strings need pt-PT translations added directly to the xcstrings file. Many strings are already written in Portuguese (e.g. `'Armar Alarme'`, `'Cancelar'`) and need the `pt-PT` entry added to match the key value.

**PR-INT-05 (ChatGPT auth):** The current implementation uses non-standard OpenAI internal API paths (`/api/accounts/deviceauth/usercode`, `/api/accounts/deviceauth/token`). The standard OAuth 2.0 device authorization flow confirmed via auth0.openai.com OpenID Configuration uses `/oauth/device/code` for device code requests and `/oauth/token` with `grant_type=urn:ietf:params:oauth:grant-type:device_code` for polling. The token exchange endpoint is correct (`/oauth/token`) but the issuer domain differs (`auth.openai.com` vs `auth0.openai.com`). The response field mapping also changes (standard `device_code` not custom `device_auth_id`).

**Primary recommendation:** Execute in order: PR-INT-04 (xcstrings edits only, safe baseline), PR-INT-03 (add unit conversion helpers + wire into views), PR-INT-01 (write negative audit comments), PR-INT-05 (patch auth endpoints + add mock test).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Identifier audit/hide (PR-INT-01) | UI Layer (`GooseSwift/` views) | — | Read-only audit of display-layer Text() calls; no model changes |
| Unit conversion (PR-INT-03) | UI Layer (display helpers) | — | Conversion at display time only; stored values in Rust bridge untouched |
| Localisation strings (PR-INT-04) | Resource Layer (`Localizable.xcstrings`) | UI Layer (call sites) | xcstrings is the single source of truth; views call `String(localized:)` |
| ChatGPT auth endpoint (PR-INT-05) | Service Layer (`CodexEmbeddedAuth.swift`) | — | Pure network layer patch; no UI or model change |

---

## PR-INT-01: Technical Identifier Audit — Full Findings

### Audit Scope
Files audited for `uuid`, `UUID`, `serialNumber`, `deviceID`, `peripheral.identifier`, `hexString`, `seqNum`, `sequence_id`, `frame_id`, `raw_frame`:

| File | UUID/Identifier Hits | In Text()/Label? |
|------|---------------------|-----------------|
| `HealthDashboardViews.swift` | 0 | — |
| `HomeDashboardView.swift` | 0 | — |
| `HomeHealthMonitorViews.swift` | 0 | — |
| `HomeScoreViews.swift` | 0 | — |
| `HomeTimelineViews.swift` | 0 | — |
| `SleepV2BevelTrendViews.swift` | 0 | — |
| `HealthRecoveryStressViews.swift` | 0 | — |
| `HealthRecoveryWidgets.swift` | 0 | — |

**Conclusion:** Negative audit. No technical identifiers appear on any main Health, Home, or Sleep tab views. [VERIFIED: direct grep of GooseSwift/ source files]

### Where Identifiers Do Appear (already in correct location)
- `GooseBLEClient.swift` / `GooseBLEClient+PeripheralDelegate.swift` — internal BLE logic, `record()` log calls only. Not UI.
- `GooseBLETypes.swift` — characteristic UUID comparison functions. Not UI.
- `GooseUploadService.swift` — JSON payload construction for server upload. Not UI.
- `DeviceView.swift` — under More > Device tab (already advanced/secondary). Displays device name, battery, generation — no raw UUID shown to user.
- `MoreDebugView.swift` — under More > Debug (already advanced). Contains BLE event log.

### Implementation
PR-INT-01 requires only adding a confirming comment block to each audited view file:

```swift
// PR-INT-01 audit (2026-06-13): no UUID, serialNumber, deviceID, hexString,
// seqNum, or raw_frame identifiers displayed in this view. Audit negative.
```

No code moves required. [VERIFIED: direct grep]

---

## PR-INT-03: Unit System Extension — Full Findings

### Existing Pattern (to replicate)
`MoreProfileFormatting` in `MoreProfileViews.swift` [VERIFIED: direct read]:

```swift
// Pattern to replicate:
enum MoreProfileFormatting {
  static func heightText(millimeters: Int, unitSystemRaw: String) -> String {
    let unitSystem = MoreProfileUnitSystem(rawValue: unitSystemRaw) ?? .imperial
    switch unitSystem {
    case .metric:  return "\(formatted(Double(millimeters) / 10, maxFractionDigits: 1)) cm"
    case .imperial:
      let totalInches = Double(millimeters) / 25.4
      let feet = Int(totalInches / 12)
      let inches = totalInches - Double(feet * 12)
      return "\(feet) ft \(formatted(inches, maxFractionDigits: 1)) in"
    }
  }
}
```

The preference key: `@AppStorage(OnboardingStorage.unitSystem)` with raw value `"imperial"` or `"metric"`. Type: `MoreProfileUnitSystem` (in `MoreProfileViews.swift`). [VERIFIED: direct read]

### Site 1: Skin Temperature — `V24BiometricsResult.skinTempText`

**File:** `GooseSwift/HealthDataStore+V24Biometrics.swift` lines 20-23 [VERIFIED: direct read]

```swift
// CURRENT (hardcoded °C):
var skinTempText: String {
  guard let v = skinTempCelsius else { return "--" }
  return String(format: "%.1f °C", v)
}
```

**Fix:** Add `unitSystemRaw: String` parameter or read `@AppStorage` in the view and pass to a static helper.

Conversion: `fahrenheit = celsius * 9/5 + 32`

```swift
// PROPOSED helper in FitnessFormatting.swift or MoreProfileFormatting extension:
static func skinTempText(celsius: Double, unitSystemRaw: String) -> String {
  let unitSystem = MoreProfileUnitSystem(rawValue: unitSystemRaw) ?? .imperial
  switch unitSystem {
  case .metric:
    return String(format: "%.1f °C", celsius)
  case .imperial:
    return String(format: "%.1f °F", celsius * 9/5 + 32)
  }
}
```

**Display site:** `HealthRecoveryWidgets.swift` line 400 — `V24BiometricsCard` passes `result.skinTempText`. [VERIFIED: direct read]
**Called from:** `HealthRecoveryStressViews.swift` lines 126-127. [VERIFIED: direct read]

### Site 2: GPS Distance — `fitnessDistanceParts`

**File:** `GooseSwift/FitnessFormatting.swift` lines 56-61 [VERIFIED: direct read]

```swift
// CURRENT (hardcoded metric):
func fitnessDistanceParts(_ meters: CLLocationDistance) -> (value: String, unit: String) {
  if meters >= 1000 {
    return (String(format: "%.2f", meters / 1000), "KM")
  }
  return ("\(Int(max(meters, 0).rounded()))", "M")
}
```

**Fix:** Add `unitSystemRaw: String` parameter.

```swift
func fitnessDistanceParts(
  _ meters: CLLocationDistance,
  unitSystemRaw: String
) -> (value: String, unit: String) {
  let imperial = MoreProfileUnitSystem(rawValue: unitSystemRaw) == .imperial
  if imperial {
    let yards = meters * 1.09361
    if yards >= 1760 {
      return (String(format: "%.2f", meters / 1609.344), "MI")
    }
    return ("\(Int(max(yards, 0).rounded()))", "YD")
  } else {
    if meters >= 1000 {
      return (String(format: "%.2f", meters / 1000), "KM")
    }
    return ("\(Int(max(meters, 0).rounded()))", "M")
  }
}
```

**Call sites in `FitnessLiveWorkoutViews.swift`:** lines 233, 334, 396. [VERIFIED: direct read]
Each call site is inside a View struct — add `@AppStorage(OnboardingStorage.unitSystem) private var unitSystemRaw`.

Also: `HomeTimelineViews.swift` `formatDistance(_ meters:)` (lines 148-152) hardcodes `km`/`m`. [VERIFIED: direct read]

```swift
// CURRENT:
private func formatDistance(_ meters: Double) -> String {
  if meters >= 1000 { return String(format: "%.2f km", meters / 1000) }
  return "\(Int(meters.rounded())) m"
}
```

This is a private method on the view model — add `unitSystemRaw` parameter or read `@AppStorage` on the containing View.

### Site 3: GPS Elevation — `FitnessElevationPage`

**File:** `GooseSwift/FitnessLiveWorkoutViews.swift` lines 425-460 [VERIFIED: direct read]

```swift
// CURRENT (hardcoded "M" unit):
struct FitnessElevationPage: View {
  let elevationMeters: CLLocationDistance
  let elevationGainMeters: CLLocationDistance
  // ...
  value: "\(Int(max(elevationGainMeters, 0).rounded()))", unit: "M"
  value: "\(Int(max(elevationMeters, 0).rounded()))", unit: "M"
```

**Fix:** Add `@AppStorage(OnboardingStorage.unitSystem)` to `FitnessElevationPage` and convert:
- imperial: feet (`meters * 3.28084`), unit `"FT"`
- metric: unchanged, unit `"M"`

### Site 4: Pace Display

**File:** `GooseSwift/FitnessFormatting.swift` lines 63-69 [VERIFIED: direct read]

```swift
func formatFitnessPace(_ secondsPerKilometer: TimeInterval?) -> String {
  // Returns min/km format e.g. "5'30\""
}
```

For imperial, pace should be min/mile. Conversion: `secondsPerMile = secondsPerKilometer * 1.60934`.

---

## PR-INT-04: Localisation Audit — Full Findings

### xcstrings File State [VERIFIED: Python parse of Localizable.xcstrings]

| Metric | Count |
|--------|-------|
| Total strings | 853 |
| `shouldTranslate: false` | 33 |
| Strings with `state: "new"` in pt-PT | **0** |
| Strings missing pt-PT entirely | **63** |
| Of those: genuine UI strings needing translation | **58** |
| Of those: format/accessibility strings → `shouldTranslate: false` | **5** |

**Important correction from CONTEXT.md:** CONTEXT.md says "16 strings with state: new". The actual file has **zero** strings with `state: "new"`. The 63 missing strings have no pt-PT localization entry at all (not even a "new" state entry). This means they fall back to the key string, not an English translation — which is the visible-key-string problem described in PR-INT-04.

### Strings Recommended for `shouldTranslate: false`

These 5 strings are format specifiers or accessibility patterns — do not translate, mark as non-translatable:

| Key | Reason |
|-----|--------|
| `'%@ — %@ remaining'` | Positional format specifier (`%1$@`, `%2$@`) — already using positional args in EN value |
| `'%@, %@, %@'` | Positional format specifier |
| `'%@. %@. Double-tap to dismiss.'` | Accessibility format, positional args |
| `'Breathing circle, %@ phase'` | Accessibility label with format arg |
| `'Include Database%@'` | UI string with format suffix — could translate but format arg makes it fragile |

### UI Strings Needing pt-PT Translations (58 strings)

Key categories found:

**Already in Portuguese as key — just add pt-PT entry matching the key:**
- `'A importar…'` (key is PT, EN value is "Importing…") — add pt-PT = "A importar…"
- `'A iniciar...'`, `'Armar Alarme'`, `'Armar alarme de despertar'`, `'Cancelado'`, `'Cancelar'`, `'Cancelar Alarme'`, `'Cancelar alarme armado'`, `'Conecta o WHOOP para ativar'`, `'Conecta o WHOOP para usar o alarme'`, `'Diário'`, `'Diário de Hoje'`, `'Eliminar'`, `'Eliminar todos os dados locais?'`, `'Escrever nota do dia'`, `'Esta acção remove…'`, `'Guardar'`, `'Hora de acordar'`, `'Import do servidor'`, `'Não executado'`, `'ROTAS COACH'`

**English keys needing PT translations:**
- `'7-Day Trends'` → "Tendências 7 Dias"
- `'Breathe'` → "Respirar"
- `'Cancel workout entry'` → "Cancelar registo de treino"
- `'Choose Export Preset'` → "Escolher predefinição de exportação"
- `'Connect WHOOP to enable haptics'` → "Liga o WHOOP para ativar hápticos"
- `'Current metric values from your WHOOP data'` → "Valores actuais das métricas dos teus dados WHOOP"
- `'Custom (current settings)'` → "Personalizado (definições actuais)"
- `'Data'` → "Dados"
- `'Dismiss nudge'` → "Dispensar aviso"
- `'Effort'` → "Esforço"
- `'Effort %lld of 10'` → "Esforço %lld de 10"
- `'Frames & Metrics'` → "Frames & Métricas"
- `'Full Diagnostic'` → "Diagnóstico Completo"
- `'HR Sanitizer'` → "HR Sanitizer" (technical — leave in English or translate)
- `'Interval Timer'` → "Temporizador de Intervalos"
- `'License'` → "Licença"
- `'Log'` → "Registo"
- `'Log Workout'` / `'Log workout'` → "Registar Treino" / "Registar treino"
- `'Metric Explorer'` → "Explorador de Métricas"
- `'No Metrics Yet'` → "Ainda sem Métricas"
- `'No data for the last 7 days'` → "Sem dados nos últimos 7 dias"
- `'Paced breathing with haptics'` → "Respiração compassada com hápticos"
- `'Perceived Effort'` → "Esforço Percebido"
- `'Sport'` → "Desporto"
- `'Start breathing session'` → "Iniciar sessão de respiração"
- `'Start interval timer'` → "Iniciar temporizador de intervalos"
- `'Stop'` → "Parar"
- `'Stop breathing session'` → "Parar sessão de respiração"
- `'Stop interval timer'` → "Parar temporizador de intervalos"
- `'Sync your WHOOP band to populate metrics.'` → "Sincroniza a tua banda WHOOP para preencher as métricas."
- `'Wellness'` → "Bem-estar"
- `'Work/rest intervals with haptic transitions'` → "Intervalos trabalho/descanso com transições hápticas"
- Format strings: `'%lld / 10'`, `'%lld min'`, `'%llds'` — keep as-is or add pt-PT entries matching the key
- `'Frames & Metrics: decoded data only\n…'` — technical export description, could stay EN or translate
- `'Include Database%@'` — mark shouldTranslate: false

### xcstrings Edit Pattern [ASSUMED]

For strings with no pt-PT entry at all, the xcstrings JSON addition is:

```json
"Breathe" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Breathe"
      }
    },
    "pt-PT" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Respirar"
      }
    }
  }
}
```

For `shouldTranslate: false` strings:

```json
"%@ — %@ remaining" : {
  "shouldTranslate" : false
}
```

---

## PR-INT-05: ChatGPT Auth Endpoint Fix — Full Findings

### Current Implementation [VERIFIED: direct read of CodexEmbeddedAuth.swift]

```
Issuer:   https://auth.openai.com
Client ID: app_EMoamEEZ73f0CkXaXp7hrann

Step 1 — Device code request:
  POST https://auth.openai.com/api/accounts/deviceauth/usercode
  Body: {"client_id": "..."}
  Decodes: {device_auth_id, user_code, interval}

Step 2 — Poll for authorization code (non-standard intermediate step):
  POST https://auth.openai.com/api/accounts/deviceauth/token
  Body: {device_auth_id, user_code}
  Decodes: {authorization_code, code_challenge, code_verifier}

Step 3 — Token exchange:
  POST https://auth.openai.com/oauth/token
  Body: grant_type=authorization_code, code=..., redirect_uri=.../deviceauth/callback,
        client_id=..., code_verifier=...
  Decodes: {id_token, access_token, refresh_token, expires_in}
```

### Standard OAuth 2.0 Device Flow [VERIFIED: auth0.openai.com/.well-known/openid-configuration]

```
Issuer:   https://auth0.openai.com

Step 1 — Device code request:
  POST https://auth0.openai.com/oauth/device/code
  Body: {"client_id": "...", "scope": "openid email profile"}
  Standard response: {device_code, user_code, verification_uri, expires_in, interval}

Step 2 — Poll for token (standard OAuth device grant):
  POST https://auth0.openai.com/oauth/token
  Body: grant_type=urn:ietf:params:oauth:grant-type:device_code,
        device_code=..., client_id=...
  Standard response: {access_token, id_token, refresh_token, token_type, expires_in}
  While pending: HTTP 428 or {"error": "authorization_pending"}

Step 3 — Token refresh (same endpoint, different grant_type):
  POST https://auth0.openai.com/oauth/token
  Body: grant_type=refresh_token, refresh_token=..., client_id=...
```

### Key Differences Requiring Code Patches

| Aspect | Current | Standard OAuth |
|--------|---------|---------------|
| Issuer domain | `auth.openai.com` | `auth0.openai.com` |
| Device code endpoint | `/api/accounts/deviceauth/usercode` | `/oauth/device/code` |
| Poll endpoint | `/api/accounts/deviceauth/token` | `/oauth/token` |
| Poll body key | `device_auth_id` | `device_code` |
| Poll grant type | none (custom) | `urn:ietf:params:oauth:grant-type:device_code` |
| Device code field | `device_auth_id` in response | `device_code` in response |
| Poll auth code flow | Custom 2-step (auth code → token exchange) | Direct token in poll response |
| Pending status HTTP code | 403 or 404 | 428 (or `error: authorization_pending`) |

### Minimum Patch Strategy

The current flow's custom intermediate step (Step 2 returning `authorization_code + code_verifier`) doesn't exist in standard OAuth — the poll returns tokens directly. The patch must:

1. Change `private let issuer` from `"https://auth.openai.com"` to `"https://auth0.openai.com"`
2. Change `requestDeviceCode` path from `/api/accounts/deviceauth/usercode` to `/oauth/device/code`
3. Change `CodexDeviceCodeResponse` decoding: `device_code` (not `device_auth_id`)
4. Change `pollForAuthorizationCode` to poll `/oauth/token` with standard grant type, and decode tokens directly (remove the intermediate `CodexDeviceTokenPollResponse` step)
5. Change poll wait condition from HTTP 403/404 to `error: authorization_pending` JSON
6. Remove `exchangeCodeForTokens` method (no longer needed — poll returns tokens directly)
7. Keep `refreshStoredAuth` — path `/oauth/token` is correct, only issuer domain changes

This is a moderate refactor of `CodexEmbeddedAuth.swift`, not a 1-line patch. The struct `CodexDeviceTokenPollResponse` becomes `CodexDeviceTokenResponse` (same as final token).

### Verification URL
Current verification URL: `"\(issuer)/codex/device"` → unchanged — still navigates user to ChatGPT for approval.

### Unit Test Strategy
Mock the two network calls: device code request returns standard `device_code` JSON; token poll first returns `{"error": "authorization_pending"}` then returns token JSON. Assert that `completeDeviceCodeLogin` returns a `CodexStoredChatGPTAuth` with non-empty access token.

---

## Architecture Patterns

### Recommended Project Structure (no new files needed for PR-INT-01, PR-INT-04)

For PR-INT-03 (unit helpers):
```
GooseSwift/
├── FitnessFormatting.swift       # Add: fitnessDistanceParts(unitSystemRaw:), fitnessPaceParts(unitSystemRaw:), fitnessElevationParts(unitSystemRaw:)
├── HealthDataStore+V24Biometrics.swift  # Modify: skinTempText → skinTempText(unitSystemRaw:) or remove computed var
├── FitnessLiveWorkoutViews.swift  # Modify: 3 call sites add @AppStorage + pass unitSystemRaw
├── FitnessElevationPage (in FitnessLiveWorkoutViews)  # Modify: add @AppStorage, convert elevation
└── HomeTimelineViews.swift        # Modify: formatDistance reads @AppStorage
```

For PR-INT-05 (auth):
```
GooseSwift/
└── CodexEmbeddedAuth.swift        # Modify: issuer, endpoints, response structs, poll flow
```

### Pattern: Display-Layer Unit Conversion [VERIFIED: MoreProfileViews.swift]

```swift
// In the View:
@AppStorage(OnboardingStorage.unitSystem) private var unitSystemRaw = MoreProfileUnitSystem.imperial.rawValue

// In body or computed var:
Text(FitnessFormatting.elevationText(meters: elevationMeters, unitSystemRaw: unitSystemRaw))
```

Key principle: `@AppStorage` is reactive — SwiftUI re-renders the view when the value changes. No `.onChange` or notification needed for live updates. [VERIFIED: MoreProfileViews.swift uses this pattern]

### Pattern: xcstrings Edit (JSON structure) [ASSUMED]

The xcstrings format is JSON. Adding a pt-PT translation for an existing string requires inserting a `pt-PT` key under `localizations`. If the string entry currently has no `localizations` key at all, add the full structure. Use Xcode's String Catalog editor or direct JSON edit — both work.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unit conversion math | Custom conversion logic per view | Centralised helper in `FitnessFormatting.swift` | Same math used in 4+ call sites; single source prevents drift |
| OAuth device flow | New auth framework | Patch existing `CodexEmbeddedAuth.swift` | Flow is already working structure; only endpoints changed |
| Localization catalogue | Per-language `.strings` files | `Localizable.xcstrings` (already present) | xcstrings is the iOS 16+ standard; project already uses it |
| Temperature unit detection | New UserDefaults key | `@AppStorage(OnboardingStorage.unitSystem)` | Same key already used in profile view; no new preference |

---

## Common Pitfalls

### Pitfall 1: Mutating Stored Values for Unit Conversion
**What goes wrong:** Converting the stored `skinTempCelsius` value in `HealthDataStore` when displaying in Fahrenheit — the Rust bridge then receives wrong input on next sync.
**Why it happens:** Confusing "display value" with "stored value".
**How to avoid:** Conversion happens only in the formatting helper. `skinTempCelsius` in `V24BiometricsResult` stays in Celsius always. The `skinTempText` computed var (or its replacement) is the only place conversion happens.
**Warning signs:** If `skinTempCelsius` property type changes or gets mutated outside `HealthDataStore+V24Biometrics.swift`.

### Pitfall 2: Using LocalizedStatusStrings for Static Strings
**What goes wrong:** Adding new static UI strings to `LocalizedStatusStrings.swift` instead of `Localizable.xcstrings`.
**Why it happens:** `LocalizedStatusStrings.swift` looks like a localisation file but is specifically for dynamic state-machine strings (see header comment in file).
**How to avoid:** Only add strings to `LocalizedStatusStrings.swift` that represent raw `@Published` state values from `GooseBLEClient` or `GooseAppModel`. New UI strings go in `Localizable.xcstrings`.

### Pitfall 3: xcstrings JSON Edit Breaks File
**What goes wrong:** Invalid JSON syntax in `Localizable.xcstrings` causes the entire localisation system to fail silently — all strings show as keys.
**Why it happens:** Manual JSON edit without validation.
**How to avoid:** After editing, run `python3 -c "import json; json.load(open('GooseSwift/Localizable.xcstrings'))"` to validate JSON before committing.

### Pitfall 4: OAuth Poll Error Code
**What goes wrong:** Patching the poll endpoint but keeping the `403 || 404` HTTP status check — the standard endpoint returns 200 with `{"error": "authorization_pending"}` body, not a non-2xx status.
**Why it happens:** Custom old endpoint returned HTTP error codes; standard OAuth returns 200 with JSON error body.
**How to avoid:** In the new poll loop, do not catch `httpStatus(428, _)` — instead decode the response body and check `error == "authorization_pending"` or `error == "slow_down"`.

### Pitfall 5: Elevation in FitnessElevationPage Gets Two Separate Conversions
**What goes wrong:** Converting `elevationGainMeters` and `elevationMeters` independently with slightly different code, leading to inconsistent rounding.
**How to avoid:** Use a single `fitnessElevationParts(_ meters: Double, unitSystemRaw: String) -> (value: String, unit: String)` helper for both.

---

## Code Examples

### Example 1: Standard OAuth Device Code Response [CITED: auth0.openai.com/.well-known/openid-configuration]

```json
// POST https://auth0.openai.com/oauth/device/code
// Response:
{
  "device_code": "Ag_EE...xYZ",
  "user_code": "ABCD-EFGH",
  "verification_uri": "https://chatgpt.com/activate",
  "verification_uri_complete": "https://chatgpt.com/activate?user_code=ABCD-EFGH",
  "expires_in": 900,
  "interval": 5
}
```

### Example 2: Standard OAuth Device Poll Response — Pending [ASSUMED]

```json
// POST https://auth0.openai.com/oauth/token
// While user hasn't approved:
{
  "error": "authorization_pending",
  "error_description": "User has yet to authorize device code."
}
// After approval:
{
  "access_token": "eyJ...",
  "id_token": "eyJ...",
  "refresh_token": "...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

### Example 3: Skin Temperature with Unit Conversion [VERIFIED: MoreProfileViews.swift pattern]

```swift
// In FitnessFormatting.swift (or MoreProfileFormatting extension):
static func skinTempText(celsius: Double, unitSystemRaw: String) -> String {
  guard celsius >= 25 && celsius <= 40 else { return "--" }
  let unitSystem = MoreProfileUnitSystem(rawValue: unitSystemRaw) ?? .imperial
  switch unitSystem {
  case .metric:
    return String(format: "%.1f °C", celsius)
  case .imperial:
    return String(format: "%.1f °F", celsius * 9.0 / 5.0 + 32.0)
  }
}

// In V24BiometricsCard view:
@AppStorage(OnboardingStorage.unitSystem) private var unitSystemRaw = MoreProfileUnitSystem.imperial.rawValue
// ...
value: MoreProfileFormatting.skinTempText(celsius: result.skinTempCelsius ?? 0, unitSystemRaw: unitSystemRaw)
```

### Example 4: Distance Parts with Imperial [VERIFIED: FitnessFormatting.swift existing pattern]

```swift
func fitnessDistanceParts(
  _ meters: CLLocationDistance,
  unitSystemRaw: String
) -> (value: String, unit: String) {
  if MoreProfileUnitSystem(rawValue: unitSystemRaw) == .imperial {
    let miles = meters / 1609.344
    if miles >= 0.1 {
      return (String(format: "%.2f", miles), "MI")
    }
    let feet = meters * 3.28084
    return ("\(Int(max(feet, 0).rounded()))", "FT")
  }
  if meters >= 1000 {
    return (String(format: "%.2f", meters / 1000), "KM")
  }
  return ("\(Int(max(meters, 0).rounded()))", "M")
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-language `.lproj/Localizable.strings` | Single `Localizable.xcstrings` (JSON) | iOS 16 / Xcode 15 | Centralised, supports plurals, state tracking |
| OAuth 2.0 custom device flow (auth.openai.com) | Standard RFC 8628 device flow (auth0.openai.com) | OpenAI 2024/2025 migration | Standard response field names, standard error codes |

**Deprecated/outdated:**
- `auth.openai.com/api/accounts/deviceauth/usercode`: OpenAI proprietary endpoint, appears to have been replaced by standard OAuth at auth0.openai.com. [ASSUMED — confirmed by OpenID config returning auth0.openai.com as device_authorization_endpoint, but cannot confirm the old endpoint is 404ing without testing against a live account]

---

## Environment Availability

Step 2.6: SKIPPED — Phase 74 is purely Swift source code changes. No external tools, databases, or CLIs beyond the existing Xcode build chain are required.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) |
| Config file | `GooseSwift.xcodeproj` — no existing Swift test target detected |
| Quick run command | `xcodebuild test -project GooseSwift.xcodeproj -scheme GooseSwift -destination 'platform=iOS Simulator,...'` |
| Full suite command | Same (no Rust tests affected by this phase) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated | Notes |
|--------|----------|-----------|-----------|-------|
| PR-INT-01 | No UUIDs in main views | Static audit | Code comment + grep | Negative result — no runtime test needed |
| PR-INT-03 | Temperature in °F when imperial | Unit | `XCTAssertEqual(skinTempText(celsius: 37, unitSystemRaw: "imperial"), "98.6 °F")` | Wave 0: write test file |
| PR-INT-03 | Distance in MI when imperial | Unit | `XCTAssertEqual(fitnessDistanceParts(1609.344, unitSystemRaw: "imperial").unit, "MI")` | Wave 0: write test file |
| PR-INT-03 | Elevation in FT when imperial | Unit | `XCTAssertEqual(fitnessElevationParts(100, unitSystemRaw: "imperial").unit, "FT")` | Wave 0: write test file |
| PR-INT-04 | No visible key strings in pt-PT | Static | `python3 validate_xcstrings.py` | Manual spot-check in simulator |
| PR-INT-05 | Device code request calls correct endpoint | Unit (mock) | Mock URLSession; assert request URL = `auth0.openai.com/oauth/device/code` | Wave 0: test file needed |
| PR-INT-05 | Poll succeeds after authorization_pending | Unit (mock) | Mock: first response = pending JSON, second = token JSON; assert auth returned | Wave 0: test file needed |
| PR-INT-05 | Manual sign-in completes in Coach settings | Manual | human_needed | Physical device with real ChatGPT account |

### Wave 0 Gaps

- [ ] `GooseSwift/Tests/UnitConversionTests.swift` — covers PR-INT-03 conversion math (temp, distance, elevation, pace)
- [ ] `GooseSwift/Tests/CodexAuthTests.swift` — covers PR-INT-05 mock network responses
- [ ] No test runner configured — if no test target exists in Xcode project, Wave 0 must add target before tests can run

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes (PR-INT-05) | OAuth 2.0 device flow (RFC 8628) |
| V3 Session Management | Yes (PR-INT-05) | Keychain storage (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) — already correct |
| V4 Access Control | No | — |
| V5 Input Validation | No | Unit conversion helpers have no user input |
| V6 Cryptography | No | Token storage in Keychain — already handled |

### Known Threat Patterns for OAuth Device Flow

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Device code phishing | Spoofing | Verification URL shown to user before they approve; cannot be forged |
| Token storage leak | Information Disclosure | Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — correct |
| Replay of device_code | Elevation | Short expiry (900s default); poll is server-authoritative |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Standard OAuth device flow at auth0.openai.com is what ChatGPT sign-in currently expects | PR-INT-05 Findings | If OpenAI uses yet another custom flow, the patch won't fix sign-in. `human_needed` verification gate covers this. |
| A2 | Poll response returns `authorization_pending` JSON error (not HTTP 4xx) while user hasn't approved | PR-INT-05 Code Examples | If auth0.openai.com returns HTTP 428 or different error key, poll loop needs adjustment |
| A3 | `app_EMoamEEZ73f0CkXaXp7hrann` client ID is still valid for auth0.openai.com | PR-INT-05 | If client ID is rejected, PR-INT-05 cannot be fixed without a new client registration |
| A4 | xcstrings JSON format is stable — adding `pt-PT` entries via direct JSON edit works without Xcode regenerating the file | PR-INT-04 | If Xcode re-serialises the file on open, JSON formatting may change (harmless as long as JSON is valid) |
| A5 | `MoreProfileUnitSystem` enum is accessible from `FitnessFormatting.swift` (same module, no access control issue) | PR-INT-03 | If declared `internal` in a future modularisation, import needed — currently fine as same module |

---

## Open Questions

1. **PR-INT-05: Does the client ID (`app_EMoamEEZ73f0CkXaXp7hrann`) work with auth0.openai.com?**
   - What we know: Client ID is hard-coded in current implementation; used with `auth.openai.com` (old domain)
   - What's unclear: Whether auth0.openai.com accepts the same client ID for device flow
   - Recommendation: The `human_needed` gate on manual sign-in verification will catch this. If it fails, a different client ID may be needed.

2. **PR-INT-04: Should strings written in Portuguese as keys (e.g. `'Cancelar'`) have pt-PT = key value, or should we rely on fallback?**
   - What we know: When no pt-PT entry exists, iOS falls back to the key string directly
   - What's unclear: If the key is already correct Portuguese, the fallback works — adding explicit pt-PT is technically redundant but Xcode marks them as missing
   - Recommendation: Add explicit pt-PT = key value for all Portuguese-keyed strings to silence Xcode warnings and future-proof.

3. **PR-INT-03: Does CONTEXT.md "4 fields" include pace, or only temp + distance + elevation?**
   - What we know: CONTEXT.md says "GPS distance/pace/elevation"; pace is computed from distance in `FitnessLiveWorkoutViews`
   - What's unclear: Whether `formatFitnessPace` (which returns min/km) needs imperial (min/mile) variant
   - Recommendation: Include pace conversion — it reads from `distanceMeters` / elapsed, so imperial path converts to min/mile. 4 sites total.

---

## Sources

### Primary (HIGH confidence)
- `GooseSwift/CodexEmbeddedAuth.swift` — full device auth implementation read directly
- `GooseSwift/MoreProfileViews.swift` — unit system pattern and `MoreProfileFormatting` read directly
- `GooseSwift/HealthDataStore+V24Biometrics.swift` — `skinTempCelsius` storage and `skinTempText` read directly
- `GooseSwift/FitnessFormatting.swift` — `fitnessDistanceParts`, `formatFitnessPace` read directly
- `GooseSwift/FitnessLiveWorkoutViews.swift` — elevation display and call sites read directly
- `GooseSwift/HomeTimelineViews.swift` — `formatDistance` read directly
- `GooseSwift/HealthRecoveryWidgets.swift` — `V24BiometricsCard` call site read directly
- `GooseSwift/Localizable.xcstrings` — parsed via Python; 853 strings, 63 missing pt-PT, 0 "new" state
- `https://auth0.openai.com/.well-known/openid-configuration` — live OpenID config fetched; device_authorization_endpoint confirmed as `https://auth0.openai.com/oauth/device/code`
- grep audit of all main-tab view files — confirmed zero UUID/identifier display in Health, Home, Sleep views

### Secondary (MEDIUM confidence)
- `GooseSwift/LocalizedStatusStrings.swift` — dynamic string pattern read; confirms separation from static xcstrings
- `GooseSwift/ChatGPTCoachProvider.swift` — full auth flow context read
- `GooseSwift/CoachSettingsSheet.swift` — sign-in UI context read

---

## Metadata

**Confidence breakdown:**
- PR-INT-01 (identifier audit): HIGH — direct codebase grep, negative result confirmed
- PR-INT-03 (unit formatting): HIGH — all 4 sites found and read directly; pattern confirmed
- PR-INT-04 (localisation): HIGH — Python parse of actual xcstrings file; exact counts
- PR-INT-05 (auth): MEDIUM — endpoint confirmed via OpenID config; response field names and error codes assumed from RFC 8628 standard (not tested against live ChatGPT sign-in)

**Research date:** 2026-06-13
**Valid until:** 2026-07-13 (OpenAI auth endpoints could change; xcstrings counts valid until new strings added)

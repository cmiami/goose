---
plan: 74-01
status: complete
requirements: PR-INT-04
duration: integrated via cherry-pick from PR #133
files_modified: 25 (Localizable.xcstrings + 24 Swift view files)
---
# Summary: i18n — English source language + pt-PT localisation

Integrated PR #133 (cmiami:pr/i18n-english-source) — 3 commits:
- `fix(i18n): make English the source language across all UI strings` — replaced hardcoded Portuguese strings with `String(localized:)` English sources across all UI files; xcstrings updated to use en as sourceLanguage
- `fix(i18n): localise remaining display labels so pt-PT follows device language` — 10 more files updated with `String(localized:)` calls
- `fix(coach,i18n): type sleep-debt math and address review feedback` — sleep debt calculation fixed to use minutes

## Acceptance criteria met
- [x] English is the source language in Localizable.xcstrings
- [x] All UI strings use String(localized:) / NSLocalizedString — no hardcoded Portuguese strings visible in pt-PT locale
- [x] Build passes

---
plan: 74-02
status: complete
requirements: PR-INT-01
duration: integrated via cherry-pick from PR #136
files_modified: 13
---
# Summary: UX — Technical identifiers moved off main screens

Integrated PR #136 (cmiami:pr/ux-advanced-sections) — 2 commits:
- `feat(ux): move technical identifiers off the main screens into advanced sections` — UUIDs, raw values, sequence IDs removed from main Health/Home/Sleep views; exposed only in More > Debug sections
- `fix(i18n,status): cover all health status strings and fix catalog "loaded" guard` — LocalizedStatusStrings.swift updated; HealthCatalog "loaded" guard fixed

## Acceptance criteria met
- [x] Technical identifiers (UUIDs, raw values, sequence IDs) not visible on main Health, Home, or Sleep views
- [x] Advanced/debug sections in More tab retain full technical data
- [x] Build passes

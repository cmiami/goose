---
plan: 75-02
status: complete
requirements: PR-INT-06
duration: integrated via cherry-pick from PR #135
files_modified: 12 (including new HealthDataStore+BaselineProgress.swift, HomeBaselineProgressViews.swift, BaselineProgressTests.swift)
---
# Summary: Home Warm-up Progress + Honest Vitals (PR-INT-06)

Integrated PR #135 (cmiami:pr/home-baseline-progress) — 6 commits:
- `feat(home): show baseline warm-up progress instead of unexplained empty dials` — BaselineProgressModel + HomeBaselineProgressViews.swift; warm-up ring shows actual EWMA accumulation progress
- `fix(home): no success checkmark on vitals that have no data` — HomeHealthMonitorViews updated
- `fix(home): replace raw engineering next_actions with friendly copy in coach tips` — HomeDashboardView coach tips humanized
- `fix(coach): friendly headline recommendation on the Coach overview` — CoachView headline improved
- `test(home): cover BaselineProgressModel` — BaselineProgressTests.swift (106 lines)
- `fix(home): address review on baseline warm-up PR` — minor polish

## Acceptance criteria met
- [x] Home screen shows warm-up progress (not empty dials) during baseline accumulation
- [x] Vitals without data don't show false success checkmarks
- [x] Coach overview has friendly headlines
- [x] BaselineProgressTests added
- [x] Build passes

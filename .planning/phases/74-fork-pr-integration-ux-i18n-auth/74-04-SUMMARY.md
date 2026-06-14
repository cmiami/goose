---
plan: 74-04
status: complete
requirements: PR-INT-05
duration: integrated via cherry-pick from PR #132
files_modified: 7
---
# Summary: Coach — ChatGPT sign-in fixed

Integrated PR #132 (cmiami:pr/coach-chatgpt-signin) — 2 commits:
- `fix(coach): make ChatGPT sign-in actually work from Coach settings` — CodexEmbeddedAuth.swift updated to OAuth 2.0 device flow; CoachChatModel.startOAuthSignIn() clears error before attempting; CoachSettingsSheet passes chat model to CoachProviderConfigView
- `fix(coach): isolate ChatGPT provider to MainActor and harden config view` — ChatGPTCoachProvider marked @MainActor @Observable; CoachProviderConfigView type-checks active provider before passing to ChatGPTConfigView

## Acceptance criteria met
- [x] ChatGPT sign-in flow initiated from Coach settings
- [x] Error cleared before each new sign-in attempt
- [x] ChatGPTCoachProvider correctly isolated to MainActor
- [x] Build passes (1 warning about protocol conformance crossing actor boundary — non-blocking)
- [ ] End-to-end sign-in with real ChatGPT account — human_needed (requires real device + account)

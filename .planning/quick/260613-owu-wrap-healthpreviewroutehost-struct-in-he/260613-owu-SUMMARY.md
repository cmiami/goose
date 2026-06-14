---
quick_id: 260613-owu
status: complete
date: 2026-06-13
---

# Quick Task 260613-owu — Summary

## What was done

Wrapped `HealthPreviewRouteHost` struct in `GooseSwift/HealthPreviews.swift`
with `#if DEBUG` / `#endif` guards.

**Root cause:** `HealthRouteDetailView.init(route:previewState:)` is declared
inside `#if DEBUG` in `HealthDashboardViews.swift`. `HealthPreviewRouteHost`
called that init without a matching guard, causing the Release configuration
build to fail with:

```
error: incorrect argument label in call (have 'route:previewState:', expected 'route:store:')
error: cannot convert value of type 'HealthPreviewState' to expected argument type 'HealthDataStore'
** BUILD FAILED **
```

**Fix:** One `#if DEBUG` / `#endif` block around lines 6–17 of
`GooseSwift/HealthPreviews.swift`. The `#Preview` macros that follow are
unaffected — they already compile only in debug contexts.

## Files changed

- `GooseSwift/HealthPreviews.swift` — added `#if DEBUG` guard around `HealthPreviewRouteHost`

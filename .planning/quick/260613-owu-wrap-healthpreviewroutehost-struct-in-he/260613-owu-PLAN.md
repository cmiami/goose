---
quick_id: 260613-owu
slug: wrap-healthpreviewroutehost-struct-in-he
description: Wrap HealthPreviewRouteHost struct in HealthPreviews.swift with #if DEBUG / #endif guards to fix Release build CI failure on v10.0 tag
date: 2026-06-13
status: planned
---

# Quick Task 260613-owu: Fix Release build — HealthPreviewRouteHost #if DEBUG guard

## Goal

The v10.0 tag CI Release build fails because `HealthPreviewRouteHost` in
`GooseSwift/HealthPreviews.swift` calls
`HealthRouteDetailView(route:previewState:)`, which is only available in
`#if DEBUG` builds. In Release configuration that init doesn't exist, so the
compiler errors out.

## Root Cause

`HealthDashboardViews.swift:316–328`:
```swift
#if DEBUG
  init(route: HealthRoute, previewState: HealthPreviewState? = nil) { ... }
#endif
```

`HealthPreviews.swift:12` (no guard):
```swift
HealthRouteDetailView(route: route, previewState: state)
```

## Task

### T1 — Wrap HealthPreviewRouteHost in #if DEBUG

**File:** `GooseSwift/HealthPreviews.swift`
**Action:** Add `#if DEBUG` before `struct HealthPreviewRouteHost` and `#endif`
after its closing brace (before the `#Preview` macros that follow).

**Before:**
```swift
struct HealthPreviewRouteHost: View {
  ...
}

#Preview("Health Landing") {
```

**After:**
```swift
#if DEBUG
struct HealthPreviewRouteHost: View {
  ...
}
#endif

#Preview("Health Landing") {
```

**Verify:** `xcodebuild -project GooseSwift.xcodeproj -scheme GooseSwift -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" build 2>&1 | tail -5` — must not contain "error:" for HealthPreviews.swift

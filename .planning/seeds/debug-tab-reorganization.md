---
status: dormant
planted: 2026-06-13
planted_during: exploration session — aba debug desorganizada
trigger_when: when starting a new milestone after v10.0 ships, or when any Debug tab work is scheduled
scope: Medium
---

# Debug Tab & More Navigation Reorganisation

## Why This Matters

The Debug tab (`MoreDebugViews.swift`) has grown to 612 lines and 12 sections in a single
flat `List` — Rust/Parser, Debug Session, Health Packet Capture, WHOOP Movement Test, HR
Sanitizer, WHOOP Event Signals, Research BT Commands, Diagnostics, Command Evidence,
Command Shortcuts, Protected Controls, and Developer. There is no hierarchy, actions are
buried after status rows, and the "Connection" status row appears three times across
different sections.

Separately, the "Support" entry in `MoreView` is miscategorised: its content (log paths,
raw bundle paths, AirDrop export buttons) is developer tooling, not user-facing help. It
sits alongside "About" in the Support group, misleading users who look for assistance and
confusing developers who look for export tools.

## Proposed Changes

### 1 — Rename and move "Support" in MoreRouteModels (low risk, high clarity)

- Rename `.support` title from "Support" to "Logs & Export"
- Move it from `supportRoutes` into `developerToolRoutes`
- The Support group in `MoreView` then contains only "About", which is appropriate for
  end users
- Developer hub grows from 6 to 7 tools — still manageable as a flat list

Files: `MoreRouteModels.swift` (title, subtitle, `supportRoutes`, `developerToolRoutes`),
`GooseSwift/Localizable.xcstrings` (string keys), `MoreInfoViews.swift` (navigationTitle)

### 2 — Split MoreDebugView into 3 tabs

Replace the flat 12-section `List` with a `TabView` containing:

| Tab | Sections |
|-----|----------|
| **Status** | Rust And Parser, BLE connection (single shared row), HR Sanitizer, Invalid Frames |
| **Capture** | Health Packet Capture (all controls + family rows), Temperature, RR Watch |
| **Research** | WHOOP Event Signals, WHOOP Movement Test, Research BT Commands, Debug Session |

Diagnostics, Command Evidence, Command Shortcuts, and Protected Controls move to a
"Tools" sub-section inside Research, or are promoted to their own `MoreRoute` under the
Developer hub if they grow further.

Files: `MoreDebugViews.swift` (split into 3 child view structs), `MoreDataStore.swift`
(no changes needed — state is already separate)

## When to Surface

**Trigger:** when starting a new milestone after v10.0 ships, or when any Debug tab work
is scheduled (e.g. adding a new capture type or diagnostic section).

This is polish / developer-experience work, not user-facing functionality. Do not
interrupt an active milestone for it.

## Scope Estimate

**Medium** — two independent sub-tasks:
- Sub-task A (Support rename+move): ~20 lines changed, 30 min
- Sub-task B (Debug TabView split): ~150 lines refactored into 3 child views, ~2h

## Breadcrumbs

- `GooseSwift/MoreDebugViews.swift` — full debug view, 612 lines
- `GooseSwift/MoreRouteModels.swift:117–124` — `supportRoutes` and `developerToolRoutes` arrays
- `GooseSwift/MoreView.swift:90–96` — "Support" and "Developer" sections in MoreView
- `GooseSwift/MoreInfoViews.swift:63` — `MoreSupportView` (content to rename)
- `GooseSwift/MoreProfileViews.swift:56` — `MoreDeveloperView` (hub list)

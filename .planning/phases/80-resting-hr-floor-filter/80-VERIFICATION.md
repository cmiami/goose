---
phase: 80
status: passed
build: passed
---
# Phase 80: Resting HR Floor Filter — Verification

## Build Status
BUILD SUCCEEDED — Rust `cargo build` clean, Xcode simulator build SUCCEEDED

## BUG-HR-01: Resting HR Floor Filter ✅

**Change:** `metric_features.rs` line 4493: `25..=240` → `30..=240`

**Evidence:**
- Any HR value below 30 bpm is now rejected at the heart rate feature building
  chokepoint with `heart_rate_marker_outside_plausible_range` quality flag
- Historical sync that previously produced 32 bpm will now produce no value or
  a plausible value since sub-30 samples are excluded from `low_quartile_mean_hr`
- Existing Rust tests unaffected (no tests used marker values in 25–29 range)

## Notes
- Simple 1-line change, no downstream test failures
- Consistent with WHOOP's documented physiological minimum (30 bpm)
- Closes #130

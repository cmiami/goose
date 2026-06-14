---
phase: 67
status: issues_found
critical_count: 1
warning_count: 2
---
# Code Review: Phase 67 — WHOOP 5.0 Protocol Fixes

## Summary

Phase 67 adds two protocol extensions to the Rust core: (1) the R22 realtime parser for WHOOP 5.0 BLE handle 0x0022, and (2) the V18 historical frame parser with stale-clock guard. The ecosystem update (bridge.rs, capture_correlation.rs, export.rs, metric_features.rs) follows the prescribed multi-file pattern correctly. Parser logic is sound and defensively written. Three issues were found: one critical (divergent date validation between two copies of `parse_rfc3339_utc_unix_ms`), and two warnings (stale-clock plausibility check uses pre-snap value, `r22_whoop5_hr` absent from heart-rate feature extraction).

---

## Findings

### [CRITICAL] Divergent `parse_rfc3339_utc_unix_ms` — historical_sync.rs accepts invalid calendar dates that metric_features.rs rejects

**File:** `Rust/core/src/historical_sync.rs:1976–1983` and `Rust/core/src/metric_features.rs:6609–6616`

**Description:**
`parse_rfc3339_utc_unix_ms` is implemented twice — once in `historical_sync.rs` (the `pub(crate)` canonical version) and once as a private copy in `metric_features.rs`. The two copies diverge on day validation:

- `historical_sync.rs` checks `!(1..=31).contains(&day)` — accepts invalid dates like `2024-02-30`, `2024-04-31`, etc.
- `metric_features.rs` checks `day == 0 || day > days_in_month(year, month)` — correctly rejects those dates.

When `historical_sync.rs` accepts a day value that exceeds the actual month length (e.g. Feb 30 = day 30 in a 28-day month), `days_from_civil` computes a correct proleptic Gregorian day count, but the resulting unix timestamp is wrong by the excess days. This means a corrupted or device-glitch timestamp like `2024-02-30T12:00:00Z` is treated as `2024-03-01T12:00:00Z` in the stale-clock confirmation path, producing a plausible but incorrect confirmation result. The `chrono_captured_at_to_unix` wrapper in metric_features.rs calls the `pub(crate)` version from `historical_sync.rs` (line 6433), so R22/R17 shadow deduplication uses the weaker validation.

`chrono_captured_at_to_unix` (metric_features.rs:6432) calls `crate::historical_sync::parse_rfc3339_utc_unix_ms` — the lenient one — not the local strict copy.

**Fix:** Remove the private copy in `metric_features.rs` (lines 6584–6625 and helpers `parse_millis_fraction`, `days_in_month`, `is_leap_year`, `days_from_civil` defined locally). Apply the stricter day validation to the canonical `pub(crate)` version in `historical_sync.rs`:

```rust
// historical_sync.rs — replace line 1977
|| !(1..=31).contains(&day)
// with:
|| day == 0
|| day > days_in_month(year, month)
```

Then add the month-length helpers (`days_in_month`, `is_leap_year`) to `historical_sync.rs` and delete the entire duplicate block from `metric_features.rs`. All callers of the local `parse_rfc3339_utc_unix_ms` in `metric_features.rs` (lines 4902, 5107, 5116, 5123, 5125, 5172, 6310, 6525, 6547, 6559, 6565) must be updated to call `crate::historical_sync::parse_rfc3339_utc_unix_ms`.

---

### [WARNING] Stale-clock plausibility gate uses original (pre-snap) device_timestamp_seconds

**File:** `Rust/core/src/historical_sync.rs:1911–1922`

**Description:**
After the stale-clock snap at line 1915, `effective_device_seconds` holds the 300-second-grid value. But the plausibility gate at line 1922 still tests `device_timestamp_seconds` (the original value):

```rust
&& plausible_unix_timestamp_seconds(device_timestamp_seconds)   // line 1922
```

`plausible_unix_timestamp_seconds` accepts seconds in `946_684_800..=4_102_444_800` (year 2000–2100). If a device RTC is stale by more than 1 day, the original value is the one that triggered the snap — meaning it could legitimately be outside the plausible range (e.g. a reset RTC at epoch 0). In that case the row is correctly rejected, which is acceptable. But if the device_timestamp is plausible yet drifted (e.g. an early-2024 device with a 2-day clock offset in 2026), the snap produces a new value that is 300-grid aligned but the plausibility gate is satisfied by the original. This is a logic inconsistency: the gate should reflect the snapped value to be semantically coherent with the sample_time comparison at line 1924 (which uses `device_timestamp_unix_ms`, derived from `effective_device_seconds`).

**Fix:**

```rust
// Replace line 1922:
&& plausible_unix_timestamp_seconds(device_timestamp_seconds)
// with:
&& plausible_unix_timestamp_seconds(effective_device_seconds)
```

---

### [WARNING] `r22_whoop5_hr` not included in heart-rate feature extraction trusted frames

**File:** `Rust/core/src/metric_features.rs:1171–1174`

**Description:**
`run_heart_rate_feature_report` calls `trusted_frames_for_summary_kinds` with:

```rust
&["normal_history", "v18_history", "raw_motion_k10"]
```

R22 (`r22_whoop5_hr`) is correctly included in the HRV feature report (line 1870) and in the bridge decode stream. However it is absent from `run_heart_rate_feature_report`. On a WHOOP 5.0 device that streams exclusively via R22 (handle 0x0022), the heart-rate feature report will have no trusted frames and will produce an empty or untrustworthy result even when R22 data is present.

The HRV path (which does include `r22_whoop5_hr`) is used for recovery scoring, but `run_heart_rate_feature_report` is used for the HR trend timeline and resting heart rate features. Both should treat R22 as a trusted source.

**Fix:**

```rust
// metric_features.rs line 1173 — add r22_whoop5_hr:
&["normal_history", "v18_history", "raw_motion_k10", "r22_whoop5_hr"]
```

Also verify `heart_rate_plan_from_row` (line 4115) handles `body_summary_kind = "r22_whoop5_hr"` — if it only matches `normal_history`/`v18_history`, R22 frames will still be silently skipped even after the trusted-frames fix.

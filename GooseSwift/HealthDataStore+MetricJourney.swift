import Darwin
import Foundation
import SwiftUI
import UIKit

// MARK: - BaselineNightCounts
//
// Real validated night counts read from the Rust EWMA fold-history. hasReport
// is false whenever the bridge read fails — while the report is still loading a
// family fails CLOSED to inDevelopment, never to a fabricated 0-night
// "calibrating" reading.

struct BaselineNightCounts {
  let hrvNights: Int
  let restingNights: Int
  let hrvReady: Bool
  let restingReady: Bool
  let hasReport: Bool
}

// MARK: - HealthDataStore+MetricJourney

extension HealthDataStore {
  // Synchronous bridge call — must run off @MainActor (see CLAUDE.md
  // anti-pattern). Mirrors HealthDataStore.packetInputBridgeReports: a
  // nonisolated static worker the view's background refresh path awaits.
  nonisolated static func baselineNightCounts(databasePath: String) async -> BaselineNightCounts {
    let bridge = GooseRustBridge()
    let empty = BaselineNightCounts(
      hrvNights: 0, restingNights: 0, hrvReady: false, restingReady: false, hasReport: false
    )
    do {
      let result = try await bridge.requestAsync(
        method: "store.ewma_baseline_fold_history",
        args: ["database_path": databasePath]
      )
      // Parsed inline rather than via the @MainActor JSON helpers so this stays
      // fully off the main actor (the synchronous bridge call must not block it).
      guard
        let hrv = result["hrv"] as? [String: Any],
        let restingHr = result["resting_hr"] as? [String: Any]
      else {
        return empty
      }
      return BaselineNightCounts(
        hrvNights: nightCount(hrv),
        restingNights: nightCount(restingHr),
        hrvReady: readyFlag(hrv),
        restingReady: readyFlag(restingHr),
        hasReport: true
      )
    } catch {
      // No coercion that invents a reading — absence of report maps to the
      // family's fail-closed state, not calibrating.
      return empty
    }
  }

  private nonisolated static func nightCount(_ state: [String: Any]) -> Int {
    if let int = state["night_count"] as? Int {
      return int
    }
    if let number = state["night_count"] as? NSNumber {
      return number.intValue
    }
    return 0
  }

  private nonisolated static func readyFlag(_ state: [String: Any]) -> Bool {
    if let bool = state["is_ready"] as? Bool {
      return bool
    }
    if let number = state["is_ready"] as? NSNumber {
      return number.boolValue
    }
    return false
  }

  // Real trusted/imported sleep night counts from the sleep score status report.
  // Returns (0, false) when the sleep score has not been computed yet.
  func sleepUsableNightCount() -> (nights: Int, hasReport: Bool) {
    guard
      let status = Self.map(packetScoreReports["sleep"], "score_result", "output", "status_report")
    else {
      return (0, false)
    }
    let trusted = Self.intValue(status["trusted_goose_sleep_nights"])
    let imported = Self.intValue(status["imported_platform_sleep_nights"])
    return (trusted ?? imported ?? 0, true)
  }

  // Length of the real cardio-load day series — no fabrication, just a count.
  func cardioLoadDayCount() -> Int {
    cardioLoadWeeklyPoints().count
  }

  // The single mapping function. Every 0 here is a real observed count;
  // absence-of-report fails closed to inDevelopment, never a fabricated reading.
  // Each family lands in exactly one MetricJourneyCategory: dataGathering rows
  // advance by wearing the strap, inDevelopment rows are blocked on a decoder we
  // are still building (wearing won't help).
  func metricJourneys(
    nightCounts: BaselineNightCounts,
    sleepNights: (nights: Int, hasReport: Bool),
    cardioDays: Int,
    readiness: BaselineProgressModel
  ) -> [MetricJourney] {
    let journeys = MetricJourneyFamily.allCases.map { family -> MetricJourney in
      MetricJourney(family: family, state: state(for: family, nightCounts: nightCounts, sleepNights: sleepNights, cardioDays: cardioDays, readiness: readiness))
    }
    return journeys.sorted { left, right in
      if left.state.sortRank != right.state.sortRank {
        return left.state.sortRank < right.state.sortRank
      }
      return left.family.window.ready < right.family.window.ready
    }
  }

  private func state(
    for family: MetricJourneyFamily,
    nightCounts: BaselineNightCounts,
    sleepNights: (nights: Int, hasReport: Bool),
    cardioDays: Int,
    readiness: BaselineProgressModel
  ) -> MetricJourneyState {
    switch family {
    case .sleep:
      // Sleep is pure data-gathering: no report or zero nights means the user
      // simply hasn't worn it to sleep yet. Wearing it tonight advances it.
      let ready = family.window.ready
      if !sleepNights.hasReport || sleepNights.nights == 0 {
        return .needsFirstNight
      }
      if sleepNights.nights >= ready {
        return .ready
      }
      return .calibrating(have: sleepNights.nights, need: ready)

    case .recovery:
      // Recovery scoring (metrics.rs recovery_v0/v1) consumes hrv_rmssd_ms,
      // whose decode is extraction_ready:false (hrv_rr_interval_scale_unverified).
      // When that *_unverified blocker is present, recovery cannot compute no
      // matter how many nights are worn — that is an in-development gate, NOT
      // calibrating, so we never imply wearing the strap will help. Fail CLOSED
      // to inDevelopment while the readiness report is still loading. Once the
      // gate is genuinely clear, recovery is ordinary data-gathering against the
      // resting-HR baseline maturity window.
      if !readiness.hasReport
        || familyHasUnverifiedExtractionBlocker("recovery", in: readiness) {
        return .inDevelopment
      }
      let ready = family.window.ready
      if !nightCounts.hasReport || nightCounts.restingNights == 0 {
        return .needsFirstNight
      }
      if nightCounts.restingReady {
        return .ready
      }
      return .calibrating(have: nightCounts.restingNights, need: ready)

    case .hrv:
      // CRITICAL GUARD: HRV depends on rr_intervals_ms whose decoder is
      // extraction_ready:false (hrv_rr_interval_scale_unverified in
      // metric_readiness.rs, not validated against openwhoop_reference.rs). The
      // proprietary decode is unproven, so HRV is ALWAYS in development today —
      // it never shows calibrating progress and never reads ready, regardless of
      // night count. This is a hardcoded product invariant, not data-dependent,
      // so the EWMA night counts can never flash a transient "calibrating".
      return .inDevelopment

    case .respiratory, .skinTemp, .spo2:
      // Sensor decoders we are still building (respiratory_rate_semantics_unverified,
      // skin_temp_delta_c, spo2 gates in metric_readiness.rs). Wearing the strap
      // streams the raw signal but we cannot yet turn it into a trustworthy
      // reading — honestly in development, never "collecting".
      return .inDevelopment

    case .cardio:
      // Cardio Load is data-gathering: it builds across a 28-day window. Before
      // the first day lands there is nothing to calibrate against yet, so it
      // reads as collecting rather than implying a missed night.
      let ready = family.window.ready
      if cardioDays == 0 {
        return .collecting("Builds over ~28 days")
      }
      if cardioDays >= ready {
        return .ready
      }
      return .calibrating(have: cardioDays, need: ready)
    }
  }

  // Detects an un-validated extraction blocker on a readiness family: blocker
  // strings of the form "<input>: <reason>" carrying "_unverified" or
  // "_not_defined" come straight from metric_readiness.rs InputPlan.blocker and
  // can only be cleared by validating the decoder — out of scope here.
  private func familyHasUnverifiedExtractionBlocker(
    _ name: String,
    in readiness: BaselineProgressModel
  ) -> Bool {
    guard let family = readiness.families.first(where: { $0.id == name }) else {
      return false
    }
    if family.ready {
      return false
    }
    return family.blockerReasons.contains { reason in
      reason.contains("_unverified") || reason.contains("_not_defined")
    }
  }
}

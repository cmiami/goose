import SwiftUI

// MARK: - MetricJourneyState
//
// The honest per-family warm-up state machine for the Home "data journey" card.
// Every state is derived from a REAL observed count (nights captured) or from a
// readiness blocker — none of these are fabricated. Glyphs are STATIC SF
// Symbols; nothing here implies background compute via a spinner or hourglass.

enum MetricJourneyState: Equatable {
  case needsNight
  case calibrating(have: Int, need: Int)
  case ready
  case blockedNeedsSupport(reason: String)
  case notStreamed

  var glyph: String {
    switch self {
    case .needsNight: "moon.stars"
    case .calibrating: "chart.line.uptrend.xyaxis"
    case .ready: "checkmark.circle.fill"
    case .blockedNeedsSupport: "exclamationmark.shield"
    case .notStreamed: "antenna.radiowaves.left.and.right.slash"
    }
  }

  var glyphTint: AnyShapeStyle {
    switch self {
    case .ready: AnyShapeStyle(.green)
    case .blockedNeedsSupport: AnyShapeStyle(.orange)
    default: AnyShapeStyle(.secondary)
    }
  }

  var shortLabel: String {
    switch self {
    case .needsNight: "Needs first night"
    case let .calibrating(have, need): "Night \(have) of \(need)"
    case .ready: "Ready"
    case .blockedNeedsSupport: "Needs validation"
    case .notStreamed: "Not streamed yet"
    }
  }

  // Collecting families sort ahead of ready ones so the user sees what is still
  // warming up first.
  var sortRank: Int {
    switch self {
    case .notStreamed: 0
    case .needsNight: 1
    case .calibrating: 2
    case .blockedNeedsSupport: 3
    case .ready: 4
    }
  }
}

// MARK: - MetricJourneyFamily

enum MetricJourneyFamily: String, CaseIterable, Identifiable {
  case sleep
  case recovery
  case hrv
  case cardio

  var id: String { rawValue }

  var title: String {
    switch self {
    case .sleep: "Sleep"
    case .recovery: "Recovery"
    case .hrv: "HRV"
    case .cardio: "Cardio Load"
    }
  }

  var systemImage: String {
    switch self {
    case .sleep: "bed.double"
    case .recovery: "battery.100percent"
    case .hrv: "waveform.path.ecg"
    case .cardio: "heart.circle"
    }
  }

  var tint: Color {
    switch self {
    case .sleep: .indigo
    case .recovery: .green
    case .hrv: .teal
    case .cardio: .pink
    }
  }

  // The REAL maturity windows the journey mirrors. recovery and hrv share the
  // EWMA baseline window from Rust/core/src/baselines.rs
  // (MIN_NIGHTS_SEED = 4, MIN_NIGHTS_READY = 7, MIN_NIGHTS_TRUST = 14). sleep is
  // framed 1 -> 7 nights; cardio fills its 28-day cardio-load window.
  var window: (seed: Int?, ready: Int, trust: Int?) {
    switch self {
    case .sleep: (seed: nil, ready: 7, trust: nil)
    case .recovery: (seed: 4, ready: 7, trust: 14)
    case .hrv: (seed: 4, ready: 7, trust: 14)
    case .cardio: (seed: nil, ready: 28, trust: nil)
    }
  }
}

// MARK: - MetricJourney

struct MetricJourney: Identifiable {
  let family: MetricJourneyFamily
  let state: MetricJourneyState

  var id: String { family.rawValue }
}

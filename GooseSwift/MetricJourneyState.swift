import SwiftUI

// MARK: - MetricJourneyCategory
//
// The single distinction this redesign exists to make clear: can WEARING the
// strap move this metric forward, or are we still BUILDING the decoder so
// wearing it changes nothing yet? dataGathering rows respond to more nights /
// more activity; inDevelopment rows do not and never will until the decode is
// validated. ready and notAvailable are terminal states.

enum MetricJourneyCategory: Equatable {
  case dataGathering
  case inDevelopment
  case ready
  case notAvailable
}

// MARK: - MetricJourneyState
//
// The honest per-family warm-up state machine for the Home "data journey" card.
// dataGathering states are derived from a REAL observed count (nights / days
// captured) — none are fabricated. inDevelopment is a hard product gate (the
// decoder is not validated yet), so wearing the strap cannot advance it. Glyphs
// are STATIC SF Symbols; nothing here implies background compute via a spinner
// or hourglass.

enum MetricJourneyState: Equatable {
  case needsFirstNight
  case calibrating(have: Int, need: Int)
  case collecting(String)
  case ready
  case inDevelopment
  case notAvailable

  var category: MetricJourneyCategory {
    switch self {
    case .needsFirstNight, .calibrating, .collecting: .dataGathering
    case .ready: .ready
    case .inDevelopment: .inDevelopment
    case .notAvailable: .notAvailable
    }
  }

  var glyph: String {
    switch self {
    case .needsFirstNight: "moon.stars"
    case .calibrating: "calendar"
    case .collecting: "clock.arrow.circlepath"
    case .ready: "checkmark.circle.fill"
    case .inDevelopment: "wrench.and.screwdriver"
    case .notAvailable: "antenna.radiowaves.left.and.right.slash"
    }
  }

  var glyphTint: AnyShapeStyle {
    switch self {
    case .ready: AnyShapeStyle(.green)
    case .inDevelopment: AnyShapeStyle(.purple)
    default: AnyShapeStyle(.secondary)
    }
  }

  var shortLabel: String {
    switch self {
    case .needsFirstNight: "Needs your first night"
    case let .calibrating(have, need): "Night \(have) of \(need)"
    case .collecting: "Collecting"
    case .ready: "Ready"
    case .inDevelopment: "In development"
    case .notAvailable: "Not on this strap"
    }
  }

  // One honest sentence explaining what the user should expect. dataGathering
  // copy tells them wearing the strap helps; inDevelopment copy is explicit that
  // it will not, so nobody waits on a metric that cannot arrive from more wear.
  var detailLabel: String {
    switch self {
    case .needsFirstNight: "Wear it to sleep — ready tomorrow morning."
    case .calibrating: "Learning your personal baseline."
    case let .collecting(detail): detail
    case .ready: "Ready"
    case .inDevelopment: "We're still building this — not available yet."
    case .notAvailable: "This sensor isn't streamed by your strap."
    }
  }

  // dataGathering families sort first (the user can act on them by wearing the
  // strap), then in-development, then not-available, then the ready ones.
  var sortRank: Int {
    switch self {
    case .needsFirstNight: 0
    case .calibrating: 1
    case .collecting: 2
    case .inDevelopment: 3
    case .notAvailable: 4
    case .ready: 5
    }
  }
}

// MARK: - MetricJourneyFamily

enum MetricJourneyFamily: String, CaseIterable, Identifiable {
  case sleep
  case recovery
  case hrv
  case cardio
  case respiratory
  case skinTemp
  case spo2

  var id: String { rawValue }

  var title: String {
    switch self {
    case .sleep: "Sleep"
    case .recovery: "Recovery"
    case .hrv: "HRV"
    case .cardio: "Cardio Load"
    case .respiratory: "Respiratory Rate"
    case .skinTemp: "Skin Temperature"
    case .spo2: "Blood Oxygen"
    }
  }

  var systemImage: String {
    switch self {
    case .sleep: "bed.double"
    case .recovery: "battery.100percent"
    case .hrv: "waveform.path.ecg"
    case .cardio: "heart.circle"
    case .respiratory: "lungs"
    case .skinTemp: "thermometer.medium"
    case .spo2: "drop.degreesign"
    }
  }

  var tint: Color {
    switch self {
    case .sleep: .indigo
    case .recovery: .green
    case .hrv: .teal
    case .cardio: .pink
    case .respiratory: .cyan
    case .skinTemp: .orange
    case .spo2: .red
    }
  }

  // The REAL maturity windows the journey mirrors. recovery and hrv share the
  // EWMA baseline window from Rust/core/src/baselines.rs
  // (MIN_NIGHTS_SEED = 4, MIN_NIGHTS_READY = 7, MIN_NIGHTS_TRUST = 14). sleep is
  // framed 1 -> 7 nights; cardio fills its 28-day cardio-load window. The
  // in-development sensors carry no data window — wearing the strap can't
  // advance them, so their window is irrelevant and reported as ready: 0.
  var window: (seed: Int?, ready: Int, trust: Int?) {
    switch self {
    case .sleep: (seed: nil, ready: 7, trust: nil)
    case .recovery: (seed: 4, ready: 7, trust: 14)
    case .hrv: (seed: 4, ready: 7, trust: 14)
    case .cardio: (seed: nil, ready: 28, trust: nil)
    case .respiratory, .skinTemp, .spo2: (seed: nil, ready: 0, trust: nil)
    }
  }
}

// MARK: - MetricJourney

struct MetricJourney: Identifiable {
  let family: MetricJourneyFamily
  let state: MetricJourneyState

  var id: String { family.rawValue }
}

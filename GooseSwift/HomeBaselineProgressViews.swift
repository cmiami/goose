import SwiftUI

// MARK: - HomeBaselineProgressCard
//
// Post-onboarding warm-up: the honest per-metric "data journey". Rows are
// grouped into two clearly-labeled sections so the user can tell apart what
// WEARING the strap advances ("Building from your data") from what we are still
// BUILDING the decoder for ("In development" — wearing won't help). Each row
// shows a STATIC state glyph and verbatim label derived from real captured
// counts (see HealthDataStore+MetricJourney.swift). There is NO spinner and no
// indeterminate ring here — the only animated indicator in the Home stack is the
// real SyncProgressRing on the device card. The card disappears once every
// family is ready.

struct HomeBaselineProgressCard: View {
  let journeys: [MetricJourney]
  let isSyncing: Bool

  private var readyCount: Int {
    journeys.filter { $0.state == .ready }.count
  }

  private var dataGathering: [MetricJourney] {
    journeys.filter { $0.state.category == .dataGathering }
  }

  private var inDevelopment: [MetricJourney] {
    journeys.filter { $0.state.category == .inDevelopment }
  }

  // Ready and not-available families round out the list so nothing silently
  // vanishes; they carry no "keep wearing" or "coming soon" promise.
  private var settled: [MetricJourney] {
    journeys.filter { journey in
      journey.state.category == .ready || journey.state.category == .notAvailable
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
        Image(systemName: "chart.bar.doc.horizontal")
          .font(.title3)
          .foregroundStyle(.blue)
        Text("Your data journey")
          .font(.headline)
        Spacer()
        if !journeys.isEmpty {
          Text("\(readyCount) of \(journeys.count) ready")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }

      if !dataGathering.isEmpty {
        JourneySection(
          title: "Building from your data",
          subtitle: "keep wearing your strap",
          glyph: "figure.walk.motion",
          tint: .blue,
          journeys: dataGathering
        )
      }

      if !inDevelopment.isEmpty {
        JourneySection(
          title: "In development",
          subtitle: "we're still building these — coming soon",
          glyph: "wrench.and.screwdriver",
          tint: .purple,
          journeys: inDevelopment
        )
      }

      if !settled.isEmpty {
        JourneySection(
          title: "Ready",
          subtitle: "scoring from your data now",
          glyph: "checkmark.seal",
          tint: .green,
          journeys: settled
        )
      }

      if isSyncing {
        // Static caption only — points the reader's eye to the device card's
        // real SyncProgressRing; no second animated indicator here.
        Text("Syncing now")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.blue)
      }

      // One-line legend tying the two states to a plain-language promise.
      Text("Data-gathering metrics arrive as you wear your strap. In-development metrics are waiting on us, not on you.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardSurface(tint: .blue)
  }
}

// A labeled group of journey rows sharing one category and one honest promise.
private struct JourneySection: View {
  let title: String
  let subtitle: String
  let glyph: String
  let tint: Color
  let journeys: [MetricJourney]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: glyph)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
        Text(title)
          .font(.caption.weight(.bold))
          .foregroundStyle(.primary)
        Text("· \(subtitle)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }

      VStack(alignment: .leading, spacing: 10) {
        ForEach(journeys) { journey in
          JourneyRow(journey: journey)
        }
      }
    }
  }
}

private struct JourneyRow: View {
  let journey: MetricJourney

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: journey.state.glyph)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(journey.state.glyphTint)
        .frame(width: 20)

      Text(journey.family.title)
        .font(.subheadline)
        .foregroundStyle(.primary)

      if case let .calibrating(have, need) = journey.state {
        CalibrationSegments(filled: have, total: need, tint: journey.family.tint)
      }

      Spacer(minLength: 8)

      Text(journey.state.shortLabel)
        .font(.caption.weight(.semibold))
        .foregroundStyle(journey.state.glyphTint)
        .lineLimit(1)
    }
  }
}

// Static segmented progress — clearly a state glyph, not an animated bar. Shows
// `filled` of `total` real captured nights with no implied background compute.
private struct CalibrationSegments: View {
  let filled: Int
  let total: Int
  let tint: Color

  var body: some View {
    HStack(spacing: 2) {
      ForEach(0..<max(total, 0), id: \.self) { index in
        Capsule()
          .fill(index < filled ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(0.14)))
          .frame(width: 8, height: 4)
      }
    }
  }
}

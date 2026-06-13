import SwiftUI

// MARK: - HomeBaselineProgressCard
//
// Post-onboarding warm-up: the honest per-metric "data journey". Each row shows
// a STATIC state glyph and verbatim label derived from real captured night
// counts (see HealthDataStore+MetricJourney.swift). There is NO spinner and no
// indeterminate ring here — the only animated indicator in the Home stack is
// the real SyncProgressRing on the device card. The card disappears once every
// family is ready.

struct HomeBaselineProgressCard: View {
  let journeys: [MetricJourney]
  let isSyncing: Bool

  private var readyCount: Int {
    journeys.filter { $0.state == .ready }.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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

      VStack(alignment: .leading, spacing: 10) {
        ForEach(journeys) { journey in
          JourneyRow(journey: journey)
        }
      }

      if isSyncing {
        // Static caption only — points the reader's eye to the device card's
        // real SyncProgressRing; no second animated indicator here.
        Text("Syncing now")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.blue)
      }

      Text("Most scores appear after your first night. Recovery and HRV baselines mature over 4–7 nights and stabilise at 14. Cardio Load fills in over 28 days.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardSurface(tint: .blue)
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

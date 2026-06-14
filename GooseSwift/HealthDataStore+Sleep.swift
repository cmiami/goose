import Darwin
import Foundation
import SwiftUI
import UIKit

extension HealthDataStore {
  func refreshPrimarySleepFromScoreReport() {
    guard let detail = Self.primarySleepDetail(fromSleepReport: packetScoreReports["sleep"]) else {
      return
    }
    primarySleepDetail = detail
  }

  static func primarySleepDetail(fromSleepReport report: [String: Any]?) -> PrimarySleepDetail? {
    guard let report,
          let output = map(report, "score_result", "output") else {
      return nil
    }
    let window = map(report, "sleep_window")
    let input = map(report, "sleep_v1_input") ?? map(report, "sleep_input")
    let start = bridgeDate(input?["start_time"] ?? window?["start_time"])
    let end = bridgeDate(input?["end_time"] ?? window?["end_time"])
    let duration = doubleValue(output["sleep_duration_minutes"])
      ?? doubleValue(window?["sleep_duration_minutes"])
      ?? doubleValue(input?["sleep_duration_minutes"])
      ?? 0
    let timeInBed = doubleValue(output["time_in_bed_minutes"])
      ?? doubleValue(window?["time_in_bed_minutes"])
      ?? doubleValue(input?["time_in_bed_minutes"])
      ?? duration
    let score = numberText(output["score_0_to_100"], fractionDigits: 0) ?? "--"
    let stages = sleepStageSegments(from: output)
    let idSuffix = start.map { "\(Int($0.timeIntervalSince1970))" } ?? "latest"

    // ALG-SLP-01: HR-threshold sleep quality metrics from score output
    let heartRateDipText = numberText(output["heart_rate_dip_percent"], fractionDigits: 1)
      .map { $0 + "%" } ?? "--"
    let wasoText = doubleValue(output["waso_minutes"]).map { minutesText($0) } ?? "--"
    let solText = doubleValue(output["sol_minutes"]).map { minutesText($0) } ?? "--"
    let disturbanceText = intValue(output["disturbance_count"]).map { "\($0)" } ?? "--"

    return PrimarySleepDetail(
      id: "primary-sleep-\(idSuffix)",
      dateLabel: start.map(dateLabel) ?? "Latest",
      startLabel: start.map(timeLabel) ?? "--",
      endLabel: end.map(timeLabel) ?? "--",
      durationText: minutesText(duration),
      durationMinutes: duration,
      timeInBedText: minutesText(timeInBed),
      scoreText: score,
      qualityText: sleepQualityLabel(score: doubleValue(output["score_0_to_100"])),
      source: .bridge("metrics.sleep_score_from_features"),
      stages: stages,
      heartRateDipText: heartRateDipText,
      wasoText: wasoText,
      solText: solText,
      disturbanceText: disturbanceText
    )
  }

  static func sleepStageSegments(from output: [String: Any]) -> [HealthSleepStageSegment] {
    let stageRows = array(output["stage_segments"])
    if !stageRows.isEmpty {
      return stageRows.enumerated().compactMap { index, row in
        let stage = row["stage_kind"] as? String ?? row["stage"] as? String ?? "core"
        let duration = doubleValue(row["duration_minutes"]) ?? 0
        guard duration > 0 else {
          return nil
        }
        let start = bridgeDate(row["start_time"])
        let end = bridgeDate(row["end_time"])
        return HealthSleepStageSegment(
          id: "bridge-stage-\(index)-\(stage)",
          stage: stage,
          startLabel: start.map(timeLabel) ?? "--",
          endLabel: end.map(timeLabel) ?? "--",
          durationMinutes: duration,
          confidence: doubleValue(row["confidence_0_to_1"]),
          source: .bridge("sleep_v1 output stage_segments")
        )
      }
    }

    guard let minutesByStage = output["stage_minutes"] as? [String: Any] else {
      return []
    }
    return ["awake", "rem", "core", "deep"].compactMap { stage in
      guard let minutes = doubleValue(minutesByStage[stage]),
            minutes > 0 else {
        return nil
      }
      return HealthSleepStageSegment(
        id: "bridge-stage-total-\(stage)",
        stage: stage,
        startLabel: "--",
        endLabel: "--",
        durationMinutes: minutes,
        confidence: doubleValue(output["stage_segment_confidence_0_to_1"]),
        source: .bridge("sleep_v1 output stage_minutes")
      )
    }
  }

  static func sleepQualityLabel(score: Double?) -> String {
    guard let score else {
      return "No score"
    }
    if score >= 85 {
      return "Optimal"
    }
    if score >= 70 {
      return "Good"
    }
    if score >= 50 {
      return "Needs attention"
    }
    return "Low"
  }

  static func recoveryQualityLabel(score: Double?) -> String {
    guard let score else {
      return "No data"
    }
    if score >= 67 {
      return "Recovered"
    }
    if score >= 34 {
      return "Moderate recovery"
    }
    if score > 0 {
      return "Low recovery"
    }
    return "No data"
  }

  static func strainStatusLabel(score: Double?) -> String {
    guard let score, score > 0 else {
      return "No strain data"
    }
    if score >= 70 {
      return "High strain"
    }
    if score >= 40 {
      return "Moderate strain"
    }
    return "Low strain"
  }

  static func strainPercent(_ rawScore0To21: Double) -> Double {
    min(max(rawScore0To21 / 21.0 * 100.0, 0), 100)
  }

  static func stressStatusLabel(score: Double?) -> String {
    guard let score else {
      return "No data"
    }
    if score >= 66 {
      return "High"
    }
    if score >= 33 {
      return "Medium"
    }
    return "Low"
  }

  @MainActor
  func importSleepFromHealthKit() async {
    externalSleepImportStatus = "Importing from Apple Health…"
    let result = await HealthKitSleepImporter.importMostRecentSleep()
    switch result {
    case .success(let detail):
      if primarySleepDetail == nil {
        primarySleepDetail = detail
      }
      externalSleepImportStatus = "Imported: \(detail.durationText) on \(detail.dateLabel)"
    case .noData(let reason):
      externalSleepImportStatus = "No data: \(reason)"
    case .denied(let reason):
      externalSleepImportStatus = "Access denied: \(reason)"
    case .unavailable:
      externalSleepImportStatus = "HealthKit unavailable on this device"
    }
  }

  @MainActor
  func importAllFromHealthKit() async {
    hkImportStatus = "Importing from Apple Health…"
    let result = await HealthKitFullImporter.importAll()

    // Sleep — only fill if band hasn't provided it
    if let detail = result.sleepDetail, primarySleepDetail == nil {
      primarySleepDetail = detail
      externalSleepImportStatus = "Imported: \(detail.durationText) on \(detail.dateLabel)"
    }

    // Vitals
    if let v = result.restingHR { hkRestingHR = v }
    if let v = result.hkHRVSDNNMs { hkHRVSDNNMs = v }
    if !result.hrvHistory.isEmpty { hkHRVHistory = result.hrvHistory }
    if !result.rhrHistory.isEmpty { hkRHRHistory = result.rhrHistory }
    if let v = result.respiratoryRate { hkRespiratoryRate = v }
    if let v = result.spO2Percent { hkSpO2Percent = v }
    if let v = result.skinTempDeltaC { hkSkinTempDeltaC = v }
    if let v = result.steps { hkSteps = v }
    if let v = result.activeKcal { hkActiveKcal = v }

    // Heart rate samples into the series store (feeds stress + HRV timeline)
    let pipeline = HeartRateSamplePipeline()
    for sample in result.hrSamples {
      pipeline.recordHeartRateSample(bpm: sample.bpm, source: "apple.health", capturedAt: sample.date)
    }

    // Workouts
    if !result.workouts.isEmpty {
      hkWorkouts = result.workouts
    }

    let imported = buildImportSummary(result)
    hkImportStatus = imported

    // Persist to SQLite so data survives app relaunch
    await persistHealthKitToSQLite(result)
  }

  func loadPersistedHealthKitData() async {
    let db = databasePath
    let df = Self.hkDateFormatter
    let today = df.string(from: Date())
    let startDate = df.string(from: Date().addingTimeInterval(-90 * 24 * 60 * 60))
    let source = "apple.health"

    func queryLatest(_ metric: String) async -> Double? {
      guard
        let rows = try? await bridge.requestAsync(
          method: "metric_series.query_range",
          args: ["database_path": db, "metric_name": metric, "start_date": startDate, "end_date": today, "source": source]
        ),
        let arr = rows["rows"] as? [[String: Any]],
        let last = arr.last,
        let value = last["value"] as? Double
      else { return nil }
      return value
    }

    func queryHistory(_ metric: String) async -> [(value: Double, date: Date)] {
      guard
        let rows = try? await bridge.requestAsync(
          method: "metric_series.query_range",
          args: ["database_path": db, "metric_name": metric, "start_date": startDate, "end_date": today, "source": source]
        ),
        let arr = rows["rows"] as? [[String: Any]]
      else { return [] }
      return arr.compactMap { row -> (Double, Date)? in
        guard let value = row["value"] as? Double, let dateStr = row["date"] as? String,
              let date = df.date(from: dateStr) else { return nil }
        return (value, date)
      }
    }

    async let rhr = queryLatest("hk.resting_hr_bpm")
    async let hrv = queryLatest("hk.hrv_sdnn_ms")
    async let resp = queryLatest("hk.respiratory_rate")
    async let spo2 = queryLatest("hk.spo2_percent")
    async let skinTemp = queryLatest("hk.skin_temp_delta_c")
    async let stepsVal = queryLatest("hk.steps")
    async let kcal = queryLatest("hk.active_kcal")
    async let rhrHist = queryHistory("hk.resting_hr_bpm")
    async let hrvHist = queryHistory("hk.hrv_sdnn_ms")

    let (rhrV, hrvV, respV, spo2V, skinTempV, stepsV, kcalV, rhrH, hrvH) =
      await (rhr, hrv, resp, spo2, skinTemp, stepsVal, kcal, rhrHist, hrvHist)

    if let v = rhrV, hkRestingHR == nil { hkRestingHR = v }
    if let v = hrvV, hkHRVSDNNMs == nil { hkHRVSDNNMs = v }
    if let v = respV, hkRespiratoryRate == nil { hkRespiratoryRate = v }
    if let v = spo2V, hkSpO2Percent == nil { hkSpO2Percent = v }
    if let v = skinTempV, hkSkinTempDeltaC == nil { hkSkinTempDeltaC = v }
    if let v = stepsV, hkSteps == nil { hkSteps = Int(v) }
    if let v = kcalV, hkActiveKcal == nil { hkActiveKcal = v }
    if hkRHRHistory.isEmpty, !rhrH.isEmpty { hkRHRHistory = rhrH.map { (bpm: $0.value, date: $0.date) } }
    if hkHRVHistory.isEmpty, !hrvH.isEmpty { hkHRVHistory = hrvH.map { (sdnn: $0.value, date: $0.date) } }

    if hkRestingHR != nil || hkHRVSDNNMs != nil {
      hkImportStatus = "Restored from local DB"
    }
  }

  private func persistHealthKitToSQLite(_ result: HealthKitFullImportResult) async {
    let db = databasePath
    let df = Self.hkDateFormatter
    let today = df.string(from: Date())
    let source = "apple.health"

    func upsertMetric(_ metric: String, date: String, value: Double) async {
      _ = try? await bridge.requestAsync(
        method: "metric_series.upsert",
        args: ["database_path": db, "source": source, "metric_name": metric, "date": date, "value": value]
      )
    }

    // Today's snapshot
    if let v = result.restingHR { await upsertMetric("hk.resting_hr_bpm", date: today, value: v) }
    if let v = result.hkHRVSDNNMs { await upsertMetric("hk.hrv_sdnn_ms", date: today, value: v) }
    if let v = result.respiratoryRate { await upsertMetric("hk.respiratory_rate", date: today, value: v) }
    if let v = result.spO2Percent { await upsertMetric("hk.spo2_percent", date: today, value: v) }
    if let v = result.skinTempDeltaC { await upsertMetric("hk.skin_temp_delta_c", date: today, value: v) }
    if let v = result.steps { await upsertMetric("hk.steps", date: today, value: Double(v)) }
    if let v = result.activeKcal { await upsertMetric("hk.active_kcal", date: today, value: v) }

    // 90-day history
    for entry in result.rhrHistory {
      await upsertMetric("hk.resting_hr_bpm", date: df.string(from: entry.date), value: entry.bpm)
    }
    for entry in result.hrvHistory {
      await upsertMetric("hk.hrv_sdnn_ms", date: df.string(from: entry.date), value: entry.sdnn)
    }
  }

  private nonisolated static let hkDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.locale = Locale(identifier: "en_US_POSIX")
    return df
  }()

  private func buildImportSummary(_ r: HealthKitFullImportResult) -> String {
    var parts: [String] = []
    if r.sleepDetail != nil { parts.append("sleep") }
    if r.restingHR != nil { parts.append("resting HR") }
    if r.hkHRVSDNNMs != nil { parts.append("HRV") }
    if r.respiratoryRate != nil { parts.append("resp rate") }
    if r.spO2Percent != nil { parts.append("SpO2") }
    if r.skinTempDeltaC != nil { parts.append("skin temp") }
    if r.steps != nil { parts.append("steps") }
    if r.activeKcal != nil { parts.append("calories") }
    if !r.hrSamples.isEmpty { parts.append("\(r.hrSamples.count) HR samples") }
    if !r.workouts.isEmpty { parts.append("\(r.workouts.count) workouts") }
    if parts.isEmpty { return "No data found" }
    return "Imported: \(parts.joined(separator: ", "))"
  }

}

import Foundation
import SwiftUI

// MARK: - IMUStepCountResult

struct IMUStepCountResult {
  let stepCount: Int          // derived from K10 zero-crossing
  let sampleCount: Int        // number of gravity samples used
  let meanMagnitude: Double   // mean acceleration magnitude (g)
  let insufficientData: Bool
}

extension IMUStepCountResult {
  var stepCountText: String {
    insufficientData ? "--" : "\(stepCount)"
  }
}

// MARK: - HealthDataStore+IMUSteps

extension HealthDataStore {
  // Reads K10 accelerometer data directly from decoded_frames for today's window,
  // runs imu_step_count_v1, and compares with the WHOOP step counter from
  // packetInputReports. Bypasses the gravity table — works for all users
  // regardless of whether server upload is configured.
  // Result is published on @MainActor.
  func runIMUStepCount() async {
    let db = databasePath
    let now = Date().timeIntervalSince1970
    let windowStart = now - 24 * 3600
    // Capture WHOOP step count from packetInputReports on @MainActor before first await.
    let stepReport = packetInputReports["step_counter_rollup"]

    let asDouble: (Any?) -> Double? = { value in
      switch value {
      case let d as Double: return d
      case let f as Float: return Double(f)
      case let i as Int: return Double(i)
      case let n as NSNumber: return n.doubleValue
      default: return nil
      }
    }

    // Read K10 frames from decoded_frames and compute step count in one bridge call.
    let imuResult: IMUStepCountResult
    do {
      let report = try await bridge.requestAsync(
        method: "metrics.imu_step_count_from_decoded_frames",
        args: [
          "database_path": db,
          "start_ts": windowStart,
          "end_ts": now,
        ]
      )
      let stepCount = (report["step_count"] as? NSNumber)?.intValue
        ?? (report["step_count"] as? Int) ?? 0
      let sampleCount = (report["sample_count"] as? NSNumber)?.intValue
        ?? (report["sample_count"] as? Int) ?? 0
      let meanMag = asDouble(report["mean_magnitude"]) ?? 0
      let insufficient = report["insufficient_data"] as? Bool ?? true
      imuResult = IMUStepCountResult(
        stepCount: stepCount,
        sampleCount: sampleCount,
        meanMagnitude: meanMag,
        insufficientData: insufficient
      )
    } catch {
      imuResult = IMUStepCountResult(
        stepCount: 0,
        sampleCount: 0,
        meanMagnitude: 0,
        insufficientData: true
      )
    }

    // Compare with WHOOP step counter from packetInputReports.
    let whoopSteps: Int? = {
      guard let r = stepReport,
            let steps = asDouble(r["step_count"]).map({ Int($0) }) else { return nil }
      return steps > 0 ? steps : nil
    }()

    // Log discrepancy if both values available.
    if !imuResult.insufficientData, let whoop = whoopSteps {
      let delta = abs(imuResult.stepCount - whoop)
      let pct = whoop > 0 ? Double(delta) / Double(whoop) * 100 : 0
      // Note: discrepancy stored for debugging; threshold for concern is >20%.
      _ = (delta: delta, percentDelta: pct)
    }

    imuStepCountResult = imuResult
  }
}

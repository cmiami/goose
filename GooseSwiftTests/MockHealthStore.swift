import Foundation
@testable import GooseSwift

/// Minimal test double for HealthDataStoring.
/// Delegates to MockRustBridge so tests can assert the correct bridge method string is used.
final class MockHealthStore: HealthDataStoring {
  let bridge: MockRustBridge
  var databasePath: String = "/tmp/mock.sqlite"

  init(bridge: MockRustBridge = MockRustBridge()) {
    self.bridge = bridge
    bridge.stubbedResult = ["rows": [[String: Any]]()]
  }

  func fetchTrendsSeries(metricName: String, days: Int) async throws -> [(date: String, value: Double)] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let endDate = formatter.string(from: Date())
    let startDate = formatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date())
    _ = try await bridge.requestAsync(
      method: "metric_series.query_range",
      args: ["database_path": databasePath, "metric_name": metricName, "start_date": startDate, "end_date": endDate]
    )
    return []
  }
}

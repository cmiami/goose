import Foundation

/// Protocol abstracting HealthDataStore for dependency injection in tests.
/// Minimal surface for Phase 72 tests. Extend as needed.
protocol HealthDataStoring: AnyObject {
  var databasePath: String { get }
  func fetchTrendsSeries(metricName: String, days: Int) async throws -> [(date: String, value: Double)]
}

extension HealthDataStoring {
  /// Convenience overload matching the concrete store's default of 7 days.
  func fetchTrendsSeries(metricName: String) async throws -> [(date: String, value: Double)] {
    try await fetchTrendsSeries(metricName: metricName, days: 7)
  }
}


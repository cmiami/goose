import XCTest
@testable import GooseSwift

final class TrendsFetchTests: XCTestCase {

  func test_fetchTrendsSeries_calls_metric_series_query_range() async throws {
    // MockHealthStore delegates to bridge — asserts the correct method string is used.
    let bridge = MockRustBridge()
    bridge.stubbedResult = ["rows": [[String: Any]]()]
    let store = MockHealthStore(bridge: bridge)
    _ = try await store.fetchTrendsSeries(metricName: "recovery", days: 7)
    XCTAssertEqual(bridge.lastMethod, "metric_series.query_range",
      "fetchTrendsSeries must call bridge with method 'metric_series.query_range'")
  }

}

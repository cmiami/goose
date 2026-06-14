import Foundation
import OSLog

private let logger = Logger(subsystem: "com.goose.swift", category: "upload")

struct GooseUploadStatus {
  let lastUploadTimestamp: Date?
  let pendingBatchCount: Int
  let lastSyncedCount: Int?
  // Total rows with synced=0 across primary hr_samples stream.
  var pendingRowCount: Int = 0
  // Non-nil when the last upload attempt failed (5xx exhausted); nil on success.
  var uploadErrorState: String? = nil
}

// Result of a single HTTP upload attempt, used to drive the exponential backoff retry loop.
private enum UploadAttemptResult {
  case success(Int)       // 2xx — count of upserted rows
  case serverError(Int)   // 500-599 — server-side failure, retry with backoff
  case clientError(Int)   // 400-499 — non-retryable; abort immediately
  case transientError     // network/transport error (nil response), also retried
}

final class GooseUploadService: @unchecked Sendable {
  private let rust = GooseRustBridge()
  private let databasePath: String
  private let session: URLSession

  // Guards the four counter/timestamp properties below.
  // Mutated from both @MainActor (upload()) and detached tasks (performUpload,
  // triggerBackfill), so an NSLock is required — Swift's cooperative thread pool
  // does not guarantee serial execution across multiple detached tasks on multi-core.
  private let stateLock = NSLock()
  private var _lastUploadTimestamp: Date?
  private var _pendingBatchCount: Int = 0
  private var _lastSyncedCount: Int?
  private var _pendingRowCount: Int = 0
  private var _uploadErrorState: String? = nil

  private var lastUploadTimestamp: Date? {
    get { stateLock.withLock { _lastUploadTimestamp } }
    set { stateLock.withLock { _lastUploadTimestamp = newValue } }
  }
  private var pendingBatchCount: Int {
    get { stateLock.withLock { _pendingBatchCount } }
    set { stateLock.withLock { _pendingBatchCount = newValue } }
  }
  private var lastSyncedCount: Int? {
    get { stateLock.withLock { _lastSyncedCount } }
    set { stateLock.withLock { _lastSyncedCount = newValue } }
  }
  private var pendingRowCount: Int {
    get { stateLock.withLock { _pendingRowCount } }
    set { stateLock.withLock { _pendingRowCount = newValue } }
  }
  private var uploadErrorState: String? {
    get { stateLock.withLock { _uploadErrorState } }
    set { stateLock.withLock { _uploadErrorState = newValue } }
  }

  var onStatusUpdate: (@MainActor (GooseUploadStatus) -> Void)?

  init(databasePath: String) {
    self.databasePath = databasePath
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 15
    self.session = URLSession(configuration: config)
  }

  init(databasePath: String, session: URLSession) {
    self.databasePath = databasePath
    self.session = session
  }

  func upload(deviceID: UUID, deviceType: String, sinceTimestamp: Date) {
    stateLock.withLock { _pendingBatchCount += 1 }
    Task.detached(priority: .utility) { [weak self] in
      guard let self else {
        return
      }
      await self.performUpload(deviceID: deviceID, deviceType: deviceType, sinceTimestamp: sinceTimestamp)
    }
  }

  private func performUpload(deviceID: UUID, deviceType: String, sinceTimestamp: Date) async {
    guard UserDefaults.standard.bool(forKey: RemoteServerStorage.uploadEnabled) else {
      stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
      return
    }
    let rawURL = UserDefaults.standard.string(forKey: RemoteServerStorage.serverURL) ?? ""
    guard !rawURL.isEmpty, let baseURL = URL(string: rawURL) else {
      stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
      return
    }
    guard let token = (try? RemoteServerKeychain.loadToken()) ?? nil, !token.isEmpty else {
      stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
      return
    }

    // Resolve effective lower bound: persisted decodedStreams watermark takes precedence over
    // caller hint. Caller value is only the fallback when no watermark exists yet (first launch).
    let effectiveSince = GooseUploadWatermark.watermark(for: .decodedStreams) ?? sinceTimestamp

    // Pre-capture pending rowIDs for all 8 upload streams BEFORE constructing the payload.
    // Rows arriving after this point will not be marked synced — eliminating the race window.
    let pendingRowIDs = captureAllPendingRowIDs(deviceID: deviceID, sinceTimestamp: effectiveSince)

    // Fetch recent decoded streams from Rust bridge (synchronous — runs on detached task thread)
    let streamsResult: [String: Any]
    do {
      streamsResult = try rust.request(
        method: "upload.get_recent_decoded_streams",
        args: [
          "database_path": databasePath,
          "device_id": deviceID.uuidString,
          "since_ts": effectiveSince.timeIntervalSince1970,
        ]
      )
    } catch {
      logger.debug("upload.get_recent_decoded_streams failed: \(error)")
      stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
      return
    }

    let hr = streamsResult["hr"] as? [Any] ?? []
    let rr = streamsResult["rr"] as? [Any] ?? []
    let events = streamsResult["events"] as? [Any] ?? []
    let battery = streamsResult["battery"] as? [Any] ?? []
    let spo2 = streamsResult["spo2"] as? [Any] ?? []
    let skinTemp = streamsResult["skin_temp"] as? [Any] ?? []
    let resp = streamsResult["resp"] as? [Any] ?? []
    let gravity = streamsResult["gravity"] as? [Any] ?? []

    let hasData = !hr.isEmpty || !rr.isEmpty || !events.isEmpty || !battery.isEmpty
      || !spo2.isEmpty || !skinTemp.isEmpty || !resp.isEmpty || !gravity.isEmpty
    guard hasData else {
      stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
      return
    }

    let streams: [String: Any] = [
      "hr": hr, "rr": rr, "events": events, "battery": battery,
      "spo2": spo2, "skin_temp": skinTemp, "resp": resp, "gravity": gravity,
    ]

    // Compute the maximum data timestamp across all streams to use as the watermark.
    // Using Date() (upload time) instead of max(data.ts) causes a silent gap: when
    // triggerBackfill inserts historical rows and calls performUpload, the watermark
    // would jump to now — permanently excluding those historical rows from future cycles.
    // Using max(data.ts) ensures the watermark represents the latest data that reached
    // the server, not the wall-clock time of the upload call.
    var maxDataTs: Double = 0
    let allStreamArrays: [[Any]] = [hr, rr, events, battery, spo2, skinTemp, resp, gravity]
    for streamArray in allStreamArrays {
      for item in streamArray {
        if let row = item as? [String: Any],
           let ts = (row["ts"] as? NSNumber)?.doubleValue ?? (row["ts"] as? Double) {
          maxDataTs = max(maxDataTs, ts)
        }
      }
    }
    // Guard against clock skew: cap at current time and fall back to effectiveSince
    // if no valid ts was found in any stream (should not happen given hasData check above).
    let uploadedUntil = maxDataTs > 0
      ? min(Date(timeIntervalSince1970: maxDataTs), Date())
      : effectiveSince

    let payload = buildUploadPayload(deviceID: deviceID, deviceType: deviceType, streams: streams)

    guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
      stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
      return
    }

    var request = URLRequest(url: baseURL.appendingPathComponent("v1/ingest-decoded"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    // Exponential backoff retry for 5xx and transient errors.
    // Delays: 1s, 2s, 4s, 8s, 16s, 32s, 60s (capped), 60s … — matching ReconnectBackoff semantics.
    // Attempt 0 fires immediately (no pre-sleep). Max 6 retry attempts (7 total including attempt 0).
    let maxAttempts = 7
    var uploadSucceeded = false
    var syncedCount: Int?
    var lastServerErrorStatus: Int? = nil
    var clientErrorStatus: Int? = nil
    for attempt in 0..<maxAttempts {
      if attempt > 0 {
        let delaySeconds = min(1.0 * pow(2.0, Double(attempt - 1)), 60.0)
        let delayNanos = UInt64(delaySeconds * 1_000_000_000)
        do {
          try await Task.sleep(nanoseconds: delayNanos)
        } catch {
          // CancellationError: task was cancelled during backoff sleep.
          // Stop retrying immediately rather than continuing after the sleep.
          logger.debug("upload backoff cancelled — aborting retry loop")
          stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
          return
        }
      }
      let result = await performRequest(request)
      switch result {
      case .success(let count):
        uploadSucceeded = true
        syncedCount = count
        uploadErrorState = nil
      case .serverError(let status):
        lastServerErrorStatus = status
        logger.debug("upload 5xx (attempt \(attempt)): \(status)")
      case .clientError(let status):
        // 4xx responses are never recoverable by retry — abort immediately.
        clientErrorStatus = status
        logger.warning("upload 4xx (attempt \(attempt)): \(status) — aborting retries")
      case .transientError:
        logger.debug("upload transient error (attempt \(attempt))")
      }
      if uploadSucceeded || clientErrorStatus != nil { break }
    }

    if !uploadSucceeded {
      if let status = clientErrorStatus {
        uploadErrorState = "Upload failed — client error (\(status))"
      } else if let status = lastServerErrorStatus {
        uploadErrorState = "Upload failed — server error (\(status))"
      } else {
        uploadErrorState = "Upload failed — server unavailable"
      }
    }

    if uploadSucceeded {
      // Mark pre-captured rowIDs as synced — only called on 2xx; rows stay synced=0 on failure.
      markStreamsSynced(rowIDsByStream: pendingRowIDs)
      // Commit decodedStreams watermark AFTER marking rows synced — never written before confirmed
      // success (RESEARCH Pitfall 1). UserDefaults writes are individually atomic; no lock needed.
      // Write uploadedUntil (max data ts, capped at now) rather than Date() so that backfill
      // uploads of historical rows don't silently advance the watermark past those rows.
      //
      // CR-02: watermark is WHOOP-only. HR monitor uploads share the same decodedStreams key
      // but must NOT advance it — a successful HR monitor upload at T_HR would cause the next
      // WHOOP cycle to start from T_HR, silently skipping WHOOP data in [T_WHOOP, T_HR].
      // HR monitor (default deviceType) always uploads from sinceTimestamp without watermark
      // advancement. Only WHOOP device types ("GEN4", "GOOSE") own this watermark.
      let isWhoopDevice = deviceType == "GEN4" || deviceType == "GOOSE"
      if isWhoopDevice {
        GooseUploadWatermark.update(.decodedStreams, to: uploadedUntil)
      }
      // Upload raw BLE frames alongside decoded streams. This enables a fresh iOS
      // install to reconstruct the trust chain via capture.import_frame_batch.
      await uploadRawFrames(deviceID: deviceID, sinceTimestamp: effectiveSince)
      // Advance the checkpoint only after both decoded and raw uploads have been attempted.
      stateLock.withLock {
        _lastUploadTimestamp = Date()
        _lastSyncedCount = syncedCount
      }
    } else {
      logger.warning("upload failed — rows not marked synced, will retry")
    }
    stateLock.withLock { _pendingBatchCount = max(0, _pendingBatchCount - 1) }
    refreshPendingRowCount()
    publishStatus()
  }

  // Upload raw BLE frames to the server's /v1/ingest-frames endpoint.
  // Raw frames allow a fresh iOS install to rebuild the trust chain via
  // capture.import_frame_batch without requiring a BLE reconnection.
  private func uploadRawFrames(deviceID: UUID, sinceTimestamp: Date) async {
    guard UserDefaults.standard.bool(forKey: RemoteServerStorage.uploadEnabled) else { return }
    let rawURL = UserDefaults.standard.string(forKey: RemoteServerStorage.serverURL) ?? ""
    guard !rawURL.isEmpty, let baseURL = URL(string: rawURL) else { return }
    guard let token = (try? RemoteServerKeychain.loadToken()) ?? nil, !token.isEmpty else { return }

    // rawFrames watermark is independent — raw and decoded uploads can fail independently
    // (RESEARCH Pitfall 3). Caller sinceTimestamp is the fallback for first launch only.
    let effectiveSince = GooseUploadWatermark.watermark(for: .rawFrames) ?? sinceTimestamp

    let framesResult: [String: Any]
    do {
      framesResult = try rust.request(
        method: "upload.get_raw_frames_for_upload",
        args: [
          "database_path": databasePath,
          "since_ts": effectiveSince.timeIntervalSince1970,
          "limit": 2000,
        ]
      )
    } catch {
      logger.debug("upload.get_raw_frames_for_upload failed: \(error)")
      return
    }

    let frames = framesResult["frames"] as? [Any] ?? []
    guard !frames.isEmpty else { return }

    let deviceDict: [String: Any] = ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()]
    let payload: [String: Any] = ["device": deviceDict, "frames": frames]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

    var request = URLRequest(url: baseURL.appendingPathComponent("v1/ingest-frames"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    guard let (data, response) = try? await session.data(for: request),
          let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      logger.debug("uploadRawFrames: server error")
      return
    }
    // Advance rawFrames watermark only on confirmed 2xx — never on failure or timeout.
    GooseUploadWatermark.update(.rawFrames, to: Date())
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let inserted = json["inserted"] as? Int {
      logger.debug("uploadRawFrames: inserted=\(inserted) frames since=\(effectiveSince)")
    }
  }

  private func performRequest(_ request: URLRequest) async -> UploadAttemptResult {
    guard let (data, response) = try? await session.data(for: request) else {
      logger.debug("upload request error")
      return .transientError
    }
    guard let http = response as? HTTPURLResponse else {
      return .transientError
    }
    if (500..<600).contains(http.statusCode) {
      logger.debug("upload server error: \(http.statusCode)")
      return .serverError(http.statusCode)
    }
    if (400..<500).contains(http.statusCode) {
      logger.warning("upload client error \(http.statusCode) — not retrying")
      return .clientError(http.statusCode)
    }
    guard (200..<300).contains(http.statusCode) else {
      logger.debug("upload non-2xx non-5xx: \(http.statusCode)")
      return .transientError
    }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let upserted = json["upserted"] as? [String: Int] {
      return .success(upserted.values.reduce(0, +))
    }
    return .success(0)
  }

  // Pure payload builder — no async, no URLSession, no Rust bridge access.
  // Internal so GooseSwiftTests (@testable import GooseSwift) can call it directly.
  // WHOOP Gen4/Gen5 use device_generation with no device_class key.
  // HR monitors (default case) use device_type (sanitized BLE name) + device_class: "HR_MONITOR"
  // so the server can distinguish wearable class from model name (review HIGH-1, HIGH-3).
  func buildUploadPayload(
    deviceID: UUID,
    deviceType: String,
    streams: [String: Any]
  ) -> [String: Any] {
    let device: [String: Any] = ["id": deviceID.uuidString, "mac": NSNull(), "name": NSNull()]
    switch deviceType {
    case "GEN4":
      return [
        "device": device,
        "streams": streams,
        "device_generation": "4.0",
      ]
    case "GOOSE":
      return [
        "device": device,
        "streams": streams,
        "device_generation": "5.0",
      ]
    default:
      // device_type carries the model/name (pre-sanitized BLE advertised name),
      // device_class carries the wearable class so the server can distinguish class from model.
      return [
        "device": device,
        "streams": streams,
        "device_type": deviceType,
        "device_class": "HR_MONITOR",
      ]
    }
  }

  // Pre-capture rowIDs for all 8 upload streams BEFORE the HTTP request is sent.
  // Called once per upload cycle; the returned dictionary is passed to markStreamsSynced
  // only after the server confirms 2xx — eliminating the blind-marking race window.
  private func captureAllPendingRowIDs(deviceID: UUID, sinceTimestamp: Date) -> [String: [Int]] {
    // Tables included in the upload payload and their device_id column presence.
    // Streams without device_id apply only the ts filter (no cross-device risk for gravity/spo2/etc.
    // because those rows are written by the same device session).
    let streams: [(table: String, hasDeviceID: Bool)] = [
      ("hr_samples", true),
      ("rr_intervals", true),
      ("events", true),
      ("battery", true),
      ("spo2_samples", false),
      ("skin_temp_samples", false),
      ("resp_samples", false),
      ("gravity", false),
    ]
    var result: [String: [Int]] = [:]
    let sinceTs = sinceTimestamp.timeIntervalSince1970
    for entry in streams {
      // CR-03: pass since_ts so the Rust query applies the timestamp filter before
      // the limit. Without it, Rust returns the 500 oldest rows (all with synced=0,
      // ordered by ts ASC) and the Swift-side ts filter below discards them all if
      // they are below effectiveSince — leaving newer rows (indices 501+) uncaptured.
      guard let pendingReport = try? rust.request(
        method: "sync.rows_pending_upload",
        args: [
          "database_path": databasePath,
          "stream": entry.table,
          "since_ts": sinceTs,
          "limit": 500, // limit=500 matches upload batch cap — intentional
        ]
      ) else {
        result[entry.table] = []
        continue
      }
      let rows = pendingReport["rows"] as? [[String: Any]] ?? []
      result[entry.table] = rows.compactMap { row in
        guard let rowid = (row["rowid"] as? NSNumber)?.intValue ?? (row["rowid"] as? Int),
              let ts = (row["ts"] as? NSNumber)?.doubleValue ?? (row["ts"] as? Double),
              ts >= sinceTs else { return nil }
        // Apply device_id filter for tables that carry a device_id column.
        if entry.hasDeviceID {
          guard let deviceIdStr = row["device_id"] as? String,
                deviceIdStr == deviceID.uuidString else { return nil }
        }
        return rowid
      }
    }
    return result
  }

  // Mark pre-captured rowIDs as synced=1 using sync.mark_synced.
  // Only called inside the uploadSucceeded=true branch — never on failure.
  private func markStreamsSynced(rowIDsByStream: [String: [Int]]) {
    for (stream, rowIDs) in rowIDsByStream {
      guard !rowIDs.isEmpty else { continue }
      do {
        _ = try rust.request(
          method: "sync.mark_synced",
          args: [
            "database_path": databasePath,
            "stream": stream,
            "row_ids": rowIDs,
          ]
        )
        logger.debug("sync.mark_synced: marked \(rowIDs.count) \(stream) rows")
      } catch {
        // Use .warning (not .debug) so mark failures are visible in production logs.
        // A failed mark leaves rows with synced=0 — they may be silently orphaned if
        // the watermark advances past their timestamp before the next retry.
        logger.warning("sync.mark_synced \(stream) failed: \(error)")
      }
    }
  }

  // Query the total pending row count (hr_samples only) for the badge.
  // Must be called off the main thread — makes a synchronous FFI call.
  func refreshPendingRowCount() {
    assert(!Thread.isMainThread, "refreshPendingRowCount makes a synchronous FFI call — dispatch to background first")
    do {
      let report = try rust.request(
        method: "sync.rows_pending_upload",
        args: [
          "database_path": databasePath,
          "stream": "hr_samples",
          "limit": 10_000,
        ]
      )
      let rows = report["rows"] as? [[String: Any]] ?? []
      stateLock.withLock { _pendingRowCount = rows.count }
    } catch {
      stateLock.withLock { _pendingRowCount = 0 }
    }
  }

  // Trigger manual backfill + upload of all pending streams.
  // Called from the More tab "Sync pendente" button.
  func triggerBackfill(deviceID: UUID, deviceType: String, sinceTimestamp: Date) {
    Task.detached(priority: .utility) { [weak self] in
      guard let self else { return }
      // Call sync.backfill_streams to populate hr_samples/rr_intervals from decoded_frames.
      let end = Date().timeIntervalSince1970
      let start = sinceTimestamp.timeIntervalSince1970
      do {
        let report = try rust.request(
          method: "sync.backfill_streams",
          args: [
            "database_path": databasePath,
            "device_id": deviceID.uuidString,
            "start_ts": start,
            "end_ts": end,
          ]
        )
        let hrInserted = (report["hr_inserted"] as? Int) ?? 0
        logger.debug("sync.backfill_streams: hr_inserted=\(hrInserted)")
      } catch {
        logger.debug("sync.backfill_streams failed: \(error)")
      }
      await performUpload(deviceID: deviceID, deviceType: deviceType, sinceTimestamp: sinceTimestamp)

      // Sync-driven compaction (after upload so synced rows are eligible to prune):
      // roll each high-rate stream's completed days into stream_daily_rollup, then
      // prune raw past the replay window. require_synced is true only when a server
      // is configured — a local-only user still prunes its rolled-up raw, while a
      // server user keeps rows the server has not yet acknowledged.
      let serverConfigured = !(UserDefaults.standard.string(forKey: RemoteServerStorage.serverURL) ?? "").isEmpty
      do {
        let report = try rust.request(
          method: "sync.compact_streams",
          args: [
            "database_path": databasePath,
            "device_id": deviceID.uuidString,
            "now_ts": Date().timeIntervalSince1970,
            "retention_days": 14,
            "require_synced": serverConfigured,
          ]
        )
        let pruned = (report["pruned_rows"] as? Int) ?? 0
        let rolled = (report["rolled_up_days"] as? Int) ?? 0
        logger.debug("sync.compact_streams: rolled_up_days=\(rolled) pruned_rows=\(pruned)")
      } catch {
        logger.debug("sync.compact_streams failed: \(error)")
      }
    }
  }

  private func publishStatus() {
    let status = stateLock.withLock {
      GooseUploadStatus(
        lastUploadTimestamp: _lastUploadTimestamp,
        pendingBatchCount: _pendingBatchCount,
        lastSyncedCount: _lastSyncedCount,
        pendingRowCount: _pendingRowCount,
        uploadErrorState: _uploadErrorState
      )
    }
    Task { @MainActor [weak self] in
      self?.onStatusUpdate?(status)
    }
  }
}

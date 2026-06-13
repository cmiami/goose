import Foundation
import BackgroundTasks


extension GooseAppModel {
  // UserDefaults key for the last successful historical BLE sync timestamp.
  // Written BEFORE the BLE call to prevent retry loops on drop+reconnect.
  static let lastHistorySyncAtKey = "goose.swift.lastHistorySyncAt"

  // Cooldown between foreground historical syncs: 30 minutes.
  // A kill+restart within this window does not trigger a redundant sync.
  static let bandFirstSyncCooldown: TimeInterval = 30 * 60

  // Called from handleAppLifecycleChange when phase == "active".
  // Fires only if already connected (D-07: no reconnect attempt from this path).
  // Skips if a sync completed within the last 30 minutes (D-09/D-10).
  func triggerForegroundBLESync() {
    guard ble.connectionState == "ready" else { return }
    if let lastSync = UserDefaults.standard.object(forKey: Self.lastHistorySyncAtKey) as? Date,
       Date().timeIntervalSince(lastSync) < Self.bandFirstSyncCooldown {
      ble.record(
        source: "band_first_sync",
        title: "foreground_sync.skipped",
        body: "foreground sync skipped — last sync within 30 min"
      )
      return
    }
    // Write BEFORE the BLE call to prevent retry loops on drop+reconnect (per SleepSync pattern).
    UserDefaults.standard.set(Date(), forKey: Self.lastHistorySyncAtKey)
    ble.record(source: "band_first_sync", title: "foreground_sync.start")
    ble.syncHistoricalPackets(rangeFirst: true)
  }

  // BGAppRefreshTask handler. Registered in GooseSwiftApp.init() for identifier
  // "com.goose.swift.bg-sync". The handler receives the task on an arbitrary thread;
  // GooseSwiftApp dispatches it to @MainActor before calling this method.
  func handleBGAppRefresh(task: BGAppRefreshTask) {
    // Reschedule next wakeup immediately — iOS requires this before setTaskCompleted (D-12).
    scheduleNextBGAppRefresh()

    // Set expiration handler before starting any work (D-14: graceful OS revocation).
    task.expirationHandler = { [weak self] in
      self?.ble.stopScan()
      task.setTaskCompleted(success: false)
    }

    // If already connected, sync data immediately with a 20-second completion window.
    if ble.connectionState == "ready" {
      ble.syncHistoricalPackets(rangeFirst: true)
      DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
        task.setTaskCompleted(success: true)
      }
      return
    }

    // Otherwise attempt a scan+connect with a 20-second timeout (D-12/D-13).
    ble.startScan()
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
      self?.ble.stopScan()
      task.setTaskCompleted(success: false)
    }
  }

  // Submits the next BGAppRefreshTask request. Called both from the handler (mandatory)
  // and from .onAppear in GooseSwiftApp (first scheduling at app launch).
  func scheduleNextBGAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.goose.swift.bg-sync")
    // iOS enforces a minimum of ~15 minutes; practical value ~30 min (Claude's discretion per CONTEXT.md).
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  // Day-spread device step-counter polling (B5). Guarantees >=2 step-counter
  // captures across the active day so the step_counter rollup can compute a
  // monotonic-counter delta. Uses ONLY the trusted decoded_frames + step_discovery
  // path — no protocol/byte-layout change. If no packet arrives, the rollup stays
  // at insufficient_step_counter_samples (honest empty, never a fabricated sample).
  static let deviceStepCounterPollInterval: TimeInterval = 3 * 60 * 60

  // UserDefaults key for the last step-counter capture timestamp. Written BEFORE
  // the BLE call to prevent retry loops on drop+reconnect (same pattern as
  // lastHistorySyncAtKey above).
  static let lastStepCounterCaptureAtKey = "goose.swift.lastStepCounterCaptureAt"

  func scheduleDeviceStepCounterPolling(reason: String) {
    guard ble.connectionState == "ready" else {
      return
    }
    // Catch up immediately if the last capture is older than one interval (or has
    // never run), so the day window starts collecting samples right away.
    let lastCapture = UserDefaults.standard.object(forKey: Self.lastStepCounterCaptureAtKey) as? Date
    if lastCapture == nil
      || Date().timeIntervalSince(lastCapture ?? .distantPast) >= Self.deviceStepCounterPollInterval {
      captureDeviceStepCounterSample(reason: reason)
    }
    stepCounterPollTimer?.cancel()
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(
      deadline: .now() + Self.deviceStepCounterPollInterval,
      repeating: Self.deviceStepCounterPollInterval,
      leeway: .seconds(60)
    )
    timer.setEventHandler { [weak self] in
      Task { @MainActor in
        guard let self else {
          return
        }
        guard self.ble.connectionState == "ready",
              self.activeHealthPacketCapture == nil else {
          return
        }
        self.captureDeviceStepCounterSample(reason: "periodic")
      }
    }
    stepCounterPollTimer = timer
    timer.resume()
    ble.record(
      source: "step_counter.poll",
      title: "schedule.armed",
      body: "reason=\(reason) interval=\(Int(Self.deviceStepCounterPollInterval.rounded()))s"
    )
  }

  func captureDeviceStepCounterSample(reason: String) {
    guard ble.connectionState == "ready" else {
      return
    }
    // Write the watermark BEFORE the call so a drop+reconnect during capture does
    // not spin into a retry loop (same ordering rule as triggerForegroundBLESync).
    UserDefaults.standard.set(Date(), forKey: Self.lastStepCounterCaptureAtKey)
    // Take a FRESH LIVE read: a brief live capture persists current-time decoded
    // frames carrying the monotonic step counter, producing a NEW time-spread
    // sample each poll. Historical sync re-pulls the SAME frames → the same
    // counter value, which never reaches the rollup's >=2-sample minimum.
    ble.record(source: "step_counter.poll", title: "capture.health_packet", body: "reason=\(reason)")
    startHealthPacketCapture(duration: 60, source: "auto.step_counter_poll")
  }

  func cancelDeviceStepCounterPolling() {
    guard stepCounterPollTimer != nil else {
      return
    }
    stepCounterPollTimer?.cancel()
    stepCounterPollTimer = nil
    ble.record(source: "step_counter.poll", title: "schedule.cancelled")
  }
}

import AVFoundation
import Flutter
import UIKit

/// Pulls the immutable Dart-rendered PCM from an AVAudioEngine render callback.
/// Scheduling is shared with the executable pure Swift tests; AVFoundation graph,
/// hardware latency and actual notification delivery still require Mac/device QA.
final class DrawMusicAudio {
  private struct Loop: AudioLoopSnapshot {
    let pcm: [Float]
    let revision: Int64
    let tempo: Int
    var frameCount: Int { pcm.count }
    init(_ arguments: [String: Any]) throws {
      guard let bytes = arguments["pcm"] as? FlutterStandardTypedData,
            bytes.data.count > 0, bytes.data.count <= 2_000_000,
            bytes.data.count % 2 == 0,
            let revision = arguments["revision"] as? NSNumber,
            let tempo = arguments["tempo"] as? Int, (60...200).contains(tempo)
      else { throw NativePortError.invalid("Invalid audio snapshot") }
      let values = Array(bytes.data)
      pcm = stride(from: 0, to: values.count, by: 2).map {
        Float(Int16(bitPattern: UInt16(values[$0]) | UInt16(values[$0 + 1]) << 8)) / 32768
      }
      guard abs(Double(pcm.count) / 44_100 - 480 / Double(tempo)) < 0.001
      else { throw NativePortError.invalid("Invalid audio duration") }
      self.revision = revision.int64Value
      self.tempo = tempo
    }
  }
  private let channel: FlutterMethodChannel
  private var engine = AVAudioEngine()
  private var source: AVAudioSourceNode?
  private let lock = NSLock()
  private var schedule = AudioSchedule<Loop>()
  private var gain: Float = 1
  private var ramp: Float = 0
  private var fadeFrom: AudioSchedule<Loop>.Position?
  private var fadeFrames = 0
  private var pauseTail: (position: AudioSchedule<Loop>.Position, remaining: Int)?
  private var outputLatency = 0.0
  private var ioBufferDuration = 0.0
  private var observers: [NSObjectProtocol] = []
  private var mediaServicesAvailable = true // Main-thread lifecycle ownership.
  private let rate = 44_100.0

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "scribblesong/audio", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    registerObservers() // Reset rebuilds graphs, never notification registrations.
  }
  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) }; engine.stop() }

  private func registerObservers() {
    let center = NotificationCenter.default
    let session = AVAudioSession.sharedInstance()
    observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] event in
      let raw = (event.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
      // Interruption end is informational; it never restarts or pauses a newer
      // explicit Play. Unknown/begin events conservatively pause immediately.
      let phase: AudioInterruptionPhase = raw == AVAudioSession.InterruptionType.ended.rawValue ? .ended :
        (raw == AVAudioSession.InterruptionType.began.rawValue ? .began : .unknown)
      if AudioInterruptionPolicy.shouldPause(phase: phase) { self?.pause() }
    })
    observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] event in
      self?.routeChanged(event)
    })
    observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.pause() })
    observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereLostNotification, object: session, queue: .main) { [weak self] _ in
      self?.mediaServicesAvailable = false
      self?.pause()
    })
    observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
      self?.recoverMediaServicesReset()
    })
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "prepare":
        guard mediaServicesAvailable, let arguments = call.arguments as? [String: Any] else { throw NativePortError.invalid("Audio services or snapshot unavailable") }
        let next = try Loop(arguments)
        lock.lock(); schedule.prepare(next); clearRenderTransitions(); lock.unlock()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try rebuildGraph()
        result(nil)
      case "queue":
        guard let arguments = call.arguments as? [String: Any] else { throw NativePortError.invalid("Missing audio snapshot") }
        let next = try Loop(arguments)
        lock.lock()
        guard schedule.hasSnapshot else { lock.unlock(); throw NativePortError.invalid("Prepare audio first") }
        schedule.queue(next, boundary: arguments["boundary"] as? String == "beat" ? .beat : .loop)
        lock.unlock(); result(nil)
      case "play": try play(); result(nil)
      case "pause": pause(smooth: true); result(nil)
      case "stop": stop(); result(nil)
      case "volume":
        guard let value = call.arguments as? NSNumber, value.doubleValue.isFinite else { throw NativePortError.invalid("Invalid preview volume") }
        lock.lock(); gain = max(0, min(1, value.floatValue)); lock.unlock(); result(nil)
      case "status": result(status())
      case "position": let value = status(); result((value["fraction"] as! Double) * 480 / Double(value["tempo"] as! Int))
      case "playing": result(status()["playing"])
      default: result(FlutterMethodNotImplemented)
      }
    } catch { result(FlutterError(code: "audio_unavailable", message: error.localizedDescription, details: nil)) }
  }

  private func sessionMatchesPolicy(_ session: AVAudioSession) -> Bool {
    session.category == .playback && session.mode == .default && session.categoryOptions.isEmpty
  }
  private func restoreSessionConfiguration() throws {
    let session = AVAudioSession.sharedInstance()
    // Idempotence avoids unnecessary category notifications on repeated Play.
    // A delayed category event is also checked against this current policy.
    if !sessionMatchesPolicy(session) { try session.setCategory(.playback, mode: .default, options: []) }
  }
  private func play() throws {
    guard mediaServicesAvailable else { throw NativePortError.invalid("Audio services are recovering; try Play again") }
    lock.lock(); let prepared = schedule.hasSnapshot; let rebuild = schedule.needsGraphRebuild; lock.unlock()
    guard prepared else { throw NativePortError.invalid("Prepare audio first") }
    do {
      if rebuild { try rebuildGraph() }
      try restoreSessionConfiguration()
      try AVAudioSession.sharedInstance().setActive(true)
      if !engine.isRunning { try engine.start() }
      let latency = engine.outputNode.presentationLatency
      let buffer = AVAudioSession.sharedInstance().ioBufferDuration
      lock.lock()
      outputLatency = latency; ioBufferDuration = buffer
      pauseTail = nil; ramp = 0
      let resumed = schedule.resume()
      lock.unlock()
      guard resumed else { throw NativePortError.invalid("Audio graph requires recovery") }
    } catch {
      lock.lock(); schedule.mediaServicesReset(latencyFrames: latencyFrames); clearRenderTransitions(); lock.unlock()
      engine.stop()
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      throw error
    }
  }

  /// Main-thread graph replacement. Invalidate state before calling engine APIs,
  /// and never hold the render lock while stopping an engine waiting for a pull.
  private func rebuildGraph() throws {
    lock.lock(); let generation = schedule.graphGeneration; lock.unlock()
    let orphaned = engine
    source = nil
    orphaned.stop()
    let replacement = AVAudioEngine()
    engine = replacement
    try restoreSessionConfiguration()
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw NativePortError.invalid("Audio format unavailable") }
    let node = AVAudioSourceNode(format: format) { [weak self] silence, _, count, buffers -> OSStatus in
      guard let self = self else { silence.pointee = true; return noErr }
      self.render(Int(count), buffers, generation: generation)
      return noErr
    }
    source = node
    replacement.attach(node)
    replacement.connect(node, to: replacement.mainMixerNode, format: format)
    replacement.prepare()
    lock.lock(); let accepted = schedule.graphWasRebuilt(generation: generation); lock.unlock()
    guard accepted else { replacement.stop(); throw NativePortError.invalid("Audio graph superseded") }
  }

  private var latencyFrames: Int64 { Int64((outputLatency * rate).rounded()) }
  private func clearRenderTransitions() {
    // Caller holds lock; every control invalidation is represented in schedule.
    fadeFrom = nil; fadeFrames = 0; pauseTail = nil; ramp = 0
  }
  private func render(_ count: Int, _ buffers: UnsafeMutablePointer<AudioBufferList>, generation: Int) {
    let output = UnsafeMutableAudioBufferListPointer(buffers)
    lock.lock(); defer { lock.unlock() }
    for offset in 0..<count {
      var value: Float = 0
      // Late pulls from an orphaned engine cannot advance the replacement state.
      if schedule.acceptsGraph(generation: generation) {
        if let next = schedule.renderFrame(generation: generation) {
          if let previous = next.previous { fadeFrom = previous; fadeFrames = 128 }
          value = next.position.snapshot.pcm[next.position.frame]
          if let previous = fadeFrom, fadeFrames > 0 {
            let t = Float(128 - fadeFrames) / 128
            value = previous.snapshot.pcm[previous.frame] * (1 - t) + value * t
            fadeFrames -= 1
            fadeFrom = fadeFrames == 0 ? nil : AudioSchedule<Loop>.Position(snapshot: previous.snapshot,
              frame: (previous.frame + 1) % previous.snapshot.frameCount)
          }
          ramp = min(1, ramp + 1 / Float(rate * 0.016))
          value *= gain * ramp
        } else if let tail = pauseTail {
          let total = max(1, Int(rate * 0.016))
          value = tail.position.snapshot.pcm[tail.position.frame] * gain * Float(tail.remaining) / Float(total)
          let remaining = tail.remaining - 1
          pauseTail = remaining > 0 ? (AudioSchedule<Loop>.Position(snapshot: tail.position.snapshot,
            frame: (tail.position.frame + 1) % tail.position.snapshot.frameCount), remaining) : nil
          if remaining == 0 {
            let token = schedule.controlGeneration
            let delay = outputLatency + ioBufferDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
              guard let self = self else { return }
              self.lock.lock()
              let shouldPause = self.schedule.mayCompletePause(generation: token) && self.pauseTail == nil
              self.lock.unlock()
              if shouldPause { self.engine.pause(); try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
            }
          }
        }
      }
      for buffer in output {
        if let pointer = buffer.mData?.assumingMemoryBound(to: Float.self) { pointer[offset] = value }
      }
    }
  }

  private func status() -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    let value = schedule.status(latencyFrames: latencyFrames)
    return ["playing": value.playing, "revision": value.revision, "targetRevision": value.targetRevision,
      "fraction": value.fraction, "tempo": value.tempo]
  }
  func pause(smooth: Bool = false) {
    lock.lock()
    let wasPlaying = schedule.playing
    let position = schedule.pause(latencyFrames: latencyFrames)
    clearRenderTransitions()
    if smooth && wasPlaying, let position = position {
      pauseTail = (position, max(1, Int(rate * 0.016)))
    }
    let immediate = pauseTail == nil
    lock.unlock()
    if immediate {
      engine.pause()
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }
  private func stop() {
    lock.lock(); schedule.stop(); clearRenderTransitions(); lock.unlock()
    engine.stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  private func recoverMediaServicesReset() {
    mediaServicesAvailable = true
    lock.lock()
    schedule.mediaServicesReset(latencyFrames: latencyFrames)
    clearRenderTransitions(); outputLatency = 0; ioBufferDuration = 0
    lock.unlock()
    // Apple QA1749: reconstruct orphaned audio objects and restore session
    // properties; keep the session inactive until explicit user Play.
    do { try rebuildGraph() }
    catch { engine.stop() } // needsGraphRebuild remains true; explicit Play retries.
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  private func routeChanged(_ event: Notification) {
    let session = AVAudioSession.sharedInstance()
    let raw = (event.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue ?? 0
    let nativeReason = AVAudioSession.RouteChangeReason(rawValue: raw) ?? .unknown
    let reason: AudioRouteReason
    switch nativeReason {
    case .newDeviceAvailable: reason = .newDevice
    case .oldDeviceUnavailable: reason = .oldDeviceRemoved
    case .categoryChange: reason = .categoryChanged
    case .override: reason = .override
    case .wakeFromSleep: reason = .wakeFromSleep
    case .noSuitableRouteForCategory: reason = .noSuitableRoute
    case .routeConfigurationChange: reason = .configurationChanged
    case .unknown: reason = .unknown
    @unknown default: reason = .unknown
    }
    func outputs(_ route: AVAudioSessionRouteDescription) -> [String] {
      route.outputs.map { "\($0.portType.rawValue):\($0.uid)" }
    }
    let previous = (event.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription).map(outputs)
    if AudioRoutePolicy.shouldPause(reason: reason, sessionMatchesPolicy: sessionMatchesPolicy(session),
      previousOutputs: previous, currentOutputs: outputs(session.currentRoute)) { pause() }
    else {
      let running = engine.isRunning
      lock.lock()
      let halted = !running && (schedule.playing || pauseTail != nil)
      if halted {
        // A logically harmless route event can still coincide with the hardware
        // graph stopping. Do not report a playing session with a frozen clock.
        schedule.graphHalted(latencyFrames: latencyFrames)
        clearRenderTransitions(); outputLatency = 0; ioBufferDuration = 0
      }
      lock.unlock()
      if halted {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        return // Explicit Play rebuilds; this event never restarts audio.
      }
      // Hardware latency/buffer duration may change even when playback continues.
      let latency = running ? engine.outputNode.presentationLatency : 0
      let buffer = session.ioBufferDuration
      lock.lock(); outputLatency = latency; ioBufferDuration = buffer; lock.unlock()
    }
  }
}

enum NativePortError: LocalizedError {
  case invalid(String)
  var errorDescription: String? { switch self { case let .invalid(message): return message } }
}

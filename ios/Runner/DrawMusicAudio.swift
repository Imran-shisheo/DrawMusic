import AVFoundation
import Flutter
import UIKit

/// Pulls the same immutable mono PCM used by Android/export from the audio render
/// callback. Dart timers never schedule musical notes. Source implementation;
/// audibility, route latency and interruption semantics require Mac/device QA.
final class DrawMusicAudio {
  private struct Loop {
    let pcm: [Float]
    let revision: Int64
    let tempo: Int
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
  private struct Segment {
    let absoluteFrame: Int64
    let phase: Int
    let loop: Loop
  }
  private let channel: FlutterMethodChannel
  private let engine = AVAudioEngine()
  private let lock = NSLock()
  private var source: AVAudioSourceNode?
  private var loop: Loop?
  private var pending: (loop: Loop, beat: Bool)?
  private var frame = 0
  private var absoluteFrame: Int64 = 0
  private var segments: [Segment] = []
  private var playing = false
  private var gain: Float = 1
  private var ramp: Float = 0
  private var fadeFrom: (loop: Loop, frame: Int)?
  private var fadeFrames = 0
  private var pauseTail: (loop: Loop, frame: Int, remaining: Int)?
  private var pauseGeneration = 0
  private var outputLatency = 0.0
  private var ioBufferDuration = 0.0
  private var observers: [NSObjectProtocol] = []
  private let rate = 44_100.0

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "scribblesong/audio", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    let center = NotificationCenter.default
    for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                 UIApplication.didEnterBackgroundNotification, AVAudioSession.mediaServicesWereResetNotification] {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        // No automatic restart on a route, interruption end or foreground event.
        self?.pause()
      })
    }
  }
  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) }; engine.stop() }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "prepare":
        guard let arguments = call.arguments as? [String: Any] else { throw NativePortError.invalid("Missing audio snapshot") }
        let next = try Loop(arguments)
        stop()
        lock.lock(); loop = next; frame = 0; segments = [Segment(absoluteFrame: 0, phase: 0, loop: next)]; segments.reserveCapacity(9); lock.unlock()
        try configureEngine()
        result(nil)
      case "queue":
        guard let arguments = call.arguments as? [String: Any] else { throw NativePortError.invalid("Missing audio snapshot") }
        let next = try Loop(arguments)
        lock.lock()
        guard loop != nil else { lock.unlock(); throw NativePortError.invalid("Prepare audio first") }
        if playing { pending = (next, arguments["boundary"] as? String == "beat") }
        else { let fraction = Double(frame) / Double(loop!.pcm.count); loop = next; frame = Int(fraction * Double(next.pcm.count)) % next.pcm.count; pending = nil; segments = [Segment(absoluteFrame: absoluteFrame, phase: frame, loop: next)] }
        lock.unlock(); result(nil)
      case "play":
        guard loop != nil else { throw NativePortError.invalid("Prepare audio first") }
        // Playback deliberately ignores the silent switch. This is documented in
        // IOS-IMPLEMENTATION.md; no microphone or background-audio entitlement.
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning { try engine.start() }
        let latency = engine.outputNode.presentationLatency
        let bufferDuration = AVAudioSession.sharedInstance().ioBufferDuration
        lock.lock(); outputLatency = latency; ioBufferDuration = bufferDuration
        pauseGeneration += 1; pauseTail = nil; playing = true; ramp = 0; lock.unlock(); result(nil)
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

  private func configureEngine() throws {
    if let old = source { engine.detach(old) }
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw NativePortError.invalid("Audio format unavailable") }
    let node = AVAudioSourceNode(format: format) { [weak self] silence, _, count, buffers -> OSStatus in
      guard let self = self else { silence.pointee = true; return noErr }
      self.render(Int(count), buffers)
      return noErr
    }
    source = node
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    engine.prepare()
  }

  private func render(_ count: Int, _ buffers: UnsafeMutablePointer<AudioBufferList>) {
    let output = UnsafeMutableAudioBufferListPointer(buffers)
    lock.lock(); defer { lock.unlock() }
    for offset in 0..<count {
      var value: Float = 0
      if playing, let current = loop {
        if let target = pending {
          let boundary = target.beat ? max(1, current.pcm.count / 8) : current.pcm.count
          if frame % boundary == 0 {
            let fraction = Double(frame) / Double(current.pcm.count)
            let nextFrame = Int((fraction * Double(target.loop.pcm.count)).rounded()) % target.loop.pcm.count
            fadeFrom = (current, frame); fadeFrames = 128
            loop = target.loop; frame = nextFrame; pending = nil
            segments.append(Segment(absoluteFrame: absoluteFrame, phase: frame, loop: target.loop))
            // Keep only enough bounded timeline to cover output latency. This is
            // eight revision boundaries, not unbounded retained PCM snapshots.
            if segments.count > 8 { segments.removeFirst(segments.count - 8) }
          }
        }
        if let active = loop {
          value = active.pcm[frame]
          if let previous = fadeFrom, fadeFrames > 0 {
            let t = Float(128 - fadeFrames) / 128
            value = previous.loop.pcm[previous.frame] * (1 - t) + value * t
            fadeFrames -= 1
            fadeFrom = fadeFrames == 0 ? nil : (previous.loop, (previous.frame + 1) % previous.loop.pcm.count)
          }
          ramp = min(1, ramp + 1 / Float(rate * 0.016))
          value *= gain * ramp
          frame = (frame + 1) % active.pcm.count
          absoluteFrame += 1
        }
      } else if let tail = pauseTail {
        let total = max(1, Int(rate * 0.016))
        value = tail.loop.pcm[tail.frame] * gain * Float(tail.remaining) / Float(total)
        let remaining = tail.remaining - 1
        pauseTail = remaining > 0 ? (tail.loop, (tail.frame + 1) % tail.loop.pcm.count, remaining) : nil
        if remaining == 0 {
          let generation = pauseGeneration
          // The render thread owns the ramp. This delayed control action only
          // releases the engine/session once the queued tail can become audible.
          let delay = outputLatency + ioBufferDuration
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let shouldPause = self.pauseGeneration == generation && !self.playing && self.pauseTail == nil
            self.lock.unlock()
            if shouldPause { self.engine.pause(); try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
          }
        }
      }
      for buffer in output {
        if let pointer = buffer.mData?.assumingMemoryBound(to: Float.self) { pointer[offset] = value }
      }
    }
  }

  private func audiblePosition() -> (loop: Loop, phase: Int)? {
    guard let active = loop else { return nil }
    let latency = playing ? Int64((outputLatency * rate).rounded()) : 0
    let audible = max(segments.first?.absoluteFrame ?? 0, absoluteFrame - latency)
    guard let segment = segments.last(where: { $0.absoluteFrame <= audible }) else { return (active, frame) }
    return (segment.loop, (segment.phase + Int(audible - segment.absoluteFrame)) % segment.loop.pcm.count)
  }
  private func status() -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    guard let value = audiblePosition() else { return ["playing": false, "revision": Int64(-1), "targetRevision": Int64(-1), "fraction": 0.0, "tempo": 120] }
    return ["playing": playing, "revision": value.loop.revision, "targetRevision": pending?.loop.revision ?? loop!.revision,
            "fraction": Double(value.phase) / Double(value.loop.pcm.count), "tempo": value.loop.tempo]
  }
  func pause(smooth: Bool = false) {
    lock.lock()
    let wasPlaying = playing
    if let value = audiblePosition() {
      loop = value.loop; frame = value.phase
      segments = [Segment(absoluteFrame: absoluteFrame, phase: frame, loop: value.loop)]
      pauseTail = smooth && wasPlaying ? (value.loop, value.phase, max(1, Int(rate * 0.016))) : nil
    }
    playing = false; fadeFrom = nil; ramp = 0; pauseGeneration += 1
    let immediate = pauseTail == nil
    lock.unlock()
    if immediate {
      engine.pause()
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }
  private func stop() {
    engine.stop()
    lock.lock(); loop = nil; pending = nil; frame = 0; absoluteFrame = 0; segments.removeAll(); fadeFrom = nil; pauseTail = nil; pauseGeneration += 1; playing = false; ramp = 0; lock.unlock()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}

enum NativePortError: LocalizedError {
  case invalid(String)
  var errorDescription: String? { switch self { case let .invalid(message): return message } }
}

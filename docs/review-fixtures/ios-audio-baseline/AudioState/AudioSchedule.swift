/// Intentionally failing extracted legacy semantics for manual review only.
/// This fixture is not imported by the app and does not execute AVFoundation.
protocol AudioLoopSnapshot {
  var frameCount: Int { get }
  var revision: Int64 { get }
  var tempo: Int { get }
}

enum AudioRevisionBoundary { case beat, loop }

struct AudioSchedule<Snapshot: AudioLoopSnapshot> {
  struct Position {
    let snapshot: Snapshot
    let frame: Int
    var fraction: Double { Double(frame) / Double(snapshot.frameCount) }
  }
  struct RenderFrame {
    let position: Position
    let previous: Position?
  }
  struct Status {
    let playing: Bool
    let revision: Int64
    let targetRevision: Int64
    let fraction: Double
    let tempo: Int
  }
  private struct Request {
    let snapshot: Snapshot
    let boundary: AudioRevisionBoundary
  }
  private struct Segment {
    let absoluteFrame: Int64
    let position: Position
  }

  private var current: Snapshot?
  private var desired: Request?
  private var pending: Request?
  private var frame = 0
  private var absoluteFrame: Int64 = 0
  private var segments: [Segment] = []
  private(set) var playing = false
  private(set) var graphGeneration = 0
  private(set) var controlGeneration = 0
  private(set) var needsGraphRebuild = true
  var hasSnapshot: Bool { current != nil }

  mutating func prepare(_ snapshot: Snapshot) {
    precondition(snapshot.frameCount > 0)
    graphGeneration += 1; controlGeneration += 1
    current = snapshot; desired = Request(snapshot: snapshot, boundary: .loop)
    pending = nil; frame = 0; absoluteFrame = 0; playing = false
    needsGraphRebuild = true
    resetSegments(snapshot, frame: 0)
  }

  @discardableResult mutating func graphWasRebuilt(generation: Int) -> Bool {
    guard generation == graphGeneration else { return false }
    needsGraphRebuild = false
    return true
  }

  mutating func queue(_ snapshot: Snapshot, boundary: AudioRevisionBoundary) {
    precondition(snapshot.frameCount > 0 && current != nil)
    let request = Request(snapshot: snapshot, boundary: boundary)
    desired = request
    if playing { pending = request }
    else {
      let mapped = mappedFrame(frame, from: current!, to: snapshot)
      current = snapshot; frame = mapped; pending = nil
      resetSegments(snapshot, frame: mapped)
    }
  }

  @discardableResult mutating func resume() -> Bool {
    guard let current = current, !needsGraphRebuild else { return false }
    if let desired = desired, !sameVersion(current, desired.snapshot) { pending = desired }
    playing = true; controlGeneration += 1
    return true
  }

  mutating func renderFrame() -> RenderFrame? {
    guard playing, !needsGraphRebuild, let active = current else { return nil }
    var previous: Position?
    if let target = pending, isBoundary(frame, in: active, policy: target.boundary) {
      previous = Position(snapshot: active, frame: frame)
      frame = mappedFrame(frame, from: active, to: target.snapshot)
      current = target.snapshot; pending = nil
      segments.append(Segment(absoluteFrame: absoluteFrame, position: Position(snapshot: target.snapshot, frame: frame)))
      if segments.count > 8 { segments.removeFirst(segments.count - 8) }
    }
    let position = Position(snapshot: current!, frame: frame)
    frame = (frame + 1) % position.snapshot.frameCount
    absoluteFrame += 1
    return RenderFrame(position: position, previous: previous)
  }

  func audiblePosition(latencyFrames: Int64) -> Position? {
    guard let active = current else { return nil }
    let latency = playing ? max(0, latencyFrames) : 0
    let audible = max(segments.first?.absoluteFrame ?? 0, absoluteFrame - latency)
    guard let segment = segments.last(where: { $0.absoluteFrame <= audible }) else {
      return Position(snapshot: active, frame: frame)
    }
    return Position(snapshot: segment.position.snapshot,
      frame: (segment.position.frame + Int(audible - segment.absoluteFrame)) % segment.position.snapshot.frameCount)
  }

  @discardableResult mutating func pause(latencyFrames: Int64) -> Position? {
    let position = audiblePosition(latencyFrames: latencyFrames)
    if let position = position {
      current = position.snapshot; frame = position.frame
      resetSegments(position.snapshot, frame: position.frame)
      // Baseline extraction: the old adapter derived its only target from the
      // render/pending state, then overwrote it with the audible loop on pause.
      if pending == nil { desired = Request(snapshot: position.snapshot, boundary: .loop) }
    }
    playing = false; controlGeneration += 1
    return position
  }

  mutating func mediaServicesReset(latencyFrames: Int64) {
    _ = pause(latencyFrames: latencyFrames)
    // Baseline reset only paused; it did not invalidate/recreate the graph.
  }

  mutating func stop() {
    current = nil; desired = nil; pending = nil; frame = 0; absoluteFrame = 0
    segments.removeAll(keepingCapacity: true); playing = false
    graphGeneration += 1; controlGeneration += 1; needsGraphRebuild = true
  }

  func status(latencyFrames: Int64) -> Status {
    guard let position = audiblePosition(latencyFrames: latencyFrames) else {
      return Status(playing: false, revision: -1, targetRevision: -1, fraction: 0, tempo: 120)
    }
    return Status(playing: playing, revision: position.snapshot.revision,
      targetRevision: desired?.snapshot.revision ?? position.snapshot.revision,
      fraction: position.fraction, tempo: position.snapshot.tempo)
  }

  func mayCompletePause(generation: Int) -> Bool { generation == controlGeneration && !playing }

  private mutating func resetSegments(_ snapshot: Snapshot, frame: Int) {
    segments.removeAll(keepingCapacity: true)
    segments.reserveCapacity(9)
    segments.append(Segment(absoluteFrame: absoluteFrame, position: Position(snapshot: snapshot, frame: frame)))
  }
  private func sameVersion(_ a: Snapshot, _ b: Snapshot) -> Bool {
    a.revision == b.revision && a.tempo == b.tempo && a.frameCount == b.frameCount
  }
  private func mappedFrame(_ frame: Int, from: Snapshot, to: Snapshot) -> Int {
    Int((Double(frame) / Double(from.frameCount) * Double(to.frameCount)).rounded()) % to.frameCount
  }
  private func isBoundary(_ frame: Int, in snapshot: Snapshot, policy: AudioRevisionBoundary) -> Bool {
    if frame == 0 { return true }
    if policy == .loop { return false }
    // Rational eighth-loop boundaries avoid truncating every beat independently.
    return frame * 8 / snapshot.frameCount != (frame - 1) * 8 / snapshot.frameCount
  }
}

/// Reasons are mapped explicitly from AVAudioSession, not duplicated raw values.
enum AudioRouteReason {
  case unknown, newDevice, oldDeviceRemoved, categoryChanged, override
  case wakeFromSleep, noSuitableRoute, configurationChanged
}
struct AudioRoutePolicy {
  static func shouldPause(reason: AudioRouteReason, sessionMatchesPolicy: Bool,
                          previousOutputs: [String]?, currentOutputs: [String]) -> Bool {
    // Baseline observer paused unconditionally for all route notifications.
    true
  }
}

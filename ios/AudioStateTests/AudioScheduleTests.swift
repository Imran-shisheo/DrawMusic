import XCTest
#if canImport(DrawMusicAudioState)
@testable import DrawMusicAudioState
#else
@testable import Runner
#endif

final class AudioScheduleTests: XCTestCase {
  private struct Loop: AudioLoopSnapshot {
    let revision: Int64
    let tempo: Int
    let frameCount: Int
    init(_ revision: Int64, tempo: Int = 120, frames: Int = 800) {
      self.revision = revision; self.tempo = tempo; frameCount = frames
    }
  }
  private func ready() -> AudioSchedule<Loop> {
    var state = AudioSchedule<Loop>()
    state.prepare(Loop(1)); XCTAssertTrue(state.graphWasRebuilt(generation: state.graphGeneration))
    XCTAssertTrue(state.resume()); return state
  }
  private func render(_ count: Int, _ state: inout AudioSchedule<Loop>) {
    for _ in 0..<count { XCTAssertNotNil(state.renderFrame()) }
  }
  func testPauseAfterRenderAdoptionKeepsTargetUntilItActuallyBecomesAudible() {
    var state = ready(); render(790, &state)
    state.queue(Loop(2), boundary: .loop); render(30, &state)
    let before = state.status(latencyFrames: 60)
    XCTAssertEqual(before.revision, 1); XCTAssertEqual(before.targetRevision, 2)
    XCTAssertEqual(before.fraction, 0.95, accuracy: 0.00001)
    state.pause(latencyFrames: 60)
    let paused = state.status(latencyFrames: 60)
    XCTAssertFalse(paused.playing); XCTAssertEqual(paused.revision, 1)
    XCTAssertEqual(paused.targetRevision, 2); XCTAssertEqual(paused.fraction, before.fraction)
    XCTAssertTrue(state.resume()) // No Dart requeue or unrelated edit.
    render(100, &state)
    let resumed = state.status(latencyFrames: 60)
    XCTAssertEqual(resumed.revision, 2); XCTAssertEqual(resumed.targetRevision, 2)
  }
  func testPauseBeforeBoundaryRetainsQueuedTargetAndLoopPolicy() {
    var state = ready(); render(790, &state)
    state.queue(Loop(2), boundary: .loop)
    state.pause(latencyFrames: 60)
    XCTAssertEqual(state.status(latencyFrames: 0).targetRevision, 2)
    XCTAssertTrue(state.resume()); render(60, &state)
    XCTAssertEqual(state.status(latencyFrames: 0).revision, 1)
    render(71, &state)
    XCTAssertEqual(state.status(latencyFrames: 0).revision, 2)
  }
  func testTempoTargetAheadOfAudiblePauseRestagesAtBeatWithPhasePreserved() {
    var state = ready(); render(190, &state)
    state.queue(Loop(2, tempo: 200, frames: 480), boundary: .beat)
    render(30, &state) // render adopted at frame200, audible is still frame160.
    state.pause(latencyFrames: 60)
    XCTAssertEqual(state.status(latencyFrames: 0).fraction, 0.2, accuracy: 0.00001)
    XCTAssertEqual(state.status(latencyFrames: 0).tempo, 120)
    XCTAssertEqual(state.status(latencyFrames: 0).targetRevision, 2)
    XCTAssertTrue(state.resume()); render(100, &state)
    let status = state.status(latencyFrames: 10)
    XCTAssertEqual(status.revision, 2); XCTAssertEqual(status.tempo, 200)
    XCTAssertEqual(status.fraction, 170.0 / 480, accuracy: 0.00001)
  }
  func testNewestRequestWinsWhenAnotherRevisionAlreadyRenderedButNotHeard() {
    var state = ready(); render(790, &state)
    state.queue(Loop(2), boundary: .loop); render(30, &state)
    state.queue(Loop(3, tempo: 160, frames: 600), boundary: .beat)
    state.pause(latencyFrames: 60)
    XCTAssertEqual(state.status(latencyFrames: 0).targetRevision, 3)
    XCTAssertTrue(state.resume()); render(150, &state)
    XCTAssertEqual(state.status(latencyFrames: 0).revision, 3)
    XCTAssertEqual(state.status(latencyFrames: 0).targetRevision, 3)
  }
  func testRapidPauseResumeAndDelayedFadeCannotLoseNewTargetOrPauseNewPlay() {
    var state = ready(); render(790, &state)
    state.queue(Loop(2), boundary: .loop); render(30, &state)
    for _ in 0..<8 {
      state.pause(latencyFrames: 60)
      let oldPause = state.controlGeneration
      XCTAssertTrue(state.mayCompletePause(generation: oldPause))
      XCTAssertTrue(state.resume())
      XCTAssertFalse(state.mayCompletePause(generation: oldPause))
      render(5, &state)
      XCTAssertEqual(state.status(latencyFrames: 60).targetRevision, 2)
    }
    render(900, &state)
    XCTAssertEqual(state.status(latencyFrames: 60).revision, 2)
  }
  func testQueueWhilePausedPreservesPhaseAndUsesLatestSnapshot() {
    var state = ready(); render(200, &state); state.pause(latencyFrames: 40)
    state.queue(Loop(7, tempo: 200, frames: 480), boundary: .loop)
    let paused = state.status(latencyFrames: 60)
    XCTAssertFalse(paused.playing); XCTAssertEqual(paused.revision, 7)
    XCTAssertEqual(paused.targetRevision, 7); XCTAssertEqual(paused.fraction, 0.2, accuracy: 0.00001)
    XCTAssertNil(state.renderFrame()); XCTAssertTrue(state.resume())
    render(1, &state); XCTAssertEqual(state.status(latencyFrames: 0).revision, 7)
  }
  func testResetInvalidatesGraphAndOldFadeButRetainsLatestDesiredSnapshot() {
    var state = ready(); render(790, &state)
    state.queue(Loop(2), boundary: .loop); render(30, &state)
    let oldGraph = state.graphGeneration
    state.pause(latencyFrames: 60); let oldPause = state.controlGeneration
    state.mediaServicesReset(latencyFrames: 60)
    XCTAssertGreaterThan(state.graphGeneration, oldGraph)
    XCTAssertTrue(state.needsGraphRebuild); XCTAssertFalse(state.playing)
    XCTAssertEqual(state.status(latencyFrames: 0).targetRevision, 2)
    XCTAssertFalse(state.mayCompletePause(generation: oldPause))
    XCTAssertFalse(state.graphWasRebuilt(generation: oldGraph))
    XCTAssertFalse(state.resume()); XCTAssertNil(state.renderFrame())
    XCTAssertTrue(state.graphWasRebuilt(generation: state.graphGeneration))
    XCTAssertFalse(state.playing) // Rebuilding itself never starts playback.
    XCTAssertTrue(state.resume()); render(100, &state)
    XCTAssertEqual(state.status(latencyFrames: 60).revision, 2)
  }
  func testResetDuringPlayAndRepeatedResetsHaveOneUsablePreparedState() {
    var state = ready(); render(220, &state)
    state.queue(Loop(9, tempo: 100, frames: 960), boundary: .beat)
    for _ in 0..<3 {
      state.mediaServicesReset(latencyFrames: 20)
      XCTAssertFalse(state.playing); XCTAssertEqual(state.status(latencyFrames: 0).targetRevision, 9)
      XCTAssertTrue(state.graphWasRebuilt(generation: state.graphGeneration))
    }
    XCTAssertTrue(state.resume()); render(150, &state)
    XCTAssertEqual(state.status(latencyFrames: 0).revision, 9)
    state.prepare(Loop(10)); XCTAssertFalse(state.playing)
    XCTAssertEqual(state.status(latencyFrames: 0).targetRevision, 10)
    XCTAssertTrue(state.graphWasRebuilt(generation: state.graphGeneration))
    XCTAssertTrue(state.resume())
  }
  func testStopClearsSessionAndStaleGraphCannotBecomeCurrent() {
    var state = ready(); let oldGraph = state.graphGeneration
    state.stop(); XCTAssertFalse(state.hasSnapshot)
    XCTAssertEqual(state.status(latencyFrames: 0).revision, -1)
    XCTAssertFalse(state.graphWasRebuilt(generation: oldGraph)); XCTAssertFalse(state.resume())
  }
  func testDelayedExpectedCategoryAndConfigurationEventsDoNotPauseExplicitPlay() {
    XCTAssertFalse(AudioRoutePolicy.shouldPause(reason: .categoryChanged, sessionMatchesPolicy: true,
      previousOutputs: ["speaker"], currentOutputs: ["speaker"]))
    XCTAssertFalse(AudioRoutePolicy.shouldPause(reason: .configurationChanged, sessionMatchesPolicy: true,
      previousOutputs: ["speaker"], currentOutputs: ["speaker"]))
    XCTAssertFalse(AudioRoutePolicy.shouldPause(reason: .newDevice, sessionMatchesPolicy: true,
      previousOutputs: ["speaker"], currentOutputs: ["headphones"]))
    XCTAssertFalse(AudioRoutePolicy.shouldPause(reason: .override, sessionMatchesPolicy: true,
      previousOutputs: ["headphones"], currentOutputs: ["speaker"]))
  }
  func testGenuineDisconnectUnavailableRouteAndExternalCategoryPauseWithoutResume() {
    XCTAssertTrue(AudioRoutePolicy.shouldPause(reason: .oldDeviceRemoved, sessionMatchesPolicy: true,
      previousOutputs: ["headphones"], currentOutputs: ["speaker"]))
    XCTAssertTrue(AudioRoutePolicy.shouldPause(reason: .noSuitableRoute, sessionMatchesPolicy: true,
      previousOutputs: ["headphones"], currentOutputs: []))
    XCTAssertTrue(AudioRoutePolicy.shouldPause(reason: .categoryChanged, sessionMatchesPolicy: false,
      previousOutputs: ["speaker"], currentOutputs: ["speaker"]))
    XCTAssertTrue(AudioRoutePolicy.shouldPause(reason: .configurationChanged, sessionMatchesPolicy: true,
      previousOutputs: ["headphones"], currentOutputs: ["speaker"]))
    var state = ready(); state.pause(latencyFrames: 20)
    _ = AudioRoutePolicy.shouldPause(reason: .newDevice, sessionMatchesPolicy: true,
      previousOutputs: ["speaker"], currentOutputs: ["headphones"])
    XCTAssertFalse(state.playing); XCTAssertNil(state.renderFrame())
  }
  func testOrphanedRenderCannotAdvanceReplacementGraph() {
    var state = ready(); render(200, &state)
    let orphan = state.graphGeneration
    state.mediaServicesReset(latencyFrames: 40)
    XCTAssertTrue(state.graphWasRebuilt(generation: state.graphGeneration))
    XCTAssertTrue(state.resume())
    let position = state.status(latencyFrames: 0).fraction
    XCTAssertNil(state.renderFrame(generation: orphan))
    XCTAssertEqual(state.status(latencyFrames: 0).fraction, position)
    XCTAssertNotNil(state.renderFrame(generation: state.graphGeneration))
  }
  func testInterruptionEndNeverAutoResumesOrPausesANewerExplicitPlay() {
    var state = ready(); render(200, &state)
    XCTAssertTrue(AudioInterruptionPolicy.shouldPause(phase: .began))
    if AudioInterruptionPolicy.shouldPause(phase: .began) { state.pause(latencyFrames: 40) }
    XCTAssertFalse(state.playing)
    XCTAssertFalse(AudioInterruptionPolicy.shouldPause(phase: .ended))
    if AudioInterruptionPolicy.shouldPause(phase: .ended) { state.pause(latencyFrames: 40) }
    XCTAssertFalse(state.playing) // End never calls resume.
    XCTAssertTrue(state.resume())
    if AudioInterruptionPolicy.shouldPause(phase: .ended) { state.pause(latencyFrames: 40) }
    XCTAssertTrue(state.playing) // A delayed End cannot stop explicit new Play.
    XCTAssertTrue(AudioInterruptionPolicy.shouldPause(phase: .unknown))
  }
  func testDelayedCategoryEventsAcrossRepeatedPlayCannotRestartOrStopTransport() {
    var state = ready()
    for _ in 0..<5 {
      state.pause(latencyFrames: 0); XCTAssertTrue(state.resume())
      if AudioRoutePolicy.shouldPause(reason: .categoryChanged, sessionMatchesPolicy: true,
        previousOutputs: ["speaker"], currentOutputs: ["speaker"]) { state.pause(latencyFrames: 0) }
      XCTAssertTrue(state.playing); render(10, &state)
    }
    state.pause(latencyFrames: 0)
    if AudioRoutePolicy.shouldPause(reason: .categoryChanged, sessionMatchesPolicy: true,
      previousOutputs: ["speaker"], currentOutputs: ["speaker"]) { state.pause(latencyFrames: 0) }
    XCTAssertFalse(state.playing)
  }

  func testHaltedGraphOnOtherwiseHarmlessRoutePausesAndRequiresExplicitRecovery() {
    var state = ready(); render(790, &state)
    state.queue(Loop(2), boundary: .loop); render(30, &state)
    let graph = state.graphGeneration
    XCTAssertFalse(AudioRoutePolicy.shouldPause(reason: .categoryChanged, sessionMatchesPolicy: true,
      previousOutputs: ["speaker"], currentOutputs: ["speaker"]))
    // Native code separately observes engine.isRunning == false in this case.
    state.graphHalted(latencyFrames: 60)
    let paused = state.status(latencyFrames: 0)
    XCTAssertFalse(paused.playing); XCTAssertEqual(paused.revision, 1)
    XCTAssertEqual(paused.targetRevision, 2); XCTAssertEqual(paused.fraction, 0.95, accuracy: 0.00001)
    XCTAssertTrue(state.needsGraphRebuild); XCTAssertNil(state.renderFrame(generation: graph))
    XCTAssertFalse(state.resume())
    XCTAssertTrue(state.graphWasRebuilt(generation: state.graphGeneration))
    XCTAssertFalse(state.playing)
    XCTAssertTrue(state.resume()); render(100, &state)
    XCTAssertEqual(state.status(latencyFrames: 60).revision, 2)
  }

}

import CoreVideo
import AVFoundation
import CryptoKit
import Flutter
import UIKit
import XCTest
@testable import Runner

/// These tests must be run on macOS/iOS; Linux source inspection does not pass them.
final class RunnerTests: XCTestCase {
  private func document(background: UInt32 = 0xfff7f5eb, style: String = "smooth") -> [String: Any] {
    ["tempo": 120, "background": NSNumber(value: background), "style": style,
     "strokes": [["instrument": "keys", "width": 0.01, "points": [[0.25, 0.5, 0], [0.75, 0.5, 100]]]]]
  }
  private func render(_ document: [String: Any], width: Int = 80, height: Int = 100, fraction: Double = 0) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
      [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer), kCVReturnSuccess)
    let renderer = try DrawMusicDocumentFrames(document: document, width: width, height: height)
    try renderer.render(into: buffer!, fraction: fraction)
    return buffer!
  }
  private func rgb(_ buffer: CVPixelBuffer, _ x: Int, _ y: Int) -> [UInt8] {
    CVPixelBufferLockBaseAddress(buffer, .readOnly); defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let pointer = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let offset = y * CVPixelBufferGetBytesPerRow(buffer) + x * 4
    return [pointer[offset+2], pointer[offset+1], pointer[offset]]
  }
  func testLegacyPaperOpacityCompositesOverWhite() throws {
    let frame = try render(document(background: 0x80ff0000))
    let sample = rgb(frame, 50, 80)
    XCTAssertEqual(sample[0], 255)
    XCTAssertLessThanOrEqual(abs(Int(sample[1]) - 127), 1)
    XCTAssertLessThanOrEqual(abs(Int(sample[2]) - 127), 1)
  }
  func testPixelInteriorUsesOriginalInstrumentColor() throws {
    let frame = try render(document(style: "pixel"))
    XCTAssertEqual(rgb(frame, 40, 51), [0x79, 0x61, 0xc6])
  }

  func testAsymmetricSmoothStrokesUseTopLeftDocumentCoordinatesAndCatalogColors() throws {
    var value = document()
    value["strokes"] = [
      ["instrument": "keys", "width": 0.05, "points": [[0.2, 0.2, 0], [0.8, 0.2, 100]]],
      ["instrument": "bell", "width": 0.05, "points": [[0.2, 0.7, 0], [0.8, 0.7, 100]]]
    ]
    let frame = try render(value)
    XCTAssertEqual(rgb(frame, 40, 20), [0x79, 0x61, 0xc6])
    XCTAssertEqual(rgb(frame, 40, 70), [0x28, 0x7e, 0x61])
    XCTAssertEqual(rgb(frame, 40, 80), [0xf7, 0xf5, 0xeb])
    XCTAssertEqual(rgb(frame, 40, 30), [0xf7, 0xf5, 0xeb])
  }

  func testAsymmetricPixelCellAndCursorCapUseTheTopOfTheFrame() throws {
    var value = document(style: "pixel")
    value["strokes"] = [["instrument": "keys", "width": 0.01, "points": [[0.25, 0.2, 0]]]]
    let pixels = try render(value)
    XCTAssertEqual(rgb(pixels, 21, 21), [0x79, 0x61, 0xc6])
    XCTAssertEqual(rgb(pixels, 21, 79), [0xf7, 0xf5, 0xeb])
    value["strokes"] = [[String: Any]]()
    let cursor = try render(value, width: 400, height: 500, fraction: 0.5)
    XCTAssertEqual(rgb(cursor, 203, 6), [0x00, 0x7e, 0x73])
    XCTAssertEqual(rgb(cursor, 203, 494), [0xf7, 0xf5, 0xeb])
  }

  func testLinearGradientStartsAtTopLeftAndEndsAtBottomRight() throws {
    var value = document()
    value["strokes"] = [[String: Any]]()
    value["paper"] = ["kind": "linear", "colors": [0xffff0000, 0xff0000ff], "opacity": 1.0]
    let frame = try render(value)
    let topLeft = rgb(frame, 10, 10), bottomRight = rgb(frame, 70, 90)
    XCTAssertGreaterThan(topLeft[0], 200)
    XCTAssertLessThan(topLeft[2], 50)
    XCTAssertLessThan(bottomRight[0], 50)
    XCTAssertGreaterThan(bottomRight[2], 200)
  }

  func testPhotoOrientationCropClockwiseRotationAndLocalMirrorMatchDocumentSpace() throws {
    // Original four-quadrant PNG with explicit top-to-bottom rows, independent
    // of the export CGContext: red/green above blue/yellow.
    var pixels = [UInt8]()
    let red: [UInt8] = [255, 0, 0, 255], green: [UInt8] = [0, 255, 0, 255]
    let blue: [UInt8] = [0, 0, 255, 255], yellow: [UInt8] = [255, 255, 0, 255]
    for y in 0..<8 { for x in 0..<8 { pixels += y < 4 ? (x < 4 ? red : green) : (x < 4 ? blue : yellow) } }
    let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
    let image = try XCTUnwrap(CGImage(width: 8, height: 8, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: 32, space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let data = try XCTUnwrap(UIImage(cgImage: image).pngData())
    let id = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let support = try XCTUnwrap(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
    let root = support.appendingPathComponent("backgrounds", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let asset = root.appendingPathComponent("\(id).png")
    let existed = FileManager.default.fileExists(atPath: asset.path)
    if !existed { try data.write(to: asset, options: .withoutOverwriting) }
    defer { if !existed { try? FileManager.default.removeItem(at: asset) } }
    func photo(turns: Int = 0, mirror: Bool = false, crop: [Double] = [0, 0, 1, 1]) throws -> CVPixelBuffer {
      var value = document()
      value["strokes"] = [[String: Any]]()
      value["paper"] = ["kind": "photo", "colors": [0xffffffff], "opacity": 1.0,
        "assetId": id, "crop": crop, "quarterTurns": turns, "mirror": mirror]
      return try render(value)
    }
    func corners(_ frame: CVPixelBuffer) -> [[UInt8]] {
      [(20, 20), (60, 20), (20, 80), (60, 80)].map { rgb(frame, $0.0, $0.1) }
    }
    let r = Array(red.prefix(3)), g = Array(green.prefix(3))
    let b = Array(blue.prefix(3)), y = Array(yellow.prefix(3))
    XCTAssertEqual(corners(try photo()), [r, g, b, y])
    XCTAssertEqual(corners(try photo(turns: 1)), [b, r, y, g])
    XCTAssertEqual(corners(try photo(mirror: true)), [g, r, y, b])
    XCTAssertEqual(corners(try photo(turns: 1, mirror: true)), [y, g, b, r])
    XCTAssertEqual(corners(try photo(crop: [0, 0, 0.5, 0.5])), [r, r, r, r])
    XCTAssertEqual(corners(try photo(crop: [0, 0.5, 0.5, 0.5])), [b, b, b, b])
  }
  func testInvalidGeometryFailsBeforeEncoding() {
    var value = document()
    value["strokes"] = [["instrument": "keys", "width": 0.01, "points": [[1.5, 0.5, 0]]]]
    XCTAssertThrowsError(try DrawMusicDocumentFrames(document: value, width: 80, height: 100))
  }
  func testMissingPhotoDoesNotBecomeSuccessfulVideo() {
    var value = document()
    value["paper"] = ["kind": "photo", "colors": [0xfff7f5eb], "opacity": 1.0,
      "assetId": String(repeating: "a", count: 64), "crop": [0.0, 0.0, 1.0, 1.0], "quarterTurns": 0, "mirror": false]
    XCTAssertThrowsError(try render(value))
  }

  private func onExportWorker<T>(_ operation: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do { continuation.resume(returning: try operation()) }
        catch { continuation.resume(throwing: error) }
      }
    }
  }

  /// Executes the actual shipping AVAssetWriter encoder, including its native
  /// validation and the .mp4.tmp handoff that failed on the iOS simulator.
  func testActualEncodedTemporaryMP4ContainsH264AndAACAtBothFrameRates() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Doodimo-video-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    var fixture = document()
    fixture["tempo"] = 200
    // An original audible 440 Hz PCM fixture; this is input to the real encoder.
    let sampleCount = Int((480.0 / 200 + 1.25) * 44_100)
    var pcm = Data(capacity: sampleCount * 2)
    for frame in 0..<sampleCount {
      var value = Int16(sin(Double(frame) * 2 * .pi * 440 / 44_100) * 8000).littleEndian
      withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
    }
    for fps in [Int32(30), Int32(60)] {
      let temporary = directory.appendingPathComponent("actual-\(fps).mp4.tmp")
      let job = DrawMusicVideo.Job()
      let metadata = try await onExportWorker {
        try DrawMusicVideo.encode(document: fixture, pcm: pcm, width: 640, fps: fps,
          output: temporary, job: job, progress: { _ in })
      }
      XCTAssertEqual(metadata["fps"] as? Int32, fps)
      XCTAssertGreaterThan(try Data(contentsOf: temporary).count, 1000)
      // The real app publishes the validated temporary to .mp4. Inspect that
      // result independently through AVFoundation's asynchronous public APIs.
      let published = temporary.deletingPathExtension()
      try FileManager.default.moveItem(at: temporary, to: published)
      let asset = AVURLAsset(url: published)
      let videos = try await asset.loadTracks(withMediaType: .video)
      let audios = try await asset.loadTracks(withMediaType: .audio)
      XCTAssertEqual(videos.count, 1)
      XCTAssertEqual(audios.count, 1)
      let video = try XCTUnwrap(videos.first)
      let audio = try XCTUnwrap(audios.first)
      let size = try await video.load(.naturalSize)
      let rate = try await video.load(.nominalFrameRate)
      XCTAssertEqual(size.width, 640)
      XCTAssertEqual(size.height, 800)
      XCTAssertEqual(rate, Float(fps), accuracy: 0.1)
      let videoFormats = try await video.load(.formatDescriptions)
      let audioFormats = try await audio.load(.formatDescriptions)
      XCTAssertEqual(CMFormatDescriptionGetMediaSubType(try XCTUnwrap(videoFormats.first)), kCMVideoCodecType_H264)
      XCTAssertEqual(CMFormatDescriptionGetMediaSubType(try XCTUnwrap(audioFormats.first)), kAudioFormatMPEG4AAC)
      XCTAssertFalse(FileManager.default.fileExists(atPath: job.stagingDirectory.path))
    }
  }

  func testNativeValidationRejectsAnActualVideoOnlyMovie() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Doodimo-track-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let movie = directory.appendingPathComponent("missing-audio.mp4")
    try await onExportWorker {
      let writer = try AVAssetWriter(outputURL: movie, fileType: .mp4)
      let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 64, AVVideoHeightKey: 64])
      let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64])
      writer.add(input)
      XCTAssertTrue(writer.startWriting())
      writer.startSession(atSourceTime: .zero)
      let end = Date().addingTimeInterval(10)
      while !input.isReadyForMoreMediaData && Date() < end { Thread.sleep(forTimeInterval: 0.001) }
      XCTAssertTrue(input.isReadyForMoreMediaData)
      let pool = try XCTUnwrap(adaptor.pixelBufferPool)
      var frame: CVPixelBuffer?
      XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &frame), kCVReturnSuccess)
      let image = try XCTUnwrap(frame)
      CVPixelBufferLockBaseAddress(image, [])
      memset(CVPixelBufferGetBaseAddress(image), 0, CVPixelBufferGetDataSize(image))
      CVPixelBufferUnlockBaseAddress(image, [])
      XCTAssertTrue(adaptor.append(image, withPresentationTime: .zero))
      input.markAsFinished()
      writer.endSession(atSourceTime: CMTime(value: 1, timescale: 30))
      let done = DispatchSemaphore(value: 0)
      writer.finishWriting { done.signal() }
      XCTAssertEqual(done.wait(timeout: .now() + 10), .success)
      XCTAssertEqual(writer.status, .completed)
      XCTAssertThrowsError(try DrawMusicVideo.validateCompletedMovie(movie, job: DrawMusicVideo.Job()))
    }
    XCTAssertTrue(FileManager.default.fileExists(atPath: movie.path))
  }

  func testCancelledNativeExportDoesNotLeaveAnArtifactOrStagingDirectory() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Doodimo-cancel-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let output = directory.appendingPathComponent("cancel.mp4.tmp")
    let fixture = document()
    let pcm = Data(count: Int((480.0 / 120 + 1.25) * 44_100) * 2)
    let job = DrawMusicVideo.Job()
    try await onExportWorker {
      XCTAssertThrowsError(try DrawMusicVideo.encode(document: fixture, pcm: pcm, width: 640, fps: 30,
        output: output, job: job, progress: { _ in job.cancel() })) { error in
          XCTAssertTrue(error is CancellationError)
        }
    }
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    XCTAssertFalse(FileManager.default.fileExists(atPath: job.stagingDirectory.path))
  }

  func testExistingDestinationIsPreservedWhenQueuedEncodingStarts() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Doodimo-existing-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let output = directory.appendingPathComponent("existing.mp4.tmp")
    let sentinel = Data("Existing export must survive".utf8)
    try sentinel.write(to: output)
    let fixture = document()
    let pcm = Data(count: Int((480.0 / 120 + 1.25) * 44_100) * 2)
    let job = DrawMusicVideo.Job()
    try await onExportWorker {
      XCTAssertThrowsError(try DrawMusicVideo.encode(document: fixture, pcm: pcm, width: 640, fps: 30,
        output: output, job: job, progress: { _ in }))
    }
    XCTAssertEqual(try Data(contentsOf: output), sentinel)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["existing.mp4.tmp"])
    XCTAssertFalse(FileManager.default.fileExists(atPath: job.stagingDirectory.path))
  }

  func testDestinationCreatedDuringEncodingSurvivesFailedPublication() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Doodimo-race-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let output = directory.appendingPathComponent("raced.mp4.tmp")
    let sentinel = Data("Another creator owns this destination".utf8)
    var fixture = document()
    fixture["tempo"] = 200
    let pcm = Data(count: Int((480.0 / 200 + 1.25) * 44_100) * 2)
    let job = DrawMusicVideo.Job()
    try await onExportWorker {
      var injected = false
      XCTAssertThrowsError(try DrawMusicVideo.encode(document: fixture, pcm: pcm, width: 640, fps: 30,
        output: output, job: job, progress: { fraction in
          if !injected && fraction > 0.3 {
            injected = true
            do { try sentinel.write(to: output, options: .withoutOverwriting) }
            catch { XCTFail("Could not inject destination race: \(error)") }
          }
        }))
      XCTAssertTrue(injected)
    }
    XCTAssertEqual(try Data(contentsOf: output), sentinel)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["raced.mp4.tmp"])
    XCTAssertFalse(FileManager.default.fileExists(atPath: job.stagingDirectory.path))
  }
}

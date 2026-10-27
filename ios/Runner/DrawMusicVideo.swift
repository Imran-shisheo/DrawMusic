import AVFoundation
import CoreGraphics
import CryptoKit
import ImageIO
import Flutter
import UIKit

final class DrawMusicVideo {
  private final class Job {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    func check() throws { lock.lock(); let cancelled = value; lock.unlock(); if cancelled { throw CancellationError() } }
  }
  private let channel: FlutterMethodChannel
  private let worker = DispatchQueue(label: "DrawMusic.offline-video", qos: .userInitiated)
  private var jobs: [String: Job] = [:] // Main-queue ownership.
  var hasActiveJobs: Bool { !jobs.isEmpty } // Read only on the main channel.
  private var background: NSObjectProtocol?
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "scribblesong/video", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    background = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.jobs.values.forEach { $0.cancel() } }
  }
  deinit { if let background = background { NotificationCenter.default.removeObserver(background) }; jobs.values.forEach { $0.cancel() } }
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "cancel" { if let id = call.arguments as? String { jobs[id]?.cancel() }; result(nil); return }
    guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
    do {
      guard let arguments = call.arguments as? [String: Any], let id = arguments["jobId"] as? String,
            id.range(of: "^[a-zA-Z0-9_-]{1,80}$", options: .regularExpression) != nil,
            let json = arguments["document"] as? String, json.utf8.count <= 20_000_000,
            let document = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
            let pcm = arguments["pcm"] as? FlutterStandardTypedData, !pcm.data.isEmpty,
            pcm.data.count <= 2_000_000, pcm.data.count % 2 == 0,
            let width = arguments["width"] as? Int, [640, 1080].contains(width),
            let path = arguments["path"] as? String, jobs[id] == nil,
            [30, 60].contains(arguments["fps"] as? Int ?? 30)
      else { throw NativePortError.invalid("Invalid export request") }
      let output = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let root = documents.appendingPathComponent("exports").resolvingSymlinksInPath().standardizedFileURL
      guard output.path.hasPrefix(root.path + "/"), output.lastPathComponent.hasSuffix(".mp4.tmp"), !FileManager.default.fileExists(atPath: output.path)
      else { throw NativePortError.invalid("Invalid export destination") }
      let job = Job(); jobs[id] = job
      worker.async {
        do {
          let metadata = try self.encode(document: document, pcm: pcm.data, width: width, fps: Int32(arguments["fps"] as? Int ?? 30), output: output, job: job) { progress in
            DispatchQueue.main.async { self.channel.invokeMethod("progress", arguments: ["jobId": id, "progress": progress]) }
          }
          DispatchQueue.main.async { self.jobs.removeValue(forKey: id); result(metadata) }
        } catch {
          try? FileManager.default.removeItem(at: output)
          DispatchQueue.main.async {
            self.jobs.removeValue(forKey: id)
            result(FlutterError(code: error is CancellationError ? "export_cancelled" : "video_unavailable", message: error.localizedDescription, details: nil))
          }
        }
      }
    } catch { result(FlutterError(code: "video_unavailable", message: error.localizedDescription, details: nil)) }
  }

  private func encode(document: [String: Any], pcm: Data, width: Int, fps: Int32, output: URL, job: Job,
                      progress: (Double) -> Void) throws -> [String: Any] {
    try job.check()
    guard let tempo = document["tempo"] as? Int, (60...200).contains(tempo),
          abs(Double(pcm.count / 2) / 44_100 - (480 / Double(tempo) + 1.25)) < 0.001
    else { throw NativePortError.invalid("Invalid immutable audio duration") }
    let height = width * 5 / 4
    let audioFrames = pcm.count / 2
    let frameCount = Int(ceil(Double(audioFrames) / 44_100 * Double(fps)))
    let renderer = try DrawMusicDocumentFrames(document: document, width: width, height: height)
    let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
    let video = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width, AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: width == 1080 ? 4_000_000 : 2_000_000,
        AVVideoExpectedSourceFrameRateKey: fps, AVVideoMaxKeyFrameIntervalKey: fps,
        AVVideoAllowFrameReorderingKey: false]])
    video.expectsMediaDataInRealTime = false
    let pixel = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
      kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
    var asbd = AudioStreamBasicDescription(mSampleRate: 44_100, mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
      mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
    var audioFormat: CMAudioFormatDescription?
    guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil,
      magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &audioFormat) == noErr, let format = audioFormat
    else { throw NativePortError.invalid("Audio export format unavailable") }
    let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000], sourceFormatHint: format)
    audio.expectsMediaDataInRealTime = false
    guard writer.canAdd(video), writer.canAdd(audio) else { throw NativePortError.invalid("H.264/AAC encoding unavailable") }
    writer.add(video); writer.add(audio)
    guard writer.startWriting() else { throw writer.error ?? NativePortError.invalid("Could not start encoding") }
    writer.startSession(atSourceTime: .zero)
    var complete = false
    defer { if !complete { writer.cancelWriting(); try? FileManager.default.removeItem(at: output) } }
    var videoIndex = 0, audioIndex = 0, lastWork = Date()
    func appendAudioChunk() throws {
      let count = min(1024, audioFrames - audioIndex)
      let sample = try audioSample(pcm: pcm, offset: audioIndex, frames: count, format: format)
      guard audio.append(sample) else { throw writer.error ?? NativePortError.invalid("Audio could not be encoded") }
      audioIndex += count; lastWork = Date()
    }
    while videoIndex < frameCount || audioIndex < audioFrames {
      try job.check()
      guard writer.status == .writing else { throw writer.error ?? NativePortError.invalid("Encoder stopped") }
      guard Date().timeIntervalSince(lastWork) < 30 else { throw NativePortError.invalid("Encoder stalled; try compact output") }
      // Prefer the next timestamp, but feed another ready track if it is
      // backpressured: AVAssetWriter orders timestamps within each track.
      // The pool has a hard six-frame allocation threshold and each audio chunk
      // is 1024 frames; never accumulate a whole video's frames.
      let wantsVideo = videoIndex < frameCount && (audioIndex >= audioFrames || Double(videoIndex) / Double(fps) <= Double(audioIndex) / 44_100)
      if videoIndex < frameCount && video.isReadyForMoreMediaData && (wantsVideo || !audio.isReadyForMoreMediaData) {
        let appended: Bool = try autoreleasepool {
          guard let pool = pixel.pixelBufferPool else { throw NativePortError.invalid("Video pixel pool unavailable") }
          var image: CVPixelBuffer?
          let allocated = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool,
            [kCVPixelBufferPoolAllocationThresholdKey: 6] as CFDictionary, &image)
          if allocated == kCVReturnWouldExceedAllocationThreshold { return false }
          guard allocated == kCVReturnSuccess, let image = image
          else { throw NativePortError.invalid("Video frame allocation failed") }
          try renderer.render(into: image, fraction: min(1, Double(videoIndex) / Double(fps) / (480 / Double(tempo))))
          guard pixel.append(image, withPresentationTime: CMTime(value: Int64(videoIndex), timescale: fps))
          else { throw writer.error ?? NativePortError.invalid("Video frame could not be encoded") }
          return true
        }
        if appended { videoIndex += 1; lastWork = Date(); progress(0.95 * Double(videoIndex) / Double(frameCount)) }
        else if audioIndex < audioFrames && audio.isReadyForMoreMediaData { try appendAudioChunk() }
        else { Thread.sleep(forTimeInterval: 0.001) }
      } else if audioIndex < audioFrames && audio.isReadyForMoreMediaData {
        try appendAudioChunk()
      } else { Thread.sleep(forTimeInterval: 0.001) }
    }
    video.markAsFinished(); audio.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: Int64(frameCount), timescale: fps))
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    let deadline = Date().addingTimeInterval(30)
    while finished.wait(timeout: .now() + 0.05) != .success {
      try job.check()
      guard Date() < deadline else { throw NativePortError.invalid("Encoder finalization timed out") }
    }
    try job.check()
    guard writer.status == .completed else { throw writer.error ?? NativePortError.invalid("Incomplete video export") }
    let asset = AVURLAsset(url: output)
    guard asset.tracks(withMediaType: .video).count == 1, asset.tracks(withMediaType: .audio).count == 1,
          (try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0
    else { throw NativePortError.invalid("Encoded tracks are missing") }
    complete = true; progress(1)
    return ["width": width, "height": height, "fps": fps, "durationSeconds": Double(frameCount) / Double(fps)]
  }
  private func audioSample(pcm: Data, offset: Int, frames: Int, format: CMAudioFormatDescription) throws -> CMSampleBuffer {
    var block: CMBlockBuffer?
    let bytes = frames * 2
    guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: bytes,
      blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: bytes, flags: 0,
      blockBufferOut: &block) == noErr, let block = block else { throw NativePortError.invalid("Audio chunk allocation failed") }
    let copied = pcm.withUnsafeBytes { pointer in CMBlockBufferReplaceDataBytes(with: pointer.baseAddress!.advanced(by: offset * 2), blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes) }
    guard copied == noErr else { throw NativePortError.invalid("Audio chunk copy failed") }
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 44_100), presentationTimeStamp: CMTime(value: Int64(offset), timescale: 44_100), decodeTimeStamp: .invalid)
    var size = 2
    var sample: CMSampleBuffer?
    guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
      sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1,
      sampleSizeArray: &size, sampleBufferOut: &sample) == noErr, let sample = sample
    else { throw NativePortError.invalid("Audio chunk timing invalid") }
    return sample
  }
}

/// Original document-coordinate renderer. No Flutter controls or screenshots.
final class DrawMusicDocumentFrames {
  private let document: [String: Any]
  private let width: Int, height: Int
  private let colors: [String: UInt32] = ["keys": 0xff7961c6, "mallet": 0xffa46b16, "bell": 0xff287e61,
    "warmSynth": 0xffa64d34, "pluck": 0xff456990, "flute": 0xff536d35, "strings": 0xff9b4273,
    "chime": 0xff53648c, "bass": 0xff795548, "chip": 0xff6c54a2, "electronicBass": 0xff925328,
    "guitar": 0xff846029, "saxophone": 0xff986b17]
  private let strokes: [[String: Any]]
  private let backgroundImage: CGImage?
  init(document: [String: Any], width: Int, height: Int) throws {
    self.document = document; self.width = width; self.height = height
    guard let strokes = document["strokes"] as? [[String: Any]], strokes.count <= 100_000 else { throw NativePortError.invalid("Invalid drawing") }
    self.strokes = strokes
    backgroundImage = try Self.loadBackground(document)
    var count = 0
    for stroke in strokes {
      guard let points = stroke["points"] as? [[NSNumber]], !points.isEmpty,
            let lineWidth = stroke["width"] as? Double, lineWidth > 0, lineWidth <= 0.1
      else { throw NativePortError.invalid("Invalid stroke") }
      count += points.count
      guard count <= 100_000 else { throw NativePortError.invalid("Drawing exceeds export budget") }
      for point in points {
        guard point.count >= 2, point[0].doubleValue.isFinite, point[1].doubleValue.isFinite,
              (0...1).contains(point[0].doubleValue), (0...1).contains(point[1].doubleValue)
        else { throw NativePortError.invalid("Invalid drawing coordinate") }
      }
    }
  }
  func render(into buffer: CVPixelBuffer, fraction: Double) throws {
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let memory = CVPixelBufferGetBaseAddress(buffer), let context = CGContext(data: memory, width: width,
      height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
    else { throw NativePortError.invalid("Video frame context unavailable") }
    try paintBackground(context)
    let pixel = document["style"] as? String == "pixel"
    for stroke in strokes {
      let points = stroke["points"] as! [[NSNumber]]
      context.setStrokeColor(color(colors[stroke["instrument"] as? String ?? "keys"] ?? colors["keys"]!))
      context.setFillColor(color(colors[stroke["instrument"] as? String ?? "keys"] ?? colors["keys"]!))
      let line = (stroke["width"] as! Double) * Double(width)
      context.setLineWidth(line); context.setLineCap(.round); context.setLineJoin(.round)
      if pixel {
        context.setShouldAntialias(false)
        var cells = Set<Int>()
        var previous: (Int, Int)?
        for point in points {
          let x = min(39, Int(point[0].doubleValue * 40)), y = min(49, Int(point[1].doubleValue * 50))
          if let old = previous {
            let steps = max(abs(x - old.0), abs(y - old.1))
            if steps > 0 { for i in 1...steps {
              let xx = Int((Double(old.0 * (steps - i) + x * i) / Double(steps)).rounded())
              let yy = Int((Double(old.1 * (steps - i) + y * i) / Double(steps)).rounded())
              cells.insert(yy * 40 + xx)
            } }
          }
          cells.insert(y * 40 + x); previous = (x, y)
        }
        for cell in cells { context.fill(CGRect(x: Double(cell % 40) * Double(width) / 40, y: Double(cell / 40) * Double(height) / 50, width: Double(width) / 40, height: Double(height) / 50)) }
        context.setShouldAntialias(true)
      } else if points.count == 1 {
        context.fillEllipse(in: CGRect(x: points[0][0].doubleValue * Double(width) - line / 2,
          y: points[0][1].doubleValue * Double(height) - line / 2, width: line, height: line))
      } else {
        context.beginPath()
        context.move(to: CGPoint(x: points[0][0].doubleValue * Double(width), y: points[0][1].doubleValue * Double(height)))
        for point in points.dropFirst() { context.addLine(to: CGPoint(x: point[0].doubleValue * Double(width), y: point[1].doubleValue * Double(height))) }
        context.strokePath()
      }
    }
    context.setStrokeColor(color(0xff007e73)); context.setFillColor(color(0xff007e73)); context.setLineWidth(2 * Double(width) / 400)
    let x = min(Double(width - 1), max(0, fraction) * Double(width))
    context.move(to: CGPoint(x: x, y: 0)); context.addLine(to: CGPoint(x: x, y: CGFloat(height))); context.strokePath()
    let radius = 5 * Double(width) / 400
    context.fillEllipse(in: CGRect(x: x - radius, y: Double(width) * 6 / 400 - radius, width: radius * 2, height: radius * 2))
  }
  private static func loadBackground(_ document: [String: Any]) throws -> CGImage? {
    guard let paper = document["paper"] as? [String: Any], paper["kind"] as? String == "photo" else { return nil }
    guard let id = paper["assetId"] as? String, id.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
          let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { throw NativePortError.invalid("Invalid background image reference") }
    let root = support.appendingPathComponent("backgrounds", isDirectory: true).resolvingSymlinksInPath()
    let active = root.appendingPathComponent("\(id).png")
    let stage = root.appendingPathComponent(".cleanup-staging", isDirectory: true)
    let usingStage = !FileManager.default.fileExists(atPath: active.path)
    let url = usingStage ? stage.appendingPathComponent("\(id).png") : active
    guard (!usingStage || stage.resolvingSymlinksInPath().path == stage.path),
          url.resolvingSymlinksInPath().path == url.path,
          (try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])).isRegularFile == true,
          (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else {
      throw NativePortError.invalid("Unsafe background image location")
    }
    guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0, size <= 32 * 1024 * 1024
    else { throw NativePortError.invalid("Background image unavailable or oversized") }
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard actual == id,
          let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 2048, height <= 2048,
          let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    else { throw NativePortError.invalid("Background image is damaged; replace it before exporting") }
    return image
  }
  private func color(_ argb: UInt32) -> CGColor {
    CGColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255,
      blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
  }
  private func paintBackground(_ context: CGContext) throws {
    let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    context.setFillColor(color(0xffffffff)); context.fill(rect)
    guard let paper = document["paper"] as? [String: Any] else {
      context.setFillColor(color((document["background"] as? NSNumber)?.uint32Value ?? 0xfff7f5eb)); context.fill(rect); return
    }
    let opacity = (paper["opacity"] as? Double ?? 1).clamped(to: 0...1)
    var values = (paper["colors"] as? [NSNumber] ?? [NSNumber(value: 0xfff7f5eb)]).map { color($0.uint32Value) }
    context.saveGState(); defer { context.restoreGState() }; context.setAlpha(opacity)
    switch paper["kind"] as? String ?? "solid" {
    case "linear", "radial":
      if values.count == 1 { values.append(values[0]) }
      guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: values as CFArray, locations: nil) else { throw NativePortError.invalid("Invalid gradient") }
      if paper["kind"] as? String == "radial" {
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2), startRadius: 0,
          endCenter: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2), endRadius: CGFloat(max(width, height)) / 2,
          options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
      } else { context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: CGFloat(width), y: CGFloat(height)), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]) }
    case "photo":
      guard let image = backgroundImage else { throw NativePortError.invalid("Background image missing; replace it before exporting") }
      let crop = paper["crop"] as? [Double] ?? [0, 0, 1, 1]
      guard crop.count == 4, crop.allSatisfy({ $0.isFinite }), crop[0] >= 0, crop[1] >= 0,
        crop[2] > 0, crop[3] > 0, crop[0] + crop[2] <= 1.0000001, crop[1] + crop[3] <= 1.0000001,
        let cropped = image.cropping(to: CGRect(x: crop[0] * Double(image.width), y: crop[1] * Double(image.height), width: crop[2] * Double(image.width), height: crop[3] * Double(image.height)))
      else { throw NativePortError.invalid("Invalid image crop") }
      let turns = paper["quarterTurns"] as? Int ?? 0
      guard (0...3).contains(turns) else { throw NativePortError.invalid("Invalid background rotation") }
      let swapped = turns % 2 != 0
      let iw = Double(swapped ? cropped.height : cropped.width), ih = Double(swapped ? cropped.width : cropped.height)
      let scale = max(Double(width) / iw, Double(height) / ih)
      context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
      context.rotate(by: CGFloat(turns) * .pi / 2)
      if paper["mirror"] as? Bool == true { context.scaleBy(x: -1, y: 1) }
      context.scaleBy(x: 1, y: -1)
      context.draw(cropped, in: CGRect(x: -Double(cropped.width) * scale / 2, y: -Double(cropped.height) * scale / 2, width: Double(cropped.width) * scale, height: Double(cropped.height) * scale))
    default: context.setFillColor(values.first ?? color(0xfff7f5eb)); context.fill(rect)
    }
  }
}
private extension Double { func clamped(to range: ClosedRange<Double>) -> Double { max(range.lowerBound, min(range.upperBound, self)) } }

import CoreVideo
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
  private func render(_ document: [String: Any]) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 80, 100, kCVPixelFormatType_32BGRA,
      [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer), kCVReturnSuccess)
    let renderer = try DrawMusicDocumentFrames(document: document, width: 80, height: 100)
    try renderer.render(into: buffer!, fraction: 0)
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
}

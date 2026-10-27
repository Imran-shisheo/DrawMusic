import AVFoundation
import CryptoKit
import Flutter
import ImageIO
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// Images stay local. PHPicker needs no broad Photos-library permission; camera
/// access is requested only after the creator selects Capture.
final class DrawMusicBackgrounds: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?
  private let recoveredKey = "DrawMusic.pendingBackgroundImport.v1"
  private let worker = DispatchQueue(label: "DrawMusic.image-import", qos: .userInitiated)
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "scribblesong/backgrounds", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "acknowledge" {
      UserDefaults.standard.removeObject(forKey: recoveredKey)
      result(nil); return
    }
    if call.method == "recover" {
      // Keep successful metadata until Dart validates and acknowledges delivery.
      let value = UserDefaults.standard.dictionary(forKey: recoveredKey)
      result(value); return
    }
    guard pending == nil, let presenter = DrawMusicFiles.presenter() else {
      result(FlutterError(code: "picker_busy", message: "An image action is already in progress", details: nil)); return
    }
    switch call.method {
    case "pickPhoto":
      pending = result
      var options = PHPickerConfiguration()
      options.filter = .images; options.selectionLimit = 1
      options.preferredAssetRepresentationMode = .current
      let picker = PHPickerViewController(configuration: options)
      picker.delegate = self; presenter.present(picker, animated: true)
    case "capture":
      guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
        result(FlutterError(code: "camera_unavailable", message: "This device has no available camera", details: nil)); return
      }
      pending = result
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: showCamera()
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { allowed in DispatchQueue.main.async {
          if allowed { self.showCamera() } else { self.finish(FlutterError(code: "permission_denied", message: "Camera access was denied", details: ["permanent": true])) }
        } }
      default: finish(FlutterError(code: "permission_denied", message: "Enable Camera for DrawMusic in iOS Settings", details: ["permanent": true]))
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func showCamera() {
    guard let presenter = DrawMusicFiles.presenter() else { finish(FlutterError(code: "camera_unavailable", message: "Camera presentation unavailable", details: nil)); return }
    let picker = UIImagePickerController()
    picker.sourceType = .camera; picker.mediaTypes = [UTType.image.identifier]
    picker.cameraCaptureMode = .photo; picker.allowsEditing = false
    picker.delegate = self; picker.modalPresentationStyle = .fullScreen
    presenter.present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let selection = results.first else { finish(["cancelled": true]); return }
    selection.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
      do {
        guard let url = url else { throw error ?? NativePortError.invalid("Image unavailable") }
        let properties = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = properties.fileSize, size > 0, size <= 32 * 1024 * 1024 else { throw NativePortError.invalid("Image exceeds 32 MB import limit") }
        // File representation is valid only inside this callback; normalize it
        // here instead of retaining the provider's temporary file URL.
        let metadata = try self.normalize(url)
        DispatchQueue.main.async { self.imported(metadata) }
      } catch { DispatchQueue.main.async { self.finish(FlutterError(code: "image_invalid", message: error.localizedDescription, details: nil)) } }
    }
  }
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true); finish(["cancelled": true])
  }
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true)
    if let url = info[.imageURL] as? URL {
      worker.async {
        do { let value = try self.normalize(url); DispatchQueue.main.async { self.imported(value) } }
        catch { DispatchQueue.main.async { self.finish(FlutterError(code: "image_invalid", message: error.localizedDescription, details: nil)) } }
      }
      return
    }
    guard let image = info[.originalImage] as? UIImage else { finish(FlutterError(code: "image_invalid", message: "Camera did not return an image", details: nil)); return }
    worker.async {
      do {
        let maxDimension = max(image.size.width, image.size.height)
        guard maxDimension > 0 else { throw NativePortError.invalid("Invalid camera image") }
        let factor = min(1, 2048 / maxDimension)
        let dimensions = CGSize(width: max(1, (image.size.width * factor).rounded()), height: max(1, (image.size.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        // UIImage.draw applies the camera's orientation metadata. The system
        // camera still owns its full capture image; peak device RSS is untested.
        let normalized = UIGraphicsImageRenderer(size: dimensions, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: dimensions)) }
        guard let png = normalized.pngData() else { throw NativePortError.invalid("Camera image could not be normalized") }
        let value = try self.store(png, width: Int(dimensions.width), height: Int(dimensions.height))
        DispatchQueue.main.async { self.imported(value) }
      } catch { DispatchQueue.main.async { self.finish(FlutterError(code: "image_invalid", message: error.localizedDescription, details: nil)) } }
    }
  }
  private func normalize(_ url: URL) throws -> [String: Any] {
    guard let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, bytes > 0, bytes <= 32 * 1024 * 1024
    else { throw NativePortError.invalid("Image exceeds 32 MB import limit") }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, Int64(width) * Int64(height) <= 80_000_000,
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
            kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    else { throw NativePortError.invalid("Unsupported, corrupt or oversized image") }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
    else { throw NativePortError.invalid("PNG normalization unavailable") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NativePortError.invalid("Image normalization failed") }
    return try store(data as Data, width: image.width, height: image.height)
  }
  private func store(_ png: Data, width: Int, height: Int) throws -> [String: Any] {
    guard !png.isEmpty, png.count <= 32 * 1024 * 1024 else { throw NativePortError.invalid("Normalized image exceeds storage budget") }
    let id = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let directory = support.appendingPathComponent("backgrounds", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let output = directory.appendingPathComponent("\(id).png")
    try png.write(to: output, options: .atomic)
    return ["id": id, "width": width, "height": height, "bytes": png.count]
  }
  private func imported(_ value: [String: Any]) {
    // Preserve a successful import across loss of the Flutter callback/activity;
    // Repeated recover reads retain metadata until Dart acknowledges validated delivery.
    // Uncommitted assets remain private.
    UserDefaults.standard.set(value, forKey: recoveredKey)
    finish(value)
  }
  private func finish(_ value: Any?) { let result = pending; pending = nil; result?(value) }
}

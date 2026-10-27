import CryptoKit
import Flutter
import UIKit
import UniformTypeIdentifiers

/// System-owned Open and Save actions. They do not assert a receiving app opened
/// the document or that a user subsequently uploaded/sent it.
final class DrawMusicFiles: NSObject, UIDocumentPickerDelegate, UIDocumentInteractionControllerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?
  private var expectedBytes: Int = 0
  private var expectedDigest: SHA256.Digest?
  private let worker = DispatchQueue(label: "DrawMusic.file-verification", qos: .userInitiated)
  private var exportCopy: URL?
  private var interaction: UIDocumentInteractionController?
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "scribblesong/export-files", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }
  static func presenter() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows).first(where: \.isKeyWindow)
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard pending == nil else { result(FlutterError(code: "export_busy", message: "Another file action is in progress", details: nil)); return }
    do {
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String, let name = arguments["name"] as? String,
            let mime = arguments["mime"] as? String, !name.isEmpty, name.count <= 180,
            !name.contains("/"), !name.contains("\\"),
            !name.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
            let presenter = Self.presenter()
      else { throw NativePortError.invalid("Export action unavailable") }
      let source = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let root = documents.appendingPathComponent("exports", isDirectory: true).resolvingSymlinksInPath().standardizedFileURL
      let types = ["mid": "audio/midi", "wav": "audio/wav", "mp4": "video/mp4", "png": "image/png"]
      guard source.path.hasPrefix(root.path + "/"), types[source.pathExtension.lowercased()] == mime,
            name.hasSuffix("." + source.pathExtension.lowercased())
      else { throw NativePortError.invalid("Invalid export location or type") }
      let bytes = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard bytes.isRegularFile == true, let size = bytes.fileSize, size > 0
      else { throw NativePortError.invalid("Export is missing or empty") }
      let cache = FileManager.default.temporaryDirectory.appendingPathComponent("open-exports", isDirectory: true)
      try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
      // Delete only old private staging copies, never a project/library artifact.
      let old = (try? FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
      for item in old {
        if let modified = try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           Date().timeIntervalSince(modified) > 86_400 { try? FileManager.default.removeItem(at: item) }
      }
      let job = cache.appendingPathComponent(UUID().uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: job, withIntermediateDirectories: false)
      let copy = job.appendingPathComponent(name)
      try FileManager.default.copyItem(at: source, to: copy)
      switch call.method {
      case "open":
        let document = UIDocumentInteractionController(url: copy)
        interaction = document; document.delegate = self
        document.uti = UTType(mimeType: mime)?.identifier
        let bounds = presenter.view.bounds
        let anchor = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
        guard document.presentOptionsMenu(from: anchor, in: presenter.view, animated: true)
        else { interaction = nil; try? FileManager.default.removeItem(at: job); throw NativePortError.invalid("No app can open this export") }
        result(nil)
      case "save":
        let digest = try Self.digest(copy)
        pending = result; expectedBytes = size; expectedDigest = digest; exportCopy = copy
        let picker = UIDocumentPickerViewController(forExporting: [copy], asCopy: true)
        picker.delegate = self
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet
        presenter.present(picker, animated: true)
      default: try? FileManager.default.removeItem(at: job); result(FlutterMethodNotImplemented)
      }
    } catch { result(FlutterError(code: "export_file_unavailable", message: error.localizedDescription, details: nil)) }
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(["cancelled": true])
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let destination = urls.first else { finish(["cancelled": true]); return }
    let access = destination.startAccessingSecurityScopedResource()
    let expected = expectedBytes, hash = expectedDigest
    worker.async {
      defer { if access { destination.stopAccessingSecurityScopedResource() } }
      do {
        let count = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let count = count, count == expected, count > 0,
              let hash = hash, try Self.digest(destination) == hash
        else { throw NativePortError.invalid("Public copy could not be verified") }
        // This is an explicit verified copy, not a persistent readable bookmark.
        let value: [String: Any] = ["uri": destination.absoluteString, "bytes": count,
          "destination": destination.deletingLastPathComponent().lastPathComponent]
        DispatchQueue.main.async { self.finish(value) }
      } catch { DispatchQueue.main.async { self.finish(FlutterError(code: "export_file_failed", message: error.localizedDescription, details: nil)) } }
    }
  }
  private static func digest(_ url: URL) throws -> SHA256.Digest {
    guard let stream = InputStream(url: url) else { throw NativePortError.invalid("Export could not be read") }
    stream.open(); defer { stream.close() }
    let capacity = 64 * 1024
    var hash = SHA256(), buffer = [UInt8](repeating: 0, count: capacity)
    while true {
      let count = stream.read(&buffer, maxLength: capacity)
      guard count >= 0 else { throw stream.streamError ?? NativePortError.invalid("Export verification failed") }
      if count == 0 { return hash.finalize() }
      hash.update(data: Data(buffer.prefix(count)))
    }
  }
  private func finish(_ value: Any?) {
    let callback = pending; pending = nil
    if let copy = exportCopy { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
    exportCopy = nil; expectedBytes = 0; expectedDigest = nil
    callback?(value)
  }
  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController { Self.presenter()! }
  func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) { interaction = nil }
}

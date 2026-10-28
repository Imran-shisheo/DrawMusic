import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audio: DrawMusicAudio?
  private var video: DrawMusicVideo?
  private var files: DrawMusicFiles?
  private var backgrounds: DrawMusicBackgrounds?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    audio = DrawMusicAudio(messenger: messenger)
    video = DrawMusicVideo(messenger: messenger)
    files = DrawMusicFiles(messenger: messenger)
    backgrounds = DrawMusicBackgrounds(messenger: messenger, canCleanup: { [weak self] in self?.video?.hasActiveJobs == false })
  }
}

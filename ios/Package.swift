// swift-tools-version: 5.9
import PackageDescription

// Only the actual render-used scheduling state is portable. This package does
// not import or pretend to execute AVFoundation, UIKit or a simulated channel.
let package = Package(
  name: "DrawMusicAudioState",
  products: [.library(name: "DrawMusicAudioState", targets: ["DrawMusicAudioState"])],
  targets: [
    .target(name: "DrawMusicAudioState", path: "AudioState"),
    .testTarget(name: "DrawMusicAudioStateTests", dependencies: ["DrawMusicAudioState"], path: "AudioStateTests")
  ]
)

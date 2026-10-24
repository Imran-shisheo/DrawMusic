# Codex Cloud setup for Android

Use a private GitHub repository owned by Imran-shisheo. The completed PRD and selected safe research references are the starting point; private phone photos/recipient suggestions and raw device dumps are excluded from Git.

## Environment

In Codex web/desktop, select **Work in → Cloud → Select environment → Create environment**. Connect the correct GitHub account and select Imran-shisheo/DrawMusic. Keep environment sharing private. Ask environment setup to prepare Linux x86_64 with JDK 17 and run:

```bash
bash scripts/setup-cloud-android.sh
```

The script pins Flutter 3.47.2 to its verified upstream commit, Android API 36/build-tools 36.0.0 and NDK 28.2.13676358. It downloads official Google command-line tools and verifies the published checksum. It intentionally refuses to run the Linux installer on macOS. It does not create the app.

If the new worker requires Android SDK license acceptance, review the terms presented by `sdkmanager --licenses` and authorize acceptance before setting `DRAWMUSIC_ACCEPT_ANDROID_LICENSES=1` for setup. Do not manufacture or copy license hashes. Hosted GitHub runners may already have valid accepted licenses.

For a later task shell:

```bash
source cloud/env.sh
flutter doctor -v
```

Allow setup/dependency access to github.com, Flutter storage endpoints, dl.google.com, pub.dev, repo.maven.apache.org, Maven Central/Google Maven, services.gradle.org, downloads.gradle.org and redirect/CDN hosts actually requested. Package-manager presets may need additional domains for Flutter engine artifacts and Android SDK archives. Diagnose actual denied destinations rather than enabling arbitrary services.

Review the environment setup report. Publish only once the toolchain checks pass. Start a new cloud task using [FIRST-TASK.md](FIRST-TASK.md), then verify it is running before switching the Mac off. A local chat/worktree or GitHub Actions run does not establish that an autonomous Codex Cloud development task has started.

## Builds

The GitHub Actions workflow validates setup files initially. Until pubspec.yaml exists, it explicitly skips application checks and the Android build. Once the cloud bootstrap creates the app, it runs formatting, analysis, tests and `flutter build apk --debug`, then retains the test APK artifact for seven days. It does not sign a store release or deploy anything.

GitHub Actions build/storage quotas are separate from the ChatGPT subscription. No paid add-on is enabled by this configuration. Cloud Codex tasks use the signed-in workspace's available allowance. A completed task does not automatically schedule another task.

## iOS on the owner's Mac

After the cloud work is committed, pull the branch locally, use Flutter 3.47.2 (FVM optional), run flutter pub get, configure Xcode and create iOS scaffolding if absent with `flutter create --platforms=ios --org com.imranshisheo .`. Review generated files before committing. Test on a simulator/device. Apple signing and store accounts are handled locally when needed; do not upload signing keys into this repository.

## Sources checked 2026-10-24

- [Codex Cloud setup](https://learn.chatgpt.com/docs/environments/cloud-environments)
- [Cloud tasks and computer sleep](https://learn.chatgpt.com/docs/cloud)
- [Flutter 3.47.2 verified release](https://github.com/flutter/flutter/releases/tag/3.47.2)
- [Flutter iOS requirements](https://docs.flutter.dev/platform-integration/ios/setup)
- [Google SDK repository metadata](https://dl.google.com/android/repository/repository2-1.xml)
- [Checkout](https://github.com/actions/checkout), [Java setup](https://github.com/actions/setup-java), [Artifact upload](https://github.com/actions/upload-artifact)

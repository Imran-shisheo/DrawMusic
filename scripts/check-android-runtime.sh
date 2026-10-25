#!/usr/bin/env bash
set -euo pipefail
source cloud/env.sh
export DASH__SUPPRESS_ANALYTICS=true
# Bound Gradle/compiler memory while the emulator occupies this runner.
export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.jvmargs=-Xmx1536m"
mkdir -p work/runtime-output
runtime_result=0
runtime_device=emulator-5554
runtime_resources() {
  {
    date -u
    free -m
    ps -eo pid,ppid,rss,comm --sort=-rss | sed -n '1,15p'
  } >> work/runtime-output/runner-resources.log
}
runtime_resources
adb -s "$runtime_device" shell svc wifi disable
adb -s "$runtime_device" shell svc data disable
(cd android && ./gradlew :app:connectedDebugAndroidTest -Ptarget-platform=android-x64 -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true --console=plain) || runtime_result=$?
adb -s "$runtime_device" exec-out run-as com.imranshisheo.scribblesong cat cache/fixture-video.mp4 > work/runtime-output/fixture-video.mp4 || true
adb -s "$runtime_device" exec-out run-as com.imranshisheo.scribblesong cat cache/audio-soak.json > work/runtime-output/audio-soak.json || true
(cd android && ./gradlew --stop --console=plain) >> work/runtime-output/runner-resources.log 2>&1 || runtime_result=$?
runtime_resources
if [[ "$runtime_result" == 0 ]]; then
  flutter test integration_test/creation_loop_test.dart --no-uninstall --no-pub --no-dds --reporter expanded -d "$runtime_device" --timeout 10m || runtime_result=$?
fi
(cd android && ./gradlew --stop --console=plain) >> work/runtime-output/runner-resources.log 2>&1 || runtime_result=$?
runtime_resources
for runtime_file in ui-export-video.mp4 ui-export-audio.wav ui-export-notes.mid ui-project.json ui-export-metadata.json; do
  adb -s "$runtime_device" exec-out run-as com.imranshisheo.scribblesong cat "cache/$runtime_file" > "work/runtime-output/$runtime_file" || true
done
if [[ "$runtime_result" == 0 ]]; then
  python3 scripts/check-android-force-stop.py || runtime_result=$?
fi
runtime_resources
adb -s "$runtime_device" logcat -d -v threadtime > work/runtime-output/android-full.log || true
adb -s "$runtime_device" logcat -d -s TestRunner AndroidRuntime MediaCodec CCodec ACodec > work/runtime-output/android.log || true
exit "$runtime_result"

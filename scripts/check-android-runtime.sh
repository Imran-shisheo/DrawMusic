#!/usr/bin/env bash
set -euo pipefail
source cloud/env.sh
export DASH__SUPPRESS_ANALYTICS=true
mkdir -p work/runtime-output
runtime_result=0
runtime_device=emulator-5554
adb -s "$runtime_device" shell svc wifi disable
adb -s "$runtime_device" shell svc data disable
(cd android && ./gradlew :app:connectedDebugAndroidTest -Ptarget-platform=android-x64 -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true --console=plain) || runtime_result=$?
adb -s "$runtime_device" exec-out run-as com.imranshisheo.scribblesong cat cache/fixture-video.mp4 > work/runtime-output/fixture-video.mp4 || true
if [[ "$runtime_result" == 0 ]]; then
  flutter test integration_test/creation_loop_test.dart --no-uninstall -d "$runtime_device" --timeout 10m || runtime_result=$?
fi
for runtime_file in ui-export-video.mp4 ui-export-audio.wav ui-export-notes.mid ui-project.json ui-export-metadata.json; do
  adb -s "$runtime_device" exec-out run-as com.imranshisheo.scribblesong cat "cache/$runtime_file" > "work/runtime-output/$runtime_file" || true
done
adb -s "$runtime_device" logcat -d -s TestRunner AndroidRuntime MediaCodec CCodec ACodec > work/runtime-output/android.log || true
exit "$runtime_result"

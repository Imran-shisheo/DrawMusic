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
adb -s "$runtime_device" exec-out run-as com.imranshisheo.scribblesong cat cache/audio-soak.json > work/runtime-output/audio-soak.json || true
if [[ "$runtime_result" == 0 ]]; then
  python3 scripts/run-android-ui.py || runtime_result=$?
fi
for runtime_file in ui-export-video.mp4 ui-export-audio.wav ui-export-notes.mid ui-project.json ui-export-metadata.json ui-export-image.png video-60-profile.json fixture-video-60.mp4 video-hd-60-profile.json fixture-video-hd-60.mp4 expanded-project.json expanded-video.mp4 expanded-audio.wav expanded-notes.mid expanded-image.png qa-hd-background.json; do
  adb -s "$runtime_device" exec-out run-as com.imranshisheo.scribblesong cat "cache/$runtime_file" > "work/runtime-output/$runtime_file" || true
done
for runtime_report in audio-soak.json video-60-profile.json video-hd-60-profile.json; do
  if [[ -s "work/runtime-output/$runtime_report" ]]; then
    cat "work/runtime-output/$runtime_report"
  fi
done
if [[ "$runtime_result" == 0 ]]; then
  python3 scripts/check-android-force-stop.py || runtime_result=$?
fi
adb -s "$runtime_device" logcat -d -s TestRunner AndroidRuntime MediaCodec CCodec ACodec > work/runtime-output/android.log || true
exit "$runtime_result"

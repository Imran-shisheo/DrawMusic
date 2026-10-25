# Android cloud process and soak checks

These checks run only on GitHub Actions' disposable `emulator-5554`, after native and offline creation/export tests. They never target an owner's phone. The host refuses to run outside GitHub Actions or without the emulator's QEMU identity.

## Real Android process stop and relaunch

The host builds a diagnostic-only APK entry point, `tool/android_recovery_probe.dart`, and installs it without uninstalling app data. Android launches it directly; no debugger or integration-test-driver connection is needed between phases. Build/install has its own deadline, and app readiness must arrive within 90 seconds. Native audio operations and repository saves also have bounded deadlines. Diagnostic failures produce an explicit failed report and fail the job.

The first phase creates an isolated token-named directory using the real FileProjectRepository. It saves a baseline drawing with title, scale, tempo, faded paper and Pixel style, starts real native playback and publishes its PID/baseline hash before attempting large 100,000-point revisions. The host verifies that PID belongs to this exact package, records revision/temp filenames, calls `am force-stop` and observes the process disappear.

The second APK phase preserves app data and must report a different PID, unchanged baseline bytes and an exact complete recovered document. Old playback must be stopped; explicit AudioTrack restart must advance its real clock. A new revision must save and reopen exactly through a fresh repository. Only those completed assertions produce a verified report. The shipping APK remains the normal lib/main.dart build uploaded before diagnostics.

`android-force-stop.json`, per-phase build/launch logs and full Android startup logs accompany runtime evidence. On failure, phase log tails are also printed in the job log. A completed candidate before force-stop is allowed and recorded. A temporary-file interruption is claimed only if the host observed a `.tmp` file. The separate Linux diagnostic deliberately observes that window repeatedly. These checks do not close power-loss, actual disk-full or physical-device acceptance.

An earlier integration-test-driver version built/installed but stalled before its ready report in run 40169151007. The native suite, 600-second soak and complete UI flow had passed. Direct diagnostic APK launch removes that extra driver attachment while retaining the data/process/audio checks. Standard setup/product/runtime CI gates remain enabled.

## Ten-minute native streaming soak

An eighth instrumentation test streams one native 120 BPM loop for at least 600 seconds. It checks live transport, revision/tempo and bounded fractional cursor values, requires at least 1,000 samples and 120 complete four-second loops, and fails a ten-second clock stall. Output is released in a finally block, and audio-soak.json is written even on assertion failure.

The report records elapsed time, samples, observed loops, sample gaps, lack-of-progress intervals and sampled whole-process PSS. These memory observations do not establish a history RSS limit or a leak proof. This native test does not exercise ten minutes of drawing, Flutter frame performance, physical sound, route changes or measured latency. Those remain in the device checklist. The runtime step permits 30 minutes for all native, UI, direct-launch force-stop and recovery checks.

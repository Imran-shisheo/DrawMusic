# Android cloud process and soak checks

These checks run only on GitHub Actions' disposable `emulator-5554`, after native and offline creation/export tests. They never target an owner's phone. The host script refuses to run outside GitHub Actions or without the emulator's QEMU identity.

## Real Android process stop and relaunch

The integration diagnostic creates an isolated token-named directory through the real FileProjectRepository. It saves a baseline drawing with title, scale, tempo, faded paper and Pixel style; starts the real native audio session; then publishes a marker containing the live process ID and baseline hash before attempting large 100,000-point revisions.

The host verifies that ID belongs to the exact application package, records revision/temp filenames, invokes `am force-stop` for that package and observes its process disappear. The interrupted first Flutter runner must exit unsuccessfully. A second run installs without uninstalling, verifies a fresh process, checks baseline bytes and the exact complete recovered document, confirms playback does not automatically resume, explicitly restarts AudioTrack and saves/reopens an exact retry. Only that second run can establish success.

`android-force-stop.json` and both phase logs accompany runtime evidence. A completed candidate before the stop is allowed and recorded; a temporary-file interruption is claimed only when the host actually observed a `.tmp` file. The separate Linux diagnostic deliberately observes that pre-publication window repeatedly. Neither substitutes for power-loss, actual disk-full or physical-device acceptance.

## Ten-minute native streaming soak

An eighth Android instrumentation test streams one native 120 BPM loop for at least 600 seconds. It checks live transport, revision/tempo and bounded fractional cursor values throughout, requires at least 1,000 samples and 120 complete four-second loops, and fails a ten-second clock stall. It releases output in a `finally` block and writes `audio-soak.json` even on assertion failure.

The report includes elapsed time, clock samples, observed loops, sample gaps, lack-of-progress intervals and sampled whole-process PSS. Memory numbers are observations, not a history RSS limit or a leak proof. This native output test does not exercise ten minutes of drawing, Flutter frame performance, physical sound, route changes or measured latency. Those remain in the device checklist. The runtime step allows 30 minutes for the native soak, original tests, complete creation flow, force-stop and recovery.

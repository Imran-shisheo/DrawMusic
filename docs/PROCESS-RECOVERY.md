# Cloud process-interruption recovery

`bash scripts/check-android.sh` runs a Linux process-recovery gate after normal Flutter/Android checks. It compiles `tool/crash_recovery_probe.dart` to an executable, runs 12 isolated attempts, and writes `work/runtime-output/process-recovery.json`. Existing CI runtime-evidence upload includes the report. To run only this diagnostic after sourcing the toolchain:

```bash
mkdir -p work/runtime-output
dart compile exe tool/crash_recovery_probe.dart -o work/crash-recovery-probe
work/crash-recovery-probe --report work/runtime-output/process-recovery.json
```

Every attempt creates its own temporary project and publishes a known baseline. An owned child starts a real 100,000-point repository save. The parent watches creation of the temporary revision and sends SIGKILL only through that child's Process handle. After exit, a fresh repository must reopen the exact baseline or a completely published, checksummed candidate. The baseline's published bytes must remain unchanged. A subsequent retry must save/reopen exactly. Cleanup is limited to that attempt's directory, and early failures stop only its still-running child. The diagnostic never scans PIDs/names, controls Android devices or accesses the owner's app data.

A run fails if the write window is not observed, its child is not interrupted, no pre-publication interruption occurs, published data changes, recovery is incomplete or retry fails. Reported temporary byte counts describe whether data had reached the orphan file; an empty temporary file is a valid creation-window interruption, not evidence of a partial payload. A fully published candidate may win the race, but must validate completely. At least one interrupted publication is required so a run cannot pass solely by finishing all saves before interruption.

Local evidence on 25 October 2026: all 12 writers were interrupted before publication; published baseline bytes were preserved, every draft recovered exactly, and all retries saved/reopened. The normal 68 Flutter tests, 20 JVM tests, formatter/analyzer, APK build and v2 signature check also passed.

This proves the Linux repository/process scenario exercised. It does not simulate Android force-stop, power loss, filesystem durability guarantees or disk-full behavior. Keep those acceptance cases open until separately exercised. There is no scheduled execution or paid service associated with the probe; it runs only as part of the explicitly invoked product check/CI workflow.

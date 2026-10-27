# 27 October review fix plan

Baseline: main a7c367058101633271c990e57922ca25f7187811, app 2.0.0+22, merged PR #21; no subsequent source fixes found. Historical Actions 40329847034 does not validate these changes. Full scope: requests/REVIEW-FIXES-2026-10-27.txt.

1. Reproduce eraser overflow, hidden gradient validation, wrong crop preview aspect and stale export-background thumbnails with failing regressions.
2. Fix each safely; preserve source geometry, snapshot identity, one-gesture Undo and compact/large-text controls.
3. Repair native iOS revision/pause state, media-services reset and reason-aware route handling. Provide genuine scheduling tests; mark unexecuted Apple-platform tests explicitly.
4. Implement conservative coordinated startup orphan mark/stage/sweep with age protection, pending-import pins and fail-closed reference scanning. Test real files, interruption and concurrency.
5. Exercise actual HD 60 FPS codecs/timestamps/A-V/memory/cancellation alongside existing gates; never silently downgrade.
6. Integrate, independently review, run focused tests and complete check-android.sh, real Android/UI/export/recovery/soak checks. Update matrix/status/background/history/video/iOS/device docs, commit and open draft PR. Never merge, publish, force-push, operate a personal device or schedule a future task.

Ownership: geometry agent owns eraser/canvas/editor commit boundary; backgrounds agent owns panel/painter preview and regressions; PNG agent owns exported-snapshot thumbnails; iOS agent owns native audio/scheduling tests; catalog agent owns new cleanup service/tests and startup/picker coordination; parent owns HD60, integration, shared docs, builds/CI/review/handoff. All agents reproduce before fixing and record focused evidence; no overlapping commits.

## Reproduction and focused evidence (not new native acceptance)

| Finding | Before-fix reproduction | Fix / regression locations | Current evidence |
|---|---|---|---|
| 2 Eraser cap | Five intended failures including actual Editor FormatException; 99,999→100,001 and 100,000→100,002 | canvas.dart/editor.dart; test/eraser_point_cap_test.dart | 10 new cases and 35 focused geometry/history/score cases passed; work/eraser-cap-evidence.txt. |
| 3 Hidden gradient input | Invalid hidden Second color disables Apply; preset retains invalid field | background_panel.dart; test/background_review_regression_test.dart | 47 focused panel/background cases passed (36 new plus 11 existing), including 3/4-stop rendering; work/background-review-focused-final.log. |
| 4 Crop preview | Actual preview aspect 3.73333 instead of .8 | Same panel and new real widget/pixel tests | Actual 4:5 preview; square/portrait/landscape crop/rotate/mirror matches PNG pixels. |
| 5 Export thumbnails | Gradient thumbnail green245, expected below40 | exports_page.dart; test/export_thumbnail_background_test.dart | Five new pixel/lifecycle cases + two PNG cases passed, analyzer clean. |
| 6 Pause/revision | Render adoption clears pending while audible timeline remains old | iOS render-used pure scheduling state and native tests | 15 render-used pure Swift state/policy tests passed in Linux; native grammar parsed. Apple-framework/native checks unrun. |
| 7 Media reset | Reset notification only pauses immutable engine | iOS graph recovery / scheduling tests | 15 render-used pure Swift state/policy tests passed in Linux; native grammar parsed. Apple-framework/native checks unrun. |
| 8 Self route changes | Unconditional pause risks delayed category notification; not a reproduced first-play failure | Reason-aware native policy/tests | Reason-aware route/state regressions passed in Swift; actual iOS notification timing unrun, with no first-play failure claim. |
| 9 Orphan storage | Baseline retains true old orphans forever | Coordinated safe startup scanner/staging/native gates + real filesystem tests | In progress; conservative retention on uncertain references. |
| 10 HD60 | No prior dedicated HD60 output/profile | AndroidRuntimeTest HD profile/cancel/retry; external packet/full-decode inspector; real HOME UI driver | Source added; compilation and actual new-source Android run pending. |

The baseline is merged PR #21, verified from the repository merge commit and connected GitHub metadata; no merge actor is attributed. New source needs new full formatter/analyzer/product/native/runtime/independent-output evidence. Version is now 2.0.1+23.

Independent review additionally caught and corrected related multi-stop gradient rendering (explicit evenly spaced stops), real ListTile thumbnail aspect constraints, HD host-handshake observation/rerun races, and the cleanup abort-restoration time bound. See feature docs for those concrete regressions; they are not silently folded into historical evidence.

Initial integrated product run: formatter/analyzer passed, 239 Flutter tests passed and one new thumbnail-disposal case failed because its fixed pump window observed zero completed decodes under concurrent load (work/review-full-product.log). This run stopped before APK/JVM/lint and is not accepted. The regression is being changed to wait for actual loading/disposal conditions while keeping its assertions; the full gate must rerun afterward.

Thumbnail wait correction: the unchanged assertions now observe every actual decode/disposal and pump asynchronous widget continuations until bounded readiness conditions hold. All 240 Flutter tests pass at concurrency 8 (work/thumbnail-full-suite-recheck.log). The actual shared Swift helper now has 15 passing cases; native source grammar parses, with Apple-framework typechecking/runtime still unrun. All 24 JVM tests and Android lint (zero errors/11 nonblocking warnings) pass; the instrumentation APK compiles. The final required full product script is rerunning against this frozen tree; new actual Android runtime/HD60 acceptance remains pending.

## Local integrated checkpoint

`bash scripts/check-android.sh` now passes formatter/analyzer, **240 Flutter / 24 JVM tests**, Android lint (zero errors/11 nonblocking warnings), real APK compilation and all 12 staged Linux interruption/recovery/retry cases. The actual APK is version2.0.1/build23 and its v2 signature verifies. Separate `assembleDebugAndroidTest` compiles all 20 Android instrumentation cases. `scripts/check-ios-audio-state.sh` passes 15 actual shared Swift cases and native grammar parsing on verified Swift6.1.2/Linux. Logs are work/review-final-{product,signature,instrumentation-build,swift}.log. Actual current-source emulator/HD60/HOME/independent-export/soak/force-stop acceptance remains pending the draft PR run.

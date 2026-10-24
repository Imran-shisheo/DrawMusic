# Android device acceptance — 1.2.1+5

Record device/Android version, APK source head, output route (speaker/wired/Bluetooth), observed result and any logs. These checks are pending unless a result is recorded in DEVELOPMENT-STATUS.md. The owner's successful playback report applies to 1.0.1+2.

| PRD checks | Steps and expected result |
|---|---|
| QA01, QA04, QA07 | Start offline, open Paper hills, add each instrument, Play for ten minutes. Pause/resume/replay and rapidly tap transport. Music remains audible without duplicated voices or stuck notes; measure physical latency separately from cursor motion. |
| QA06 | During playback, select 60, 120 and 200 BPM. Pitch stays fixed; tempo applies at the next available beat. Add/erase/undo a stroke and change scale; the pending badge clears when the next loop revision is audible. |
| QA07, lifecycle | While playing, background/foreground the app, interrupt audio focus, and disconnect headphones. Playback pauses and never automatically resumes. Explicit Play restores usable output. Repeat on speaker and Bluetooth; record clicks, dropouts and route failures. |
| QA08, QA14 | Save strokes, title, tempo, scale and paper color. Leave through Back, reopen from Drafts and compare. Rename, duplicate, delete then Undo. Verify the duplicate edits independently. On a disposable drawing, force-stop around an autosave and reopen; only complete revisions should load. |
| QA09–QA11 | Export MIDI/WAV plus both MP4 resolutions. Play the files in actual recipient apps; inspect the MP4 on Android and later iOS. The canvas has no app chrome, cursor follows music, dimensions/FPS/codecs match the selected format, and alignment is within one frame. MIDI timbre may differ from preview; WAV/MP4 use original voices. |
| QA12 | Cancel video halfway, then background during a separate video export. Retry successfully and reopen the drawing. Check low-storage and encoder-unavailable failure paths on a disposable test installation; editable drawings remain available and incomplete files are removed. |
| QA13 | Explicitly share each completed file to a chosen receiving app. Cancel the share sheet and test an unavailable recipient. The UI must not claim delivery from a dismissed or merely closed sheet. |
| QA15–QA16 | Test small screens, cutouts, gesture/three-button navigation, 200% text and TalkBack. Reach every editor/export action and distinguish instrument voices without relying only on color. |

Settings/tutorial persistence, exported-library UI, tempo press-repeat, pause/focus fades and large-scene performance remain implementation work. This checklist does not mark them complete. Cloud tests must never operate the owner's personal phone. iOS adapters and local Mac validation remain outside the Linux build evidence.

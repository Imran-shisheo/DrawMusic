# Evidence scope and caveats

Session date: 2026-10-23, Asia/Dubai. Target: `com.banix.drawsound.drawmusic`, version 2.0 (11).

- Attached request terminates after “Feature-first” in section 7. The provided file is retained as `original-request.txt`.
- Existing installed app state was preserved. No app-data reset, decompilation, asset extraction, root access, or technical protection bypass was used.
- First captured launch was already a full-screen ad. A subsequent ordinary restart captured the illustrated loading splash, welcome screen and premium offer. These observations do not prove a clean-install sequence.
- During the optional camera test, the human user granted permission and took a photo to assist. User confirmed this in chat. `040-camera-permission.png` is the permission prompt; `041-camera-denied.png` is misleadingly named and actually shows the resulting cropper. It is NOT evidence of permission-denial behavior. `042`–`044` show the same cropper with a black preview in some frames. Top-left cropper Back returned to the background sheet (`045`).
- Full-screen and expandable ads changed while exploratory actions were running. The initial vertical/circle/zigzag/reverse experimental recordings are quarantined under `videos/invalid/` and `experiments/invalid/`; they cannot support drawing/audio conclusions. One unexpected store overlay was closed without purchasing or deliberately installing anything. Follow-up tests guard the foreground and visible full-screen ad hierarchy before further inputs.
- `screenshots/` retains raw screen evidence at the device resolution. Screenshots containing advertisements or source illustrations are research references, never production assets.
- `actions.jsonl` initially logs capture timestamps only. Experiment JSON files include actual input descriptions and action times. No fabricated timestamps are added for earlier actions.
- ADB/scrcpy capture measures software-visible behavior. Physical haptics, end-to-end speaker latency, stylus pressure and other form factors need separate verification.

## Final evidence audit

- The `high` run was excluded: its drawn screenshot showed only the requested horizontal line, but video review revealed an additional uncontrolled loop-like stroke appearing before/during playback. The high run and its analysis are under `invalid/`; no clean high-line pitch claim is made from it. The cause of that extra input was not established.
- Device volume overlays appear in the low and multi runs. Their visible shapes/frequency evidence can be used with caution; amplitude comparisons across the session are not controlled. The exported MIDI provides independent note/timing evidence for the two-line document.
- The horizontal video acquires a full-screen ad near its end. Only its earlier unobscured drawing/playback interval supports behavior claims; the reverse/fast/slow videos provide cleaner same-geometry comparisons.
- Final video review contact sheets are `valid-video-review-1.jpg` and `valid-video-review-2.jpg`. These are sampled visual checks; raw recordings remain the authoritative evidence.
- Native share-sheet captures contain device-specific suggestions and are excluded from the curated visual gallery. They are not production design references.
- Wi-Fi and mobile data were both 1 (enabled) before the user-authorized offline pass. Both were restored to 1; see `network-*-before.txt` and `network-after-restoration.txt`. No connectivity-setting change remains pending.

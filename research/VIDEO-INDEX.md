# Video and drawing experiment index

All original experimental videos below are Android playback-audio captures made with scrcpy. They contain drawing, Play and playback. Default configuration: 120 BPM, C, major pentatonic, Soft Key, smooth, no accompaniment selected. Coordinates are raw 1080 × 2392 device pixels. Capture timing and input injection are software observations, not physical touch-to-speaker latency measurements.

## Valid controlled runs

| Case / original recording | Duration | Input record | What it establishes / limits |
|---|---:|---|---|
| [horizontal](videos/exp-horizontal.mkv) | 14.20 s | [gesture + events](experiments/horizontal.json), [audio](experiments/horizontal.wav), [analysis](experiments/horizontal-analysis.json) | Sustained pitch; early unobscured segment only. A full-screen ad arrives near the end. |
| [vertical](videos/exp-vertical.mkv) | 21.60 s | [gesture + events](experiments/vertical.json), [audio](experiments/vertical.wav), [analysis](experiments/vertical-analysis.json) | Multi-frequency cluster at one narrow horizontal position. This is the successful retry. |
| [circle](videos/exp-circle.mkv) | 22.37 s | [gesture + events](experiments/circle.json), [audio](experiments/circle.wav), [analysis](experiments/circle-analysis.json) | Pitch changes and multiple scan intersections. Polygonal continuous-touch approximation; a rating prompt appears near the end. |
| [zigzag](videos/exp-zigzag.mkv) | 20.98 s | [gesture + events](experiments/zigzag.json), [audio](experiments/zigzag.wav), [analysis](experiments/zigzag-analysis.json) | Changing pitch follows repeated vertical changes. This is the successful retry. |
| [reverse](videos/exp-reverse.mkv) | 21.97 s | [gesture + events](experiments/reverse.json), [audio](experiments/reverse.wav), [analysis](experiments/reverse-analysis.json) | Same horizontal geometry drawn right to left; scan still moves left to right. Same predominant pitch in sampled steady segment. |
| [fast](videos/exp-fast.mkv) | 21.53 s | [gesture + events](experiments/fast.json), [audio](experiments/fast.wav), [analysis](experiments/fast-analysis.json) | Same horizontal geometry drawn in 250 ms. Compare geometry and musical result with slow, not loudness. |
| [slow](videos/exp-slow.mkv) | 24.34 s | [gesture + events](experiments/slow.json), [audio](experiments/slow.wav), [analysis](experiments/slow-analysis.json) | Same horizontal geometry drawn in 3000 ms. No tested musical speed difference established. |
| [low](videos/exp-low.mkv) | 22.24 s | [gesture + events](experiments/low.json), [audio](experiments/low.wav), [analysis](experiments/low-analysis.json) | Lower horizontal line has lower predominant pitch. System volume overlay prevents amplitude comparisons. |
| [short](videos/exp-short.mkv) | 22.04 s | [gesture + events](experiments/short.json), [audio](experiments/short.wav), [analysis](experiments/short-analysis.json) | Same-height shorter line; comparable pitch and shorter occupied horizontal span. |
| [multi](videos/exp-multi.mkv) | 23.23 s | [gesture + events](experiments/multi.json), [audio](experiments/multi.wav), [analysis](experiments/multi-analysis.json) | Two simultaneous horizontal lines. Volume overlay limits loudness conclusions; independent MIDI confirms notes 72 and 60. |

Browser-compatible preview copies: [vertical](videos/exp-vertical-preview.mp4), [circle](videos/exp-circle-preview.mp4), [zigzag](videos/exp-zigzag-preview.mp4). Video streams are copied; playback audio is transcoded to AAC. Originals remain unchanged. These three previews and the source export are playable in the [visual index](index.html).

Event `elapsed_s` values in JSON are from recorder-process orchestration. They are not guaranteed to match container presentation timestamps exactly. Use the picture/audio to locate exact events; do not treat their offset as measured latency. `capture_exit: 0` alone does not validate a run.

Frequency measurements use 100 ms analysis windows. FFT peaks are descriptive and may contain harmonics; they are not a complete note transcription. [Aggregate measurements](experiments/audio-summary.json). Visual audits: [sheet 1](evidence/valid-video-review-1.jpg), [sheet 2](evidence/valid-video-review-2.jpg).

## Independently generated source-app exports

The source app exported the known two-line research project while offline. Each artifact was saved through the app’s Library overflow → Save action, then copied from the public `Downloads/DrawMusic` folder. These are our own generated results, not extracted private application assets.

| Artifact | Verified properties |
|---|---|
| [MIDI](experiments/source-export-two-lines.mid) | 55 bytes, SMF format 0, one track, 480 PPQ; 120 BPM, 8 beats / 4 seconds; notes 72 and 60 simultaneously, velocity 100; onset tick 640, off tick 3200 |
| [WAV](experiments/source-export-two-lines.wav) | PCM signed 16-bit little endian, 44100 Hz mono, 5.230816 s, 461402 bytes; includes time beyond the four-second score loop |
| [MP4](videos/source-export-two-lines.mp4) | H.264 1136 × 1440 at 60 fps; AAC 44100 Hz mono; 5.294150 s, 495397 bytes; rendered drawing and scan without editor chrome |

[Parsed MIDI event list](experiments/source-midi-inspection.json) · [ffprobe media report](evidence/export-verification.json) · [exported-video frame montage](evidence/source-video-frames.png). Source MP4 duration differing from the score loop is observed; exact proprietary padding policy is not known.

## Discovery and excluded recordings

[Initial editor discovery](videos/01-canvas-discovery.mkv) illustrates the early drawing/transport exploration. It is exploratory evidence, not a controlled comparison.

`videos/invalid/` and `experiments/invalid/` retain the first interrupted vertical/circle/zigzag/reverse runs and the high-line run. The initial runs were interrupted by ads or guards; the high run acquired an uncontrolled extra mark. Their measurements do not support the PRD’s behavioral conclusions. Raw `exp-high-*` screenshots remain for provenance and must not be mistaken for a valid complete test.

The native camera capture was human-assisted; source-app share sheets were canceled. The curated visual gallery excludes device-specific recipient suggestions and the human’s camera photograph. See [evidence scope](evidence/research-scope.md) for the full limitations.

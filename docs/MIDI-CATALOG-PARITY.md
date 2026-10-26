# MIDI parts and expanded-catalog parity

SMF0 remains 480 PPQ, one eight-beat loop ending at tick 3840. The 96-bin score maps each bin to 40 ticks. Tempo metadata uses the immutable snapshot BPM. Standard GM substitutions represent the original synthesized roles; an external synthesizer need not reproduce the PCM timbres exactly.

The thirteen drawing instruments occupy channels 0–8 and 10–13 (zero-based). Channel 9 is reserved for GM percussion: kick 36, snare 38, clap 39 and closed hi-hat 42. Drum-kit and individually enabled controls never emit duplicate copies; an explicitly enabled individual control overrides its kit voice, including its mute/level.

Accompaniment bass uses channel 14/program 32; arpeggio uses channel 15/program 45. Their program changes are emitted only when the part is audible. Separate channels are necessary even when an accompaniment instrument matches a drawing instrument: a short arpeggio note-off must not terminate a held drawn note at the same pitch. This was found during the independent parity review and corrected with an optional internal score-note MIDI part assignment. PCM preview/WAV/MP4 retain independent voices from the same snapshot and ignore channel allocation. Zero-gain or zero-velocity notes emit no note events.

`test/midi_catalog_parity_test.dart` contains two passing focused regressions on 26 October 2026. Its independent SMF parser handles VLQ deltas, metadata and running status; it validates 137 BPM, all thirteen drawing programs, both accompaniment programs, channel 9 allocation, 59 balanced note lifetimes, exact ticks/levels, kit override/mute and tick-3840 completion. The overlap regression explicitly proves that arpeggio pitch-60 note-off at tick 160 is on channel 15, while drawn pluck pitch 60 remains on channel 4 until tick 3840. A second case covers zero-gain/velocity omission and a muted kick overriding the otherwise audible kit.

These are serialization checks. Actual external MIDI player timbre, note handling and receiving-app delivery remain physical acceptance work. The final checkpoint records broader checks and exact source separately; historical acceptance does not validate these new changes.

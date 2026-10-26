# Original music catalog and score policy

Implementation checkpoint: 26 October 2026. This document describes new product rules, not the reference application's proprietary algorithm. Every instrument, root and scale is free in this development build.

The append-only stable instrument IDs are `keys`, `mallet`, `bell`, `warmSynth`, `pluck`, `flute`, `strings`, `chime`, `bass`, `chip`, `electronicBass`, `guitar` and `saxophone`. Their original names, accessible musical roles, coordinated colors, icon identifiers and General MIDI programs are defined in `lib/creative_document/music_catalog.dart`. The first three retain their historical IDs, indices, colors, equations and envelopes. Test fixtures generated from the actual fd5074a source record SHA-256 hashes of their complete PCM WAV output; the new implementation must produce those same hashes.

| Original name | Musical role | Original synthesis | GM program (zero-based) |
|---|---|---|---|
| Cloud keys | Soft keyboard | Three additive harmonics with a soft attack and exponential decay | 0 |
| Wood drops | Marimba/mallet | Fundamental plus fourth harmonic, fast decay | 12 |
| Glass stars | Bells | Inharmonic 2.76/5.4 partials | 10 |
| Amber tide | Warm synth | Softly introduced, band-limited, detuned harmonic banks | 89 |
| Seed pluck | Pluck | Position-dependent excitation, independently damped harmonic string modes | 45 |
| Reed breeze | Flute | Breath-like deterministic modulation and slow introduction of a mostly sinusoidal spectrum | 73 |
| Velvet bow | Strings | Slowly bowed, detuned odd/even harmonic banks | 48 |
| Silver rain | Chime | Four noninteger modes with independently decaying envelopes | 14 |
| Deep pebble | Bass | A strongly damped plucked fundamental with transient upper harmonics | 32 |
| Bit lantern | 8-bit | Band-limited odd-harmonic square spectrum with a stepped sustain envelope | 80 |
| Copper pulse | Electronic bass | Time-decaying FM excitation through a saturating transfer function | 38 |
| Cedar strings | Guitar | Two excitation-position factors and frequency-dependent string-mode damping | 24 |
| Brass ember | Saxophone | Reed-like odd/even spectrum, vibrato and a controlled attack | 65 |

These are original procedural interpretations of musical roles, not sampled or physically modeled replicas. No recordings, paid sound packs or reference assets are shipped. Physical timbre quality and route behavior remain unverified until listened to on devices. New harmonic banks stop below Nyquist; the historical three equations remain untouched. Preview, WAV and MP4 consume the same generated PCM. Device preview volume is not part of the frozen document mix.

Root IDs are `c,cSharp,d,dSharp,e,f,fSharp,g,gSharp,a,aSharp,b`. Root and family persist separately. Legacy scale IDs `major` and `minor` continue to mean major/minor **pentatonic**; new `diatonicMajor` and `diatonicMinor` must never reinterpret them. The other stable families are `harmonicMinor,dorian,phrygian,lydian,mixolydian,blues,chromatic`. `scaleIntervals` is the declared interval contract. The ladder starts from each family's C-root degrees over MIDI 48–84, transposes by the root and caps upper degrees at the highest in-scale pitch no greater than 84. This preserves ordinary semitone transposition while keeping the declared pitch ceiling; capped duplicate pitches merge through normal occupancy deduplication. Horizontal timing, eight-beat duration, geometry and default speed/direction invariance are unchanged.

The 32-simultaneous-voice/4096-note safety budget remains explicit. A full-height chromatic vertical line occupies 37 pitches and therefore produces a complexity error rather than silently deleting pitches. Ordinary chords within the limit remain intact. Instrument, root and scale edits are normal immutable document/history edits; the native transport's existing revision boundary policy applies.

MIDI uses SMF0/480 PPQ. Melodic instruments occupy zero-based channels 0–8 and 10–13, preserving the historical first three channels while reserving channel 9 (displayed channel 10) for percussion. `midiChannel` is the single mapping. Programs are substitute instructions for the receiving synthesizer, not an exact timbre guarantee. Expanded catalog tests independently walk MIDI events, check channel/program allocation and balanced notes. Catalog/scale tests cover all 132 root/family combinations, deterministic round-trips, pitch bounds and distinct deterministic non-silent PCM across all 13 voices. New platform runtime/physical evidence must be recorded separately from these pure checks.

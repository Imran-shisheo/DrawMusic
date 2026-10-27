// Stable persisted IDs. Append-only enum order also preserves v1 score fixtures.
enum Instrument {
  keys,
  mallet,
  bell,
  warmSynth,
  pluck,
  flute,
  strings,
  chime,
  bass,
  chip,
  electronicBass,
  guitar,
  saxophone;

  InstrumentDefinition get definition => instrumentCatalog[index];
  static Instrument resolve(String id) =>
      values.firstWhere((item) => item.name == id, orElse: () => keys);
}

class InstrumentDefinition {
  const InstrumentDefinition(
    this.label,
    this.role,
    this.color,
    this.midiProgram,
    this.iconId,
  );
  final String label, role, iconId;
  final int color, midiProgram;
}

// Original names, colors and synthesis. GM programs are zero-based substitutes;
// an external MIDI synthesizer is not expected to reproduce the PCM timbre.
const instrumentCatalog = [
  InstrumentDefinition('Cloud keys', 'Soft keyboard', 0xff7961c6, 0, 'piano'),
  InstrumentDefinition(
    'Wood drops',
    'Marimba / mallet',
    0xffa46b16,
    12,
    'mallet',
  ),
  InstrumentDefinition('Glass stars', 'Bells', 0xff287e61, 10, 'stars'),
  InstrumentDefinition('Amber tide', 'Warm synth', 0xffa64d34, 89, 'waves'),
  InstrumentDefinition('Seed pluck', 'Pluck', 0xff456990, 45, 'seed'),
  InstrumentDefinition('Reed breeze', 'Flute', 0xff536d35, 73, 'air'),
  InstrumentDefinition('Velvet bow', 'Strings', 0xff9b4273, 48, 'strings'),
  InstrumentDefinition('Silver rain', 'Chime', 0xff53648c, 14, 'chime'),
  InstrumentDefinition('Deep pebble', 'Bass', 0xff795548, 32, 'bass'),
  InstrumentDefinition('Bit lantern', '8-bit', 0xff6c54a2, 80, 'chip'),
  InstrumentDefinition(
    'Copper pulse',
    'Electronic bass',
    0xff925328,
    38,
    'pulse',
  ),
  InstrumentDefinition('Cedar strings', 'Guitar', 0xff846029, 24, 'guitar'),
  InstrumentDefinition('Brass ember', 'Saxophone', 0xff986b17, 65, 'saxophone'),
];

enum RootKey {
  c,
  cSharp,
  d,
  dSharp,
  e,
  f,
  fSharp,
  g,
  gSharp,
  a,
  aSharp,
  b;

  String get label => const [
    'C',
    'C♯',
    'D',
    'D♯',
    'E',
    'F',
    'F♯',
    'G',
    'G♯',
    'A',
    'A♯',
    'B',
  ][index];
  static RootKey resolve(String id) =>
      values.firstWhere((item) => item.name == id, orElse: () => c);
}

enum MusicalScale {
  // Historical IDs major/minor mean pentatonic, never diatonic.
  major,
  minor,
  diatonicMajor,
  diatonicMinor,
  harmonicMinor,
  dorian,
  phrygian,
  lydian,
  mixolydian,
  blues,
  chromatic;

  List<int> get intervals => scaleIntervals[index];
  String get label => const [
    'Major pentatonic',
    'Minor pentatonic',
    'Major',
    'Minor',
    'Harmonic minor',
    'Dorian',
    'Phrygian',
    'Lydian',
    'Mixolydian',
    'Blues',
    'Chromatic',
  ][index];
  static MusicalScale resolve(String id) =>
      values.firstWhere((item) => item.name == id, orElse: () => major);
}

const scaleIntervals = <List<int>>[
  [0, 2, 4, 7, 9],
  [0, 3, 5, 7, 10],
  [0, 2, 4, 5, 7, 9, 11],
  [0, 2, 3, 5, 7, 8, 10],
  [0, 2, 3, 5, 7, 8, 11],
  [0, 2, 3, 5, 7, 9, 10],
  [0, 1, 3, 5, 7, 8, 10],
  [0, 2, 4, 6, 7, 9, 11],
  [0, 2, 4, 5, 7, 9, 10],
  [0, 3, 5, 6, 7, 10],
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
];

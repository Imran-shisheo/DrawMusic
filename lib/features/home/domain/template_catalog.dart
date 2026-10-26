import 'dart:math' as math;

import '../../../creative_document/document.dart';

class OriginalTemplate {
  const OriginalTemplate(this.id, this.title, this.description, this.kind);
  final String id, title, description;
  final int kind;
  ProjectDocument create() {
    Stroke mark(String id, Instrument voice, List<InkPoint> points) =>
        Stroke(id: id, instrument: voice, points: points);
    final strokes = <Stroke>[];
    if (kind == 0) {
      strokes.add(
        mark('original-template-v1', Instrument.mallet, [
          InkPoint(.08, .65),
          InkPoint(.25, .3),
          InkPoint(.42, .65),
          InkPoint(.6, .3),
          InkPoint(.78, .65),
          InkPoint(.92, .45),
        ]),
      );
    } else if (kind == 1) {
      strokes.add(
        mark('original-template-v1', Instrument.bell, [
          InkPoint(.15, .2),
          InkPoint(.15, .35),
          InkPoint(.35, .25),
          InkPoint(.35, .5),
          InkPoint(.6, .3),
          InkPoint(.6, .6),
          InkPoint(.85, .2),
          InkPoint(.85, .45),
        ]),
      );
    } else {
      final voice = Instrument.values[(kind - 2) % Instrument.values.length];
      final variation = kind ~/ 6;
      switch (kind % 6) {
        case 0:
          for (var i = 0; i < 6; i++) {
            strokes.add(
              mark('steps-$i', voice, [
                InkPoint(
                  .08 + i * .14,
                  .76 - variation * .03 - i * (.065 + variation * .01),
                ),
                InkPoint(
                  .17 + i * .14,
                  .76 - variation * .03 - i * (.065 + variation * .01),
                ),
              ]),
            );
          }
        case 1:
          for (var i = 0; i < 4; i++) {
            strokes.add(
              mark('chord-$i', voice, [
                InkPoint(
                  .12 + i * .23 + variation * .008,
                  .22 + variation * .025 + (i % 2) * .08,
                ),
                InkPoint(
                  .12 + i * .23 + variation * .008,
                  .72 - variation * .03,
                ),
              ]),
            );
          }
        case 2:
          strokes.add(
            mark('wave', voice, [
              for (var i = 0; i <= 80; i++)
                InkPoint(
                  .06 + .88 * i / 80,
                  .5 + .18 * math.sin(i / 80 * math.pi * (2 + kind ~/ 6)),
                ),
            ]),
          );
        case 3:
          for (var i = 0; i < 8; i++) {
            strokes.add(
              mark('dots-$i', voice, [
                InkPoint(
                  .08 + i * .12 + variation * .008,
                  .28 + variation * .03 + (i % 3) * (.09 + variation * .015),
                ),
              ]),
            );
          }
        case 4:
          strokes.add(
            mark('orbit', voice, [
              for (var i = 0; i <= 64; i++)
                InkPoint(
                  .5 +
                      (.28 + variation * .02) *
                          math.cos(i * math.pi / 32 + variation * .3),
                  .5 +
                      (.18 + variation * .025) *
                          math.sin(i * math.pi / 32 + variation * .3),
                ),
            ]),
          );
        case 5:
          for (var i = 0; i < 3; i++) {
            strokes.add(
              mark(
                'ribbon-$i',
                Instrument.values[(kind + i) % Instrument.values.length],
                [
                  for (var p = 0; p <= 24; p++)
                    InkPoint(
                      .08 + .84 * p / 24,
                      .28 +
                          i * .2 +
                          (.04 + variation * .01) *
                              math.sin(p / 24 * math.pi * (4 + variation)),
                    ),
                ],
              ),
            );
          }
      }
    }
    return ProjectDocument(
      id: newId(),
      title: title,
      strokes: strokes,
      mix: kind == 17 || kind == 19
          ? const AccompanimentMix()
                .withLayer(
                  AccompanimentLayer.drumKit,
                  const LayerMix(enabled: true, level: .35),
                )
                .withLayer(
                  AccompanimentLayer.bass,
                  const LayerMix(enabled: true, level: .4),
                )
          : const AccompanimentMix(),
      tempo: kind < 2 ? 120 : 88 + (kind * 7) % 73,
      root: RootKey.values[kind < 2 ? 0 : kind % 12],
      scale: kind < 2
          ? MusicalScale.major
          : MusicalScale.values[(kind - 2) % MusicalScale.values.length],
    );
  }
}

// Original normalized geometric compositions authored for this app. Descriptions
// are catalog metadata, never copied from reference artwork or musical recordings.
const originalTemplates = [
  OriginalTemplate(
    'template-hills',
    'Paper hills',
    'Two rising peaks on a mallet voice.',
    0,
  ),
  OriginalTemplate(
    'template-rain',
    'Little rain',
    'Falling bell lines form vertical chords.',
    1,
  ),
  OriginalTemplate(
    'template-tide',
    'Quiet tide',
    'A smooth keyboard wave explores pitch.',
    2,
  ),
  OriginalTemplate(
    'template-footsteps',
    'Small footsteps',
    'Eight isolated mallet dots make a rhythm.',
    3,
  ),
  OriginalTemplate(
    'template-orbit',
    'Green orbit',
    'A bell ellipse meets the scan twice.',
    4,
  ),
  OriginalTemplate(
    'template-ribbons',
    'Woven ribbons',
    'Three voices travel side by side.',
    5,
  ),
  OriginalTemplate(
    'template-staircase',
    'Amber staircase',
    'Ascending plucked steps leave breathing gaps.',
    6,
  ),
  OriginalTemplate(
    'template-lanterns',
    'Evening lanterns',
    'Four flute chords at spaced times.',
    7,
  ),
  OriginalTemplate(
    'template-breeze',
    'String breeze',
    'A broad string wave changes direction.',
    8,
  ),
  OriginalTemplate(
    'template-sparks',
    'Tiny sparks',
    'Separate chime dots make a short pattern.',
    9,
  ),
  OriginalTemplate(
    'template-moon',
    'Bass moon',
    'A low-voice ellipse is a beginner loop.',
    10,
  ),
  OriginalTemplate(
    'template-wires',
    'Bright wires',
    'Guitar, saxophone and keyboard ribbons interweave.',
    11,
  ),
  OriginalTemplate(
    'template-stones',
    'Stepping stones',
    'Electronic bass steps climb in thirds.',
    12,
  ),
  OriginalTemplate(
    'template-windows',
    'Open windows',
    'Guitar chords make four vertical windows.',
    13,
  ),
  OriginalTemplate(
    'template-river',
    'Sax river',
    'A saxophone wave meanders across the page.',
    14,
  ),
  OriginalTemplate(
    'template-beacons',
    'Soft beacons',
    'Keyboard dots leave generous silence.',
    15,
  ),
  OriginalTemplate(
    'template-halo',
    'Wooden halo',
    'A mallet ring demonstrates two pitch paths.',
    16,
  ),
  OriginalTemplate(
    'template-streams',
    'Three streams',
    'Three original voices trace parallel ribbons.',
    17,
  ),
  OriginalTemplate(
    'template-ascent',
    'Glass ascent',
    'Bell steps rise through the scale.',
    18,
  ),
  OriginalTemplate(
    'template-columns',
    'Warm columns',
    'Four synthesizer chords repeat calmly.',
    19,
  ),
];
OriginalTemplate templateById(String id) => originalTemplates.firstWhere(
  (t) => t.id == id,
  orElse: () => throw const FormatException('Unknown template'),
);

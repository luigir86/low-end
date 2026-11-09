import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/click_sound.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/walking_bass.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/songs/example_song.dart';

double _hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

Int16List _sine(double hz, int length) => Int16List.fromList([
  for (var i = 0; i < length; i++)
    (16000 * math.sin(2 * math.pi * hz * i / BassSamples.sampleRate)).round(),
]);

/// A double bass of pure tones: every take of every note a sine at its own
/// pitch, two seconds long, put out of tune as the recordings are so that
/// it comes out right.
BassSamples _sines() => BassSamples({
  for (final root in BassSamples.roots)
    root: {
      for (final MapEntry(key: layer, value: n) in BassSamples.takes.entries)
        layer: [
          for (var t = 0; t < n; t++)
            _sine(
              _hz(root) *
                  math.pow(2, BassSamples.tuning[root]![layer]![t] / 1200),
              BassSamples.sampleRate * 2,
            ),
        ],
    },
});

double _power(Float64List s, double hz, int from, int length) {
  var re = 0.0, im = 0.0;
  for (var i = from; i < from + length; i++) {
    final a = 2 * math.pi * hz * i / ClickSound.sampleRate;
    re += s[i] * math.cos(a);
    im += s[i] * math.sin(a);
  }
  return re * re + im * im;
}

/// The piano's chords of a progression in C, as Harmony plays them.
List<PianoChord> _chords(Progression p) => [
  for (final step in p.steps)
    [
      48 + step.offset,
      ...[
        for (final s in step.quality.semitones)
          60 + (step.offset + s - 60) % 12,
      ]..sort(),
    ],
];

void main() {
  final blues = _chords(Progression.blues);
  const four = TimeSignature.fourFour;

  group('the walking line', () {
    test('a note a beat, the root on the "one", within the range', () {
      final line = WalkingBass.line(blues, four);
      for (var bar = 0; bar < blues.length; bar++) {
        final notes = [
          for (final n in line)
            if (n.at >= bar * 4 && n.at < bar * 4 + 4) n,
        ];
        // The four beats, and the fills between them at most.
        for (var beat = 0; beat < 4; beat++) {
          expect(
            notes.where((n) => n.at == bar * 4 + beat),
            hasLength(1),
            reason: 'bar $bar, beat $beat',
          );
        }
        expect(notes.first.midi % 12, blues[bar].first % 12, reason: '$bar');
      }
      for (final n in line) {
        expect(n.midi, inInclusiveRange(WalkingBass.low, WalkingBass.high));
      }
    });

    test('leads into the next chord: its last note a step or a fifth away', () {
      final line = WalkingBass.line(blues, four);
      for (var bar = 0; bar < blues.length; bar++) {
        final next = line.firstWhere(
          (n) => n.at == ((bar + 1) % blues.length) * 4,
        );
        final last = line.lastWhere((n) => n.at < bar * 4 + 4);
        final gap = (next.midi - last.midi).abs();
        expect(gap, anyOf(1, 2, 5, 7), reason: 'bar $bar');
      }
    });

    test('goes somewhere: not the same pattern twice running', () {
      final line = WalkingBass.line(blues, four);
      final bars = [
        for (var bar = 0; bar < blues.length; bar++)
          [
            for (final n in line)
              if (n.at >= bar * 4 && n.at < bar * 4 + 4 && n.at % 1 == 0)
                n.midi - blues[bar].first % 12,
          ],
      ];
      var repeats = 0;
      for (var i = 1; i < bars.length; i++) {
        if (bars[i].toString() == bars[i - 1].toString()) repeats++;
      }
      expect(repeats, lessThan(2));
    });

    test('is the same every time, for the same chords', () {
      expect(
        WalkingBass.line(blues, four).toString(),
        WalkingBass.line(blues, four).toString(),
      );
    });

    test('fills mostly at the end of a four-bar phrase, and only a few', () {
      final line = WalkingBass.line(blues, four);
      final fills = line.where((n) => n.at % 1 != 0).length;
      expect(fills, lessThan(blues.length));
    });

    test('walks in every time signature, on the beats felt', () {
      expect(WalkingBass.beatsOf(TimeSignature.sixEight), [0, 3]);
      expect(WalkingBass.beatsOf(TimeSignature.sevenEight), [0, 2, 4]);
      expect(WalkingBass.beatsOf(TimeSignature.threeFour), [0, 1, 2]);
      expect(WalkingBass.beatsOf(TimeSignature.oneOne), [0]);
      for (final s in TimeSignature.all) {
        final line = WalkingBass.line(blues, s);
        final beats = WalkingBass.beatsOf(s);
        for (var bar = 0; bar < blues.length; bar++) {
          final first = line.firstWhere((n) => n.at == bar * s.beats);
          expect(first.midi % 12, blues[bar].first % 12, reason: '$s $bar');
        }
        expect(
          line.where((n) => n.at % 1 == 0).length,
          blues.length * beats.length,
          reason: '$s',
        );
        for (final n in line) {
          expect(n.at + n.length, lessThanOrEqualTo(blues.length * s.beats));
        }
      }
    });

    test('takes turns between the takes of a recording', () {
      final line = WalkingBass.line(blues, four);
      final seen = <(int, int), int>{};
      for (final n in line) {
        final key = (BassSamples.rootFor(n.midi), n.layer);
        expect(n.take, isNot(seen[key]), reason: '$n');
        seen[key] = n.take;
      }
    });
  });

  group('the comping', () {
    test('short chords above the root, the Charleston on each phrase', () {
      final comp = WalkingBass.comping(blues, four);
      for (final c in comp) {
        for (final m in c.notes) {
          expect(m, greaterThanOrEqualTo(60));
        }
        expect(c.length, lessThan(2.3));
      }
      for (final bar in [0, 4, 8]) {
        final chords = comp.where((c) => c.at >= bar * 4 && c.at < bar * 4 + 4);
        expect(chords.map((c) => c.at - bar * 4), [
          0,
          closeTo(1 + 2 / 3, 1e-9),
        ]);
      }
    });
  });

  group('the walking loop', () {
    final bass = _sines();
    final piano = PianoSamples.mono({
      for (final m in PianoSamples.roots)
        m: Float32List(PianoSamples.sampleRate),
    });
    final samples = PianoSamples(piano.notes, bass: bass);

    test('the double bass plays the line, in tune', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: blues,
        style: PianoStyle.walking,
        bpm: 60,
        signature: four,
      );
      const beat = ClickSound.sampleRate;
      expect(loop.length, beat * 4 * blues.length);
      final line = WalkingBass.line(blues, four);
      // Each beat of the first bar: its own note, not a quarter tone off.
      for (final n in line.where((n) => n.at < 4 && n.at % 1 == 0)) {
        final from = (n.at * beat).round() + beat ~/ 10;
        const window = 24000;
        final right = _power(loop, _hz(n.midi), from, window);
        final off = _power(
          loop,
          _hz(n.midi) * math.pow(2, 0.5 / 12),
          from,
          window,
        );
        expect(right, greaterThan(off * 4), reason: '$n');
      }
    });

    test('a single chord is walked over four bars', () {
      expect(
        PianoSound.barsOf(
          const [
            [48, 64, 67],
          ],
          PianoStyle.walking,
          four,
        ),
        hasLength(4),
      );
    });

    test('without the double bass, the piano comps alone', () {
      final loop = PianoSound.loop(
        samples: PianoSamples.mono({
          for (final m in PianoSamples.roots)
            m: Float32List.fromList([
              for (var i = 0; i < PianoSamples.sampleRate; i++)
                0.5 *
                    math.sin(
                      2 * math.pi * _hz(m) * i / PianoSamples.sampleRate,
                    ),
            ]),
        }),
        chords: blues,
        style: PianoStyle.walking,
        bpm: 120,
        signature: four,
      );
      expect(loop.any((v) => v != 0), isTrue);
    });
  });

  group('the recordings', () {
    test('every take of the double bass is shipped, and they stay small', () {
      var bytes = 0;
      for (final (root, layer, take) in BassSamples.all) {
        final file = File(BassSamples.assetOf(root, layer, take));
        expect(file.existsSync(), isTrue, reason: file.path);
        bytes += file.lengthSync();
        expect(
          BassSamples.tuning[root]![layer],
          hasLength(greaterThanOrEqualTo(take)),
        );
      }
      expect(bytes, lessThan(4 * 1024 * 1024));
    });

    test('the line never needs a note the recordings do not cover', () {
      for (var m = WalkingBass.low; m <= WalkingBass.high; m++) {
        expect((BassSamples.rootFor(m) - m).abs(), lessThanOrEqualTo(1));
      }
    });
  });

  group('Harmony', () {
    test('the walking bass plays the double bass, got ready ahead', () async {
      final tone = SilentToneOutput();
      final piano = SilentPianoOutput();
      final drone = DroneController(tone, piano: piano);
      drone.setVoicing(DroneVoicing.progression);
      drone.setStyle(DroneStyle.walking);
      drone.preparePiano();
      await Future<void>.delayed(Duration.zero);
      expect(piano.preparedBass, isTrue);
      await drone.tapNote(0);
      expect(piano.style, PianoStyle.walking);
      drone.dispose();
    });

    group('example songs', () {
      ExampleSong song(String title) =>
          exampleSongs.singleWhere((s) => s.title == title);
      late DroneController drone;
      late MetronomeController metronome;
      setUp(() {
        drone = DroneController(SilentToneOutput(), piano: SilentPianoOutput());
        metronome = MetronomeController(SilentClickOutput());
      });
      tearDown(() {
        drone.dispose();
        metronome.dispose();
      });
      void apply(String title) =>
          applySong(song(title), drone: drone, metronome: metronome);

      test('each song sets its style: the jazz standards walked, the bossa '
          'arpeggiated, the slow anthem held, the rest on every beat', () {
        expect(
          {for (final s in exampleSongs) s.title: s.style},
          {
            'Stand by Me': DroneStyle.beat,
            'With or Without You': DroneStyle.held,
            'Hit the Road Jack': DroneStyle.beat,
            'Sweet Home Chicago': DroneStyle.beat,
            'Mr. P.C.': DroneStyle.walking,
            'Tune Up': DroneStyle.walking,
            'Blue Bossa': DroneStyle.arpeggio,
            'I Got Rhythm': DroneStyle.walking,
            'Autumn Leaves': DroneStyle.walking,
          },
        );
      });

      test('a song is a preset: its style and tempo, whatever was set', () {
        drone.setStyle(DroneStyle.arpeggio);
        metronome.setBpm(60);
        apply('Tune Up');
        expect(drone.style, DroneStyle.walking);
        expect(metronome.bpm, 120);
        apply('Stand by Me');
        expect(drone.style, DroneStyle.beat);
        expect(metronome.bpm, 118);
        // A style chosen afterwards is the player's, until the next song.
        drone.setStyle(DroneStyle.held);
        apply('Blue Bossa');
        expect(drone.style, DroneStyle.arpeggio);
      });

      test('I Got Rhythm is the Anatole in B♭, one chord a bar in 2/4, '
          'and the next song gives back 4/4', () {
        metronome.setSignature(TimeSignature.threeFour);
        apply('I Got Rhythm');
        expect(drone.note.pitchClass, 10);
        expect(drone.progression, Progression.oneSixTwoFive);
        expect(drone.style, DroneStyle.walking);
        expect(metronome.signature, TimeSignature.twoFour);
        expect(metronome.bpm, 120);
        apply('Tune Up');
        expect(metronome.signature, TimeSignature.fourFour);
      });

      test('in 2/4 the walking bass plays two notes a chord, the root '
          'on the one', () {
        final chords = _chords(Progression.oneSixTwoFive);
        final line = WalkingBass.line(chords, TimeSignature.twoFour);
        for (var bar = 0; bar < chords.length; bar++) {
          final notes = [
            for (final n in line)
              if (n.at >= bar * 2 && n.at < bar * 2 + 2) n,
          ];
          for (var beat = 0; beat < 2; beat++) {
            expect(
              notes.where((n) => n.at == bar * 2 + beat),
              hasLength(1),
              reason: 'bar $bar, beat $beat',
            );
          }
          expect(notes.first.midi % 12, chords[bar].first % 12);
        }
        for (final n in line) {
          expect(n.midi, inInclusiveRange(WalkingBass.low, WalkingBass.high));
        }
      });

      test('a song brings the piano back from the held tone', () {
        drone.setContinuous(true);
        apply('Autumn Leaves');
        expect(drone.continuous, isFalse);
        expect(drone.usesPiano, isTrue);
        expect(drone.style, DroneStyle.walking);
      });

      test('the double bass can be got ready before a song', () async {
        final piano = SilentPianoOutput();
        final d = DroneController(SilentToneOutput(), piano: piano);
        d.prepareBass();
        await Future<void>.delayed(Duration.zero);
        expect(piano.preparedBass, isTrue);
        d.dispose();
      });
    });
  });
}

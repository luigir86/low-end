import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/subdivision.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/tuner/drone/drone_controller.dart';
import 'package:low_end/features/tuner/drone/example_song.dart';
import 'package:low_end/features/tuner/drone/harmony.dart';

void main() {
  group('changing song while it plays', () {
    testWidgets('the old song stops, then one loop starts for the new one', (
      tester,
    ) async {
      final piano = _LoggingPiano();
      final metronome = MetronomeController(SilentClickOutput());
      final drone = DroneController(
        SilentToneOutput(),
        piano: piano,
        clock: metronome,
      );
      ExampleSong song(String title) =>
          exampleSongs.singleWhere((s) => s.title == title);
      applySong(song('Autumn Leaves'), drone: drone, metronome: metronome);
      drone.start();
      await tester.pump(const Duration(seconds: 3));
      expect(piano.log, ['play walking 120']);
      piano.log.clear();

      applySong(song('Stand by Me'), drone: drone, metronome: metronome);
      // Not heard yet: the chords wait on the first one, the wait shown.
      await tester.pump(const Duration(milliseconds: 100));
      expect(drone.isPlaying, isTrue);
      expect(drone.isStarting, isTrue);
      expect(drone.step, 0);
      await tester.pump(const Duration(seconds: 1));
      // Only the new song, at its own tempo, after the old one stopped.
      expect(piano.log, ['stop', 'play beat 118 patient']);
      expect(drone.isStarting, isFalse);

      drone.stop();
      await tester.pump(const Duration(seconds: 1));
      drone.dispose();
      metronome.dispose();
    });

    test('not playing, a song plays nothing', () async {
      final piano = _LoggingPiano();
      final metronome = MetronomeController(SilentClickOutput());
      final drone = DroneController(
        SilentToneOutput(),
        piano: piano,
        clock: metronome,
      );
      addTearDown(drone.dispose);
      addTearDown(metronome.dispose);
      applySong(exampleSongs.first, drone: drone, metronome: metronome);
      await Future<void>.delayed(Duration.zero);
      expect(piano.log, isEmpty);
      expect(drone.isPlaying, isFalse);
    });
  });

  group('a song is a whole preset, as an object', () {
    test('every example song reads back the same from JSON', () {
      for (final song in exampleSongs) {
        final back = ExampleSong.fromJson(song.toJson());
        expect(back.toJson(), song.toJson(), reason: song.title);
        expect(back.signature, same(song.signature), reason: song.title);
      }
    });

    test('the JSON uses the names of the actions', () {
      final tuneUp = exampleSongs.singleWhere((s) => s.title == 'Tune Up');
      expect(tuneUp.toJson(), {
        'title': 'Tune Up',
        'artist': 'Miles Davis',
        'key': 2,
        'progression': 'twoFiveOne',
        'bpm': 160,
        'style': 'walking',
        'signature': '4/4',
      });
    });

    test('a song made elsewhere can carry its metronome settings', () {
      final waltz = ExampleSong.fromJson({
        'title': 'My waltz',
        'key': 7,
        'progression': 'blues',
        'bpm': 90,
        'style': 'arpeggio',
        'signature': '3/4',
        'subdivision': 'swing_eighths',
        'backbeat': false,
      });
      expect(waltz.artist, '');
      expect(waltz.signature, TimeSignature.threeFour);
      expect(waltz.subdivision, Subdivision.swungEighths);
      expect(ExampleSong.fromJson(waltz.toJson()).toJson(), waltz.toJson());

      final drone = DroneController(
        SilentToneOutput(),
        piano: SilentPianoOutput(),
      );
      final metronome = MetronomeController(SilentClickOutput());
      addTearDown(drone.dispose);
      addTearDown(metronome.dispose);
      metronome.setBackbeat(true);
      applySong(waltz, drone: drone, metronome: metronome);
      expect(metronome.signature, TimeSignature.threeFour);
      expect(metronome.bpm, 90);
      expect(metronome.subdivision, Subdivision.swungEighths);
      expect(metronome.backbeat, isFalse);
      expect(drone.style, DroneStyle.arpeggio);
      expect(drone.note.pitchClass, 7);

      // A song without them leaves the player's.
      metronome.setBackbeat(true);
      applySong(exampleSongs.first, drone: drone, metronome: metronome);
      expect(metronome.subdivision, Subdivision.swungEighths);
      expect(metronome.backbeat, isTrue);
      expect(metronome.signature, TimeSignature.fourFour);
    });

    test('a wrong song says which field is wrong', () {
      final good = exampleSongs.first.toJson();
      for (final (field, value) in [
        ('title', null),
        ('key', 12),
        ('key', 'A'),
        ('bpm', 0),
        ('progression', 'nope'),
        ('style', 'tone'),
        ('signature', '4/3'),
        ('subdivision', 'eighths!'),
        ('backbeat', 'yes'),
      ]) {
        expect(
          () => ExampleSong.fromJson({...good, field: value}),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('"$field"'),
            ),
          ),
          reason: '$field = $value',
        );
      }
    });
  });
}

/// A piano that notes what it is asked to do, and takes a while to get each
/// loop ready, as rendering does.
class _LoggingPiano extends SilentPianoOutput {
  final log = <String>[];

  @override
  Future<LoopStart> play({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
    required double volume,
    Duration? startAt,
    bool onTheBeat = false,
    bool patient = false,
  }) async {
    log.add('play ${style.name} $bpm${patient ? ' patient' : ''}');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return super.play(
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
      volume: volume,
      startAt: startAt,
      onTheBeat: onTheBeat,
    );
  }

  @override
  Future<void> stop() {
    log.add('stop');
    return super.stop();
  }
}

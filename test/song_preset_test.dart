import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/subdivision.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/tuner/drone/drone_controller.dart';
import 'package:low_end/features/tuner/drone/example_song.dart';
import 'package:low_end/features/tuner/drone/harmony.dart';

void main() {
  group('a song is a whole preset, as an object', () {
    test('every example song reads back the same from JSON', () {
      for (final song in exampleSongs) {
        final back = ExampleSong.fromJson(song.toJson());
        expect(back.toJson(), song.toJson(), reason: song.title);
        expect(back.signature, same(TimeSignature.fourFour));
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

// What the Player keeps between launches (RF-PLY-13): written as JSON and
// read back without ever failing.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/player_setup.dart';

const _track = TrackRef(
  uri: 'content://song',
  name: 'Blue Bossa.mp3',
  size: 99,
);

Map<String, Object?> _json({Map<String, Object?> change = const {}}) => {
  'uri': 'content://song',
  'name': 'Blue Bossa.mp3',
  'size': 99,
  'duration': 300000,
  'speed': 80,
  'start': 60000,
  'end': 90000,
  'looping': true,
  'title': 'Blue Bossa',
  'artist': 'Kenny Dorham',
  ...change,
};

void main() {
  test('goes through JSON and comes back the same', () {
    const setup = PlayerSetup(
      track: _track,
      duration: Duration(minutes: 5),
      speed: 80,
      loopStart: Duration(seconds: 60),
      loopEnd: Duration(seconds: 90),
      looping: true,
      title: 'Blue Bossa',
      artist: 'Kenny Dorham',
    );
    final back = PlayerSetup.fromJson(jsonDecode(jsonEncode(setup.toJson())))!;
    expect(back.track, _track);
    expect(back.track.size, 99);
    expect(back.duration, const Duration(minutes: 5));
    expect(back.speed, 80);
    expect(back.loopStart, const Duration(seconds: 60));
    expect(back.loopEnd, const Duration(seconds: 90));
    expect(back.looping, isTrue);
    expect(back.title, 'Blue Bossa');
    expect(back.artist, 'Kenny Dorham');
    expect(back.toJson(), setup.toJson());
  });

  test('what is not marked is not written', () {
    const setup = PlayerSetup(track: _track, duration: Duration(minutes: 5));
    final json = setup.toJson();
    expect(json.containsKey('start'), isFalse);
    expect(json.containsKey('end'), isFalse);
    expect(json.containsKey('title'), isFalse);
    expect(json['looping'], false);
  });

  group('reading what is wrong', () {
    test('no track, nothing', () {
      expect(PlayerSetup.fromJson(null), isNull);
      expect(PlayerSetup.fromJson('text'), isNull);
      expect(PlayerSetup.fromJson(<String, Object?>{}), isNull);
      expect(PlayerSetup.fromJson(_json(change: {'uri': ''})), isNull);
      expect(PlayerSetup.fromJson(_json(change: {'uri': 7})), isNull);
      expect(PlayerSetup.fromJson(_json(change: {'name': null})), isNull);
    });

    test('a length that is no use, nothing', () {
      expect(PlayerSetup.fromJson(_json(change: {'duration': 0})), isNull);
      expect(PlayerSetup.fromJson(_json(change: {'duration': -5})), isNull);
      expect(PlayerSetup.fromJson(_json(change: {'duration': 'long'})), isNull);
      expect(PlayerSetup.fromJson(_json(change: {'duration': null})), isNull);
    });

    test('a wrong speed is 100, one out of range is kept in range', () {
      expect(
        PlayerSetup.fromJson(_json(change: {'speed': 'fast'}))!.speed,
        100,
      );
      expect(PlayerSetup.fromJson(_json(change: {'speed': 3}))!.speed, 50);
      expect(PlayerSetup.fromJson(_json(change: {'speed': 900}))!.speed, 125);
    });

    test('ends outside the track, or the wrong way round, are no passage', () {
      var s = PlayerSetup.fromJson(_json(change: {'end': 999999}))!;
      expect(s.loopEnd, isNull);
      expect(s.loopStart, const Duration(seconds: 60));
      expect(s.looping, isFalse);
      s = PlayerSetup.fromJson(_json(change: {'start': 100000, 'end': 50000}))!;
      expect(s.loopStart, isNull);
      expect(s.loopEnd, isNull);
      s = PlayerSetup.fromJson(_json(change: {'start': -4}))!;
      expect(s.loopStart, isNull);
      expect(s.looping, isFalse);
    });

    test('a loop on needs both ends', () {
      final s = PlayerSetup.fromJson(
        _json(change: {'end': null, 'looping': true}),
      )!;
      expect(s.looping, isFalse);
      expect(
        PlayerSetup.fromJson(_json(change: {'looping': 'yes'}))!.looping,
        isFalse,
      );
    });

    test('empty or wrong tags are none', () {
      var s = PlayerSetup.fromJson(
        _json(change: {'title': '  ', 'artist': 4}),
      )!;
      expect(s.title, isNull);
      expect(s.artist, isNull);
      s = PlayerSetup.fromJson(_json(change: {'title': null}))!;
      expect(s.title, isNull);
    });

    test('a size that is not a number is left out', () {
      final s = PlayerSetup.fromJson(_json(change: {'size': 'big'}))!;
      expect(s.track.size, isNull);
    });
  });
}

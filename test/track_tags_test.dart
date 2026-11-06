// The title and the artist of an MP3, read from its ID3v2 tag (RF-PLY-14),
// with tags built here byte by byte.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/player/track_tags.dart';

List<int> _syncsafe(int n) => [
  (n >> 21) & 0x7F,
  (n >> 14) & 0x7F,
  (n >> 7) & 0x7F,
  n & 0x7F,
];

List<int> _plain(int n) => [
  (n >> 24) & 0xFF,
  (n >> 16) & 0xFF,
  (n >> 8) & 0xFF,
  n & 0xFF,
];

/// A frame: its id, its size (syncsafe in 2.4), two bytes of flags, the body.
List<int> _frame(String id, List<int> body, {int version = 3, int flags = 0}) =>
    [
      ...ascii.encode(id),
      ...(version == 4 ? _syncsafe(body.length) : _plain(body.length)),
      0,
      flags,
      ...body,
    ];

List<int> _latin1(String text) => [0, ...latin1.encode(text)];
List<int> _utf8(String text) => [3, ...utf8.encode(text)];
List<int> _utf16(String text, {bool big = false}) => [
  1,
  if (big) ...[0xFE, 0xFF] else ...[0xFF, 0xFE],
  for (final unit in text.codeUnits)
    if (big) ...[unit >> 8, unit & 0xFF] else ...[unit & 0xFF, unit >> 8],
];
List<int> _utf16NoBom(String text) => [
  2,
  for (final unit in text.codeUnits) ...[unit >> 8, unit & 0xFF],
];

/// A whole tag with [frames], then [padding] zeros, then audio-like bytes.
Uint8List _tag(
  List<List<int>> frames, {
  int version = 3,
  int flags = 0,
  List<int> extended = const [],
  int padding = 0,
}) {
  final body = [
    ...extended,
    for (final f in frames) ...f,
    ...List.filled(padding, 0),
  ];
  return Uint8List.fromList([
    ...ascii.encode('ID3'),
    version,
    0,
    flags,
    ..._syncsafe(body.length),
    ...body,
    0xFF, 0xFB, 0x90, 0x00, // the start of the audio
  ]);
}

void main() {
  group('version 2.3', () {
    test('Latin-1 title and artist', () {
      final tags = readId3Tags(
        _tag([
          _frame('TIT2', _latin1('Blue Bossa')),
          _frame('TPE1', _latin1('Kenny Dorham')),
        ]),
      );
      expect(tags.title, 'Blue Bossa');
      expect(tags.artist, 'Kenny Dorham');
    });

    test('accents in Latin-1', () {
      final tags = readId3Tags(_tag([_frame('TIT2', _latin1('Café Mélodie'))]));
      expect(tags.title, 'Café Mélodie');
    });

    test('UTF-16 with a byte order mark, either way', () {
      final tags = readId3Tags(
        _tag([
          _frame('TIT2', _utf16('Così è')),
          _frame('TPE1', _utf16('Mina', big: true)),
        ]),
      );
      expect(tags.title, 'Così è');
      expect(tags.artist, 'Mina');
    });

    test('UTF-16 without a byte order mark is big endian', () {
      expect(
        readId3Tags(_tag([_frame('TIT2', _utf16NoBom('Ñandú'))])).title,
        'Ñandú',
      );
    });

    test('frames in any order, others skipped', () {
      final tags = readId3Tags(
        _tag([
          _frame('TALB', _latin1('Album')),
          _frame('TPE1', _latin1('Artist')),
          _frame('TYER', _latin1('1963')),
          _frame('TIT2', _latin1('Title')),
        ]),
      );
      expect(tags.title, 'Title');
      expect(tags.artist, 'Artist');
    });

    test('only one of them is enough, the other is null', () {
      final tags = readId3Tags(_tag([_frame('TPE1', _latin1('Artist'))]));
      expect(tags.title, isNull);
      expect(tags.artist, 'Artist');
    });

    test('padding after the frames ends the search', () {
      final tags = readId3Tags(
        _tag([_frame('TIT2', _latin1('Title'))], padding: 40),
      );
      expect(tags.title, 'Title');
      expect(tags.artist, isNull);
    });

    test('an extended header is skipped', () {
      // Size field (not counting itself), flags, padding size.
      final extended = [..._plain(6), 0, 0, 0, 0, 0, 0];
      final tags = readId3Tags(
        _tag(
          [_frame('TIT2', _latin1('Title'))],
          flags: 0x40,
          extended: extended,
        ),
      );
      expect(tags.title, 'Title');
    });

    test('a compressed frame is skipped', () {
      final tags = readId3Tags(
        _tag([
          _frame('TIT2', _latin1('Packed'), flags: 0x80),
          _frame('TPE1', _latin1('Artist')),
        ]),
      );
      expect(tags.title, isNull);
      expect(tags.artist, 'Artist');
    });
  });

  group('version 2.4', () {
    test('UTF-8 text, sizes as syncsafe numbers', () {
      // 200 bytes of body: the size does not fit in seven bits.
      final long = 'Così ' * 40;
      final tags = readId3Tags(
        _tag([
          _frame('TIT2', _utf8(long), version: 4),
          _frame('TPE1', _utf8('Mina'), version: 4),
        ], version: 4),
      );
      expect(tags.title, long.trim());
      expect(tags.artist, 'Mina');
    });

    test('an extended header is skipped by its syncsafe size', () {
      final extended = [..._syncsafe(6), 1, 0];
      final tags = readId3Tags(
        _tag(
          [_frame('TIT2', _utf8('Title'), version: 4)],
          version: 4,
          flags: 0x40,
          extended: extended,
        ),
      );
      expect(tags.title, 'Title');
    });

    test('an unsynchronised frame is skipped', () {
      final tags = readId3Tags(
        _tag([
          _frame('TIT2', _utf8('Odd'), version: 4, flags: 0x02),
          _frame('TPE1', _utf8('Artist'), version: 4),
        ], version: 4),
      );
      expect(tags.title, isNull);
      expect(tags.artist, 'Artist');
    });
  });

  group('text', () {
    test('several values: the first', () {
      final tags = readId3Tags(
        _tag([
          _frame('TPE1', [
            0,
            ...latin1.encode('One'),
            0,
            ...latin1.encode('Two'),
          ]),
        ]),
      );
      expect(tags.artist, 'One');
    });

    test('spaces around are trimmed, nothing is nothing', () {
      expect(
        readId3Tags(_tag([_frame('TIT2', _latin1('  Hi  '))])).title,
        'Hi',
      );
      expect(readId3Tags(_tag([_frame('TIT2', _latin1('   '))])).title, isNull);
      expect(
        readId3Tags(
          _tag([
            _frame('TIT2', [0]),
          ]),
        ).title,
        isNull,
      );
    });

    test('an encoding that does not exist is skipped', () {
      expect(
        readId3Tags(
          _tag([
            _frame('TIT2', [9, 65, 66]),
          ]),
        ).title,
        isNull,
      );
    });
  });

  group('what is no use gives no tags and no error', () {
    const none = (title: null, artist: null);

    test('no tag, a short file, an empty one', () {
      expect(readId3Tags(Uint8List(0)), none);
      expect(readId3Tags(Uint8List.fromList([1, 2, 3])), none);
      expect(readId3Tags(Uint8List.fromList(List.filled(100, 0xFF))), none);
    });

    test('a version that is not 2.3 or 2.4', () {
      expect(
        readId3Tags(_tag([_frame('TIT2', _latin1('X'))], version: 2)),
        none,
      );
      expect(
        readId3Tags(_tag([_frame('TIT2', _latin1('X'))], version: 5)),
        none,
      );
    });

    test('a tag written with unsynchronisation is given up', () {
      expect(
        readId3Tags(_tag([_frame('TIT2', _latin1('X'))], flags: 0x80)),
        none,
      );
    });

    test('a frame that says it is longer than the tag', () {
      final bad = Uint8List.fromList([
        ...ascii.encode('ID3'),
        3,
        0,
        0,
        ..._syncsafe(20),
        ...ascii.encode('TIT2'),
        ..._plain(900),
        0,
        0,
        0,
        65,
        ...List.filled(5, 0),
      ]);
      expect(readId3Tags(bad), none);
    });

    test('a tag cut short in the file', () {
      final whole = _tag([_frame('TIT2', _latin1('A long enough title'))]);
      final cut = Uint8List.sublistView(whole, 0, 20);
      expect(readId3Tags(cut), none);
    });

    test('a tag whose size is far beyond the bytes given', () {
      final head = Uint8List.fromList([
        ...ascii.encode('ID3'),
        3,
        0,
        0,
        ..._syncsafe(5000000),
        ..._frame('TIT2', _latin1('Still found')),
      ]);
      expect(readId3Tags(head).title, 'Still found');
    });

    test('noise after ID3 is not an error', () {
      final noise = Uint8List.fromList([
        ...ascii.encode('ID3'),
        3,
        0,
        0,
        0,
        0,
        0,
        40,
        for (var i = 0; i < 60; i++) (i * 37) & 0xFF,
      ]);
      expect(() => readId3Tags(noise), returnsNormally);
    });
  });
}

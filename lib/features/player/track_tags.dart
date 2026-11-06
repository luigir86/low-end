import 'dart:convert';
import 'dart:typed_data';

import '../../audio/track_files.dart';

/// The title and the artist in the ID3v2 tag at the start of an MP3 (what a
/// browser cannot tell us: Android reads every format through the system).
/// [head] is the first bytes of the file, 128 KB are enough. Versions 2.3 and
/// 2.4; a tag written with unsynchronisation is given up; anything strange
/// gives no tags and never an error (RF-PLY-14).
TrackTags readId3Tags(Uint8List head) {
  const none = (title: null, artist: null);
  try {
    if (head.length < 10 ||
        head[0] != 0x49 || // I
        head[1] != 0x44 || // D
        head[2] != 0x33) {
      // 3
      return none;
    }
    final version = head[3];
    if (version != 3 && version != 4) return none;
    final flags = head[5];
    // Unsynchronisation of the whole tag: not undone here.
    if (flags & 0x80 != 0) return none;
    final end = (10 + _syncsafe(head, 6)).clamp(10, head.length);
    var at = 10;
    // The extended header is skipped.
    if (flags & 0x40 != 0) {
      if (at + 4 > end) return none;
      final size = version == 4 ? _syncsafe(head, at) : _plain(head, at) + 4;
      at += size;
    }
    String? title, artist;
    while (at + 10 <= end && (title == null || artist == null)) {
      final id = String.fromCharCodes(head.sublist(at, at + 4));
      // Padding: no more frames.
      if (head[at] == 0) break;
      final size = version == 4
          ? _syncsafe(head, at + 4)
          : _plain(head, at + 4);
      final frameFlags = head[at + 9];
      final body = at + 10;
      if (size <= 0 || body + size > end) break;
      // A frame that is compressed, encrypted or unsynchronised is skipped
      // (the format flags: 2.3 has compression and encryption in the top
      // bits, 2.4 in the low ones).
      final skipped = version == 4
          ? frameFlags & 0x0E != 0
          : frameFlags & 0xC0 != 0;
      if (!skipped) {
        if (id == 'TIT2') title ??= _text(head, body, size);
        if (id == 'TPE1') artist ??= _text(head, body, size);
      }
      at = body + size;
    }
    return (title: title, artist: artist);
  } on Object {
    return none;
  }
}

int _syncsafe(Uint8List b, int at) =>
    (b[at] & 0x7F) << 21 |
    (b[at + 1] & 0x7F) << 14 |
    (b[at + 2] & 0x7F) << 7 |
    (b[at + 3] & 0x7F);

int _plain(Uint8List b, int at) =>
    b[at] << 24 | b[at + 1] << 16 | b[at + 2] << 8 | b[at + 3];

/// The text of a text frame: the first byte says how it is written.
String? _text(Uint8List b, int at, int size) {
  if (size < 2) return null;
  final encoding = b[at];
  final data = b.sublist(at + 1, at + size);
  String text;
  switch (encoding) {
    case 0:
      text = latin1.decode(data, allowInvalid: true);
    case 1:
      text = _utf16(data);
    case 2:
      text = _utf16(data, bigEndian: true, bom: false);
    case 3:
      text = utf8.decode(data, allowMalformed: true);
    default:
      return null;
  }
  // Several values are separated by a zero; the first is the one shown.
  final zero = text.indexOf('\u0000');
  if (zero >= 0) text = text.substring(0, zero);
  text = text.trim();
  return text.isEmpty ? null : text;
}

/// UTF-16 with a byte order mark (or without, when [bom] is false).
String _utf16(Uint8List data, {bool bigEndian = false, bool bom = true}) {
  var start = 0;
  var big = bigEndian;
  if (bom && data.length >= 2) {
    if (data[0] == 0xFF && data[1] == 0xFE) {
      big = false;
      start = 2;
    } else if (data[0] == 0xFE && data[1] == 0xFF) {
      big = true;
      start = 2;
    }
  }
  final units = <int>[];
  for (var i = start; i + 1 < data.length; i += 2) {
    units.add(big ? data[i] << 8 | data[i + 1] : data[i + 1] << 8 | data[i]);
  }
  return String.fromCharCodes(units);
}

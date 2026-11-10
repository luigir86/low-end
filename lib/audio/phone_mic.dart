/// The phone's own microphone in the web app, so that a Bluetooth headset
/// with a microphone is never asked for it (RF-ACC-10).
///
/// A browser listening to the headset's microphone puts it in call mode:
/// both ways in call quality, and in Chrome and Edge on Android the app's
/// sound could stay so until the browser was closed. The Android app picks
/// the phone's microphone through the record package (manageBluetooth off);
/// a web page can only name the microphone it wants, by the list the
/// browser gives (names known once the microphone has been allowed).
library;

import 'package:record/record.dart';

export 'phone_mic_stub.dart' if (dart.library.js_interop) 'phone_mic_web.dart';

/// Names of a Bluetooth microphone, in the browsers' lists: Chrome and Edge
/// on Android call it "Bluetooth headset", others give the headset's name.
final _bluetooth = RegExp(
  r'bluetooth|\bbt\b|\bsco\b|hands-?free|airpods|buds|\bhfp\b',
  caseSensitive: false,
);

/// Names of the phone's own microphone: Chrome on Android ("Speakerphone",
/// "Headset earpiece", both the phone's microphone), Safari ("iPhone
/// Microphone"), and the usual words for a built-in one.
final _phone = RegExp(
  r'speakerphone|earpiece|built-?in|internal|iphone|ipad|\bphone\b|'
  r'bottom|front|back|telefono|teléfono|téléphone',
  caseSensitive: false,
);

/// The microphone to ask for among [inputs]: the phone's own when a
/// Bluetooth one is also there, else null (the browser's choice, which is
/// right without a headset, and with a wired one). Shown to the tests.
InputDevice? choosePhoneMic(List<InputDevice> inputs) {
  final real = [
    for (final input in inputs)
      if (input.id.isNotEmpty &&
          input.id != 'default' &&
          input.id != 'communications' &&
          input.label.isNotEmpty)
        input,
  ];
  bool bluetooth(InputDevice input) => _bluetooth.hasMatch(input.label);
  if (!real.any(bluetooth)) return null;
  final others = real.where((input) => !bluetooth(input)).toList();
  for (final input in others) {
    if (_phone.hasMatch(input.label)) return input;
  }
  // Only one other microphone besides the headset: the phone's.
  return others.length == 1 ? others.single : null;
}

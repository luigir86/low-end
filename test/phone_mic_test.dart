// The phone's microphone chosen in the web app when a Bluetooth headset with
// a microphone is there (RF-ACC-10): the names browsers give.

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/phone_mic.dart';
import 'package:record/record.dart';

InputDevice _mic(String id, String label) => InputDevice(id: id, label: label);

void main() {
  test('Chrome and Edge on Android: the speakerphone, not the headset', () {
    final chosen = choosePhoneMic([
      _mic('default', 'Default'),
      _mic('a', 'Speakerphone'),
      _mic('b', 'Headset earpiece'),
      _mic('c', 'Bluetooth headset'),
    ]);
    expect(chosen?.id, 'a');
  });

  test('Safari on the iPhone: the iPhone microphone, not the AirPods', () {
    final chosen = choosePhoneMic([
      _mic('x', 'AirPods Pro'),
      _mic('y', 'iPhone Microphone'),
    ]);
    expect(chosen?.id, 'y');
  });

  test('a headset named by its brand and one other microphone', () {
    final chosen = choosePhoneMic([
      _mic('default', 'Default'),
      _mic('h', 'Sennheiser BT 4.40'),
      _mic('p', 'SM-G781B'),
    ]);
    expect(chosen?.id, 'p');
  });

  test('without a Bluetooth microphone the browser chooses', () {
    expect(
      choosePhoneMic([_mic('a', 'Speakerphone'), _mic('w', 'Wired headset')]),
      isNull,
    );
    // Names unknown until the microphone is allowed.
    expect(choosePhoneMic([_mic('', ''), _mic('', '')]), isNull);
    expect(choosePhoneMic([]), isNull);
  });

  test('a headset and no way to tell the phone among several leaves the '
      'browser to choose', () {
    expect(
      choosePhoneMic([
        _mic('h', 'Bluetooth headset'),
        _mic('1', 'Microphone 1'),
        _mic('2', 'Microphone 2'),
      ]),
      isNull,
    );
  });
}

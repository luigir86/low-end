import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web/web.dart' as web;

import 'phone_mic.dart';

/// See phone_mic.dart. The list is read without opening a microphone (that
/// alone would wake the headset's): before the microphone is first allowed
/// the names are empty and the browser chooses.
Future<InputDevice?> phoneMic() async {
  try {
    final devices = await web.window.navigator.mediaDevices
        .enumerateDevices()
        .toDart;
    final inputs = [
      for (final device in devices.toDart)
        if (device.kind == 'audioinput')
          InputDevice(id: device.deviceId, label: device.label),
    ];
    final chosen = choosePhoneMic(inputs);
    debugPrint(
      'Microphones: ${inputs.map((i) => i.label).join(', ')}; '
      'chosen: ${chosen?.label ?? 'the browser\'s'}',
    );
    return chosen;
  } catch (error) {
    debugPrint('The microphones could not be listed: $error');
    return null;
  }
}

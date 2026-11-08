import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'recorded_track.dart';
import 'system_track_files.dart' as system;
import 'web_audio_session.dart';

/// Records a take from the microphone into a temporary file (RF-PLY-20).
///
/// Kept behind an interface, like [MicInput], so that the Player's recording
/// can be tested without a microphone.
abstract class TakeRecorder {
  /// Asks for microphone access if needed; returns whether it was granted.
  Future<bool> requestPermission();

  /// Starts recording a take called [name] (with its extension).
  Future<void> start(String name);

  /// Stops and returns the take, ready for the Player.
  Future<RecordedTrack> stop();

  /// Stops and throws the take away.
  Future<void> cancel();

  /// The file extension of a take: compressed on Android, WAV on the web.
  String get extension;

  Future<void> dispose();
}

/// [TakeRecorder] backed by the record package: AAC in an .m4a file on
/// Android (TakeFiles.kt keeps it in the app's cache), WAV in a blob on the
/// web.
class RecordTakeRecorder implements TakeRecorder {
  AudioRecorder? _recorder;
  String? _name;

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  @override
  String get extension => kIsWeb ? 'wav' : 'm4a';

  @override
  Future<bool> requestPermission() => _rec.hasPermission();

  @override
  Future<void> start(String name) async {
    final path = await system.recordingPath(name);
    // On the iPhone the web app keeps its sound while the microphone is on.
    setWebAudioSession(listening: true);
    await _rec.start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
        numChannels: 1,
      ),
      path: path,
    );
    _name = name;
  }

  @override
  Future<RecordedTrack> stop() async {
    final path = await _rec.stop();
    setWebAudioSession(listening: false);
    final name = _name;
    _name = null;
    if (path == null || name == null) throw StateError('No take recorded');
    return system.recordedTrack(path, name);
  }

  @override
  Future<void> cancel() async {
    _name = null;
    await _recorder?.cancel();
    setWebAudioSession(listening: false);
  }

  @override
  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }
}

/// A [TakeRecorder] for tests: no microphone, every take a made-up file.
class FakeTakeRecorder implements TakeRecorder {
  FakeTakeRecorder({this.granted = true});

  /// What [requestPermission] answers.
  bool granted;

  /// When set, [requestPermission] waits for it: a prompt still open.
  Future<bool>? prompt;
  var starts = 0;

  /// Makes [start] fail, as a microphone taken by another app does.
  bool failStart = false;

  /// The take being recorded, or null.
  String? recording;
  var takes = 0;
  var cancelled = 0;
  var disposed = false;

  @override
  String get extension => 'm4a';

  @override
  Future<bool> requestPermission() => prompt ?? Future.value(granted);

  @override
  Future<void> start(String name) async {
    starts++;
    if (failStart) throw StateError('Microphone busy');
    recording = name;
  }

  @override
  Future<RecordedTrack> stop() async {
    final name = recording;
    recording = null;
    if (name == null) throw StateError('No take recorded');
    takes++;
    return RecordedTrack(uri: 'file:///takes/$takes.m4a', name: name);
  }

  @override
  Future<void> cancel() async {
    if (recording != null) cancelled++;
    recording = null;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

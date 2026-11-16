import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/take_recorder.dart';
import 'package:low_end/audio/web_audio_session.dart';
import 'package:record/record.dart';

/// Safari on the iPhone refuses the microphone, without asking, while the
/// page's audio session says music only ("playback"). The tuner and the
/// Player's REC must switch it to listening before they ask.
void main() {
  late List<bool> session;
  void setSession({required bool listening}) => session.add(listening);

  setUp(() => session = []);

  group('askForMicrophone', () {
    test('sets the session for listening before asking', () async {
      List<bool>? whenAsked;
      final allowed = await askForMicrophone(() async {
        whenAsked = [...session];
        return true;
      }, session: setSession);
      expect(allowed, isTrue);
      expect(whenAsked, [true]);
      // With a yes the listening that follows keeps the session.
      expect(session, [true]);
    });

    test('goes back to music after a no', () async {
      final allowed = await askForMicrophone(
        () async => false,
        session: setSession,
      );
      expect(allowed, isFalse);
      expect(session, [true, false]);
    });

    test('goes back to music when asking fails', () async {
      await expectLater(
        askForMicrophone(
          () async => throw StateError('no'),
          session: setSession,
        ),
        throwsStateError,
      );
      expect(session, [true, false]);
    });
  });

  test('the tuner asks with the session set for listening', () async {
    final recorder = _AskingRecorder(() => session.lastOrNull);
    final mic = RecordMicInput(recorder: recorder, session: setSession);
    expect(await mic.requestPermission(), isTrue);
    expect(recorder.sessionWhenAsked, [true]);
  });

  test('the Player\'s REC asks with the session set for listening', () async {
    final recorder = _AskingRecorder(() => session.lastOrNull, allow: false);
    final takes = RecordTakeRecorder(recorder: recorder, session: setSession);
    expect(await takes.requestPermission(), isFalse);
    expect(recorder.sessionWhenAsked, [true]);
    expect(session.last, isFalse);
  });
}

/// An [AudioRecorder] that only answers whether the microphone is allowed,
/// noting the audio session at that moment.
class _AskingRecorder implements AudioRecorder {
  _AskingRecorder(this._session, {this.allow = true});

  final bool? Function() _session;
  final bool allow;
  final sessionWhenAsked = <bool?>[];

  @override
  Future<bool> hasPermission({bool request = true}) async {
    sessionWhenAsked.add(_session());
    return allow;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

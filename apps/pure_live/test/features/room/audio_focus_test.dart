import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/audio_focus.dart';
import 'package:pure_live/system/playback/audio_focus_port.dart';

/// The room's audio focus, without a phone: calls pause and resume it, a
/// prompt ducks it, and the focus it holds is given back when the room closes.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePort port;
  late _FakeTarget target;
  late RoomAudioFocus focus;
  late bool mayPlay;

  setUp(() {
    port = _FakePort();
    target = _FakeTarget()..sounding = true;
    mayPlay = true;
    focus = RoomAudioFocus(target: target, port: port, mayPlayNow: () => mayPlay)..start();
  });

  tearDown(() async {
    await focus.dispose();
    await port.close();
  });

  test('the focus is asked for when playback starts and given back on close', () async {
    await _settle();
    expect(port.activations, [true]);
    await focus.dispose();
    expect(port.activations, [true, false]);
  });

  test('a call pauses the room and its end resumes it', () async {
    port.interruptionController.add(AudioInterruptionEvent(true, AudioInterruptionType.pause));
    await _settle();
    expect(target.paused, isTrue);

    port.interruptionController.add(AudioInterruptionEvent(false, AudioInterruptionType.pause));
    await _settle();
    expect(target.paused, isFalse);
    expect(target.resumes, 1);
  });

  test('another player taking the focus pauses for good', () async {
    port.interruptionController.add(AudioInterruptionEvent(true, AudioInterruptionType.unknown));
    await _settle();
    expect(target.paused, isTrue);

    port.interruptionController.add(AudioInterruptionEvent(false, AudioInterruptionType.unknown));
    await _settle();
    expect(target.paused, isTrue);
    expect(target.resumes, 0);
  });

  test('a prompt lowers the volume to a fifth and restores it', () async {
    target.volume = 0.8;
    port.interruptionController.add(AudioInterruptionEvent(true, AudioInterruptionType.duck));
    await _settle();
    expect(target.volume, closeTo(0.16, 1e-6));

    port.interruptionController.add(AudioInterruptionEvent(false, AudioInterruptionType.duck));
    await _settle();
    expect(target.volume, closeTo(0.8, 1e-6));
  });

  test('a volume the viewer chose during the prompt stays', () async {
    port.interruptionController.add(AudioInterruptionEvent(true, AudioInterruptionType.duck));
    await _settle();
    target.setVolume(0.5);

    port.interruptionController.add(AudioInterruptionEvent(false, AudioInterruptionType.duck));
    await _settle();
    expect(target.volume, 0.5);
  });

  test('a muted room is not ducked into sound', () async {
    target
      ..muted = true
      ..volume = 0.7;
    port.interruptionController.add(AudioInterruptionEvent(true, AudioInterruptionType.duck));
    await _settle();
    expect(target.volume, 0.7);
  });

  test('unplugged headphones pause the room for good', () async {
    port.noisyController.add(null);
    await _settle();
    expect(target.paused, isTrue);
    expect(target.resumes, 0);
  });

  test('an interruption that ends in the background waits for the app', () async {
    await _settle();
    mayPlay = false;

    port.interruptionController.add(AudioInterruptionEvent(true, AudioInterruptionType.pause));
    await _settle();
    port.interruptionController.add(AudioInterruptionEvent(false, AudioInterruptionType.pause));
    await _settle();
    expect(target.paused, isTrue);

    mayPlay = true;
    focus.onAppResumed();
    await _settle();
    expect(target.paused, isFalse);
  });

  test('the viewer pausing during a call keeps the room paused after it', () async {
    port.interruptionController.add(AudioInterruptionEvent(true, AudioInterruptionType.pause));
    await _settle();
    expect(target.paused, isTrue);

    focus.onUserChanged();
    port.interruptionController.add(AudioInterruptionEvent(false, AudioInterruptionType.pause));
    await _settle();
    expect(target.paused, isTrue);
    expect(target.resumes, 0);
  });
}

/// Lets the focus's serialized event queue drain.
Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _FakePort implements AudioFocusPort {
  final StreamController<AudioInterruptionEvent> interruptionController =
      StreamController<AudioInterruptionEvent>.broadcast();
  final StreamController<void> noisyController = StreamController<void>.broadcast();
  final List<bool> activations = [];

  Future<void> close() async {
    await interruptionController.close();
    await noisyController.close();
  }

  @override
  Future<bool> activate({required bool active}) async {
    activations.add(active);
    return true;
  }

  @override
  Stream<void> get becomingNoisy => noisyController.stream;

  @override
  Stream<AudioInterruptionEvent> get interruptions => interruptionController.stream;
}

final class _FakeTarget implements RoomAudioTarget {
  @override
  bool sounding = false;

  @override
  bool paused = false;

  @override
  bool muted = false;

  @override
  double volume = 1;

  int resumes = 0;

  @override
  void pause() => paused = true;

  @override
  void resume() {
    resumes++;
    paused = false;
  }

  @override
  void setVolume(double volume) => this.volume = volume;
}

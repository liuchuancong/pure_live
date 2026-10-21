import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The system's audio focus as the session sees it: asking for it, giving it
/// back, and what the system says while it is held.
abstract interface class AudioFocusPort {
  /// Asks for the focus ([active]) or gives it back; whether it was granted.
  Future<bool> activate({required bool active});

  /// Another sound wants the output: a call or an alarm (pause), a prompt
  /// that may play over a lower volume (duck), another player taking it for
  /// good (unknown); then their ends.
  Stream<AudioInterruptionEvent> get interruptions;

  /// Headphones were unplugged or a Bluetooth output went away.
  Stream<void> get becomingNoisy;
}

/// [AudioFocusPort] over `audio_session`: one music session for the app.
///
/// Only the phones have this focus: Android and iOS. A desktop window keeps
/// playing without one; the store build is the only Android/iOS flavour.
final class SystemAudioFocus implements AudioFocusPort {
  new _();

  /// The app's one session.
  static final SystemAudioFocus instance = SystemAudioFocus._();

  /// Whether the system has an audio focus worth asking for here.
  static bool get available => Platform.isAndroid || Platform.isIOS;

  Future<AudioSession>? _session;

  Future<AudioSession> _configured() => _session ??= () async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    return session;
  }();

  @override
  Future<bool> activate({required bool active}) async => await (await _configured()).setActive(active);

  @override
  Stream<AudioInterruptionEvent> get interruptions =>
      Stream.fromFuture(_configured()).asyncExpand((session) => session.interruptionEventStream);

  @override
  Stream<void> get becomingNoisy =>
      Stream.fromFuture(_configured()).asyncExpand((session) => session.becomingNoisyEventStream);
}

/// The platform's focus, or null on a host that has none (the desktops).
final audioFocusPortProvider = Provider<AudioFocusPort?>(
  (ref) => SystemAudioFocus.available ? SystemAudioFocus.instance : null,
);

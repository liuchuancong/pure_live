import 'dart:async';

import 'package:live_sites/live_sites.dart';

/// One interaction source of a room: something that produces
/// [LiveMessage]s (danmaku today, more later).
///
/// Sources translate their transport into the shared message models; the
/// protocol parsing itself stays in `live_sites`. A broken connection is
/// reported as an error on [messages]; the session decides on reconnects.
abstract interface class InteractionSource {
  /// A stable source id (e.g. `danmaku`).
  String get id;

  /// The message stream; single subscription. The stream ends when the
  /// source is closed, fails when the connection broke.
  Stream<LiveMessage> get messages;

  /// Closes the source and releases its transport.
  Future<void> close();
}

/// A [InteractionSource] over a `live_sites` danmaku session.
///
/// The site layer owns the protocol; this adapter only forwards its
/// normalized messages and closes it with the session.
///
/// The connect function is invoked lazily by the session on the first
/// [messages] listen and again after a connection error (reconnect), so
/// one source instance can outlive a broken socket.
final class DanmakuInteractionSource implements InteractionSource {
  /// A source wrapping [connect] (a `LiveDanmakuCapability.connect` call).
  new({required this.connect, this.id = 'danmaku'});

  /// Connects the danmaku session (called on every listen/reconnect).
  final Future<LiveDanmakuSession> Function() connect;

  @override
  final String id;

  LiveDanmakuSession? _session;

  @override
  Stream<LiveMessage> get messages async* {
    final session = await connect();
    _session = session;
    yield* session.events;
  }

  @override
  Future<void> close() async {
    final session = _session;
    _session = null;
    await session?.dispose();
  }
}

/// Builds an [InteractionSource] for one room; the session invokes the
/// factory per source and re-invokes the source's own connect on
/// reconnect.
typedef InteractionSourceFactory = InteractionSource Function();

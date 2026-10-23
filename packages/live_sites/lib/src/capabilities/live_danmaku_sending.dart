import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';

/// A danmaku session the viewer can speak through.
///
/// Most sessions only listen; the platforms whose chat accepts a posted
/// message implement this beside [LiveDanmakuSession], and a caller that
/// wants to send asks `session is LiveDanmakuSending`. A platform that
/// needs credentials to send reports it through the returned error, not by
/// withholding the interface — the session exists either way.
abstract interface class LiveDanmakuSending {
  /// Posts [text] to the room's chat. Throws when it could not be sent
  /// (missing credentials, the room's chat is closed, a transport break).
  Future<void> send(String text);
}

/// The connective state of a danmaku session, told apart from the message
/// stream: a reconnecting session keeps delivering what arrives, and a
/// closed one says so without throwing.
enum LiveDanmakuConnectionState {
  /// Connecting for the first time.
  connecting,

  /// Connected and delivering.
  connected,

  /// The transport broke and is being re-established.
  reconnecting,

  /// Closed; no further messages arrive.
  closed,
}

/// A danmaku session that reports its connection's ups and downs.
///
/// Protocol-level reconnects are the session's own business (the
/// [LiveDanmakuProvider] contract); this tells the caller about them so a
/// room can show "重连中" instead of silence. A session that never
/// reconnects (a plain polling transport) never implements it.
abstract interface class LiveDanmakuStatusEvents {
  /// The session's connective states, in order.
  Stream<LiveDanmakuConnectionState> get connectionStates;

  /// The state right now.
  LiveDanmakuConnectionState get connectionState;
}

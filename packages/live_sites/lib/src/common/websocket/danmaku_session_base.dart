import 'dart:async';

import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own. Every session's own timers typedef spells this record, so a
/// test's clock keeps driving a session that moved onto the base.
typedef DanmakuTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// What a session's connection is doing, in order on the session's `states`
/// stream — what every session wrote by hand as `_joined` and friends. The
/// platform reports the facts through its [DanmakuRun]; the base turns them
/// into this stream, so a consumer subscribes instead of each platform
/// keeping its own flags.
@immutable
sealed class DanmakuStateEvent {
  /// Creates the event.
  const DanmakuStateEvent();
}

/// An attempt is under way: the transport is being opened and the protocol
/// joined (each [DanmakuSessionBase.beginRun]).
final class DanmakuConnecting extends DanmakuStateEvent {
  /// Creates the event.
  const DanmakuConnecting();

  @override
  bool operator ==(Object other) => other is DanmakuConnecting;

  @override
  int get hashCode => (DanmakuConnecting).hashCode;

  @override
  String toString() => 'DanmakuConnecting()';
}

/// The transport opened and the protocol's own handshake is under way or its
/// join is pending — not delivering yet ([DanmakuRun.handshakeDone]). A
/// protocol whose open socket is the join goes straight to
/// [DanmakuJoined] instead.
final class DanmakuHandshakeDone extends DanmakuStateEvent {
  /// Creates the event.
  const DanmakuHandshakeDone();

  @override
  bool operator ==(Object other) => other is DanmakuHandshakeDone;

  @override
  int get hashCode => (DanmakuHandshakeDone).hashCode;

  @override
  String toString() => 'DanmakuHandshakeDone()';
}

/// The protocol joined: messages flow ([DanmakuRun.joined]). Comes again
/// after every reconnect.
final class DanmakuJoined extends DanmakuStateEvent {
  /// Creates the event.
  const DanmakuJoined();

  @override
  bool operator ==(Object other) => other is DanmakuJoined;

  @override
  int get hashCode => (DanmakuJoined).hashCode;

  @override
  String toString() => 'DanmakuJoined()';
}

/// A connection that was joined was lost and the session is recovering by
/// itself ([DanmakuRun.reconnecting]); messages and [DanmakuJoined] follow
/// once it recovers.
final class DanmakuReconnecting extends DanmakuStateEvent {
  /// Creates the event.
  const DanmakuReconnecting(this.reason);

  /// Why, as the platform's retry path named it.
  final String reason;

  @override
  bool operator ==(Object other) => other is DanmakuReconnecting && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'DanmakuReconnecting($reason)';
}

/// The reconnect budget ran out ([DanmakuRun.exhausted]): the session is over
/// for good — its events stream closes — until it is built again.
final class DanmakuExhausted extends DanmakuStateEvent {
  /// Creates the event.
  const DanmakuExhausted(this.reason);

  /// Why, as the platform's budget path named it.
  final String reason;

  @override
  bool operator ==(Object other) => other is DanmakuExhausted && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'DanmakuExhausted($reason)';
}

/// The lifecycle every site's danmaku session shares (what each session
/// wrote by hand with `_generation`, `_disposed` and per-socket guards).
///
/// The base holds the generation: every [beginRun] — the session's connect
/// and each of its reconnects — makes the previous attempt's callbacks,
/// timers and sockets go silent for good, so no platform keeps its own
/// generation accounting. The platform implements [stop] (release its
/// transport and protocol timers; safe when nothing is open) and drives its
/// attempts through the run [beginRun] hands it; [disconnect] and [dispose]
/// are the base's.
abstract base class DanmakuSessionBase implements LiveDanmakuSession {
  /// A session whose watches [timers] keep; null uses real [Timer]s.
  DanmakuSessionBase({DanmakuTimers? timers}) : timers = timers ?? (after: Timer.new, every: Timer.periodic);

  /// The session's watches; the platform arms its protocol timers (heartbeat,
  /// watchdog, join budget) through it, and [DanmakuRun.delay] waits by it.
  final DanmakuTimers timers;

  final StreamController<LiveMessage> _messages = StreamController.broadcast();
  final StreamController<DanmakuStateEvent> _states = StreamController.broadcast(sync: true);
  DanmakuRun? _run;
  int _generation = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _messages.stream;

  /// What the connection is doing, in order (a broadcast stream); closed by
  /// [dispose]. See [DanmakuStateEvent].
  Stream<DanmakuStateEvent> get states => _states.stream;

  /// Whether the session was disposed and reports nothing any more; not
  /// reusable afterwards.
  bool get isDisposed => _disposed;

  /// The attempt now under way; null between attempts and once the session
  /// stopped. The analog of a hand-written generation read, for a platform
  /// whose failure paths run outside the attempt that armed them.
  DanmakuRun? get run => _run;

  /// Begins an attempt: the previous one's callbacks, timers and sockets
  /// report nothing any more, and the states stream tells connecting. The
  /// attempt reports through the returned [DanmakuRun].
  DanmakuRun beginRun() {
    _finish();
    _add(const DanmakuConnecting());
    return _run = DanmakuRun._(this, _generation);
  }

  /// Ends the current attempt without a replacement — between attempts, or
  /// once the session stopped: everything it reports from now on goes
  /// silent. The next [beginRun] starts over.
  void endRun() => _finish();

  /// The platform releases its transport and protocol timers; called by
  /// [disconnect] and [dispose], and safe when nothing is open.
  @protected
  Future<void> stop() async {}

  /// Stops delivery, leaving the session able to connect again.
  @override
  Future<void> disconnect() async {
    _finish();
    await stop();
  }

  /// Releases everything the session owns; not reusable afterwards. The
  /// events and states streams close after [stop], so pending messages
  /// flush first.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _finish();
    await stop();
    await _messages.close();
    await _states.close();
  }

  void _finish() {
    _generation++;
    final run = _run;
    _run = null;
    run?._teardown();
    if (run != null && !run._ended.isCompleted) run._ended.complete();
  }

  void _add(DanmakuStateEvent event) {
    if (!_states.isClosed) _states.add(event);
  }
}

/// One attempt of a [DanmakuSessionBase]: what the platform reports through.
/// Every method does nothing once the attempt is over ([isActive] false) —
/// the session began another one, stopped it, or was disposed.
final class DanmakuRun {
  DanmakuRun._(this._session, this._generation);

  final DanmakuSessionBase _session;
  final int _generation;
  final Completer<void> _ended = Completer();
  Timer? _joinWatch;
  var _joined = false;
  var _toldExhausted = false;

  /// Whether this attempt is still the session's current one. Replaces the
  /// hand-written `generation == _generation && !_disposed`.
  bool get isActive => _session._generation == _generation && !_session._disposed && !_ended.isCompleted;

  /// Whether the protocol joined in this attempt ([joined] told it so); a
  /// fresh attempt has not.
  bool get isJoined => _joined;

  /// Completes when the attempt is over: replaced, stopped or disposed.
  Future<void> get ended => _ended.future;

  /// The transport opened and the protocol's own handshake is under way or
  /// its join is pending; tells [DanmakuHandshakeDone]. A protocol whose
  /// open socket is the join reports [joined] instead.
  void handshakeDone() {
    if (isActive) _session._add(const DanmakuHandshakeDone());
  }

  /// The protocol joined: messages flow, and [DanmakuJoined] is told. A
  /// session's reconnect budget resets here, where the platform counts it.
  /// The join budget ([armJoinTimeout]) ends with the join.
  void joined() {
    if (!isActive) return;
    _joined = true;
    _joinWatch?.cancel();
    _joinWatch = null;
    _session._add(const DanmakuJoined());
  }

  /// A connection that was joined was lost: [DanmakuReconnecting] tells why.
  /// Nothing when the attempt never joined — it is still connecting, and the
  /// retry is the session's ordinary business.
  void reconnecting(String reason) {
    if (!isActive || !_joined) return;
    _session._add(DanmakuReconnecting(reason));
  }

  /// The reconnect budget ran out: [DanmakuExhausted] tells why, once per
  /// attempt. Does not end the attempt by itself — the platform tells its
  /// terminal message through [message] and lets
  /// [DanmakuSessionBase.dispose] close the session.
  void exhausted(String reason) {
    if (!isActive || _toldExhausted) return;
    _toldExhausted = true;
    _session._add(DanmakuExhausted(reason));
  }

  /// [message] reaches the session's events, its text and the sender's name
  /// and fan badge name without invisible placeholder characters
  /// ([cleanDanmakuMessage]); nothing once the attempt is over. Every
  /// message passes through it — the session's single outlet.
  void message(LiveMessage message) {
    if (!isActive) return;
    _session._messages.add(cleanDanmakuMessage(message));
  }

  /// Waits [duration] unless the attempt ends first — replaced, stopped or
  /// disposed — and true when it is still active. A delay a dead attempt
  /// kept is the replacement for a timer a hand-written generation guarded.
  Future<bool> delay(Duration duration) async {
    if (!isActive) return false;
    final elapsed = Completer<void>();
    final timer = _session.timers.after(duration, elapsed.complete);
    await Future.any([elapsed.future, _ended.future]);
    timer.cancel();
    return isActive;
  }

  /// Arms the join budget: [onTimeout] runs unless the protocol joined
  /// ([joined]) or the attempt ended first. Re-arming replaces the previous
  /// watch — the budget restarts at every socket open. Eleven sessions wrote
  /// this same timer by hand (`Timer(joinTimeout, () { if joined/disposed
  /// return; ... })` plus a cancel at every teardown); the watch is the
  /// base's now, cancelled by [joined], by [cancelJoinTimeout] — the
  /// platform's answer to the join, even a refusal, stops it — and when the
  /// attempt ends, so a replaced or disposed session leaks no timer.
  void armJoinTimeout(Duration timeout, void Function() onTimeout) {
    _joinWatch?.cancel();
    _joinWatch = _session.timers.after(timeout, () {
      _joinWatch = null;
      if (isActive && !_joined) onTimeout();
    });
  }

  /// Stops the join budget without counting the join: the platform got an
  /// answer to its join frames — a refusal is an answer too — and its own
  /// escalation decides what happens next.
  void cancelJoinTimeout() {
    _joinWatch?.cancel();
    _joinWatch = null;
  }

  void _teardown() {
    _joinWatch?.cancel();
    _joinWatch = null;
  }
}

/// [text] without the invisible characters platforms pad into frame text,
/// which fonts draw as a box or nothing: U+0000-U+0008, U+000B, U+000C and
/// U+000E-U+001F (\t, \n and \r stay), the C1 controls U+007F-U+009F, and
/// the U+FFF9-U+FFFC placeholders and the U+FFFE-U+FFFF noncharacters. CJK
/// and every other letter stay. The same string when it has none.
String cleanDanmakuText(String text) =>
    _invisibleCharacters.hasMatch(text) ? text.replaceAll(_invisibleCharacters, '') : text;

final RegExp _invisibleCharacters = RegExp(
  r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\uFFF9-\uFFFC\uFFFE\uFFFF]',
);

/// [message] with its text and the sender's name and fan badge name without
/// invisible placeholder characters ([cleanDanmakuText]); the same message
/// when it has none. Every message passes through it in [DanmakuRun.message].
LiveMessage cleanDanmakuMessage(LiveMessage message) {
  final text = cleanDanmakuText(message.text);
  final sender = message.sender;
  final MessageSender? cleaned;
  if (sender == null) {
    cleaned = null;
  } else {
    final name = cleanDanmakuText(sender.userName);
    final badge = cleanDanmakuText(sender.fanBadgeName);
    cleaned = identical(name, sender.userName) && identical(badge, sender.fanBadgeName)
        ? sender
        : sender.rebuild(
            (builder) => builder
              ..userName = name
              ..fanBadgeName = badge,
          );
  }
  if (identical(text, message.text) && identical(cleaned, sender)) return message;
  return message.rebuild((builder) {
    builder.text = text;
    if (!identical(cleaned, sender)) builder.sender = cleaned?.toBuilder();
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_http.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_session.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '555';

/// The scheduler's answer handing out [hosts].
String _dispatch(List<String> hosts, {String token = 'tok'}) => jsonEncode({
  'code': 0,
  'data': {
    'protocol': 'wss://',
    'addrs': [
      for (final host in hosts) {'host': host},
    ],
    'soctoken': token,
    'age': 300000,
  },
});

/// A socket that stays open until the session replaces it.
final class _Socket implements SocketChannel {
  final _incoming = StreamController<Object?>();

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  void add(Object data) {}

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

/// The scheduler: each request answers the next of [answers], the last
/// repeating.
final class _Http implements LiveHttp {
  _Http(this.answers);

  final List<String> answers;
  var _handed = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final text = answers[_handed.clamp(0, answers.length - 1)];
    _handed += 1;
    return LiveResponse(statusCode: 200, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(text)));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A timer the test fires by hand.
final class _Armed implements Timer {
  _Armed(this._gone);

  final void Function() _gone;
  var _cancelled = false;

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _gone();
  }

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

/// The one-shot timers the session arms, fired by their delay.
final class _Clock {
  final _after = <({Duration delay, void Function() fire})>[];

  KugouliveTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      return _Armed(() => _after.remove(record));
    },
    every: (period, callback) => _Armed(() {}),
  );

  /// Fires the last timer armed for [delay].
  void fire(Duration delay) {
    final index = _after.lastIndexWhere((timer) => timer.delay == delay);
    if (index < 0) throw StateError('nothing is armed for $delay');
    _after.removeAt(index).fire();
  }

  /// Fires the last timer armed: the reconnect step.
  void fireLast() => _after.removeLast().fire();
}

Future<void> _settle() async {
  for (var turn = 0; turn < 20; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A session over [answers], the hosts it connects to recorded in order.
({KugouliveDanmakuSession session, List<Uri> asked, _Clock clock}) _session(List<String> answers) {
  final asked = <Uri>[];
  final clock = _Clock();
  Future<SocketChannel> connect(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    asked.add(endpoint);
    return _Socket();
  }

  final site = KugouliveSite(http: KugouliveHttp(_Http(answers)), connect: connect);
  final session = KugouliveDanmakuSession(
    args: const KugouliveDanmakuArgs(roomId: _room),
    site: site,
    timers: clock.timers,
    now: () => DateTime.utc(2026, 11, 6),
    random: Random(5),
  );
  return (session: session, asked: asked, clock: clock);
}

void main() {
  test('each replacement goes to the next of the scheduler’s hosts, round and round', () async {
    final (:session, :asked, :clock) = _session([_dispatch(['a:1', 'b:2', 'c:3'])]);
    addTearDown(session.dispose);
    await session.connect();
    await _settle();
    for (var replaced = 0; replaced < 3; replaced++) {
      clock.fire(KugouliveDanmakuCodec.joinTimeout);
      await _settle();
      clock.fireLast();
      await _settle();
    }
    expect(asked.map((uri) => uri.authority), ['a:1', 'b:2', 'c:3', 'a:1']);
  });

  test('a renewed grant with fewer hosts keeps the turn within its own list', () async {
    // A socket never joined drops its token, so every replacement asks the
    // scheduler again; the second answer lists one host only.
    final (:session, :asked, :clock) = _session([
      _dispatch(['a:1', 'b:2']),
      _dispatch(['z:9'], token: 'tok-2'),
    ]);
    addTearDown(session.dispose);
    await session.connect();
    await _settle();
    clock.fire(KugouliveDanmakuCodec.joinTimeout);
    await _settle();
    clock.fireLast();
    await _settle();
    expect(asked.map((uri) => uri.authority), ['a:1', 'z:9']);
  });
}

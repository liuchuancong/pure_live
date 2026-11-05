import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_http.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_codec.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_session.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _steam = '76561198000000000';
const String _broadcast = '123';
const String _template =
    'https://steambroadcastchat.akamaized.net/chat/abc/messages/{0}?chat_origin=https://steamcommunity.com';

/// The `getbroadcastmpd` answer: [success], its broadcast id and its viewers.
String _mpd({String success = 'ready', Object? id = _broadcast, Object? viewers = '10'}) =>
    jsonEncode({'success': success, 'broadcastid': ?id, 'num_viewers': ?viewers, 'title': 'A broadcast'});

/// One chat window's answer: the next request's time, its delay and its lines.
String _window({int next = 1000, int? delay, List<Map<String, Object?>> messages = const []}) =>
    jsonEncode({'next_request': next, 'initial_delay': ?delay, 'messages': messages});

/// A chat line of a window.
Map<String, Object?> _line(String text, {String name = 'Ann', String id = '21'}) => {
  'msg': text,
  'persona_name': name,
  'steamid': id,
};

/// The transport under the session: the three URLs of the chat log answered by
/// [mpd], [info] and [windows] (consumed in order, the last repeating);
/// [breaks] throws on window requests only, [breaksAll] on every one.
final class _Http implements LiveHttp {
  _Http({this.mpd = _ready, this.info = _good, List<String> windows = const [], this.breaks, this.breaksAll})
    : windows = windows.isEmpty ? [_window()] : windows;

  static const String _ready = '{"success":"ready","broadcastid":"123","num_viewers":"10"}';
  static const String _good = '{"success":1,"view_url_template":"$_template"}';

  String mpd;
  String info;
  List<String> windows;

  /// Thrown for a window request only, as a chat log that stops answering is.
  Exception? breaks;

  /// Thrown for every request, as a breakdown is.
  Exception? breaksAll;

  final asked = <Uri>[];
  var _handed = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    final path = request.url.path;
    if (breaksAll case final error?) throw error;
    if (path.contains('getbroadcastmpd')) return _answer(mpd);
    if (path.contains('getchatinfo')) return _answer(info);
    if (breaks case final error?) throw error;
    final text = windows[_handed.clamp(0, windows.length - 1)];
    _handed += 1;
    return _answer(text);
  }

  LiveResponse _answer(String text) => LiveResponse(
    statusCode: 200,
    headers: const <String, String>{},
    bodyBytes: Uint8List.fromList(utf8.encode(text)),
  );

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A timer the session can arm and cancel while the test keeps its callback.
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

/// The timers the session arms, kept so the ladder can be fired by hand.
final class _Clock {
  final _after = <({Duration delay, void Function() fire})>[];

  /// Every delay whose timer was fired, in order.
  final fired = <Duration>[];

  SteambroadcastTimers get timers => (
    after: (delay, callback) {
      final record = (delay: delay, fire: callback);
      _after.add(record);
      return _Armed(() => _after.remove(record));
    },
  );

  /// The one-shot timers currently armed.
  int get armedCount => _after.length;

  /// The delay of the last timer armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last timer armed: the wait before the next step.
  void fireLast() {
    if (_after.isEmpty) return;
    final timer = _after.removeLast();
    fired.add(timer.delay);
    timer.fire();
  }
}

/// The session's monotonic clock, moved by the test.
final class _Elapsed {
  Duration at = Duration.zero;

  Duration read() => at;

  /// Moves the clock on by [step], which defaults to the wait that just ran.
  void advance([Duration? step]) => at += step ?? Duration.zero;
}

/// A session with its connector, clock and answers.
(_Room, _Clock, _Elapsed, _Http) _session({
  String? broadcastId,
  String mpd = _Http._ready,
  String info = _Http._good,
  List<String> windows = const [],
  Exception? breaks,
  Exception? breaksAll,
}) {
  final clock = _Clock();
  final elapsed = _Elapsed();
  final http = _Http(mpd: mpd, info: info, windows: windows, breaks: breaks, breaksAll: breaksAll);
  final session = SteambroadcastDanmakuSession(
    args: SteambroadcastDanmakuArgs(_steam, broadcastId: broadcastId),
    http: SteambroadcastHttp(http),
    timers: clock.timers,
    elapsed: elapsed.read,
  );
  return (_Room(session), clock, elapsed, http);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final SteambroadcastDanmakuSession session;
  late final StreamSubscription<LiveMessage> subscription;
  final seen = <LiveMessage>[];
  final closed = Completer<void>();

  Future<LiveSiteError?> connect() => session.connect();

  /// The messages of the reported kind.
  List<LiveMessage> ofType(LiveMessageType type) => seen.where((message) => message.type == type).toList();

  /// The chat lines reported so far.
  List<String> get chat =>
      seen.where((message) => message.type == LiveMessageType.chat).map((message) => message.text).toList();

  Future<void> dispose() async {
    await subscription.cancel();
    await session.dispose();
  }
}

Future<void> _settle() async {
  for (var turn = 0; turn < 20; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Runs one step of the loop: the wait that is due, and the request it bounds.
Future<void> _pump(_Clock clock, _Elapsed elapsed, {Duration? moved}) async {
  clock.fireLast();
  elapsed.advance(moved ?? clock.fired.last);
  await _settle();
}

void main() {
  group('the start', () {
    test('the broadcast is looked up, its viewers told, and window 0 only sets the clock', () async {
      final (room, clock, elapsed, http) = _session(windows: [_window(delay: 500)]);
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(http.asked, isEmpty, reason: 'the loop starts on its first wait');

      await _pump(clock, elapsed);
      expect(http.asked, [
        SteambroadcastEndpoints.mpdUrl(_steam),
        SteambroadcastDanmakuCodec.chatInfoUrl(_steam, _broadcast),
        Uri.parse(
          'https://steambroadcastchat.akamaized.net/chat/abc/messages/0?chat_origin=https://steamcommunity.com',
        ),
      ], reason: 'one step looks the chat up and reads window 0 in it');
      final viewers = room.ofType(LiveMessageType.audienceUpdate).single.payload! as LiveAudienceUpdate;
      expect(viewers.kind, LiveAudienceSignalKind.onlineViewers);
      expect(viewers.value, 10);
      expect(room.seen.where((message) => message.type == LiveMessageType.chat), isEmpty);
      expect(clock.lastArmed, const Duration(milliseconds: 500), reason: 'the window’s own delay');
    });

    test('a broadcast id brought by the room skips getbroadcastmpd', () async {
      final (room, clock, elapsed, http) = _session(broadcastId: '456', windows: [_window(delay: 200)]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      expect(http.asked.first, SteambroadcastDanmakuCodec.chatInfoUrl(_steam, '456'));
      expect(http.asked.where((url) => url.path.contains('getbroadcastmpd')), isEmpty);
      expect(room.seen, isEmpty, reason: 'no viewers are told without the mpd request');
      expect(clock.lastArmed, const Duration(milliseconds: 200));
    });

    test('the window after the first is asked when the clock says it is due', () async {
      final (room, clock, elapsed, http) = _session(
        windows: [
          _window(delay: 500),
          _window(next: 2000, messages: [_line('one'), _line('two')]),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      await _pump(clock, elapsed);
      expect(http.asked.last.toString(), contains('/messages/1000'));
      expect(room.chat, ['one', 'two'], reason: 'the history of window 0 was not, in order');
      // Due at 500 + (2000 − 1000) = 1500 ms, and the clock stands at 500 ms.
      expect(clock.lastArmed, const Duration(milliseconds: 1000));

      await _pump(clock, elapsed);
      expect(http.asked.last.toString(), contains('/messages/2000'));
    });

    test('an initial delay on a later window sets the clock again', () async {
      final (room, clock, elapsed, _) = _session(
        windows: [
          _window(delay: 500),
          _window(next: 2000, delay: 100, messages: [_line('one')]),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      await _pump(clock, elapsed);
      expect(room.chat, ['one'], reason: 'a late window is still read');
      expect(clock.lastArmed, const Duration(milliseconds: 100), reason: 'and its own delay wins');
    });

    test('an id the log refuses is forgotten, so the next look-up asks mpd', () async {
      final (room, clock, elapsed, http) = _session(broadcastId: '999', info: '{"success":0}', windows: [_window()]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      expect(http.asked.single.toString(), contains('getchatinfo'));
      expect(clock.lastArmed, SteambroadcastDanmakuCodec.retryDelay);

      await _pump(clock, elapsed);
      expect(http.asked[1], SteambroadcastEndpoints.mpdUrl(_steam), reason: 'the id may no longer be current');
      expect(
        http.asked.last.toString(),
        contains('broadcastid=$_broadcast'),
        reason: 'and the log is asked with the id mpd names now',
      );
    });
  });

  group('the ladder', () {
    test('a missed window adds its nudge to the next window’s own wait', () async {
      final (room, clock, elapsed, http) = _session(
        windows: [
          _window(delay: 500),
          _window(next: 2000, messages: [_line('one')]),
        ],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      expect(clock.lastArmed, const Duration(milliseconds: 500));

      // The window at 500 ms does not answer: the clock is at 500 ms and the
      // nudge begins.
      http.breaks = const ConnectFailure('chat log down');
      await _pump(clock, elapsed);
      expect(clock.lastArmed, SteambroadcastDanmakuCodec.retryDelay, reason: 'a failed window waits its step');

      http.breaks = null;
      await _pump(clock, elapsed);
      expect(room.chat, ['one']);
      // Due at 500 + (2000 − 1000) + 10 − 1000 = 510 ms.
      expect(
        clock.lastArmed,
        const Duration(milliseconds: 510),
        reason: 'the nudge of the missed window is added to the pacing',
      );
    });

    test('the fourth failure reads from window 0 again, the eighth looks the chat up', () async {
      final (room, clock, elapsed, http) = _session(breaks: const ConnectFailure('chat log down'));
      addTearDown(room.dispose);

      String window(int index) => http.asked.where((url) => url.path.contains('/messages/')).toList()[index].path;

      await room.connect();
      await _settle();
      for (var failure = 1; failure <= 4; failure++) {
        await _pump(clock, elapsed);
        expect(
          clock.lastArmed,
          SteambroadcastDanmakuCodec.retryDelay,
          reason: 'failure $failure stays at half a second',
        );
      }
      expect(window(0), endsWith('/messages/0'));
      expect(window(1), endsWith('/messages/0'), reason: 'a failed window is asked again');
      expect(window(3), endsWith('/messages/0'), reason: 'the fourth resyncs the clock, so window 0 again');

      for (var failure = 5; failure <= 8; failure++) {
        await _pump(clock, elapsed);
      }
      expect(clock.lastArmed, const Duration(seconds: 1), reason: 'the eighth begins the growing waits');
      expect(http.asked.where((url) => url.path.contains('getbroadcastmpd')), hasLength(1));

      await _pump(clock, elapsed);
      expect(http.asked.where((url) => url.path.contains('getbroadcastmpd')), hasLength(2), reason: 'looked up again');
      expect(http.asked.where((url) => url.path.contains('getchatinfo')), hasLength(2));
      expect(clock.lastArmed, const Duration(seconds: 2), reason: 'the ninth doubles the wait again');
      for (final (failure, seconds) in [(10, 4), (11, 8), (12, 8), (13, 8)]) {
        await _pump(clock, elapsed);
        expect(clock.lastArmed, Duration(seconds: seconds), reason: 'failure $failure');
      }
    });

    test('the sixteenth failure ends the session with the answer’s own words', () async {
      final (room, clock, elapsed, http) = _session(breaks: const ConnectFailure('chat log down'));
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var failure = 0; failure <= SteambroadcastDanmakuCodec.maxFailures; failure++) {
        await _pump(clock, elapsed);
      }
      await room.closed.future;
      expect(
        room.ofType(LiveMessageType.system).single.text,
        contains('chat log down'),
        reason: 'the line names what never came',
      );
      expect(clock.armedCount, isZero);
      final before = http.asked.length;
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(before), reason: 'nothing asks again after the budget');
    });

    test('a window that answers resets the count', () async {
      final (room, clock, elapsed, http) = _session(
        breaks: const ConnectFailure('chat log down'),
        windows: [_window(delay: 100)],
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var failure = 1; failure < SteambroadcastDanmakuCodec.lookUpAfter; failure++) {
        await _pump(clock, elapsed);
      }
      http.breaks = null;
      await _pump(clock, elapsed);
      expect(room.chat, isEmpty, reason: 'window 0 is only the clock’s start');
      expect(clock.lastArmed, const Duration(milliseconds: 100));

      http.breaks = const ConnectFailure('chat log down');
      await _pump(clock, elapsed);
      expect(clock.lastArmed, SteambroadcastDanmakuCodec.retryDelay, reason: 'the count began again at one');
    });
  });

  group('a broadcast that cannot be followed', () {
    test('offline, restricted and subscribers-only each end the session at once', () async {
      for (final (success, id, words) in <(String, Object?, String)>[
        ('offline', null, 'Offline'),
        ('user_restricted', null, 'The account may not broadcast'),
        ('missing_subscription', null, 'Subscribers only'),
        ('ready', null, 'getbroadcastmpd: no broadcast id (live)'),
      ]) {
        final (room, clock, elapsed, http) = _session(
          mpd: _mpd(success: success, id: id),
        );
        addTearDown(room.dispose);

        await room.connect();
        await _settle();
        await _pump(clock, elapsed);
        await room.closed.future;
        expect(room.ofType(LiveMessageType.system).single.text, words, reason: success);
        expect(http.asked.where((url) => url.path.contains('getchatinfo')), isEmpty, reason: 'nothing is joined');
        expect(clock.armedCount, isZero);
      }
    });
  });

  group('stopping', () {
    test('disconnect stops the loop and its pending wait', () async {
      final (room, clock, elapsed, http) = _session(windows: [_window(delay: 500)]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      expect(clock.lastArmed, const Duration(milliseconds: 500));
      await room.session.disconnect();
      expect(clock.armedCount, isZero);
      final before = http.asked.length;
      clock.fireLast();
      await _settle();
      expect(http.asked, hasLength(before), reason: 'the wait that fired found the session gone');

      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      expect(http.asked.length, greaterThan(before), reason: 'and the session can be followed again');
    });

    test('dispose ends the stream', () async {
      final (room, clock, elapsed, _) = _session(windows: [_window(delay: 500)]);
      await room.connect();
      await _settle();
      await _pump(clock, elapsed);
      await room.session.dispose();
      await room.closed.future;
      expect(clock.armedCount, isZero);
      await room.session.dispose();
      await room.dispose();
    });

    test('a broadcaster id that is not one is refused before any request', () async {
      final (room, _, _, http) = _session();
      final other = SteambroadcastDanmakuSession(
        args: const SteambroadcastDanmakuArgs('not-a-steam-id'),
        http: SteambroadcastHttp(_Http()),
        timers: (after: (delay, callback) => _Armed(() {})),
      );
      expect(await other.connect(), isA<LiveSiteNotFound>());
      expect(http.asked, isEmpty);

      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await other.dispose();
      await room.dispose();
    });
  });
}

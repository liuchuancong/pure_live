import 'dart:async';

import 'package:live_net/testing.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_http.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku_session.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _room = '7530951';
final Uri _chatList = Uri.parse('https://liveshowstatic.baidu.com/live/chat_$_room-a.m3u8');
final Uri _reliableList = Uri.parse('https://liveshowstatic.baidu.com/live/reliable_$_room-a.m3u8');
final Uri _hostList = Uri.parse('https://liveshowstatic.baidu.com/live/host_$_room-a.m3u8');
final DateTime _at = DateTime.utc(2026, 11, 5, 12);

/// The samples of the replayed tests, under the platform's fixture directory:
/// a message list's answers in call order (the last repeats) and the segments
/// the lists name, each a chat line of [_room] unless told otherwise. `S16` the
/// chat list whose second answer adds `seg_new.flv` (`S17`), `S18` the chat
/// list that answers 500, `S19` the empty chat list, `S20`/`S21` the reliable
/// and host lists naming `r1.flv`/`h1.flv` (`S22`/`S23`), `S24` the reliable
/// list's 404, `S25`/`S26` the reliable and host lists that cannot be reached
/// (every request fails before an answer: the lists a test leaves out), `S27`
/// the empty chat list that then answers 500, `S28`/`S29` the empty reliable
/// and host lists, `S30` the chat list that adds `b.flv` and `c.flv`
/// (`S31`/`S32`), `S33` the one that adds `gone.flv` (401, `S34`) and
/// `flaky.flv` (500, `S35`), `S36` the one that adds `x.flv`, a line of another
/// room (`S37`), `S38` the one that adds `end.flv`, a line and the broadcast's
/// end (`S39`), and `S40` the empty chat list that then answers 401.
const String _samples = 'test/fixtures/baidulive';

/// The transport under the session: [samples] answer, every request is
/// recorded.
ReplayHttp _replay(List<String> samples) => ReplayHttp.fixtures(_samples, samples);

/// The path of every request [http] recorded, in order.
List<String> _asked(ReplayHttp http) => [for (final request in http.requests) request.url.path];

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

/// The waits the session sets, kept so the poll interval and the backoff steps
/// can be fired by hand.
final class _Clock {
  final _after = <({Duration delay, void Function() fire})>[];

  /// Every delay whose timer was fired, in order.
  final fired = <Duration>[];

  BaiduliveSchedule get schedule => (delay, callback) {
    final record = (delay: delay, fire: callback);
    _after.add(record);
    return _Armed(() => _after.remove(record));
  };

  /// The waits currently armed (the session keeps one).
  int get armedCount => _after.length;

  /// The delay of the last wait armed.
  Duration? get lastArmed => _after.isEmpty ? null : _after.last.delay;

  /// Fires the last wait armed: the next poll, a start retry or a backoff step.
  void fireLast() {
    if (_after.isEmpty) return;
    final timer = _after.removeLast();
    fired.add(timer.delay);
    timer.fire();
  }
}

/// The session's own wall clock, moved by a test.
final class _Wall {
  DateTime at = _at;

  DateTime read() => at;

  void by(Duration delay) => at = at.add(delay);
}

/// A session over the given lists answered by [samples], with its clock and
/// transport.
(_Room, _Clock, ReplayHttp) _session(List<String> samples, {BaiduliveDanmakuArgs? args, DateTime Function()? wall}) {
  final clock = _Clock();
  final http = _replay(samples);
  final session = BaiduliveDanmakuSession(
    args:
        args ??
        BaiduliveDanmakuArgs(roomId: _room, chatList: _chatList, reliableList: _reliableList, hostList: _hostList),
    http: BaiduliveHttp(http),
    now: wall ?? _Wall().read,
    schedule: clock.schedule,
  );
  return (_Room(session), clock, http);
}

/// The session, with its event log already collected.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final BaiduliveDanmakuSession session;
  late final StreamSubscription<LiveMessage> subscription;
  final seen = <LiveMessage>[];
  final closed = Completer<void>();

  Future<LiveSiteError?> connect() => session.connect();

  /// The chat lines reported so far.
  List<String> get chat =>
      seen.where((message) => message.type == LiveMessageType.chat).map((message) => message.text).toList();

  /// The messages of the reported kind.
  List<LiveMessage> ofType(LiveMessageType type) => seen.where((message) => message.type == type).toList();

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

void main() {
  group('joining the chat list', () {
    test('the first answer is history: its segments are remembered, not fetched', () async {
      final (room, clock, http) = _session([
        'S16-chat-old-then-new',
        'S17-segment-new',
      ], args: BaiduliveDanmakuArgs(roomId: _room, chatList: _chatList));
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(_asked(http), [_chatList.path], reason: 'the join reads the list only');
      expect(clock.lastArmed, const Duration(seconds: 5), reason: 'and arms the next poll');

      clock.fireLast();
      await _settle();
      expect(_asked(http), [_chatList.path, _chatList.path, '/live/seg_new.flv']);
      expect(room.chat, ['你好']);
    });

    test('a signature that ran out ends the start without a request', () async {
      final (room, _, http) = _session(
        const [],
        args: BaiduliveDanmakuArgs(
          roomId: _room,
          chatList: _chatList,
          expiresAt: _at.subtract(const Duration(seconds: 1)),
        ),
      );
      final failure = await room.connect();
      expect(failure, isA<LiveSiteError>());
      expect(
        failure!.message,
        contains('signature expired at ${_at.subtract(const Duration(seconds: 1)).toUtc().toIso8601String()}'),
      );
      expect(failure, isA<LiveSiteAuthenticationError>());
      expect(http.requests, isEmpty);
      await room.dispose();
    });

    test('the start asks three times, two seconds apart, and then says so', () async {
      final (room, clock, http) = _session(['S18-chat-500']);
      addTearDown(room.dispose);

      final pending = room.connect();
      await _settle();
      expect(_asked(http), [_chatList.path]);
      expect(clock.lastArmed, BaiduliveDanmakuProtocol.startRetryDelay);
      clock.fireLast();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(http.requests, hasLength(BaiduliveDanmakuProtocol.startAttempts));

      final failure = await pending;
      expect(failure, isA<LiveSiteNetworkError>());
      expect(failure!.message, contains('${BaiduliveDanmakuProtocol.startAttempts} tries without an answer'));
      expect(failure.message, contains('500'), reason: 'the last answer’s own words');
      expect(clock.armedCount, isZero, reason: 'a start that never joined polls nothing');
    });

    test('a second connect is ignored while the run is up', () async {
      final (room, clock, http) = _session(['S19-chat-empty']);
      addTearDown(room.dispose);

      expect(await room.connect(), isNull);
      await _settle();
      expect(await room.connect(), isNull);
      await _settle();
      expect(http.requests, hasLength(1), reason: 'no second join, no second poll loop');
      expect(clock.armedCount, 1);
    });
  });

  group('the polls', () {
    test('each poll asks the chat list, then the reliable and the host list', () async {
      final (room, clock, http) = _session([
        'S19-chat-empty',
        'S20-reliable-r1',
        'S21-host-h1',
        'S22-segment-r1',
        'S23-segment-h1',
      ]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      expect(_asked(http), [_chatList.path], reason: 'the first answer of every list is history');

      clock.fireLast();
      await _settle();
      expect(_asked(http).skip(1), [
        _chatList.path,
        _reliableList.path,
        _hostList.path,
      ], reason: 'one poll, three lists, in this order');

      clock.fireLast();
      await _settle();
      expect(_asked(http).skip(4), [
        _chatList.path,
        _reliableList.path,
        _hostList.path,
      ], reason: 'the other lists are asked again once primed');
      expect(room.chat, isEmpty, reason: 'their first answers were history');
    });

    test('a list that answers 404 is asked less often as it keeps failing', () async {
      final (room, clock, http) = _session(['S19-chat-empty', 'S24-reliable-404', 'S26-host-down']);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var poll = 0; poll < 3; poll++) {
        clock.fireLast();
        await _settle();
      }
      expect(
        _asked(http).where((path) => path == _reliableList.path).length,
        2,
        reason: 'the 404 is asked at the join, skipped once, then asked again',
      );
      expect(_asked(http).where((path) => path == _chatList.path).length, 4, reason: 'the chat list never skips');
    });

    test('the chat list’s failures back off 1, 2, 4, 8 and the ninth ends the run', () async {
      final (room, clock, _) = _session(['S27-chat-empty-then-500', 'S28-reliable-empty', 'S29-host-empty']);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      for (var failure = 1; failure <= BaiduliveDanmakuProtocol.maxFailures; failure++) {
        clock.fireLast();
        await _settle();
        expect(clock.lastArmed, BaiduliveDanmakuProtocol.backoff(failure), reason: 'failure $failure');
        expect(room.closed.isCompleted, isFalse);
      }
      clock.fireLast();
      await _settle();
      await room.closed.future;
      final terminal = room.ofType(LiveMessageType.system).single;
      expect(
        terminal.text,
        contains('${BaiduliveDanmakuProtocol.maxFailures + 1} times in a row'),
        reason: 'the line counts the failures it made',
      );
      expect(terminal.sentAt, _at);
      expect(clock.armedCount, isZero, reason: 'nothing polls afterwards');
    });

    test('a new segment is fetched once, in the list’s order', () async {
      final (room, clock, http) = _session([
        'S30-chat-a-then-abc',
        'S31-segment-b',
        'S32-segment-c',
        'S25-reliable-down',
        'S26-host-down',
      ]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(room.chat, ['二', '三'], reason: 'in the order the list names them');
      expect(_asked(http).where((path) => path == '/live/b.flv').length, 1);

      clock.fireLast();
      await _settle();
      expect(_asked(http).where((path) => path == '/live/b.flv').length, 1, reason: 'seen is seen');
    });

    test('a segment answered 4xx is given up at once; one not answered is tried three times', () async {
      final (room, clock, http) = _session([
        'S33-chat-empty-then-gone-flaky',
        'S34-segment-gone-401',
        'S35-segment-flaky-500',
        'S25-reliable-down',
        'S26-host-down',
      ]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(room.chat, isEmpty);
      expect(_asked(http).where((path) => path == '/live/gone.flv').length, 1, reason: 'a 401 will not come');
      expect(_asked(http).where((path) => path == '/live/flaky.flv').length, 1);

      clock.fireLast();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(_asked(http).where((path) => path == '/live/flaky.flv').length, 3, reason: 'three tries in all');
      clock.fireLast();
      await _settle();
      expect(_asked(http).where((path) => path == '/live/flaky.flv').length, 3, reason: 'then it is given up');
    });

    test('a message of another room is not this room’s chat', () async {
      final (room, clock, _) = _session([
        'S36-chat-empty-then-x',
        'S37-segment-x-other-room',
        'S25-reliable-down',
        'S26-host-down',
      ]);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(room.chat, isEmpty);
      expect(room.seen, isEmpty);
    });
  });

  group('the end of a broadcast', () {
    test('the stopped notice ends the run once, with a terminal line', () async {
      final (room, clock, http) = _session(['S38-chat-empty-then-end', 'S39-segment-end-stopped']);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      await room.closed.future;
      expect(room.ofType(LiveMessageType.system).map((message) => message.text), [
        BaiduliveDanmakuProtocol.endedDetail,
      ]);
      expect(clock.armedCount, isZero, reason: 'no poll is armed afterwards');
      final before = http.requests.length;
      clock.fireLast();
      await _settle();
      expect(http.requests, hasLength(before));
    });

    test('a list refused after its signature ran out ends the run as expired', () async {
      final wall = _Wall();
      final expiry = _at.add(const Duration(minutes: 1));
      final (room, clock, _) = _session(
        ['S40-chat-empty-then-401'],
        args: BaiduliveDanmakuArgs(roomId: _room, chatList: _chatList, expiresAt: expiry),
        wall: wall.read,
      );
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      clock.fireLast();
      await _settle();
      expect(room.closed.isCompleted, isFalse, reason: 'a refusal while the signature lives is a failure');
      expect(clock.lastArmed, BaiduliveDanmakuProtocol.backoff(1));

      wall.by(const Duration(minutes: 2));
      clock.fireLast();
      await _settle();
      await room.closed.future;
      expect(
        room.ofType(LiveMessageType.system).single.text,
        contains('Chat list signature expired'),
        reason: 'a refusal once it ran out will not mend itself',
      );
    });
  });

  group('stopping', () {
    test('disconnect ends a wait in flight and stops the polls', () async {
      final (room, clock, http) = _session(['S19-chat-empty']);
      addTearDown(room.dispose);

      await room.connect();
      await _settle();
      final before = http.requests.length;
      await room.session.disconnect();
      clock.fireLast();
      await _settle();
      expect(http.requests, hasLength(before), reason: 'the cancelled wait ends the loop quietly');
      expect(room.seen, isEmpty, reason: 'no notice for a poll the caller stopped');
      expect(room.closed.isCompleted, isFalse);

      await room.connect();
      await _settle();
      expect(http.requests, hasLength(before + 1), reason: 'and it joins again');
    });

    test('dispose ends the stream and leaves no timer armed', () async {
      final (room, clock, _) = _session(['S19-chat-empty']);
      await room.connect();
      await _settle();
      await room.session.dispose();
      await room.closed.future;
      expect(clock.armedCount, isZero);
      await room.session.dispose();
      await room.dispose();
    });

    test('a disposed session says so', () async {
      final (room, _, _) = _session(const []);
      await room.session.dispose();
      expect(await room.connect(), isA<LiveSiteUnsupported>());
      await room.dispose();
    });
  });
}

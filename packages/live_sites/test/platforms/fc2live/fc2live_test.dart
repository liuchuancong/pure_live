import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_anchor_provider.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_hot_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_web_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/built_in_sites.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_http.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_control.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku_codec.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku_session.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_json.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_play_parser.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_room_parser.dart';
import 'package:test/test.dart';

// One request as the fake transport records it.
typedef _Seen = ({String method, Uri url, Map<String, String> headers, String body});

/// The channel of the tests: the number of the 2026-09-27 capture.
const String _channel = '10608314';

/// Another channel, for the rules that need a second one.
const String _other = '11916060';

/// The fixed clock: when the platform's own samples were taken.
final DateTime _at = DateTime.utc(2026, 9, 27, 19, 37);

String _json(Object? value) => jsonEncode(value);

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

/// One row of `allchannellist.php`.
Map<String, Object?> _directoryRow(
  String id, {
  Object? type = 1,
  Object? category = 1,
  Object? name = 'Fixture owner',
  Object? title = 'Fixture game stream',
  Object? image = 'https://live-storage.fc2.com/thumb/10608314/thumb.jpg?fixture=1',
  Object? pay = 0,
  Object? login = 0,
  Object? tid = 0,
  Object? count = 61,
  Object? total = 1727,
  Object? startTime = 1789885361806,
}) => {
  'id': id,
  'type': type,
  'category': category,
  'name': name,
  'title': title,
  'image': image,
  'start_time': startTime,
  'pay': pay,
  'login': login,
  'tid': tid,
  'count': count,
  'total': total,
};

/// A directory answer of [rows].
String _directory(Object? rows, {Object? time = 1789980977}) => _json({'time': time, 'channel': rows});

/// The rows the reference recorded: three public channels (one of them ticketed)
/// and an open chat that is not a room.
String _directoryFixture() => _directory([
  _directoryRow(_channel),
  _directoryRow(_other, category: 9, name: 'Kitten radio', title: '24/7 Kitten audio', count: 3, total: 1279),
  _directoryRow('12000001', category: 5, name: 'Ticket room', image: '', tid: 7),
  _directoryRow('1', type: 0, title: '', image: ''),
]);

/// The `channel_data` of a member answer.
Map<String, Object?> _channelData({Map<String, Object?> set = const {}, Set<String> remove = const {}}) {
  final data = <String, Object?>{
    'channelid': _channel,
    'adult': 0,
    'title': 'Fixture game stream',
    'info': 'Fixture description',
    'image': 'https://live-storage.fc2.com/thumb/10608314/thumb.jpg',
    'login_only': 0,
    'fee': 0,
    'ticketid': 0,
    'ticket_only': 0,
    'is_limited': 0,
    'category': 1,
    'count': 61,
    'total': 1727,
    'is_publish': 1,
    'start': 1789885361806,
    'version': 'fixture-version',
    'tname': '',
    ...set,
  };
  remove.forEach(data.remove);
  return data;
}

/// The text of a `memberApi.php` answer.
String _memberJson({
  Map<String, Object?> set = const {},
  Set<String> remove = const {},
  Object? profile = const {'userid': 10608314, 'name': 'Fixture owner'},
  Object? status = 1,
}) => _json({
  'status': status,
  'data': {'channel_data': _channelData(set: set, remove: remove), 'profile_data': ?profile},
});

/// The member answer of the tests' channel.
Fc2LiveMember _member({
  Map<String, Object?> set = const {},
  Set<String> remove = const {},
  Object? profile = const {'userid': 10608314, 'name': 'Fixture owner'},
  Object? status = 1,
  int code = 200,
}) => Fc2LiveRoomParser.member(
  _memberJson(set: set, remove: remove, profile: profile, status: status),
  channelId: _channel,
  status: code,
);

/// The text of a `getControlServer.php` answer.
String _controlJson({Map<String, Object?> set = const {}, int status = 0}) => _json({
  'url': 'wss://us-west-1-media-worker1077.live.fc2.com/control/channels/$_channel',
  'orz': 'ignored.long.orz.value',
  'orz_raw': 'fixture_orz-token',
  'control_token': 'fixture-control-token',
  'status': status,
  ...set,
});

/// The grant of the tests' channel.
Fc2LiveGrant _grant({Map<String, Object?> set = const {}, int status = 0, String channel = _channel}) =>
    Fc2LivePlayParser.grant(
      _controlJson(set: set, status: status),
      channelId: channel,
    );

/// The master playlist of the synthetic answer.
String get _master => _playlist(0);

/// The address of mode [mode]: a master below 10, a variant from 10 up.
String _playlist(int mode) => mode < 10
    ? 'https://us-west-1-media.live.fc2.com/a/stream/$_channel/$mode/master_playlist?targets=10,20,30,90&c=cc&d=dd'
    : 'https://us-west-1-media.live.fc2.com/a/stream/$_channel/$mode/playlist?c=cc&d=dd';

/// A playlist row of [mode].
Map<String, Object?> _row(int mode, {Object? url, Object? status = 0}) => {
  'mode': mode,
  'status': status,
  'url': url ?? _playlist(mode),
};

/// The rows of the reference's S04 answer: tiers 10, 20 and 30 in all three
/// latency families, their masters, and the sound-only modes.
List<Object?> _s04Rows() => [
  for (final mode in [0, 1, 2, 10, 11, 12, 20, 21, 22, 30, 31, 32, 90, 91, 92]) _row(mode),
];

/// The HLS answer of a control.
Map<String, Object?> _hlsAnswer({
  Object? status = 0,
  List<Object?>? rows,
  Map<String, Object?> more = const {},
  String name = '_response_',
  Object? id = 1,
}) => {
  'name': name,
  'id': id,
  'arguments': {
    'status': status,
    'playlists': rows ?? [_row(0), _row(10)],
    'playlists_high_latency': <Object?>[],
    'playlists_middle_latency': <Object?>[],
    ...more,
  },
};

/// The HLS answer of [rows], by mode.
Map<int, Uri> _playlists({
  Object? status = 0,
  List<Object?>? rows,
  Map<String, Object?> more = const {},
  String channel = _channel,
}) => Fc2LivePlayParser.hlsPlaylists(
  _hlsAnswer(status: status, rows: rows, more: more),
  channelId: channel,
);

/// The playlists of a channel that offers tiers 10, 20 and 30.
Map<int, Uri> _offered() => _playlists(rows: _s04Rows());

/// One comment row of a `comment` message.
Map<String, Object?> _comment({
  Object? comment = 'hello',
  Object? user = 'Ann',
  Object? encrypted = 'a3456',
  Object? time = 1759000000000,
  Object? color,
  Object? anonymous,
  Object? history,
  Object? owner,
  Object? system,
  Object? orz,
}) => {
  'comment': comment,
  'user_name': user,
  'encrypted_user_id': encrypted,
  'timestamp': ?time,
  'color': ?color,
  'anonymous': ?anonymous,
  'history': ?history,
  'owner': ?owner,
  'system_comment': ?system,
  'orz_token': ?orz,
};

/// A control frame of [name].
String _frame(String name, {Object? arguments, Object? id}) =>
    _json({'name': name, 'id': ?id, 'arguments': ?arguments});

/// A `comment` frame of [rows].
String _commentsFrame(List<Object?> rows) => _frame('comment', arguments: {'comments': rows});

final class _FakeHttp implements LiveHttp {
  new(this.onSend);

  final LiveResponse Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    sent.add((
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: request.body ?? utf8.decode(request.bodyBytes ?? const <int>[]),
    ));
    return onSend(sent.last);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// The answers of a live, playable channel.
LiveResponse _ordinary(_Seen request) => switch (request.url.path) {
  '/contents/allchannellist.php' => _resp(200, _directoryFixture()),
  '/api/memberApi.php' => _resp(200, _memberJson()),
  '/api/getControlServer.php' => _resp(200, _controlJson()),
  _ => _resp(404, '{}'),
};

/// The site over a fake transport, with a fixed clock and no socket.
({Fc2LiveSite site, _FakeHttp http}) _adapter({
  LiveResponse Function(_Seen request)? onSend,
  Fc2LiveSocketConnect? connect,
  DateTime Function()? now,
}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (
    site: Fc2LiveSite(http: Fc2LiveHttp(http), connect: connect ?? _refuseSocket, now: now ?? () => _at),
    http: http,
  );
}

/// A connector that refuses: a test that needs a socket replaces it.
Future<Fc2LiveSocket> _refuseSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Duration connectTimeout,
}) async => throw StateError('no socket was asked for in this test');

/// The socket a test drives by hand.
final class _FakeSocket implements Fc2LiveSocket {
  final StreamController<Object?> _frames = StreamController<Object?>();
  final List<Object?> sent = [];
  int? _closeCode;
  bool closed = false;

  @override
  Stream<Object?> get frames => _frames.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  void send(String frame) => sent.add(frame);

  @override
  Future<void> close() async {
    closed = true;
  }

  /// One frame from the site.
  void push(Object? frame) => _frames.add(frame);

  /// The site closed the socket.
  Future<void> ended({int? code}) async {
    _closeCode = code;
    await _frames.close();
  }

  /// The text frames sent, for a search through them.
  String get sentText => sent.whereType<String>().join('\n');
}

/// A connector that hands back one socket, after the grant's address.
final class _Connector {
  new(this.socket, {this.answer = true});

  final _FakeSocket socket;
  final bool answer;
  final List<Uri> endpoints = [];
  final List<Map<String, String>> headers = [];

  Future<Fc2LiveSocket> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Duration connectTimeout,
  }) async {
    endpoints.add(endpoint);
    this.headers.add(headers);
    if (answer) {
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(Duration.zero);
          socket.push(_frame('connect_complete', arguments: const {}));
          await Future<void>.delayed(Duration.zero);
          socket.push(_json(_hlsAnswer(rows: _s04Rows())));
        }),
      );
    }
    return socket;
  }
}

/// A control socket that opens and answers with the tiers 10, 20 and 30.
({Fc2LiveSocketConnect connect, _Connector connector, _FakeSocket socket}) _controlSocket({bool answer = true}) {
  final socket = _FakeSocket();
  final connector = _Connector(socket, answer: answer);
  return (connect: connector.call, socket: socket, connector: connector);
}

/// A timer that never goes off: the watches are kept by [FakeTimers] instead.
final class _IdleTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

/// The watches a session or a control set, so a test can read them and ring
/// them by hand instead of waiting out the platform's own patience.
final class FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];
  final List<({Duration period, void Function(Timer timer) callback})> every = [];

  /// The seam a session takes.
  Fc2LiveTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  /// Rings the [index]th wait set with [after].
  void fire({int index = 0}) => after[index].callback();

  /// Rings the [index]th periodic watch.
  void ring({int index = 0}) => every[index].callback(_IdleTimer());
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The next [count] messages a session reports.
///
/// A session's events are live: a message with no listener is gone, so the
/// collector is started before a frame is pushed.
Future<List<LiveMessage>> _next(Stream<LiveMessage> events, int count) {
  final seen = <LiveMessage>[];
  final done = Completer<void>();
  late StreamSubscription<LiveMessage> subscription;
  subscription = events.listen((message) {
    seen.add(message);
    if (seen.length == count && !done.isCompleted) {
      done.complete();
      unawaited(subscription.cancel());
    }
  });
  return done.future.then((_) => seen);
}

/// A comment connection over a socket and clocks the test holds.
Future<({Fc2LiveDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector, _FakeHttp http})>
_chat({LiveResponse Function(_Seen request)? onSend}) async {
  final socket = _FakeSocket();
  final connector = _Connector(socket, answer: false);
  final timers = FakeTimers();
  final http = _FakeHttp(onSend ?? _ordinary);
  final session = Fc2LiveDanmakuSession(
    args: const Fc2LiveDanmakuArgs(_channel),
    site: Fc2LiveSite(http: Fc2LiveHttp(http), connect: connector.call, now: () => _at),
    timers: timers.timers,
  );
  await session.connect();
  return (session: session, socket: socket, timers: timers, connector: connector, http: http);
}

void main() {
  group('answers, ids and areas', () {
    test('a status says what kind of answer it is', () {
      expect(Fc2LiveJson.statusFailure(200, 'x'), isNull);
      expect(Fc2LiveJson.statusFailure(400, 'x')!.kind, Fc2LiveFailureKind.apiChanged);
      expect(Fc2LiveJson.statusFailure(422, 'x')!.kind, Fc2LiveFailureKind.apiChanged);
      expect(Fc2LiveJson.statusFailure(401, 'x')!.kind, Fc2LiveFailureKind.riskControl);
      expect(Fc2LiveJson.statusFailure(403, 'x')!.kind, Fc2LiveFailureKind.riskControl);
      expect(Fc2LiveJson.statusFailure(404, 'x')!.kind, Fc2LiveFailureKind.notFound);
      expect(Fc2LiveJson.statusFailure(429, 'x')!.kind, Fc2LiveFailureKind.rateLimited);
      for (final status in [301, 302, 500, 503]) {
        expect(Fc2LiveJson.statusFailure(status, 'x')!.kind, Fc2LiveFailureKind.network, reason: '$status');
      }
      expect('${Fc2LiveJson.statusFailure(503, 'memberApi')}', contains('memberApi: HTTP 503'));
    });

    test('an answer is JSON of a bounded size and an object', () {
      expect(Fc2LiveJson.object('{"a":1}', 'x'), {'a': 1});
      expect(() => Fc2LiveJson.object('<html>', 'x'), throwsA(predicate((e) => '$e'.contains('not JSON'))));
      expect(() => Fc2LiveJson.object('[]', 'x'), throwsA(predicate((e) => '$e'.contains('not an object'))));
      expect(() => Fc2LiveJson.object('"text"', 'x'), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveJson.object('', 'x'), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveJson.object('{}', 'x', status: 404), throwsA(isA<Fc2LiveFailure>()));
      expect(
        () => Fc2LiveJson.object('{"a":1}', 'x', status: 500),
        throwsA(predicate((e) => '$e'.contains('network: x: HTTP 500'))),
      );
      expect(
        () => Fc2LiveJson.object('{"a":"${'x' * (Fc2LiveEndpoints.responseLimit + 1)}"}', 'x'),
        throwsA(predicate((e) => '$e'.contains('over 4 MiB'))),
      );
      // A body of multi-byte characters is bounded by its bytes as well.
      final wide = '"あ"' * (Fc2LiveEndpoints.responseLimit ~/ 4);
      expect(() => Fc2LiveJson.object('[$wide]', 'x'), throwsA(predicate((e) => '$e'.contains('over 4 MiB'))));
    });

    test('numbers are read as the platform writes them', () {
      expect(Fc2LiveJson.integer(7, 'x'), 7);
      expect(Fc2LiveJson.integer(2.9, 'x'), 2);
      expect(Fc2LiveJson.integer(' -3 ', 'x'), -3);
      expect(Fc2LiveJson.integer('-1', 'x'), -1);
      for (final bad in ['x', null, true, double.nan, double.infinity, const <Object?, Object?>{}, 0x80000000]) {
        expect(() => Fc2LiveJson.integer(bad, 'count'), throwsA(isA<Fc2LiveFailure>()), reason: '$bad');
      }
      expect(Fc2LiveJson.integer(-0x7fffffff, 'x'), -0x7fffffff);
      expect(Fc2LiveJson.anyInteger(1 << 60, 'x'), 1 << 60);
      expect(() => Fc2LiveJson.anyInteger('x', 'x'), throwsA(isA<Fc2LiveFailure>()));
      expect(Fc2LiveJson.jsonInt('42'), 42);
      expect(Fc2LiveJson.jsonInt(4.5), isNull);
      expect(Fc2LiveJson.jsonInt(null), isNull);
    });

    test('counts, categories and times are read where the site is loose', () {
      expect(Fc2LiveJson.count(null, 'x'), isNull);
      expect(Fc2LiveJson.count(-4, 'x'), isNull);
      expect(Fc2LiveJson.count('0', 'x'), 0);
      expect(() => Fc2LiveJson.count(true, 'x'), throwsA(isA<Fc2LiveFailure>()));
      expect(Fc2LiveJson.category(99, 'x'), 99);
      for (final bad in [-1, 100, 'x']) {
        expect(() => Fc2LiveJson.category(bad, 'memberApi'), throwsA(isA<Fc2LiveFailure>()), reason: '$bad');
      }
      expect(Fc2LiveJson.startTime(1789885361806), DateTime.fromMillisecondsSinceEpoch(1789885361806, isUtc: true));
      for (final bad in [null, 0, -1, 946684800000 - 1, 4102444800000 + 1, 'x', 1.5]) {
        expect(Fc2LiveJson.startTime(bad), isNull, reason: '$bad');
      }
    });

    test('text is trimmed, collapsed, decoded and bounded', () {
      expect(Fc2LiveJson.text(null, 'x'), '');
      expect(Fc2LiveJson.text(' a\n\tb ', 'x'), 'a b');
      expect(() => Fc2LiveJson.text(7, 'x'), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveJson.text('x' * 65537, 'x'), throwsA(isA<Fc2LiveFailure>()));
      expect(Fc2LiveJson.displayText('a &lt;3 b &amp; c', 'x'), 'a <3 b & c');
      expect(Fc2LiveJson.displayText('a&#13;&#10;b', 'x'), 'a b');
      expect(Fc2LiveJson.displayText('&unknown;', 'x'), '&unknown;');
      expect(Fc2LiveJson.displayText('&#x4e2d;', 'x'), '中');
      expect(Fc2LiveJson.firstText(['', 'b', 'c']), 'b');
      expect(Fc2LiveJson.firstText(['', '']), '');
      expect(Fc2LiveJson.bounded('ok', 8, 'url'), 'ok');
      for (final bad in [null, '', 'x' * 9]) {
        expect(
          () => Fc2LiveJson.bounded(bad, 8, 'getControlServer url'),
          throwsA(isA<Fc2LiveFailure>()),
          reason: '$bad',
        );
      }
      expect(Fc2LiveJson.channelNumber(' 10608314 ', 'id'), _channel);
      for (final bad in [null, '', 'x', '010608314', '1' * 13, 10608314]) {
        expect(() => Fc2LiveJson.channelNumber(bad, 'id'), throwsA(isA<Fc2LiveFailure>()), reason: '$bad');
      }
      expect(Fc2LiveJson.optionalId(' 10608314 '), '10608314');
      expect(Fc2LiveJson.optionalId(''), isNull);
      expect(Fc2LiveJson.optionalId(10608314), '10608314', reason: 'a number is text too');
      expect(Fc2LiveJson.list(null), isEmpty);
      expect(Fc2LiveJson.list([1, 2]), [1, 2]);
    });

    test('an image is kept only when the platform serves it', () {
      expect(Fc2LiveJson.image('https://live-storage.fc2.com/thumb/a.jpg?x=1'), isNotEmpty);
      expect(Fc2LiveJson.image('https://fc2.com/a.jpg'), 'https://fc2.com/a.jpg');
      for (final bad in [
        '',
        null,
        'http://a.fc2.com/x.jpg',
        'https://evil.test/a.jpg',
        'https://evilfc2.com/a.jpg',
        'https://u@a.fc2.com/x.jpg',
        'https://a.fc2.com/x.jpg#frag',
        '//a.fc2.com/x.jpg',
      ]) {
        expect(Fc2LiveJson.image(bad), '', reason: '$bad');
      }
      expect(() => Fc2LiveJson.image(7), throwsA(isA<Fc2LiveFailure>()));
    });

    test('a host is the platform itself or a subdomain of it', () {
      for (final host in ['live.fc2.com', 'LIVE.FC2.COM', 'us-west-1-media.live.fc2.com']) {
        expect(Fc2LiveJson.isFc2Live(host), isTrue, reason: host);
      }
      for (final host in ['live.fc2.com.evil.test', 'evil.test', 'xlive.fc2.com', 'fc2.com', '']) {
        expect(Fc2LiveJson.isFc2Live(host), isFalse, reason: host);
      }
    });

    test('a channel is a number or a channel link', () {
      expect(Fc2LiveEndpoints.isChannelId(_channel), isTrue);
      for (final bad in ['', '0', '0123456', 'x', '1' * 13, ' 10608314 ']) {
        expect(Fc2LiveEndpoints.isChannelId(bad), isFalse, reason: bad);
      }
      expect(Fc2LiveRoomParser.channel(' 10608314 '), _channel);
      expect(Fc2LiveRoomParser.channel('http://live.fc2.com/10608314/'), _channel);
      expect(Fc2LiveRoomParser.channel('https://live.fc2.com/10608314/'), _channel);
      expect(Fc2LiveRoomParser.channel('https://live.fc2.com/ja/62996200/?utm_source=share'), '62996200');
      for (final url in [
        'https://live.fc2.com/',
        'https://live.fc2.com/rank/',
        'https://live.fc2.com/10608314/archive',
        'https://live.fc2.com.evil.test/10608314/',
        'https://u@live.fc2.com/10608314/',
        'https://live.fc2.com/10608314/#chat',
        'https://live.fc2.com/zh/10608314/extra',
        'https://live.fc2.com/xx/10608314/',
        'not a url',
      ]) {
        expect(Fc2LiveRoomParser.channelIdFromUrl(url), isNull, reason: url);
      }
      expect(Fc2LiveEndpoints.channelUrl(_channel), 'https://live.fc2.com/10608314/');
      expect(Fc2LiveRoomParser.requiredChannel(' $_other '), _other);
      expect(
        () => Fc2LiveRoomParser.requiredChannel('/rank/'),
        throwsA(predicate((e) => '$e'.contains('is not an FC2 channel'))),
      );
    });

    test('the areas are the platform own six, in its order', () {
      final areas = Fc2LiveRoomParser.areas();
      expect(areas.map((area) => area.areaId), ['all', '1', '2', '4', '9', '5']);
      expect(areas.map((area) => area.areaName), ['全部公开直播', '闲聊', '游戏 / 作业', '视频', '音频', '其他']);
      expect(areas.every((area) => area.platform == 'fc2live'), isTrue);
      expect(areas.first.parentAreaId, 'fc2live');
      expect(areas.first.parentAreaName, 'FC2 Live');
      expect(areas.map((area) => area.position), [0, 1, 2, 3, 4, 5]);
      expect(Fc2LiveRoomParser.areaFilter('all'), isNull);
      expect(Fc2LiveRoomParser.areaFilter(' 2 '), 2);
      for (final bad in ['0', '3', '6', 'x', '', '10', 'all2']) {
        expect(() => Fc2LiveRoomParser.areaFilter(bad), throwsA(isA<Fc2LiveFailure>()), reason: bad);
      }
      expect(
        () => Fc2LiveRoomParser.areaFilter('3'),
        throwsA(predicate((e) => '$e'.contains('is not an FC2 Live area'))),
      );
    });

    test('an area holds its category, and game / work holds two', () {
      Fc2LiveChannel of(int category) => Fc2LiveChannel(
        channelId: _channel,
        userName: '',
        title: '',
        cover: '',
        categoryId: category,
        state: Fc2LiveState.live,
      );
      expect(Fc2LiveRoomParser.inArea(of(3), 2), isTrue);
      expect(Fc2LiveRoomParser.inArea(of(3), 3), isTrue, reason: 'only areaFilter selects, and it has no 3');
      expect(Fc2LiveRoomParser.inArea(of(1), null), isTrue);
      expect(Fc2LiveRoomParser.inArea(of(8), 1), isFalse);
      expect(Fc2LiveEndpoints.areaName(1), '闲聊');
      expect(Fc2LiveEndpoints.areaName(3), '游戏 / 作业');
      expect(Fc2LiveEndpoints.areaName(0), '');
      expect(Fc2LiveEndpoints.areaName(8), '');
      expect(Fc2LiveEndpoints.legacyAreaName(3), 'Game / Work');
      expect(Fc2LiveEndpoints.legacyAreaName(7), 'FC2 Live');
      expect(of(9).categoryName, '音频');
      expect(Fc2LiveEndpoints.locales, contains('ja'));
      expect(Fc2LiveEndpoints.areaCategories, {1, 2, 4, 5, 9});
    });
  });

  group('directory', () {
    test('public rows become channels and other types are not', () {
      final channels = Fc2LiveRoomParser.directory(_directoryFixture());
      expect(channels.map((channel) => channel.channelId), [_channel, _other, '12000001']);
      final first = channels.first;
      expect(first.userName, 'Fixture owner');
      expect(first.title, 'Fixture game stream');
      expect(first.categoryName, '闲聊');
      expect(first.currentViewers, 61);
      expect(first.totalViewers, 1727);
      expect(first.cover, 'https://live-storage.fc2.com/thumb/10608314/thumb.jpg?fixture=1');
      expect(first.avatar, '');
      expect(first.description, '');
      expect(first.isAdult, isFalse);
      expect(first.restriction, LiveRestriction.none);
      expect(first.state, Fc2LiveState.live);
      expect(first.startedAt, DateTime.fromMillisecondsSinceEpoch(1789885361806, isUtc: true));
    });

    test('a restricted row is live and marked, in the platform order of marks', () {
      final channels = Fc2LiveRoomParser.directory(
        _directory([
          _directoryRow('1', pay: 1),
          _directoryRow('2', tid: 3),
          _directoryRow('3', login: 1),
          _directoryRow('4', login: 2),
          _directoryRow('5', pay: 1, login: 1),
          _directoryRow('6'),
        ]),
      );
      expect(channels.map((channel) => channel.restriction), [
        LiveRestriction.paid,
        LiveRestriction.paid,
        LiveRestriction.needsLogin,
        LiveRestriction.needsLogin,
        LiveRestriction.paid,
        LiveRestriction.none,
      ]);
      expect(channels.take(5).every((channel) => channel.state == Fc2LiveState.restricted), isTrue);
      expect(channels.last.state, Fc2LiveState.live);
      expect(Fc2LiveRoomParser.directoryRestriction(pay: 0, ticket: 0, login: 0), LiveRestriction.none);
    });

    test('a repeated channel is listed once', () {
      final channels = Fc2LiveRoomParser.directory(_directory([_directoryRow(_channel), _directoryRow(_channel)]));
      expect(channels, hasLength(1));
    });

    test('one unreadable row is skipped and all of them is api-changed', () {
      final broken = {..._directoryRow(_other), 'category': 'x'};
      final channels = Fc2LiveRoomParser.directory(_directory([_directoryRow(_channel), broken, 'not a row']));
      expect(channels.map((channel) => channel.channelId), [_channel]);
      expect(
        () => Fc2LiveRoomParser.directory(_directory([broken, 'not a row'])),
        throwsA(predicate((e) => '$e'.contains('none of 2 rows can be read'))),
      );
      expect(Fc2LiveRoomParser.directory(_directory(const [])), isEmpty);
    });

    test('the list itself must be there', () {
      expect(() => Fc2LiveRoomParser.directory(_directory([], time: 0)), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveRoomParser.directory(_directory([], time: 'x')), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveRoomParser.directory(_directory(null)), throwsA(isA<Fc2LiveFailure>()));
      expect(
        () => Fc2LiveRoomParser.directory(_directory([for (var i = 1; i <= 1001; i++) _directoryRow('$i')])),
        throwsA(isA<Fc2LiveFailure>()),
      );
      expect(() => Fc2LiveRoomParser.directory('{}'), throwsA(predicate((e) => '$e'.contains('allchannellist time'))));
      expect(
        () => Fc2LiveRoomParser.directory('{"time":1}'),
        throwsA(predicate((e) => '$e'.contains('allchannellist: no channel list'))),
      );
      expect(() => Fc2LiveRoomParser.directory('<html>'), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveRoomParser.directory(_directoryFixture(), status: 500), throwsA(isA<Fc2LiveFailure>()));
    });

    test('marks that must be numbers fail only their own row', () {
      for (final key in ['pay', 'login', 'tid', 'category', 'count', 'total', 'name', 'title']) {
        final row = {..._directoryRow(_channel), key: true};
        expect(
          () => Fc2LiveRoomParser.directory(_directory([row])),
          throwsA(isA<Fc2LiveFailure>()),
          reason: '$key as a boolean',
        );
        expect(
          Fc2LiveRoomParser.directory(_directory([row, _directoryRow(_other)])),
          hasLength(1),
          reason: '$key loses only its own row',
        );
      }
      for (final id in ['x', '', '0', 10608314]) {
        final row = {..._directoryRow(_channel), 'id': id};
        expect(
          Fc2LiveRoomParser.directory(_directory([row, _directoryRow(_other)])),
          hasLength(1),
          reason: 'an id of $id is not a channel',
        );
      }
    });

    test('a title falls back to the name and a count to nothing', () {
      final channels = Fc2LiveRoomParser.directory(
        _directory([
          _directoryRow(_channel, title: '', name: 'Only a name'),
          _directoryRow(_other, title: ' ', name: ' ', count: -1, total: null, image: ''),
        ]),
      );
      expect(channels.first.title, 'Only a name');
      expect(channels.last.title, '');
      expect(channels.last.userName, '');
      expect(channels.last.currentViewers, isNull);
      expect(channels.last.totalViewers, isNull);
      expect(channels.last.cover, '');
    });

    test('pages are sliced with the platform own limits', () {
      final values = [for (var i = 1; i <= 45; i++) '$i'];
      expect(Fc2LiveRoomParser.slice(values, page: 1, pageSize: 20).length, 20);
      expect(Fc2LiveRoomParser.slice(values, page: 3, pageSize: 20).length, 5);
      expect(Fc2LiveRoomParser.slice(values, page: 4, pageSize: 20), isEmpty);
      for (final (page, size) in [(0, 20), (-1, 20), (1, 0), (1, -5), (1, 101)]) {
        expect(
          Fc2LiveRoomParser.validSlice(page: page, pageSize: size),
          isFalse,
          reason: '$page/$size',
        );
        expect(
          Fc2LiveRoomParser.slice(values, page: page, pageSize: size),
          isEmpty,
          reason: '$page/$size',
        );
      }
      expect(Fc2LiveRoomParser.validSlice(page: 1, pageSize: 100), isTrue);
      expect(Fc2LiveRoomParser.validSlice(page: 1, pageSize: 1), isTrue);
    });
  });

  group('member and rooms', () {
    test('a live channel is read whole', () {
      final (:channel, :version) = _member();
      expect(version, 'fixture-version');
      expect(channel.channelId, _channel);
      expect(channel.userName, 'Fixture owner');
      expect(channel.title, 'Fixture game stream');
      expect(channel.description, 'Fixture description');
      expect(channel.cover, 'https://live-storage.fc2.com/thumb/10608314/thumb.jpg');
      expect(channel.avatar, '');
      expect(channel.categoryId, 1);
      expect(channel.currentViewers, 61);
      expect(channel.totalViewers, 1727);
      expect(channel.startedAt, DateTime.fromMillisecondsSinceEpoch(1789885361806, isUtc: true));
      expect(channel.restriction, LiveRestriction.none);
      expect(channel.state, Fc2LiveState.live);
      expect(channel.isAdult, isFalse);
      expect('$channel', 'Fc2LiveChannel(10608314, live)');
    });

    test('the name is the profile one, then the channel one', () {
      expect(_member(profile: {'userid': 1, 'name': ' Profile '}).channel.userName, 'Profile');
      expect(_member(profile: {'userid': 1}, set: {'tname': ' &amp; Title'}).channel.userName, '& Title');
      expect(_member(profile: null).channel.userName, '');
      final nameless = _member(profile: {'userid': 1, 'name': ''}, set: {'title': 'T'});
      expect(nameless.channel.userName, '');
      expect(nameless.channel.title, 'T');
      expect(_member(set: {'info': '   '}).channel.description, '');
      expect(_member(profile: {'userid': 1}, set: {'title': ' ', 'tname': 'Backup'}).channel.title, 'Backup');
    });

    test('the avatar is the profile picture and the cover fills in', () {
      final withIcon = _member(profile: {'userid': 1, 'icon': 'https://live.fc2.com/10608314/smallicon.png?1'});
      expect(withIcon.channel.avatar, 'https://live.fc2.com/10608314/smallicon.png?1');
      final both = _member(profile: {'userid': 1, 'icon': 'http://bad/x.png', 'image': 'https://live.fc2.com/a.png'});
      expect(both.channel.avatar, 'https://live.fc2.com/a.png');
      expect(
        Fc2LiveRoomParser.room(withIcon.channel).anchor?.avatarUrl,
        'https://live.fc2.com/10608314/smallicon.png?1',
      );
      expect(
        Fc2LiveRoomParser.room(_member().channel).anchor?.avatarUrl,
        'https://live-storage.fc2.com/thumb/10608314/thumb.jpg',
      );
      // A picture of the wrong type is simply no picture.
      expect(_member(profile: {'userid': 1, 'icon': const <Object?, Object?>{}}).channel.avatar, '');
      expect(
        _member(profile: {'userid': 1, 'image': 'https://x.fc2.com/b.png'}).channel.avatar,
        'https://x.fc2.com/b.png',
      );
    });

    test('an offline channel is offline, not a schema failure', () {
      final (:channel, :version) = _member(
        set: {'is_publish': 0, 'version': '', 'is_limited': 1, 'count': 0, 'start': 1789885361806},
      );
      expect(channel.state, Fc2LiveState.offline);
      expect(version, isNull);
      expect(channel.restriction, isNull);
      expect(channel.startedAt, isNull);
      expect(channel.currentViewers, 0);
      final room = Fc2LiveRoomParser.room(channel);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(room.broadcast.restriction, isNull);
      expect(room.broadcast.startedAt, isNull);
      expect(room.audience.onlineViewers, isNull);
      expect(room.audience.totalViewers, isNull);
      expect(room.content.notice, isNull);
      expect(room.anchor?.liveStatus, LiveStatus.offline);
      expect('$channel', 'Fc2LiveChannel(10608314, offline)');
      expect(room.broadcast.isPlayableNow, isFalse);
    });

    test('a restricted channel is live and says why', () {
      final cases = <Map<String, Object?>, LiveRestriction>{
        {'is_limited': 1}: LiveRestriction.unplayable,
        {'fee': 1}: LiveRestriction.paid,
        {'ticketid': 1}: LiveRestriction.paid,
        {'ticket_only': 1}: LiveRestriction.paid,
        {'login_only': 1}: LiveRestriction.needsLogin,
        {'login_only': 2}: LiveRestriction.needsLogin,
      };
      for (final entry in cases.entries) {
        final channel = _member(set: entry.key).channel;
        expect(channel.restriction, entry.value, reason: '${entry.key}');
        expect(channel.state, Fc2LiveState.restricted, reason: '${entry.key}');
      }
      expect(
        Fc2LiveRoomParser.memberRestriction(limited: 1, fee: 1, ticketId: 1, ticketOnly: 1, loginOnly: 1),
        LiveRestriction.unplayable,
      );
      expect(
        Fc2LiveRoomParser.memberRestriction(limited: 0, fee: 0, ticketId: 1, ticketOnly: 0, loginOnly: 1),
        LiveRestriction.paid,
      );
      final room = Fc2LiveRoomParser.room(_member(set: {'login_only': 1}).channel);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.needsLogin);
      expect(room.content.notice, Fc2LiveRoomParser.noticeText['restricted']);
    });

    test('adult is a mark and a notice, never a restriction', () {
      final channel = _member(set: {'adult': 1}).channel;
      expect(channel.isAdult, isTrue);
      expect(channel.restriction, LiveRestriction.none);
      final room = Fc2LiveRoomParser.room(channel);
      expect(room.content.notice, Fc2LiveRoomParser.noticeText['adult']);
      expect(room.content.platformTags, ['adult']);
      expect(room.broadcast.restriction, LiveRestriction.none);
      // A restricted adult room names the restriction: that is why it cannot be
      // watched.
      expect(
        Fc2LiveRoomParser.room(_member(set: {'adult': 1, 'fee': 1}).channel).content.notice,
        Fc2LiveRoomParser.noticeText['restricted'],
      );
      expect(Fc2LiveRoomParser.room(_member().channel).content.platformTags, isEmpty);
    });

    test('a channel that is not there is not-found, and so is one about another', () {
      expect(
        () => _member(status: 0),
        throwsA(predicate((e) => '$e'.contains('notFound: memberApi: no channel 10608314'))),
      );
      expect(() => _member(status: 'x'), throwsA(predicate((e) => '$e'.contains('apiChanged: memberApi status'))));
      expect(
        () => _member(profile: {'userid': '', 'name': 'Ghost'}),
        throwsA(predicate((e) => '$e'.contains('has no owner'))),
      );
      expect(
        () => _member(set: {'channelid': _other}),
        throwsA(predicate((e) => '$e'.contains('answered for channel 11916060, not 10608314'))),
      );
      expect(() => _member(code: 404), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveRoomParser.member('{"status":1}', channelId: _channel), throwsA(isA<Fc2LiveFailure>()));
      expect(() => Fc2LiveRoomParser.member('<html>', channelId: _channel), throwsA(isA<Fc2LiveFailure>()));
    });

    test('the flags, category and version must be what the site sends', () {
      for (final key in ['is_publish', 'fee', 'login_only', 'ticketid', 'ticket_only', 'is_limited', 'adult']) {
        expect(() => _member(set: {key: 'x'}), throwsA(predicate((e) => '$e'.contains('memberApi $key'))), reason: key);
      }
      expect(() => _member(set: {'category': 100}), throwsA(isA<Fc2LiveFailure>()));
      expect(() => _member(set: {'version': 'x' * 257}), throwsA(isA<Fc2LiveFailure>()));
      expect(() => _member(set: {'channelid': 10608314}), throwsA(isA<Fc2LiveFailure>()));
      expect(() => _member(remove: {'channelid'}), throwsA(isA<Fc2LiveFailure>()));
      expect(
        () => Fc2LiveRoomParser.member(
          _json({
            'status': 1,
            'data': <String, Object?>{'profile_data': <String, Object?>{}},
          }),
          channelId: _channel,
        ),
        throwsA(isA<Fc2LiveFailure>()),
      );
      expect(() => _member(profile: 'not an object'), throwsA(isA<Fc2LiveFailure>()));
      expect(() => _member(set: {'title': 7}), throwsA(isA<Fc2LiveFailure>()));
      // A profile that is simply absent is a channel with no profile.
      expect(_member(profile: null).channel.userName, '');
    });

    test('a room carries its area, link, audience and handles', () {
      final channel = _member(set: {'category': 9}).channel;
      final room = Fc2LiveRoomParser.room(channel, danmaku: true);
      expect(room.platform, 'fc2live');
      expect(room.roomId, _channel);
      expect(room.identityKey, 'fc2live:10608314');
      expect(room.content.title, 'Fixture game stream');
      expect(room.content.introduction, 'Fixture description');
      expect(room.content.coverUrl, 'https://live-storage.fc2.com/thumb/10608314/thumb.jpg');
      expect(room.anchor?.anchorId, _channel);
      expect(room.anchor?.name, 'Fixture owner');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.area?.areaId, '9');
      expect(room.area?.areaName, '音频');
      expect(room.area?.parentAreaId, 'fc2live');
      expect(room.area?.parentAreaName, 'FC2 Live');
      expect(room.audience.onlineViewers, 61);
      expect(room.audience.totalViewers, 1727);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.links.webUrl, 'https://live.fc2.com/10608314/');
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1789885361806, isUtc: true));
      expect(room.runtime.danmakuHandle, const Fc2LiveDanmakuArgs(_channel));
      final data = room.runtime.streamHandle! as Fc2LiveRoomData;
      expect(data.channelId, _channel);
      expect(data.categoryId, 9);
      expect(data.state, Fc2LiveState.live);
      expect(data.restriction, LiveRestriction.none);
      expect(data.isAdult, isFalse);
      expect('$data', 'Fc2LiveRoomData(10608314, live)');
      // Without `danmaku` the room has no chat handle: a refresh must not tear
      // a live chat down.
      expect(Fc2LiveRoomParser.room(channel).runtime.danmakuHandle, isNull);
      expect(const Fc2LiveDanmakuArgs(_channel), const Fc2LiveDanmakuArgs(_channel));
      expect(const Fc2LiveDanmakuArgs(_channel).hashCode, const Fc2LiveDanmakuArgs(_channel).hashCode);
      expect(const Fc2LiveDanmakuArgs(_other), isNot(const Fc2LiveDanmakuArgs(_channel)));
      expect('${const Fc2LiveDanmakuArgs(_channel)}', 'Fc2LiveDanmakuArgs(10608314)');
    });

    test('a room with no viewer figure says so rather than zero', () {
      final room = Fc2LiveRoomParser.room(_member(set: {'count': null}).channel);
      expect(room.audience.onlineViewers, isNull);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.live);
    });

    test('a refusal names the restriction, and an open room has none', () {
      expect(Fc2LiveRoomParser.refusal(null, _channel), isNull);
      expect(Fc2LiveRoomParser.refusal(LiveRestriction.none, _channel), isNull);
      expect(Fc2LiveRoomParser.refusal(LiveRestriction.needsLogin, _channel)!.kind, Fc2LiveFailureKind.needsLogin);
      expect(
        Fc2LiveRoomParser.refusal(LiveRestriction.paid, _channel)!.message,
        'channel 10608314 is a paid or ticketed broadcast',
      );
      expect(
        Fc2LiveRoomParser.refusal(LiveRestriction.unplayable, _channel)!.message,
        contains('restricted by FC2 (配信規制中)'),
      );
      expect(
        Fc2LiveRoomParser.refusal(LiveRestriction.regionBlocked, _channel)!.message,
        contains('restricted (regionBlocked)'),
      );
    });

    test('search matches what the directory shows', () {
      final channels = Fc2LiveRoomParser.directory(_directoryFixture());
      expect(Fc2LiveRoomParser.search(channels, ' kitten ').map((c) => c.channelId), [_other], reason: 'the owner');
      expect(Fc2LiveRoomParser.search(channels, 'AUDIO').map((c) => c.channelId), [_other], reason: 'the title');
      // A keyword that is only part of a channel number still finds it: that is the
      // site's own substring behaviour, not a prefix match.
      expect(Fc2LiveRoomParser.search(channels, '2000').map((c) => c.channelId), contains('12000001'));
      expect(Fc2LiveRoomParser.search(channels, '1191').map((c) => c.channelId), contains(_other));
      expect(Fc2LiveRoomParser.search(channels, '闲聊').length, 1, reason: 'the area name the platform writes');
      expect(Fc2LiveRoomParser.search(channels, 'idle chat').length, 1, reason: 'the English name 3.x wrote');
      expect(Fc2LiveRoomParser.search(channels, 'ticket room').length, 1);
      expect(Fc2LiveRoomParser.search(channels, '   '), isEmpty);
      expect(Fc2LiveRoomParser.search(channels, 'no such thing'), isEmpty);
      expect(Fc2LiveRoomParser.search(channels, '10608314').length, 1);
    });
  });
  group('grant, playlists and the control socket', () {
    test('a grant is the control socket of its own channel', () {
      final grant = _grant();
      expect(grant.channelId, _channel);
      expect(grant.socket.toString(), 'wss://us-west-1-media-worker1077.live.fc2.com/control/channels/10608314');
      expect(grant.controlToken, 'fixture-control-token');
      expect(grant.orz, 'fixture_orz-token');
      expect(
        grant.endpoint.toString(),
        'wss://us-west-1-media-worker1077.live.fc2.com/control/channels/10608314?control_token=fixture-control-token',
      );
      expect(grant.handshakeHeaders, {
        'origin': 'https://live.fc2.com',
        'user-agent': Fc2LiveEndpoints.userAgent,
        'cookie': 'l_ortkn=fixture_orz-token',
      });
      expect('$grant', 'Fc2LiveGrant(10608314, us-west-1-media-worker1077.live.fc2.com)');
    });

    test('a grant that says no, or names another channel, is refused', () {
      expect(
        () => _grant(status: 1),
        throwsA(predicate((e) => '$e'.contains('streamUnavailable: getControlServer: status 1'))),
      );
      expect(
        () => _grant(channel: _other),
        throwsA(predicate((e) => '$e'.contains('not a control socket of the channel'))),
      );
      expect(
        () => Fc2LivePlayParser.grant('{"status":0}', channelId: _channel),
        throwsA(predicate((e) => '$e'.contains('getControlServer url: missing or too long'))),
      );
      expect(() => Fc2LivePlayParser.grant('<html>', channelId: _channel), throwsA(isA<Fc2LiveFailure>()));
      expect(
        () => Fc2LivePlayParser.grant(_controlJson(), channelId: _channel, status: 500),
        throwsA(isA<Fc2LiveFailure>()),
      );
    });

    test('a socket, token or cookie outside its shape is api-changed', () {
      for (final set in [
        {'url': 'http://us-west-1.live.fc2.com/control/channels/10608314'},
        {'url': 'wss://live.fc2.com.evil.test/control/channels/10608314'},
        {'url': 'wss://live.fc2.com/control/channels/10608314/extra'},
        {'url': 'wss://u@live.fc2.com/control/channels/10608314'},
        {'url': 'wss://live.fc2.com/control/channels/10608314?x=1'},
        {'url': 'wss://live.fc2.com/control/channels/10608314#frag'},
        {'url': 'wss://live.fc2.com/other/10608314'},
        {'url': 'wss://live.fc2.com/control/channels/11916060'},
        {'url': 'wss://live.fc2.com/control/channels/10608314${'?x' * 2000}'},
        {'orz_raw': ''},
        {'orz_raw': 'a;b'},
        {'orz_raw': 'x' * 257},
        {'control_token': ''},
        {'control_token': 'x' * 4097},
      ]) {
        expect(() => _grant(set: set), throwsA(isA<Fc2LiveFailure>()), reason: '$set');
      }
    });

    test('the HLS answer must be the reply to the one request', () {
      expect(_playlists(), {0: Uri.parse(_master), 10: Uri.parse(_playlist(10))});
      expect(
        () => Fc2LivePlayParser.hlsPlaylists({'name': '_response_', 'id': 2}, channelId: _channel),
        throwsA(predicate((e) => '$e'.contains('not the answer to get_hls_information'))),
      );
      expect(
        () => Fc2LivePlayParser.hlsPlaylists({'name': 'comment', 'id': 1}, channelId: _channel),
        throwsA(isA<Fc2LiveFailure>()),
      );
      expect(
        () => _playlists(status: 2),
        throwsA(predicate((e) => '$e'.contains('streamUnavailable: get_hls_information: status 2'))),
      );
      expect(() => _playlists(status: 'x'), throwsA(isA<Fc2LiveFailure>()));
      expect(() => _playlists(rows: const []), throwsA(predicate((e) => '$e'.contains('control: no playlist'))));
      expect(
        () => Fc2LivePlayParser.hlsPlaylists({
          'name': '_response_',
          'id': 1,
          'arguments': 'not an object',
        }, channelId: _channel),
        throwsA(isA<Fc2LiveFailure>()),
      );
      expect(
        () => Fc2LivePlayParser.hlsPlaylists({'name': '_response_', 'id': 1}, channelId: _channel),
        throwsA(isA<Fc2LiveFailure>()),
      );
    });

    test('a playlist must be of its channel, on the platform, with its tokens', () {
      for (final url in [
        'http://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=cc&d=dd',
        'https://evil.test/a/stream/10608314/10/playlist?c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/11916060/10/playlist?c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/11/playlist?c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/master_playlist?c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/playlist?c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=cc',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=cc&d=dd&x=1',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=${'c' * 1025}&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/master_playlist?targets=&c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/master_playlist?c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/master_playlist?targets=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17&c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/master_playlist?targets=${'1,' * 40}1&c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/master_playlist?targets=10,abc&c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/master_playlist?targets=${'9' * 129}&c=cc&d=dd',
        'https://u@us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=cc&d=dd',
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=cc&d=dd#frag',
        '',
        'x' * 65537,
        'https://us-west-1-media.live.fc2.com/a/stream/10608314/10/playlist?c=%&d=dd',
      ]) {
        expect(
          _playlists(rows: [_row(10, url: url)]),
          isEmpty,
          reason: url,
        );
      }
      expect(_playlists(rows: [_row(1)])[1], isNotNull, reason: 'a master of another family');
      expect(
        _playlists(rows: [_row(0, url: _playlist(0).replaceAll('targets=10,20,30,90&', ''))])[0],
        isNull,
        reason: 'a master names the tiers it serves',
      );
      expect(_playlists(rows: [_row(9)])[9], isNotNull, reason: 'mode 9 is still a master');
      expect(_playlists(rows: [_row(999)])[999], isNotNull, reason: 'a mode up to 999');
    });

    test('a bad row or family loses only itself', () {
      final playlists = _playlists(
        rows: [
          _row(10),
          'not a row',
          _row(20, url: 'https://evil.test/x'),
          _row(30, status: 1),
          {'mode': 'x', 'status': 0, 'url': _playlist(40)},
          {'url': _playlist(50)},
          _row(50),
          {'mode': -1, 'status': 0, 'url': _playlist(10)},
          {'mode': 1000, 'status': 0, 'url': _playlist(10)},
        ],
        more: {
          'playlists_high_latency': [_row(11)],
        },
      );
      expect(playlists.keys, [10, 11, 50]);
    });

    test('a family of more than 32 rows is skipped whole', () {
      final playlists = _playlists(
        rows: [_row(10)],
        more: {
          'playlists_high_latency': [for (var i = 0; i <= 32; i++) _row(11)],
        },
      );
      expect(playlists.keys, [10]);
    });

    test('the first row of a mode wins, whatever family it came from', () {
      final playlists = _playlists(
        rows: [_row(10)],
        more: {
          'playlists_high_latency': [
            _row(10, url: 'https://a.live.fc2.com/a/stream/10608314/10/playlist?c=c&d=d'),
            _row(11),
          ],
          'playlists_middle_latency': [_row(10, url: 'https://b.live.fc2.com/a/stream/10608314/10/playlist?c=c&d=d')],
        },
      );
      expect(playlists[10].toString(), _playlist(10));
      expect(playlists[11].toString(), 'https://a.live.fc2.com/a/stream/10608314/11/playlist?c=c&d=d');
    });

    test('a channel offers the tiers its answer holds, plus auto', () {
      expect(Fc2LivePlayParser.qualitiesOf(_offered()).map((q) => q.qualityId), ['30', '20', '10', 'auto']);
      expect(Fc2LivePlayParser.qualitiesOf(_playlists()).map((q) => q.qualityId), ['10', 'auto']);
      expect(Fc2LivePlayParser.qualitiesOf(_playlists(rows: [_row(0)])).map((q) => q.qualityId), ['auto']);
      expect(
        Fc2LivePlayParser.qualitiesOf({
          for (final mode in [0, 10, 11, 12, 20, 21, 22, 30, 31, 32, 40, 50]) mode: Uri.parse(_playlist(mode)),
        }).map((q) => q.qualityId),
        ['50', '40', '30', '20', '10', 'auto'],
      );
      // One family is enough for a tier; sound-only is no quality at all.
      expect(Fc2LivePlayParser.qualitiesOf({12: Uri.parse(_playlist(12))}).map((q) => q.qualityId), ['10']);
      expect(Fc2LivePlayParser.qualitiesOf({90: Uri.parse(_playlist(90))}), isEmpty);
      expect(Fc2LivePlayParser.qualitiesOf(const {}), isEmpty);
      final ranked = Fc2LivePlayParser.qualitiesOf(_offered());
      expect(ranked.map((q) => q.platformOrder), [4, 3, 2, 1], reason: 'best first');
      expect(ranked.last.label, '自适应 HLS');
      expect(ranked.first.label, '高清');
      expect(ranked.first.codec, isNull, reason: 'the control names no codec');
      expect(ranked.first.isPlaybackUnconfirmed, isFalse);
      expect(Fc2LivePlayParser.tierQualities.map((q) => q.qualityId), ['50', '40', '30', '20', '10']);
      expect(Fc2LivePlayParser.menu.length, 6);
      expect(Fc2LivePlayParser.qualityIds, {'50', '40', '30', '20', '10', 'auto'});
    });

    test('a tier plays its high-latency variant, and falls back near its ask', () {
      Map<int, Uri> ofModes(Iterable<int> modes) => {for (final mode in modes) mode: Uri.parse(_playlist(mode))};
      expect(Fc2LivePlayParser.playlistFor(ofModes([30, 31, 32]), '30')!.url.toString(), _playlist(31));
      expect(Fc2LivePlayParser.playlistFor(ofModes([30, 32]), '30')!.url.toString(), _playlist(30));
      expect(Fc2LivePlayParser.playlistFor(ofModes([32]), '30')!.url.toString(), _playlist(32));
      expect(Fc2LivePlayParser.playlistFor(ofModes([20, 21]), '30')!.url.toString(), _playlist(21), reason: 'downward');
      expect(
        Fc2LivePlayParser.playlistFor(ofModes([40, 41, 20, 21]), '30')!.url.toString(),
        _playlist(21),
        reason: 'the nearer tier below',
      );
      expect(
        Fc2LivePlayParser.playlistFor(ofModes([40, 50, 41, 51]), '30')!.url.toString(),
        _playlist(41),
        reason: 'the nearer tier above',
      );
      expect(Fc2LivePlayParser.playlistFor(ofModes([10]), '30')!.url.toString(), _playlist(11));
      expect(Fc2LivePlayParser.playlistFor(ofModes([0, 10]), '50')!.url.toString(), _master, reason: 'a master last');
      expect(Fc2LivePlayParser.playlistFor(ofModes([0, 1, 2]), 'auto')!.url.toString(), _master);
      expect(Fc2LivePlayParser.playlistFor(ofModes([1]), 'auto')!.url.toString(), _playlist(1));
      expect(
        Fc2LivePlayParser.playlistFor(ofModes([20, 30]), 'auto')!.url.toString(),
        _playlist(31),
        reason: 'best tier',
      );
      expect(Fc2LivePlayParser.playlistFor(ofModes([90]), 'auto'), isNull);
      expect(Fc2LivePlayParser.playlistFor(ofModes([90]), '30'), isNull);
      for (final bad in ['', '60', 'original', '31', '030', '5', 'auto2', '30 ']) {
        expect(Fc2LivePlayParser.playlistFor(ofModes([0, 10, 20, 30, 40, 50]), bad), isNull, reason: bad);
      }
      expect(Fc2LivePlayParser.playlistFor(ofModes([30]), '30')!.quality, '30');
      expect(Fc2LivePlayParser.playlistFor(ofModes([30]), '50')!.quality, '30', reason: 'what plays is named');
    });

    test('a line is the playlist, its headers, and the rest of its grant', () {
      final lines = Fc2LivePlayParser.lines(
        (quality: '30', url: Uri.parse(_playlist(30))),
        channelId: _channel,
        issuedAt: _at,
      );
      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line.url, _playlist(30));
      expect(line.format, LiveStreamFormat.hls);
      expect(line.formatSource, LivePlayFormatSource.declared, reason: 'the address has no suffix to infer from');
      expect(line.headers, {
        'user-agent': Fc2LiveEndpoints.userAgent,
        'origin': 'https://live.fc2.com',
        'referer': 'https://live.fc2.com/10608314/',
      });
      expect(line.codec, isNull);
      expect(line.lineLabel, '30');
      expect(line.singleUse, isFalse, reason: 'the address is read again while its control lives');
      expect(line.lease!.expiresAt, _at.add(Fc2LiveEndpoints.controlLife));
      expect(line.lease!.refreshAt, _at.add(Fc2LiveEndpoints.controlLife).subtract(Fc2LivePlayParser.renewLead));
      expect(line.lease!.requiresReconnect, isTrue);
      expect(Fc2LiveEndpoints.controlLife, const Duration(minutes: 1));
      expect(
        Fc2LivePlayParser.lines(
          (quality: 'auto', url: Uri.parse(_master)),
          channelId: _channel,
          issuedAt: _at,
          life: const Duration(seconds: 8),
        ).single.lease!.refreshAt,
        _at.add(const Duration(seconds: 2)),
      );
    });

    test('a control opens on the HLS answer and names its playlists', () async {
      final opened = _controlSocket();
      final control = await Fc2LiveControl.open(
        _grant(),
        connect: opened.connect,
        startupTimeout: const Duration(seconds: 5),
      );
      expect(control.channelId, _channel);
      expect(control.playlists.keys, containsAll([10, 20, 30, 0]));
      expect(control.playlist.quality, 'auto');
      expect(control.playlist.url.toString(), _master);
      expect(control.requestedQuality, 'auto');
      expect(control.mediaHeaders['referer'], 'https://live.fc2.com/10608314/');
      expect(control.isClosed, isFalse);
      expect(opened.connector.endpoints.single.toString(), _grant().endpoint.toString());
      expect(opened.connector.headers.single['cookie'], 'l_ortkn=fixture_orz-token');
      expect(opened.socket.sentText, contains(Fc2LiveControl.hlsRequest));
      expect(
        opened.socket.sent.where((frame) => '$frame'.contains('get_hls_information')),
        hasLength(1),
        reason: 'the request is made exactly once',
      );
      await control.close();
      expect(control.isClosed, isTrue);
      expect(await control.done, isNull);
      expect(opened.socket.closed, isTrue);
    });

    test('a tier asked of the control plays its own variant', () async {
      final opened = _controlSocket();
      final control = await Fc2LiveControl.open(_grant(), connect: opened.connect, quality: '20');
      expect(control.requestedQuality, '20');
      expect(control.playlist.quality, '20');
      expect(control.playlist.url.toString(), _playlist(21));
      await control.close();
    });

    test('a control that never gets its answer gives up on its deadline', () async {
      final silent = _controlSocket(answer: false);
      var fired = 0;
      final waiting = Fc2LiveControl.open(
        _grant(),
        connect: silent.connect,
        timer: (delay, callback) {
          fired += 1;
          expect(delay, const Duration(seconds: 20));
          callback();
          return _IdleTimer();
        },
      );
      await expectLater(waiting, throwsA(predicate((e) => '$e'.contains('no HLS information within 20 s'))));
      expect(fired, 1);
      expect(silent.socket.closed, isTrue);
    });

    test('a control with no playlist for its quality never opens', () async {
      final opened = _controlSocket(answer: false);
      final waiting = Fc2LiveControl.open(_grant(), connect: opened.connect, quality: '50');
      await Future<void>.delayed(Duration.zero);
      opened.socket.push(_frame('connect_complete', arguments: const {}));
      opened.socket.push(_json(_hlsAnswer(rows: [_row(10)])));
      await expectLater(waiting, throwsA(predicate((e) => '$e'.contains('no playlist for 50'))));
    });

    test('a quality the platform has no name for asks for nothing', () async {
      final opened = _controlSocket();
      await expectLater(
        Fc2LiveControl.open(_grant(), connect: opened.connect, quality: '1080p'),
        throwsA(predicate((e) => '$e'.contains('not an FC2 Live quality'))),
      );
      expect(opened.connector.endpoints, isEmpty);
      expect(opened.socket.sent, isEmpty);
    });

    test('a handshake that fails names no secret of the grant', () async {
      Future<Fc2LiveSocket> connect(
        Uri endpoint, {
        required Map<String, String> headers,
        required Duration connectTimeout,
      }) async => throw StateError('handshake of $endpoint failed');
      await expectLater(
        Fc2LiveControl.open(_grant(), connect: connect),
        throwsA(predicate((e) => '$e'.contains('control handshake: StateError'))),
      );
      await expectLater(
        Fc2LiveControl.open(_grant(), connect: connect),
        throwsA(predicate((e) => !'$e'.contains('fixture-control-token'))),
      );
    });

    test('a frame a control cannot read ends it', () async {
      for (final frame in [
        7,
        [1, 2],
        'nope',
        '[]',
        '"text"',
        '{"name":7}',
        'x' * 4000,
      ]) {
        final opened = _controlSocket(answer: false);
        final waiting = Fc2LiveControl.open(_grant(), connect: opened.connect);
        await Future<void>.delayed(Duration.zero);
        opened.socket.push(_frame('connect_complete', arguments: const {}));
        opened.socket.push(frame);
        await expectLater(waiting, throwsA(isA<Fc2LiveFailure>()), reason: '$frame');
        expect(opened.socket.closed, isTrue, reason: '$frame');
      }
    });

    test('a disconnection ends the control, with the site code', () async {
      final opened = _controlSocket(answer: false);
      final waiting = Fc2LiveControl.open(_grant(), connect: opened.connect);
      await Future<void>.delayed(Duration.zero);
      opened.socket.push(_frame('control_disconnection', arguments: {'code': 4500}));
      await expectLater(waiting, throwsA(predicate((e) => '$e'.contains('control_disconnection 4500'))));
      expect(opened.socket.closed, isTrue);
    });

    test('a socket the site closes ends the control', () async {
      final opened = _controlSocket(answer: false);
      final waiting = Fc2LiveControl.open(_grant(), connect: opened.connect);
      await Future<void>.delayed(Duration.zero);
      await opened.socket.ended(code: 1006);
      await expectLater(waiting, throwsA(predicate((e) => '$e'.contains('closed by the server (1006)'))));
    });

    test('an open control keeps its playlists until the site ends it', () async {
      final opened = _controlSocket();
      final control = await Fc2LiveControl.open(_grant(), connect: opened.connect);
      // Frames after the answer grant nothing to a control.
      opened.socket.push(_frame('user_count', arguments: {'pc_user_count': 9}));
      opened.socket.push(_frame('control_disconnection', arguments: {'code': 1000}));
      await Future<void>.delayed(Duration.zero);
      expect(control.playlist.quality, 'auto');
      expect(await control.done, isNotNull, reason: 'the disconnection still ended it');
      expect(control.playlists, isNotEmpty);
      expect(control.isClosed, isTrue);
    });

    test('closing twice is one close', () async {
      final opened = _controlSocket();
      final control = await Fc2LiveControl.open(_grant(), connect: opened.connect);
      await control.close();
      await control.close();
      expect(await control.done, isNull);
    });
  });
  group('chat protocol', () {
    test('a frame is text or bytes, and junk costs only that frame', () {
      expect(Fc2LiveDanmakuCodec.decode(_commentsFrame(const []))!.name, 'comment');
      expect(Fc2LiveDanmakuCodec.decode(utf8.encode(_frame('user_count')))!.name, 'user_count');
      expect(Fc2LiveDanmakuCodec.decode('nope'), isNull);
      expect(Fc2LiveDanmakuCodec.decode('[]'), isNull);
      expect(Fc2LiveDanmakuCodec.decode('"text"'), isNull);
      expect(Fc2LiveDanmakuCodec.decode('{}'), isNull, reason: 'a frame with no name');
      expect(Fc2LiveDanmakuCodec.decode('{"name":7}'), isNull);
      expect(Fc2LiveDanmakuCodec.decode(null), isNull);
      expect(Fc2LiveDanmakuCodec.decode(7), isNull);
      expect(Fc2LiveDanmakuCodec.decode('x' * (Fc2LiveEndpoints.messageLimit + 1)), isNull);
      expect(Fc2LiveDanmakuCodec.decode(utf8.encode('x' * (Fc2LiveEndpoints.messageLimit + 1))), isNull);
      expect(Fc2LiveDanmakuCodec.decode(_frame('comment'))!.arguments, isEmpty);
      expect(Fc2LiveDanmakuCodec.decode(_frame('comment', arguments: [1]))!.arguments, isEmpty);
      expect(Fc2LiveDanmakuCodec.decode(_frame('comment', arguments: const {}))!.arguments, isEmpty);
      expect(Fc2LiveDanmakuCodec.decode(_frame('x', id: 12))!.id, 12);
      expect(Fc2LiveDanmakuCodec.decode('{"name":"x","arguments":{"a":1}}')!.arguments, {'a': 1});
    });

    test('the heartbeat is the page command and the address is the grant', () {
      expect(Fc2LiveDanmakuCodec.heartbeat(3), '{"name":"heartbeat","arguments":{},"id":3}');
      expect(
        Fc2LiveDanmakuCodec.endpoint(_channel).toString(),
        'https://live.fc2.com/api/getControlServer.php?channel_id=10608314',
      );
      expect(Fc2LiveDanmakuCodec.channelOf(Fc2LiveDanmakuCodec.endpoint(_channel)), _channel);
      for (final bad in [
        'https://live.fc2.com/api/getControlServer.php',
        'https://live.fc2.com/api/getControlServer.php?channel_id=10608314&x=1',
        'https://live.fc2.com/api/getControlServer.php?channel_id=x',
        'https://live.fc2.com/api/getControlServer.php?other=10608314',
        'https://evil.test/api/getControlServer.php?channel_id=10608314',
        'wss://live.fc2.com/api/getControlServer.php?channel_id=10608314',
        'https://live.fc2.com/other?channel_id=10608314',
      ]) {
        expect(Fc2LiveDanmakuCodec.channelOf(Uri.parse(bad)), isNull, reason: bad);
      }
    });

    test('a comment reads as the page shows it', () {
      final message = Fc2LiveDanmakuCodec.comment(_comment())!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.effectiveSender.userName, 'Ann');
      expect(message.effectiveSender.userId, 'id-101-102-103-104');
      expect(message.messageId, isEmpty, reason: 'the site names no comment');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1759000000000));
      expect(message.color, LiveMessageColor.white);
      expect(message.replayed, isFalse);
      expect(message.emotes, isEmpty);
      expect(message.sender?.avatarUrl, isNull);
    });

    test('anonymous, blank and replayed comments show nothing', () {
      for (final anonymous in [1, true, '1']) {
        expect(
          Fc2LiveDanmakuCodec.comment(_comment(anonymous: anonymous))!.effectiveSender.userName,
          '[anonymous]',
          reason: '$anonymous',
        );
      }
      expect(Fc2LiveDanmakuCodec.comment(_comment(anonymous: '0'))!.effectiveSender.userName, 'Ann');
      expect(Fc2LiveDanmakuCodec.comment(_comment(anonymous: 2))!.effectiveSender.userName, 'Ann');
      expect(Fc2LiveDanmakuCodec.comment(_comment(user: ''))!.effectiveSender.userName, '[anonymous]');
      expect(Fc2LiveDanmakuCodec.comment(_comment(user: ' <b>Ann</b> '))!.effectiveSender.userName, 'Ann');
      expect(Fc2LiveDanmakuCodec.comment(_comment(history: 1)), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(history: '1')), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(history: true)), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(history: 0)), isNotNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(system: {'type': 'tip'})), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(comment: '   ')), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(comment: '<br>')), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(comment: 7)), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(comment: null)), isNull);
      expect(Fc2LiveDanmakuCodec.comment('not a row'), isNull);
      expect(Fc2LiveDanmakuCodec.comment(null), isNull);
      expect(Fc2LiveDanmakuCodec.comment(_comment(user: null))!.effectiveSender.userName, '[anonymous]');
    });

    test('text is cleaned the way the page cleans it', () {
      expect(Fc2LiveDanmakuCodec.plainText('a &lt;3 b &amp; c'), 'a <3 b & c');
      expect(Fc2LiveDanmakuCodec.plainText('<span class="x">hi</span><br>there'), 'hithere');
      expect(Fc2LiveDanmakuCodec.plainText('&lt;b&gt;literal&lt;/b&gt;'), '<b>literal</b>');
      expect(Fc2LiveDanmakuCodec.plainText('x < y > z'), 'x < y > z');
      expect(Fc2LiveDanmakuCodec.plainText('<!doctype html>only'), 'only');
      expect(Fc2LiveDanmakuCodec.plainText(' a '), 'a');
      expect(Fc2LiveDanmakuCodec.escapedText('a &amp; b'), 'a &amp; b');
      expect(Fc2LiveDanmakuCodec.escapedText(' <b>x</b> '), ' x ');
      expect(Fc2LiveDanmakuCodec.escapedText('&lt;tag&gt;'), '&lt;tag&gt;');
    });

    test('a sender key is decoded with the offset of each comment', () {
      expect(Fc2LiveDanmakuCodec.userId('a3456'), 'id-101-102-103-104');
      expect(
        Fc2LiveDanmakuCodec.userId('a3456'),
        Fc2LiveDanmakuCodec.userId('a4567'),
        reason: 'the same id with another offset',
      );
      expect(Fc2LiveDanmakuCodec.userId('a3'), 'id');
      expect(Fc2LiveDanmakuCodec.userId('aX'), 'id_aX', reason: 'no offset digit');
      expect(Fc2LiveDanmakuCodec.userId('a0'), 'id');
      expect(Fc2LiveDanmakuCodec.userId('b345'), 'id_b345');
      expect(Fc2LiveDanmakuCodec.userId('a' * 13), 'id_aaaaaaaaaaaaa');
      expect(Fc2LiveDanmakuCodec.userId(null), '');
      expect(Fc2LiveDanmakuCodec.userId(''), '');
      expect(Fc2LiveDanmakuCodec.userId(7), '');
      expect(Fc2LiveDanmakuCodec.comment(_comment(encrypted: null))!.effectiveSender.userId, '');
    });

    test('the eight comment colours, and white for the rest', () {
      expect(Fc2LiveDanmakuCodec.color('blue'), const LiveMessageColor(0x44, 0x72, 0xF3));
      expect(Fc2LiveDanmakuCodec.color(' Blue '), const LiveMessageColor(0x44, 0x72, 0xF3));
      expect(Fc2LiveDanmakuCodec.color('PURPLE'), const LiveMessageColor(0xB8, 0x4A, 0xC5));
      for (final name in ['black', 'white', 'weird', null, 7]) {
        expect(Fc2LiveDanmakuCodec.color(name), LiveMessageColor.white, reason: '$name');
      }
      expect(Fc2LiveDanmakuCodec.colors.length, 8);
      expect(Fc2LiveDanmakuCodec.comment(_comment(color: 'red'))!.color, const LiveMessageColor(0xE6, 0x3D, 0x37));
      expect(Fc2LiveDanmakuCodec.colors.keys, ['red', 'pink', 'orange', 'yellow', 'green', 'cyan', 'blue', 'purple']);
    });

    test('a comment time out of a clock reach leaves the line unstamped', () {
      for (final bad in [0, -1, 'x', 1.5, 8640000000000001, null]) {
        expect(Fc2LiveDanmakuCodec.comment(_comment(time: bad))!.sentAt, isNull, reason: '$bad');
      }
      expect(
        Fc2LiveDanmakuCodec.comment(_comment(time: '1759000000000'))!.sentAt!.millisecondsSinceEpoch,
        1759000000000,
      );
    });

    test('a comment message is a list, filtered and in order', () {
      final rows = [_comment(comment: 'one'), _comment(comment: 'two'), 'junk', 7, _comment(history: 1)];
      expect(Fc2LiveDanmakuCodec.comments({'comments': rows}).map((m) => m.text), ['one', 'two']);
      expect(Fc2LiveDanmakuCodec.comments({}), isEmpty);
      expect(Fc2LiveDanmakuCodec.comments({'comments': 'not a list'}), isEmpty);
      final ng = Fc2LiveNgList()
        ..apply({
          'ng_comments': [
            {'type': 'keyword', 'ng_keyword': 'two', 'ng_comment_id': 1},
          ],
        });
      expect(Fc2LiveDanmakuCodec.comments({'comments': rows}, ng: ng).map((m) => m.text), ['one']);
      expect(ng.length, 1);
    });

    test('user_count carries only what changed, and sums the halves', () {
      final audience = Fc2LiveAudience();
      expect(audience.online, isNull);
      expect(audience.total, isNull);
      final first = audience.update({'pc_user_count': 5});
      expect(first.single.type, LiveMessageType.audienceUpdate);
      final figure = first.single.payload! as LiveAudienceUpdate;
      expect(figure.kind, LiveAudienceSignalKind.onlineViewers);
      expect(figure.value, 5);
      expect(first.single.text, '');
      expect(audience.update({'pc_user_count': 5}), isEmpty, reason: 'the same figure is not told twice');
      expect(audience.update({'mobile_user_count': 3, 'pc_total_count': 20}).length, 2);
      expect(audience.online, 8);
      expect(audience.total, 20);
      expect(audience.update({'mobile_total_count': 1}).length, 1);
      expect(audience.total, 21);
      for (final bad in ['9', 1.5, -1, null]) {
        expect(audience.update({'pc_user_count': bad}), isEmpty, reason: '$bad');
      }
      expect(audience.update({'other_field': 9}), isEmpty);
      expect(audience.online, 8);
      final totalOnly = Fc2LiveAudience().update({'mobile_total_count': 4});
      expect((totalOnly.single.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.totalViewers);
      expect(Fc2LiveAudience().update({}), isEmpty);
    });

    test('the ng lists apply as the page applies them', () {
      final ng = Fc2LiveNgList();
      expect(ng.usesAdminLists, isFalse);
      expect(ng.sharedLevel, 0);
      ng.apply({'admin_ng': 1, 'shared_ng_level': '2'});
      expect(ng.usesAdminLists, isTrue);
      expect(ng.sharedLevel, 2);
      ng.apply({'admin_ng': 0});
      expect(ng.usesAdminLists, isFalse);
      ng.apply({'shared_ng_level': 1});
      expect(ng.sharedLevel, 1);
      expect(ng.hides(_comment()), isFalse);

      ng.apply({
        'ng_comments': [
          {'type': 'keyword', 'ng_keyword': 'HeLLo', 'ng_comment_id': 7},
          {'type': 'channel_user', 'ng_encrypted_user_id': 'a3456', 'ng_comment_id': 8},
          {'type': 'user', 'ng_orz_token': 'orz-1', 'ng_comment_id': 9},
          {'type': 'share_low', 'ng_keyword': 'rude'},
          {'type': 'admin_keyword', 'ng_keyword': 'banned'},
          {'type': 'not_a_type', 'ng_keyword': 'ignored'},
          'not a row',
        ],
      });
      expect(ng.length, 5);
      expect(ng.hides(_comment(comment: 'say hello')), isTrue);
      expect(ng.hides(_comment(comment: 'clean')), isTrue);
      expect(ng.hides(_comment(encrypted: 'a9999', comment: 'clean')), isFalse);
      expect(ng.hides(_comment(orz: 'orz-1', comment: 'clean')), isTrue);
      expect(ng.hides(_comment(orz: 'orz-2', comment: 'clean')), isFalse);
      expect(
        ng.hides(_comment(encrypted: null, orz: 'orz-1', comment: 'clean')),
        isTrue,
        reason: 'a visitor by cookie',
      );
      expect(ng.hides(_comment(comment: 'a RUDE word')), isTrue, reason: 'shared_low applies at level 1');
      expect(ng.hides(_comment(comment: 'a banned word')), isFalse, reason: 'the admin list is off');
      expect(ng.hides(_comment(comment: 'ignored')), isFalse);
      expect(
        ng.hides(_comment(user: 'HeLLo', comment: 'x')),
        isTrue,
        reason: 'a name is compared too',
      );
      expect(
        ng.hides(_comment(user: 'HeLLo', comment: 'x', anonymous: 1)),
        isFalse,
        reason: 'not of an anonymous line',
      );
      expect(ng.hides(_comment(owner: 1)), isTrue, reason: 'the streamer is checked against plain keywords only');
      ng.apply({
        'admin_ng': true,
        'ng_comments': [
          {'type': 'admin_keyword', 'ng_keyword': 'banned'},
        ],
      });
      expect(ng.hides(_comment(comment: 'a banned word')), isTrue);
    });

    test('a stored entry is removed by its id, an unnamed one by an equal entry', () {
      final ng = Fc2LiveNgList()
        ..apply({
          'ng_comments': [
            {'type': 'keyword', 'ng_keyword': 'a', 'ng_comment_id': 1},
            {'type': 'keyword', 'ng_keyword': 'b'},
            {'type': 'keyword', 'ng_keyword': 'c', 'ng_comment_id': 'x'},
          ],
        });
      expect(ng.length, 3);
      ng.apply({
        'ng_comments': [
          {'type': 'keyword', 'ng_keyword': 'a', 'ng_comment_id': 1, 'mode': 'del'},
          {'type': 'keyword', 'ng_keyword': 'z', 'ng_comment_id': 1, 'mode': 'del'},
          {'type': 'keyword', 'ng_keyword': 'c', 'ng_comment_id': 'x', 'mode': 'del'},
        ],
      });
      expect(ng.length, 2, reason: 'the id goes, whatever keyword it now carries');
      ng.apply({
        'ng_comments': [
          {'type': 'keyword', 'ng_keyword': 'B', 'mode': 'del'},
        ],
      });
      expect(ng.length, 1);
      expect(ng.hides(_comment(comment: 'b')), isFalse);
      expect(ng.hides(_comment(comment: 'a')), isTrue, reason: 'the entry kept its id');
    });

    test('the timing the page own socket keeps', () {
      expect(Fc2LiveDanmakuCodec.heartbeatInterval, const Duration(seconds: 30));
      expect(Fc2LiveDanmakuCodec.joinTimeout, const Duration(seconds: 8));
      expect(Fc2LiveDanmakuCodec.inactivityTimeout, const Duration(seconds: 90));
      expect(Fc2LiveDanmakuCodec.maxReconnects, 8);
      expect(Fc2LiveDanmakuCodec.reconnectBaseDelay, const Duration(seconds: 1));
      expect(Fc2LiveDanmakuCodec.anonymousName, '[anonymous]');
      expect(Fc2LiveControl.pingInterval, const Duration(seconds: 15));
      expect(Fc2LiveControl.hlsRequest, '{"name":"get_hls_information","arguments":{},"id":1}');
      expect(Fc2LiveEndpoints.closeTimeout, const Duration(seconds: 2));
      expect(Fc2LiveEndpoints.connectTimeout, const Duration(seconds: 10));
      expect(Fc2LiveEndpoints.snapshotLifetime, const Duration(seconds: 20));
      expect(Fc2LiveEndpoints.requestTimeout, const Duration(seconds: 20));
      expect(Fc2LiveEndpoints.maxPageSize, 100);
      expect(Fc2LiveEndpoints.directoryPageSize, 20);
      expect(Fc2LiveEndpoints.clientVersion, '2.1.0\n [1]');
    });

    test('a failure never names the secrets of a grant', () {
      final text = Fc2LiveDanmakuCodec.redact(
        "HandshakeException: bad control_token=abc.def%20 l_ortkn=xyz; 'q' https://x/a?c=1&control_token=k",
      );
      expect(text, contains('control_token=…'));
      expect(text, contains('l_ortkn=…'));
      expect(text, isNot(contains('abc.def')));
      expect(text, isNot(contains('xyz')));
      expect(text, isNot(contains('=k')));
      expect(text, contains('c=1'), reason: 'an unrelated parameter stays');
      expect(Fc2LiveDanmakuCodec.redact('nothing secret here'), 'nothing secret here');
    });
  });

  group('adapter wiring', () {
    test('the seven capabilities the platform can serve are wired, the rest are not', () {
      final site = _adapter().site;
      expect(site.manifest.id, 'fc2live');
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveHotProvider>(), isNull, reason: 'FC2 ranks its list by viewers and names no trend');
      expect(site.capability<LiveAnchorProvider>(), isNull);
      expect(site.capability<LiveWebSearchProvider>(), isNull, reason: 'the search is the local one');
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
      expect(createBuiltInLiveSites(http: _FakeHttp((_) => _resp(200, '{}'))), contains(isA<Fc2LiveSite>()));
    });

    test('every request is a form POST with the page own headers', () async {
      final adapter = _adapter();
      await adapter.site.detail(_channel);
      final seen = adapter.http.sent.single;
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://live.fc2.com/api/memberApi.php');
      expect(seen.body, 'channel=1&profile=1&user=1&streamid=10608314');
      expect(seen.headers['content-type'], Fc2LiveEndpoints.formContentType);
      expect(seen.headers['x-requested-with'], 'XMLHttpRequest');
      expect(seen.headers['referer'], 'https://live.fc2.com/');
      expect(seen.headers['accept'], contains('application/json'));

      await adapter.site.controlGrant(_channel);
      final grant = adapter.http.sent.last;
      expect(grant.url.path, '/api/getControlServer.php');
      expect(
        grant.body,
        'channel_id=10608314&mode=play&orz=&channel_version=fixture-version'
        '&client_version=2.1.0%0A+%5B1%5D&client_type=pc&client_app=browser_hls&ipv6=',
      );
    });

    test('a room is one request, and its handles name the control and the chat', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final room = _right(await rooms.getRoom('https://live.fc2.com/10608314/'));
      expect(adapter.http.sent, hasLength(1));
      expect(room.roomId, _channel);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(room.runtime.danmakuHandle, const Fc2LiveDanmakuArgs(_channel));
      expect((room.runtime.streamHandle! as Fc2LiveRoomData).categoryId, 1);
      adapter.http.sent.clear();
      expect(_leftOf(await rooms.getRoom('not a room')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty, reason: 'a room id that is not a channel asks for nothing');
    });

    test('a directory page comes from one snapshot, and pages after it from the same one', () async {
      final clock = [_at];
      final adapter = _adapter(now: () => clock[0]);
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.items.map((room) => room.roomId), [_channel, _other, '12000001']);
      expect(first.totalCount, 3);
      expect(first.hasMore, isFalse, reason: 'three rooms fit in one page of 20');
      expect(adapter.http.sent, hasLength(1));

      adapter.http.sent.clear();
      final second = _right(await rooms.getRooms(const LivePageRequest(page: 2)));
      expect(second.items, isEmpty);
      expect(adapter.http.sent, isEmpty, reason: 'a later page comes from the snapshot page 1 read');

      clock[0] = _at.add(const Duration(seconds: 21));
      adapter.http.sent.clear();
      await rooms.getRooms(const LivePageRequest());
      expect(adapter.http.sent, hasLength(1), reason: 'page 1 always asks anew');

      clock[0] = _at;
      adapter.http.sent.clear();
      await rooms.getRooms(const LivePageRequest(page: 3));
      expect(adapter.http.sent, hasLength(1), reason: 'a clock that went backwards does not reuse the snapshot');
    });

    test('a snapshot is shared with everyone waiting for it, and a failed one is forgotten', () async {
      final adapter = _adapter();
      final first = adapter.site.snapshot();
      final second = adapter.site.snapshot();
      await Future.wait([first, second]);
      expect(adapter.http.sent, hasLength(1), reason: 'two callers, one fetch');

      var answer = _resp(500, 'nope');
      final failing = _adapter(onSend: (_) => answer);
      await expectLater(failing.site.snapshot(), throwsA(isA<Fc2LiveFailure>()));
      answer = _resp(200, _directoryFixture());
      final channels = await failing.site.snapshot();
      expect(channels, hasLength(3), reason: 'the breakdown is not kept as an answer');
    });

    test('an area filters the snapshot locally, and an unknown one is refused', () async {
      final adapter = _adapter();
      final areas = adapter.site.capability<LiveAreaProvider>()!;
      final listed = _right(await areas.getAreas());
      expect(listed.map((area) => area.areaId), ['all', '1', '2', '4', '9', '5']);
      expect(adapter.http.sent, isEmpty, reason: 'FC2 has no area list to read');

      final inAudio = _right(await areas.getAreaRooms(areaId: '9'));
      expect(inAudio.items.map((room) => room.roomId), [_other]);
      final everything = _right(await areas.getAreaRooms(areaId: 'all'));
      expect(everything.items, hasLength(3));
      expect(_leftOf(await areas.getAreaRooms(areaId: 'nope')), isA<LiveSiteInvalidArgument>());
      expect(_leftOf(await areas.getAreaRooms(areaId: '3')), isA<LiveSiteInvalidArgument>());
      expect(
        _right(await areas.getAreaRooms(areaId: '1', request: const LivePageRequest(page: 0))),
        isA<Object>(),
        reason: 'a page below 1 gives nothing, as 3.x gave nothing',
      );
      expect(
        adapter.http.sent,
        hasLength(3),
        reason: 'page 1 of the three areas asked, the refused ones asked nothing',
      );
    });

    test('the discovery feed is the directory again, sliced by what the caller asked', () async {
      final adapter = _adapter();
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final page = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 2)));
      expect(page.items.map((room) => room.roomId), [_channel, _other]);
      expect(page.hasMore, isTrue);
      expect(page.totalCount, 3);
      final wide = _leftOf(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 500)));
      expect(wide, isA<LiveSiteError>(), reason: 'a page the platform never served is reported, not fetched');
    });

    test('a search is the snapshot filtered here, or one exact channel', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      final byWord = _right(
        await search.search(const LiveSearchRequest(query: ' kitten ', target: LiveSearchTarget.rooms)),
      );
      expect((byWord.items.single as RoomSearchResult).room.roomId, _other);
      expect(byWord.totalCount, 1);
      expect(adapter.http.sent, hasLength(1), reason: 'one snapshot read, no search request');

      adapter.http.sent.clear();
      final exact = _right(
        await search.search(const LiveSearchRequest(query: '10608314', target: LiveSearchTarget.rooms)),
      );
      expect((exact.items.single as RoomSearchResult).room.roomId, _channel);
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/api/memberApi.php']);

      adapter.http.sent.clear();
      final later = _right(
        await search.search(const LiveSearchRequest(query: '10608314', target: LiveSearchTarget.rooms, page: 2)),
      );
      expect(later.items, isEmpty);
      expect(adapter.http.sent, isEmpty, reason: 'only the first page gives an exact channel');

      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '   ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      final missing = _adapter(onSend: (_) => _resp(200, _memberJson(status: 0)));
      expect(
        (await missing.site.search('99999999')).rooms,
        isEmpty,
        reason: 'a channel that is not there is no result, not a failure',
      );
    });

    test('the qualities are what a control answers, and cost both requests and a socket', () async {
      final opened = _controlSocket();
      final adapter = _adapter(connect: opened.connect);
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _channel));
      expect(qualities.map((quality) => quality.qualityId), ['30', '20', '10', 'auto']);
      expect(qualities.map((quality) => quality.platformOrder), [4, 3, 2, 1]);
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/api/memberApi.php', '/api/getControlServer.php']);
      expect(opened.connector.endpoints.single.queryParameters.keys.toList(), ['control_token']);
      expect(opened.socket.sentText, contains(Fc2LiveControl.hlsRequest));

      adapter.http.sent.clear();
      final lines = _right(await playback.getLines(roomId: _channel, quality: qualities.first));
      expect(adapter.http.sent, isEmpty, reason: 'the held control still authorizes the playlists');
      expect(lines, hasLength(1));
      expect(lines.single.url, _playlist(31), reason: 'the high-latency variant of the tier');
      expect(lines.single.lineLabel, '30');
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.headers['referer'], 'https://live.fc2.com/10608314/');
      expect(lines.single.lease!.expiresAt, _at.add(Fc2LiveEndpoints.controlLife));
      expect(lines.single.lease!.requiresReconnect, isTrue);

      final adaptive = _right(await playback.getLines(roomId: _channel));
      expect(adaptive.single.url, _master);
      expect(adaptive.single.lineLabel, 'auto');
      await adapter.site.dispose();
      expect(opened.socket.closed, isTrue, reason: 'disposing the site closes the control it held');
    });

    test('a second viewer of the same channel is served from the same control', () async {
      final opened = _controlSocket();
      final adapter = _adapter(connect: opened.connect);
      await adapter.site.qualitiesOf(_channel);
      expect(adapter.http.sent, hasLength(2));
      await adapter.site.qualitiesOf('https://live.fc2.com/10608314/');
      expect(adapter.http.sent, hasLength(2), reason: 'the grant still holds');
      expect(opened.connector.endpoints, hasLength(1));
    });

    test('a control the site ends is replaced by the next caller', () async {
      final opened = _controlSocket();
      final adapter = _adapter(connect: opened.connect);
      await adapter.site.qualitiesOf(_channel);
      await opened.socket.ended(code: 1006);
      await Future<void>.delayed(Duration.zero);
      final lines = await adapter.site.linesOf(_channel);
      expect(adapter.http.sent, hasLength(4), reason: 'both requests again for the fresh grant');
      expect(opened.connector.endpoints, hasLength(2));
      expect(lines.single.url, isNotEmpty);
    });

    test('a line is re-resolved before its grant dies', () async {
      final clock = [_at];
      final opened = _controlSocket();
      final adapter = _adapter(connect: opened.connect, now: () => clock[0]);
      await adapter.site.linesOf(_channel);
      clock[0] = _at.add(Fc2LiveEndpoints.controlLife - Fc2LivePlayParser.renewLead + const Duration(seconds: 1));
      await adapter.site.linesOf(_channel);
      expect(adapter.http.sent, hasLength(4), reason: 'the lease led the player back before the socket died');
      expect(opened.connector.endpoints, hasLength(2));
    });

    test('a room that cannot be played names why, without a grant or a socket', () async {
      Future<LiveSiteError> refused(Map<String, Object?> set) async {
        final opened = _controlSocket();
        final adapter = _adapter(
          connect: opened.connect,
          onSend: (request) => request.url.path.endsWith('memberApi.php')
              ? _resp(200, _memberJson(set: set))
              : _resp(200, _controlJson()),
        );
        final error = _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel));
        expect(adapter.http.sent, hasLength(1), reason: 'the member answer alone, then nothing');
        expect(opened.connector.endpoints, isEmpty);
        return error;
      }

      expect(await refused({'is_publish': 0}), isA<LiveSiteContentUnavailable>());
      expect(await refused({'login_only': 1}), isA<LiveSiteAuthenticationError>());
      expect(await refused({'fee': 1}), isA<LiveSiteContentUnavailable>());
      expect(await refused({'is_limited': 1}), isA<LiveSiteContentUnavailable>());
    });

    test('a live channel that answers no version cannot be granted', () async {
      final opened = _controlSocket();
      final adapter = _adapter(
        connect: opened.connect,
        onSend: (request) => request.url.path.endsWith('memberApi.php')
            ? _resp(200, _memberJson(set: {'version': ''}))
            : _resp(200, _controlJson()),
      );
      final error = _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel));
      expect(error, isA<LiveSiteParseError>());
      expect(opened.connector.endpoints, isEmpty);
    });

    test('a grant that is refused, gone or unreadable is reported per kind', () async {
      final opened = _controlSocket();
      final refused = _adapter(
        connect: opened.connect,
        onSend: (request) => request.url.path.endsWith('getControlServer.php')
            ? _resp(200, _controlJson(status: 3))
            : _resp(200, _memberJson()),
      );
      expect(
        _leftOf(await refused.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteContentUnavailable>(),
      );
      final broken = _adapter(
        connect: opened.connect,
        onSend: (request) =>
            request.url.path.endsWith('getControlServer.php') ? _resp(200, '<html>') : _resp(200, _memberJson()),
      );
      expect(
        _leftOf(await broken.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteParseError>(),
      );
      final throttled = _adapter(
        connect: opened.connect,
        onSend: (request) =>
            request.url.path.endsWith('getControlServer.php') ? _resp(429, '{}') : _resp(200, _memberJson()),
      );
      expect(
        _leftOf(await throttled.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteRateLimitError>(),
      );
      final gone = _adapter(
        connect: opened.connect,
        onSend: (request) => request.url.path.endsWith('getControlServer.php')
            ? _resp(200, _controlJson(set: {'url': 'wss://elsewhere.test/control/channels/10608314'}))
            : _resp(200, _memberJson()),
      );
      expect(
        _leftOf(await gone.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteParseError>(),
      );
      expect(opened.connector.endpoints, isEmpty, reason: 'a grant for another host is never opened');
    });

    test('a quality the platform has no name for is a caller error', () async {
      final opened = _controlSocket();
      final adapter = _adapter(connect: opened.connect);
      final error = _leftOf(
        await adapter.site.capability<LivePlaybackProvider>()!.getLines(
          roomId: _channel,
          quality: const LivePlayQuality(label: 'x', qualityId: '1080p'),
        ),
      );
      expect(error, isA<LiveSiteInvalidArgument>());
      expect(adapter.http.sent, isEmpty);
      expect(opened.connector.endpoints, isEmpty);
    });

    test('a link is canonicalized, an alien host is unsupported and a site page is not a channel', () async {
      final adapter = _adapter();
      final links = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await links.resolve(Uri.parse('https://live.fc2.com/JA/10608314/?x=1'))).toString(),
        'https://live.fc2.com/10608314/',
      );
      expect(_leftOf(await links.resolve(Uri.parse('https://www.google.com/x'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await links.resolve(Uri.parse('https://live.fc2.com/rank/'))), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty, reason: 'no short link to follow');
    });

    test('a comment session takes a grant of its own and reads what the site pushes', () async {
      final chat = await _chat();
      expect(chat.http.sent.map((seen) => seen.url.path), ['/api/memberApi.php', '/api/getControlServer.php']);
      expect(chat.connector.headers.single['cookie'], 'l_ortkn=fixture_orz-token');
      chat.timers.ring();
      expect(chat.socket.sentText, contains('{"name":"heartbeat","arguments":{},"id":1}'));

      final pending = _next(chat.session.events, 2);
      chat.socket.push(_commentsFrame([_comment(), _comment(history: 1, comment: 'replay')]));
      chat.socket.push(_frame('user_count', arguments: {'pc_user_count': 6, 'pc_total_count': 90}));
      final messages = await pending;
      expect(messages.map((message) => message.type), [LiveMessageType.chat, LiveMessageType.audienceUpdate]);
      expect(messages.first.text, 'hello');
      expect((messages.last.payload! as LiveAudienceUpdate).value, 6);

      chat.socket.push(
        _frame(
          'ng_comment',
          arguments: {
            'ng_comments': [
              {'type': 'keyword', 'ng_keyword': 'hidden', 'ng_comment_id': 3},
            ],
          },
        ),
      );
      final after = _next(chat.session.events, 1);
      chat.socket.push(_commentsFrame([_comment(comment: 'hidden word'), _comment(comment: 'shown', user: 'Bob')]));
      expect((await after).map((message) => message.text), ['shown']);
      await chat.session.dispose();
      expect(chat.socket.closed, isTrue);
    });

    test('a session follows the site orders with a fresh grant', () async {
      final chat = await _chat();
      expect(chat.http.sent, hasLength(2));
      chat.socket.push(_frame('move_server'));
      await Future<void>.delayed(Duration.zero);
      expect(chat.http.sent, hasLength(4), reason: 'the page follows a move at once, on a fresh grant');
      chat.socket.push(_frame('control_disconnection', arguments: {'code': 4500}));
      await Future<void>.delayed(Duration.zero);
      chat.timers.fire(index: chat.timers.after.length - 1);
      await Future<void>.delayed(Duration.zero);
      expect(chat.http.sent, hasLength(6), reason: 'an expired grant is replaced after the backoff step');
      // The heartbeat id counts up through the run, and an answered heartbeat
      // restarts the count of replacements.
      chat.timers.ring(index: chat.timers.every.length - 1);
      expect(chat.socket.sentText, contains('"id":2'));
      chat.socket.push(_frame('_response_', arguments: {'status': 0}, id: 2));
      for (var attempt = 0; attempt <= Fc2LiveDanmakuCodec.maxReconnects; attempt++) {
        chat.socket.push(_frame('control_disconnection', arguments: {'code': 4500}));
        await Future<void>.delayed(Duration.zero);
        chat.timers.fire(index: chat.timers.after.length - 1);
        await Future<void>.delayed(Duration.zero);
      }
      final seen = <LiveMessage>[];
      await chat.session.events.listen(seen.add).asFuture<void>();
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      expect(seen.last.text, contains('Chat connection lost'));
    });

    test('a grant the site will not give ends the session at once', () async {
      for (final set in [
        <String, Object?>{'is_publish': 0},
        <String, Object?>{'login_only': 1},
      ]) {
        final opened = _controlSocket();
        final adapter = _adapter(
          connect: opened.connect,
          onSend: (request) => request.url.path.endsWith('memberApi.php')
              ? _resp(200, _memberJson(set: set))
              : _resp(200, _controlJson()),
        );
        final session = Fc2LiveDanmakuSession(
          args: const Fc2LiveDanmakuArgs(_channel),
          site: adapter.site,
          timers: FakeTimers().timers,
        );
        expect(await session.connect(), isNotNull, reason: '$set');
        expect(opened.connector.endpoints, isEmpty);
        await session.dispose();
      }
      final opened = _controlSocket();
      final broken = _adapter(onSend: (_) => _resp(500, 'nope'), connect: opened.connect);
      final waiting = Fc2LiveDanmakuSession(
        args: const Fc2LiveDanmakuArgs(_channel),
        site: broken.site,
        timers: FakeTimers().timers,
      );
      expect(await waiting.connect(), isNull, reason: 'a breakdown only fails this handshake, which is retried');
      expect(opened.connector.endpoints, isEmpty);
      expect(broken.http.sent, hasLength(1));
      await waiting.dispose();
    });

    test('the provider builds a session only for a room that names a channel', () async {
      final opened = _controlSocket();
      final adapter = _adapter(connect: opened.connect);
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _channel));
      expect(session, isA<Fc2LiveDanmakuSession>());
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/api/memberApi.php',
        '/api/memberApi.php',
        '/api/getControlServer.php',
      ], reason: 'the room read, then the grant of the connection');
      await session.dispose();
      expect(_leftOf(await danmaku.createSession(roomId: 'x')), isA<LiveSiteNotFound>());
      final offline = _adapter(
        connect: opened.connect,
        onSend: (request) => _resp(
          200,
          request.url.path.endsWith('memberApi.php') ? _memberJson(set: {'is_publish': 0}) : _controlJson(),
        ),
      );
      expect(
        _leftOf(await offline.site.capability<LiveDanmakuProvider>()!.createSession(roomId: _channel)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a room id that is not a channel is refused before any request', () async {
      final adapter = _adapter();
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('https://x.test/1')),
        isA<LiveSiteNotFound>(),
      );
      expect(adapter.http.sent, isEmpty);
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: 'abc')),
        isA<LiveSiteNotFound>(),
      );
      expect(adapter.http.sent, isEmpty);
    });
  });
}

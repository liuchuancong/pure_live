import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_http.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_session.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_json.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-06-01, around noon.
final DateTime _at = DateTime.parse('2026-06-01T12:00:00.000Z').toUtc();

const int _roomId = 101;
const int _otherRoom = 103;
const String _roomKey = 'rooma';
const String _otherKey = 'roomc';
const String _bcsvrHost = 'bcsvr42.o.showroom-live.com';
const String _bcsvrKey = '6e6c686835796846:23483509';
const int _startedAt = 1780000000;

String _json(Object? data) => jsonEncode(data);

String _hls(String name) => 'https://hls.showroom-live.com/live/$name';

String _image(String name) => 'https://image.showroom-live.com/$name';

Map<String, Object?> _liveRow({
  Object roomId = _roomId,
  Object key = _roomKey,
  String name = 'ルームA',
  int genreId = 0,
  Object? genreName = 'ミュージック',
  Object? telop = '生放送テスト',
  Object? followers = 1200,
  Object? views = 3400,
  Object? startedAt = _startedAt,
  Object? premium = 0,
  String image = 'square.png',
}) => {
  'room_id': roomId,
  'room_url_key': key,
  'main_name': name,
  'image_square': _image(image),
  'genre_id': genreId,
  'genre_name': genreName,
  'follower_num': followers,
  'view_num': views,
  'telop': telop,
  'started_at': startedAt,
  'premium_room_type': premium,
};

String _snapshotFixture({Map<int, Object?>? genres}) => _json({
  'onlives': [
    for (final entry in (genres ?? _defaultGenres()).entries)
      {'genre_id': entry.key, 'genre_name': entry.key == 0 ? 'Popularity' : 'Music', 'lives': entry.value},
  ],
});

Map<int, List<Object?>?> _defaultGenres() => {
  0: [_liveRow(), _liveRow(roomId: 102, key: 'roomb', name: 'ルームB')],
  1: [_liveRow(roomId: _otherRoom, key: _otherKey, name: 'ルームC', genreId: 1, image: 'square-c.png')],
  2: [
    // A genre with nobody live holds a message cell.
    {'cell_type': 7, 'message': '誰も放送していません'},
  ],
};

String _statusFixture({int roomId = _roomId}) => _json({'room_id': roomId});

String _profileFixture({
  int roomId = _roomId,
  Object key = _roomKey,
  Object name = 'ルームA',
  Object? mainName,
  Object isOnlive = true,
  Object? genreId = 1,
}) => _json({
  'room_id': roomId,
  'room_url_key': key,
  'main_name': mainName ?? name,
  'image_square': _image('square.png'),
  'genre_id': genreId,
  'genre_name': 'ミュージック',
  'follower_num': 1200,
  'view_num': 3400,
  'description': 'よろしくね',
  'current_live_started_at': _startedAt,
  'is_onlive': isOnlive,
});

String _liveInfoFixture({
  int roomId = _roomId,
  int liveStatus = 2,
  Object premium = 0,
  Object host = _bcsvrHost,
  Object key = _bcsvrKey,
}) => _json({
  'room_id': roomId,
  'live_status': liveStatus,
  'premium_room_type': premium,
  'bcsvr_host': host,
  'bcsvr_key': key,
});

Map<String, Object?> _tierRow(
  String type,
  int id,
  int quality,
  String label, {
  String? url,
  Object? isDefault = true,
}) => {
  'type': type,
  'id': id,
  'quality': quality,
  'label': label,
  'is_default': isDefault,
  'url': url ?? _hls('$id.m3u8'),
};

String _streamingFixture({List<Object?>? rows}) => _json({
  'streaming_url_list': rows ?? [_tierRow('hls', 2, 1000, '高画質'), _tierRow('hls', 1, 200, '中画質')],
});

String _giftListFixture() => _json({
  'normal': [
    {'gift_id': 1, 'gift_name': 'スター', 'point': 1, 'free': true, 'image': _image('g1.png')},
    {'gift_id': 2, 'gift_name': 'ハート', 'point': 50, 'free': false, 'image': _image('g2.png')},
    {'gift_id': 0, 'gift_name': 'no id', 'point': 1, 'free': true},
    {'gift_id': 'x', 'gift_name': 'bad id', 'point': 1, 'free': true},
    'not a row',
  ],
  'enquete': [
    {'gift_id': 3, 'gift_name': 'アンケート', 'point': 10, 'free': false, 'image': _image('g3.png')},
  ],
  'other': [
    {'gift_id': 4, 'gift_name': '無視', 'point': 1, 'free': true},
  ],
});

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : url = request.url;
  final Uri url;
}

final class _FakeHttp implements LiveHttp {
  new(this.onSend);
  final FutureOr<LiveResponse> Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final seen = _Seen(request);
    sent.add(seen);
    return await onSend(seen);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// The answers of the site: the snapshot, the room lookups, the streams and
/// the gift table.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  final roomId = int.tryParse(request.url.queryParameters['room_id'] ?? '');
  if (path == '/api/live/onlives') {
    return _resp(200, _snapshotFixture());
  }
  if (path == '/api/room/status') {
    final key = request.url.queryParameters['room_url_key'] ?? '';
    return key == _roomKey || RegExp(r'^[0-9]+$').hasMatch(key)
        ? _resp(200, _statusFixture())
        : _resp(404, 'no such key');
  }
  if (path == '/api/room/profile') {
    return _resp(200, _profileFixture(roomId: roomId ?? _roomId));
  }
  if (path == '/api/live/live_info') {
    return _resp(200, _liveInfoFixture(roomId: roomId ?? _roomId));
  }
  if (path == '/api/live/streaming_url') {
    return _resp(200, _streamingFixture());
  }
  if (path == '/api/live/gift_list') {
    return _resp(200, _giftListFixture());
  }
  return _resp(404, 'nope');
}

/// A connector that refuses: a test that needs a socket replaces it.
Future<SocketChannel> _refuseSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw StateError('no socket was asked for in this test');

/// The socket a test drives by hand.
final class _FakeSocket implements SocketChannel {
  final StreamController<Object?> _stream = StreamController<Object?>();
  final List<Object?> sentList = [];
  bool closed = false;

  @override
  Stream<Object?> get stream => _stream.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  void add(Object data) => sentList.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  void push(Object? frame) => _stream.add(frame);

  Future<void> ended() => _stream.close();

  /// The text frames sent, joined for a whole-view check.
  String get sentText => sentList.whereType<String>().join('\n');
}

/// A connector that never opens a socket: every handshake breaks.
final class _DownConnector {
  int attempts = 0;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    attempts++;
    throw StateError('down');
  }
}

final class _Connector {
  final List<_FakeSocket> sockets = [];
  final List<Uri> endpoints = [];

  _FakeSocket get latest => sockets.last;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }
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

final class FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];
  final List<({Duration period, void Function(Timer timer) callback})> every = [];

  ShowroomTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  void fire({int index = 0}) => after[index].callback();

  void ring({int index = 0}) => every[index].callback(_IdleTimer());
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

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

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// The site over a fake transport, with a fixed clock and no socket.
({ShowroomSite site, _FakeHttp http}) _adapter({
  LiveResponse Function(_Seen request)? onSend,
  Future<SocketChannel> Function(
    Uri, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  })?
  connect,
  DateTime Function()? now,
}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (
    site: ShowroomSite(http: ShowroomHttp(http), connect: connect ?? _refuseSocket, now: now ?? () => _at),
    http: http,
  );
}

Future<({ShowroomDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector})> _chat({
  LiveResponse Function(_Seen request)? onSend,
  DateTime Function()? now,
}) async {
  final connector = _Connector();
  final timers = FakeTimers();
  final session = ShowroomDanmakuSession(
    args: const ShowroomDanmakuArgs(roomId: '$_roomId', host: _bcsvrHost, key: _bcsvrKey),
    site: _adapter(onSend: onSend, connect: connector.call, now: now).site,
    timers: timers.timers,
    now: now,
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (session: session, socket: connector.latest, timers: timers, connector: connector);
}

/// A full `MSG` frame of broadcast [key], as the wire carries it.
String _msgFrame(String key, Object? event) => 'MSG\t$key\t${_json(event)}';

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, ShowroomFailureKind kind) {
        try {
          ShowroomJson.checked('{}', status: status, what: 'x');
          fail('no throw for $status');
        } on ShowroomFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, ShowroomFailureKind.riskControl);
      expectKind(403, ShowroomFailureKind.riskControl);
      expectKind(404, ShowroomFailureKind.notFound);
      expectKind(429, ShowroomFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, ShowroomFailureKind.network);
      }
      expect(ShowroomJson.checked('{"a":1}', status: 200, what: 'x'), {'a': 1});
    });

    test('the answer must be a JSON object', () {
      expect(
        () => ShowroomJson.checked('<html>', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('not JSON'))),
      );
      expect(
        () => ShowroomJson.checked('[1,2]', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('not an object'))),
      );
    });

    test('ids, counts, texts and keys are read strictly', () {
      expect(ShowroomJson.integer(5), 5);
      expect(ShowroomJson.integer('5'), 5);
      expect(ShowroomJson.integer('x'), isNull);
      expect(ShowroomJson.positive('3', 'x'), 3);
      expect(() => ShowroomJson.positive(0, 'x'), throwsA(anything));
      expect(ShowroomJson.count(0, 'x'), 0);
      expect(() => ShowroomJson.count(-1, 'x'), throwsA(anything));
      expect(ShowroomJson.optionalCount(null, 'x'), isNull);
      expect(ShowroomJson.optionalCount('', 'x'), isNull);
      expect(() => ShowroomJson.optionalCount('x', 'x'), throwsA(anything));
      expect(ShowroomJson.text(' ぶん ', 'x'), 'ぶん');
      expect(() => ShowroomJson.text('   ', 'x'), throwsA(anything));
      expect(() => ShowroomJson.text(5, 'x'), throwsA(anything));
      expect(ShowroomJson.optionalText(null, 'x'), '');
      expect(ShowroomJson.optionalText(' a ', 'x'), 'a');
      expect(() => ShowroomJson.optionalText(5, 'x'), throwsA(anything));
      expect(ShowroomJson.key('AbC_12-x', 'x'), 'AbC_12-x');
      expect(() => ShowroomJson.key('bad key!', 'x'), throwsA(anything));
      expect(ShowroomJson.optionalString(' a '), 'a');
      expect(ShowroomJson.optionalString('  '), isNull);
    });

    test('an image must be https on a SHOWROOM host', () {
      expect(ShowroomJson.image(_image('a.png')), _image('a.png'));
      expect(ShowroomJson.image('https://img.showroom-txlive.com/a.png'), 'https://img.showroom-txlive.com/a.png');
      for (final bad in [
        'http://image.showroom-live.com/a.png',
        'https://evil.com/a.png',
        'https://u:image.showroom-live.com@a.png',
        'not a url',
        5,
      ]) {
        expect(ShowroomJson.image(bad), '', reason: '$bad');
      }
    });

    test('a stream url must be https on a SHOWROOM host without junk', () {
      expect(ShowroomJson.mediaUrl(_hls('a.m3u8'), 'x'), _hls('a.m3u8'));
      for (final bad in [
        'http://hls.showroom-live.com/live/a.m3u8',
        'https://evil.com/live/a.m3u8',
        'https://hls.showroom-live.com/live/a.m3u8#f',
        'https://u@hls.showroom-live.com/live/a.m3u8',
        'https://hls.showroom-live.com/live/a b.m3u8',
      ]) {
        expect(() => ShowroomJson.mediaUrl(bad, 'x'), throwsA(anything), reason: bad);
      }
    });

    test('a start time is unix seconds within 2000-2100', () {
      expect(ShowroomParser.startTime(_startedAt), DateTime.fromMillisecondsSinceEpoch(_startedAt * 1000, isUtc: true));
      expect(
        ShowroomParser.startTime('$_startedAt'),
        DateTime.fromMillisecondsSinceEpoch(_startedAt * 1000, isUtc: true),
      );
      expect(ShowroomParser.startTime(0), isNull);
      expect(ShowroomParser.startTime(946684799), isNull, reason: 'before 2000');
      expect(ShowroomParser.startTime(4102444801), isNull, reason: 'after 2100');
      expect(ShowroomParser.startTime(1.5), isNull);
      expect(ShowroomParser.startTime('x'), isNull);
    });
  });

  group('snapshot', () {
    test('every genre keeps its rooms, empty ones included', () {
      final snapshot = ShowroomParser.snapshot(_snapshotFixture());
      expect(snapshot.genres.map((genre) => genre.id), [0, 1, 2]);
      expect(snapshot.genres.map((genre) => genre.name), ['Popularity', 'Music', 'Music']);
      expect(snapshot.genres[2].lives, isEmpty, reason: 'the message cell is skipped');
      expect(snapshot.uniqueLives.map((live) => live.roomId), [_roomId, 102, _otherRoom]);
      expect(snapshot.popular.map((live) => live.roomId), [_roomId, 102]);
      expect(snapshot.genre(1)!.single.roomId, _otherRoom);
      expect(snapshot.genre(9), isNull);
    });

    test('the recommendations fall back to every live once', () {
      final snapshot = ShowroomParser.snapshot(
        _snapshotFixture(
          genres: {
            5: [_liveRow(roomId: 7, key: 'k7'), _liveRow(roomId: 8, key: 'k8')],
          },
        ),
      );
      expect(snapshot.popular.map((live) => live.roomId), [7, 8]);
    });

    test('a broken row or genre costs only itself', () {
      final snapshot = ShowroomParser.snapshot(
        _snapshotFixture(
          genres: {
            0: [
              _liveRow(),
              {'no room_id': true},
              _liveRow(roomId: 'x'),
            ],
            4: 'no lives',
          },
        ),
      );
      expect(snapshot.genres, hasLength(1));
      expect(snapshot.genres.single.lives, hasLength(1));
    });

    test('a snapshot without a genre, or without a readable row, is api-changed', () {
      expect(
        () => ShowroomParser.snapshot(_json({'onlives': <Object?>[]})),
        throwsA(predicate((e) => '$e'.contains('no genre'))),
      );
      expect(() => ShowroomParser.snapshot(_json(<String, Object?>{})), throwsA(anything));
      expect(
        () => ShowroomParser.snapshot(
          _snapshotFixture(
            genres: {
              0: [
                {'no room_id': true},
              ],
            },
          ),
        ),
        throwsA(predicate((e) => '$e'.contains('none of the 1 live rows'))),
      );
    });
  });

  group('cards', () {
    test('a card reads the telop as title and the views as total viewers', () {
      final room = ShowroomParser.card(ShowroomParser.snapshot(_snapshotFixture()).popular.first);
      expect(room.roomId, '$_roomId');
      expect(room.content.title, '生放送テスト');
      expect(room.anchor?.name, 'ルームA');
      expect(room.anchor?.avatarUrl, _image('square.png'));
      expect(room.content.coverUrl, _image('square.png'));
      expect(room.audience.totalViewers, 3400);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.totalViewers);
      expect(room.anchor?.followerCount, 1200);
      expect(room.links.webUrl, '${ShowroomEndpoints.origin}/r/$_roomKey');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(_startedAt * 1000, isUtc: true));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.area?.areaId, '0');
      expect(room.area?.areaName, 'ミュージック');
      expect(room.area?.parentAreaName, 'SHOWROOM');
    });

    test('a card without a telop or audience falls back honestly', () {
      final room = ShowroomParser.card(
        ShowroomParser.snapshot(
          _snapshotFixture(
            genres: {
              0: [_liveRow(telop: '', views: null, genreName: '', premium: 4)],
            },
          ),
        ).popular.single,
      );
      expect(room.content.title, 'ルームA');
      expect(room.audience.totalViewers, isNull);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(room.broadcast.restriction, isNull, reason: 'an unknown premium type is not known');
      expect(room.area, isNull, reason: 'no genre name, no area');
    });
  });

  group('directory, slices and search', () {
    final lives = [
      for (var index = 1; index <= 31; index++)
        ShowroomLive(roomId: index, roomUrlKey: 'k$index', name: 'r$index', cover: '', genreId: 0, genreName: ''),
    ];

    test('the directory is 30 a page, with hasMore', () {
      final first = ShowroomParser.directoryPage(lives, page: 1);
      expect(first.rooms, hasLength(30));
      expect(first.hasMore, isTrue);
      final second = ShowroomParser.directoryPage(lives, page: 2);
      expect(second.rooms, hasLength(1));
      expect(second.hasMore, isFalse);
      expect(ShowroomParser.directoryPage(lives, page: 3).rooms, isEmpty);
      expect(ShowroomParser.directoryPage(lives, page: 3).hasMore, isFalse);
    });

    test('a slice the reference served nothing for is empty', () {
      expect(ShowroomParser.slice(lives, page: 0, pageSize: 30), isEmpty);
      expect(ShowroomParser.slice(lives, page: 1, pageSize: 0), isEmpty);
      expect(ShowroomParser.slice(lives, page: 1, pageSize: 101), isEmpty);
      expect(ShowroomParser.slice(lives, page: 9, pageSize: 30), isEmpty);
      expect(ShowroomParser.slice(lives, page: 1, pageSize: 30), hasLength(30));
      expect(ShowroomParser.slice(lives, page: 1, pageSize: 100), hasLength(31));
      expect(ShowroomParser.validSlice(page: 1, pageSize: 100), isTrue);
      expect(ShowroomParser.validSlice(page: 0, pageSize: 100), isFalse);
    });

    test('the search matches id, key, name, telop and genre, case ignored', () {
      final snapshot = ShowroomParser.snapshot(_snapshotFixture());
      List<String> idsOf(String keyword) =>
          ShowroomParser.search(snapshot, keyword).map((live) => '${live.roomId}').toList();
      expect(idsOf('$_roomId'), ['$_roomId']);
      expect(idsOf(_otherKey), ['$_otherRoom']);
      expect(idsOf('ROOMA'), ['$_roomId']);
      expect(idsOf('ルーム'), ['$_roomId', '102', '$_otherRoom']);
      expect(idsOf('テスト'), ['$_roomId', '102', '$_otherRoom'], reason: 'the telop of every row');
      expect(idsOf('ミュージック'), ['$_roomId', '102', '$_otherRoom']);
      expect(idsOf(' nobody '), isEmpty);
      expect(ShowroomParser.search(snapshot, ''), isEmpty);
    });
  });

  group('rooms', () {
    test('a profile answers for its own room only', () {
      final profile = ShowroomParser.profile(_profileFixture(), roomId: _roomId);
      expect(profile.roomId, _roomId);
      expect(profile.roomUrlKey, _roomKey);
      expect(profile.name, 'ルームA');
      expect(profile.cover, _image('square.png'));
      expect(profile.genreId, 1);
      expect(profile.followers, 1200);
      expect(profile.views, 3400);
      expect(profile.description, 'よろしくね');
      expect(profile.liveStartedAt, DateTime.fromMillisecondsSinceEpoch(_startedAt * 1000, isUtc: true));
      expect(
        () => ShowroomParser.profile(_profileFixture(), roomId: _otherRoom),
        throwsA(predicate((e) => '$e'.contains('answer for room $_roomId, asked $_otherRoom'))),
      );
      expect(
        () => ShowroomParser.profile(_profileFixture(isOnlive: 'yes'), roomId: _roomId),
        throwsA(predicate((e) => '$e'.contains('is_onlive'))),
      );
      expect(
        () => ShowroomParser.profile(_profileFixture(genreId: null), roomId: _roomId),
        throwsA(anything),
        reason: 'a profile without a genre_id is refused',
      );
      expect(
        () => ShowroomParser.profile(_profileFixture(mainName: ''), roomId: _roomId),
        throwsA(anything),
        reason: 'the name must not be blank',
      );
    });

    test('a room_name answers when the main_name is missing', () {
      final body = _json({
        'room_id': _roomId,
        'room_url_key': _roomKey,
        'room_name': 'ルームA',
        'genre_id': 1,
        'is_onlive': false,
      });
      expect(ShowroomParser.profile(body, roomId: _roomId).name, 'ルームA');
    });

    test('a live info tells live, offline and the unknown states apart', () {
      final live = ShowroomParser.liveInfo(_liveInfoFixture(), roomId: _roomId);
      expect(live.live, isTrue);
      expect(live.restriction, LiveRestriction.none);
      expect(live.danmaku?.host, _bcsvrHost);
      expect(live.danmaku?.key, _bcsvrKey);
      expect(ShowroomParser.liveInfo(_liveInfoFixture(liveStatus: 0), roomId: _roomId).live, isFalse);
      expect(ShowroomParser.liveInfo(_liveInfoFixture(liveStatus: 1), roomId: _roomId).live, isFalse);
      expect(() => ShowroomParser.liveInfo(_liveInfoFixture(liveStatus: 3), roomId: _roomId), throwsA(anything));
      expect(
        () => ShowroomParser.liveInfo(_liveInfoFixture(roomId: _otherRoom), roomId: _roomId),
        throwsA(predicate((e) => '$e'.contains('answer for room $_otherRoom'))),
      );
      expect(
        ShowroomParser.liveInfo(_liveInfoFixture(premium: 'x'), roomId: _roomId).restriction,
        isNull,
        reason: 'an unknown premium type is not known, not refused',
      );
    });

    test('comment arguments are only for hosts on showroom-live.com', () {
      ShowroomDanmakuArgs? argsOf(Object host, Object key) =>
          ShowroomParser.danmakuArgs(roomId: _roomId, host: host, key: key);
      expect(argsOf(_bcsvrHost, _bcsvrKey)!.host, _bcsvrHost);
      expect(argsOf('BCSVR42.O.Showroom-Live.com', _bcsvrKey)!.host, _bcsvrHost, reason: 'the host is lower-cased');
      for (final (Object host, Object key) in [
        ('evil.com', _bcsvrKey),
        ('showroom-live.com.evil.com', _bcsvrKey),
        ('bcsvr42', _bcsvrKey),
        ('-bad.showroom-live.com', _bcsvrKey),
        ('', _bcsvrKey),
        (5, _bcsvrKey),
        (_bcsvrHost, 'a key with spaces'),
        (_bcsvrHost, 'key\ttab'),
        (_bcsvrHost, ''),
      ]) {
        expect(argsOf(host, key), isNull, reason: '$host / $key');
      }
      expect(ShowroomParser.danmakuArgs(roomId: _roomId, host: _bcsvrHost, key: 'x' * 256), isNotNull);
      expect(ShowroomParser.danmakuArgs(roomId: _roomId, host: _bcsvrHost, key: 'x' * 257), isNull);
    });

    test('the status of a key names its room, a 404 is not-found', () {
      expect(ShowroomParser.roomIdOfStatus(_statusFixture()), _roomId);
      expect(() => ShowroomParser.roomIdOfStatus(_statusFixture(), status: 404), throwsA(anything));
      expect(() => ShowroomParser.roomIdOfStatus(_json({'room_id': 0})), throwsA(anything));
    });

    test('a room number is a positive integer, nothing else', () {
      expect(ShowroomParser.roomNumber(' 42 '), 42);
      expect(ShowroomParser.roomNumber('0'), isNull);
      expect(ShowroomParser.roomNumber('-3'), isNull);
      expect(ShowroomParser.roomNumber(_roomKey), isNull);
    });
  });

  group('gift table', () {
    test('the normal and enquete gifts are in the table by id', () {
      final gifts = ShowroomParser.giftList(_giftListFixture());
      expect(gifts.length, 3);
      expect(gifts['1']?.name, 'スター');
      expect(gifts['1']?.free, isTrue);
      expect(gifts['2']?.point, 50);
      expect(gifts['2']?.free, isFalse);
      expect(gifts['2']?.image, Uri.parse(_image('g2.png')));
      expect(gifts['3']?.name, 'アンケート', reason: 'the enquete gifts are in');
      expect(gifts['4'], isNull, reason: 'the other list is not read');
    });

    test('a picture must be on a SHOWROOM host', () {
      final gifts = ShowroomParser.giftList(
        _json({
          'normal': [
            {'gift_id': 9, 'gift_name': 'x', 'point': 1, 'free': true, 'image': 'https://evil.com/g.png'},
          ],
        }),
      );
      expect(gifts['9']?.image, isNull);
    });

    test('a refused answer is refused', () {
      expect(() => ShowroomParser.giftList('no', status: 429), throwsA(anything));
      expect(() => ShowroomParser.giftList('[]'), throwsA(anything));
    });
  });

  group('streams', () {
    test('the tiers are named and ordered like the reference serves them', () {
      final tiers = ShowroomParser.tiers([
        _tierRow('hls_all', 100, 0, '自動', url: _hls('auto.m3u8')),
        _tierRow('hls', 1, 100, '低画質', url: _hls('low.m3u8')),
        _tierRow('hls', 2, 1000, '高画質', url: _hls('hi.m3u8')),
        _tierRow('hls', 3, 200, '中画質', url: _hls('mid.m3u8')),
        {..._tierRow('webrtc', 9, 1000, 'web'), 'url': 'wss://hls.showroom-live.com/x'},
        _tierRow('hls', 2, 1000, '高画質', url: _hls('hi.m3u8')),
      ]);
      expect(tiers.map((tier) => tier.quality.label), ['原画', '中画质', '低画质', '自动']);
      expect(tiers.map((tier) => tier.quality.id), ['hls:2:1000', 'hls:3:200', 'hls:1:100', 'hls_all:100:0']);
      expect(tiers.map((tier) => tier.quality.order), [1000, 200, 100, -1]);
      final qualities = ShowroomParser.qualities([
        _tierRow('hls_all', 100, 0, '自動', url: _hls('auto.m3u8')),
        _tierRow('hls', 2, 1000, '高画質', url: _hls('hi.m3u8')),
      ]);
      expect(qualities.map((quality) => quality.label), ['原画', '自动']);
      expect(qualities.first.qualityId, 'hls:2:1000');
      expect(qualities.last.platformOrder, ShowroomEndpoints.autoSort);
    });

    test('an irregular tier costs only itself, unless none is usable', () {
      final tiers = ShowroomParser.tiers([
        _tierRow('hls', 1, 200, '中画質'),
        _tierRow('hls', 2, 1000, '高画質', url: 'http://evil.com/x.m3u8'),
        {'no type': true},
      ]);
      expect(tiers, hasLength(1));
      expect(
        () => ShowroomParser.tiers([_tierRow('hls', 2, 1000, '高画質', url: 'http://evil.com/x.m3u8')]),
        throwsA(predicate((e) => '$e'.contains('none of the 1 HLS rows'))),
      );
      expect(() => ShowroomParser.tiers(const []), throwsA(predicate((e) => '$e'.contains('no HLS stream'))));
      expect(
        () => ShowroomParser.tiers([_tierRow('hls', 2, 1000, '高画質', isDefault: 'yes')]),
        throwsA(predicate((e) => '$e'.contains('none of the 1 HLS rows'))),
        reason: 'a tier only the platform could explain is still an unreadable row',
      );
      expect(() => ShowroomParser.tiers(List.filled(65, _tierRow('hls', 1, 200, 'x'))), throwsA(anything));
      expect(
        () => ShowroomParser.tiers([
          {'type': 'hls', 'id': 1, 'quality': 200, 'label': '', 'is_default': true, 'url': _hls('x.m3u8')},
        ]),
        throwsA(anything),
        reason: 'a tier without a label is refused',
      );
    });

    test('a repeated url is one tier', () {
      final tiers = ShowroomParser.tiers([_tierRow('hls', 1, 200, '中画質'), _tierRow('hls', 1, 200, '中画質')]);
      expect(tiers, hasLength(1));
    });

    test('the line carries the media headers, its type and no lease', () {
      final tier = ShowroomParser.tiers([_tierRow('hls_all', 100, 0, '自動', url: _hls('auto.m3u8'))]).single;
      final line = ShowroomParser.line(tier);
      expect(line.url, _hls('auto.m3u8'));
      expect(line.format, LiveStreamFormat.hls);
      expect(line.formatSource, LivePlayFormatSource.declared);
      expect(line.lineLabel, 'hls_all');
      expect(line.headers, ShowroomEndpoints.mediaHeaders);
      expect(line.lease, isNull, reason: 'the urls are not signed and do not expire');
    });

    test('the rows of an answer are the list, 64 at most', () {
      expect(ShowroomParser.streamRows(_streamingFixture()), hasLength(2));
      expect(
        () => ShowroomParser.streamRows(_json({'streaming_url_list': List.filled(65, _tierRow('hls', 1, 1, 'x'))})),
        throwsA(anything),
      );
      expect(() => ShowroomParser.streamRows(_json({'streaming_url_list': 'no'})), throwsA(anything));
    });
  });

  group('links', () {
    test('a profile page names its room, key pages name their key', () {
      expect(ShowroomParser.link(Uri.parse('${ShowroomEndpoints.origin}/room/profile?room_id=$_roomId')), (
        roomId: '$_roomId',
        key: null,
      ));
      expect(ShowroomParser.link(Uri.parse('${ShowroomEndpoints.origin}/r/$_roomKey')), (roomId: null, key: _roomKey));
      expect(ShowroomParser.link(Uri.parse('${ShowroomEndpoints.origin}/$_roomKey'))?.key, _roomKey);
      expect(ShowroomParser.link(Uri.parse('http://www.showroom-live.com/r/$_roomKey'))?.key, _roomKey);
      expect(
        ShowroomParser.link(Uri.parse('https://live.showroom-live.com/room/profile?room_id=$_roomId&x=1'))?.roomId,
        '$_roomId',
      );
    });

    test('a page that is no room is no link', () {
      for (final bad in [
        'https://www.showroom-live.com/',
        'https://www.showroom-live.com/r/api',
        'https://www.showroom-live.com/ranking',
        'https://www.showroom-live.com/R/onlive',
        'https://www.showroom-live.com/room/other',
        'https://www.showroom-live.com/room/profile',
        'https://www.showroom-live.com/room/profile?room_id=0123',
        'https://www.showroom-live.com/room/profile?room_id=99999999999999999999999',
        'https://www.showroom-live.com/r/$_roomKey/extra',
        'https://www.showroom-live.com/r/bad key',
        'https://evil.com/r/$_roomKey',
        'https://u:p@www.showroom-live.com/r/$_roomKey',
        'ftp://www.showroom-live.com/r/$_roomKey',
      ]) {
        expect(ShowroomParser.link(Uri.tryParse(bad)), isNull, reason: bad);
      }
    });

    test('the canonical page of a room is its profile page', () {
      expect(ShowroomEndpoints.roomUrl('$_roomId'), '${ShowroomEndpoints.origin}/room/profile?room_id=$_roomId');
      expect(ShowroomEndpoints.roomUrl(_roomKey), isNull);
      expect(ShowroomEndpoints.roomUrl(' 8 '), '${ShowroomEndpoints.origin}/room/profile?room_id=8');
    });
  });

  group('chat protocol', () {
    test('the socket address and the frames name the broadcast', () {
      final endpoint = ShowroomDanmakuCodec.endpoint(_bcsvrHost);
      expect(endpoint.scheme, 'wss');
      expect(endpoint.host, _bcsvrHost);
      expect(endpoint.path, '/');
      expect(ShowroomDanmakuCodec.subscribe(_bcsvrKey), 'SUB\t$_bcsvrKey');
      expect(ShowroomDanmakuCodec.ping, 'PING\tshowroom');
      expect(ShowroomDanmakuCodec.socketHeaders['origin'], ShowroomEndpoints.origin);
    });

    test('the arguments are re-checked, the host lower-cased', () {
      final checked = ShowroomDanmakuCodec.checked(
        const ShowroomDanmakuArgs(roomId: '$_roomId', host: 'BCSVR.o.showroom-live.com', key: _bcsvrKey),
      );
      expect(checked?.host, 'bcsvr.o.showroom-live.com');
      expect(ShowroomDanmakuCodec.checked(const ShowroomDanmakuArgs(roomId: '1', host: 'evil.com', key: 'k')), isNull);
    });

    test('a comment line is read with its sender and time', () {
      final chat = ShowroomDanmakuCodec.decode(
        _msgFrame(_bcsvrKey, {'t': 1, 'cm': ' こんちゃん ', 'ac': ' 観客 ', 'u': 7, 'cl': 3, 'created_at': _startedAt}),
        key: _bcsvrKey,
      ).single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, 'こんちゃん');
      expect(chat.effectiveSender.userName, '観客');
      expect(chat.effectiveSender.userId, '7');
      expect(chat.effectiveSender.userLevel, '3');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(_startedAt * 1000));
      // A counting comment is a SHOWROOM custom and stays.
      final counting = ShowroomDanmakuCodec.decode(
        _msgFrame(_bcsvrKey, {'t': 1, 'cm': 5, 'ac': 'n', 'u': 1, 'cl': 0}),
        key: _bcsvrKey,
      ).single;
      expect(counting.text, '5');
      expect(counting.effectiveSender.userLevel, '');
      expect(counting.sentAt, isNull);
      // A blank text, a wrong kind and a bad time are nothing.
      expect(
        ShowroomDanmakuCodec.decode(_msgFrame(_bcsvrKey, {'t': 1, 'cm': '   ', 'ac': 'n', 'u': 1}), key: _bcsvrKey),
        isEmpty,
      );
      expect(
        ShowroomDanmakuCodec.decode(_msgFrame(_bcsvrKey, {'t': 8, 'cm': 'x', 'ac': 'n', 'u': 1}), key: _bcsvrKey),
        isEmpty,
      );
      expect(
        ShowroomDanmakuCodec.decode(
          _msgFrame(_bcsvrKey, {'t': 1, 'cm': 'x', 'ac': 'n', 'u': 1, 'created_at': -5}),
          key: _bcsvrKey,
        ).single.sentAt,
        isNull,
      );
      // The kind also arrives as a string, as the archived client read it.
      expect(
        ShowroomDanmakuCodec.decode(_msgFrame(_bcsvrKey, {'t': '1', 'cm': 'x', 'ac': 'n', 'u': 1}), key: _bcsvrKey),
        hasLength(1),
      );
    });

    test('a gift is priced in points by the room table, or by its own kind', () {
      final gifts = ShowroomParser.giftList(_giftListFixture());
      final paid = ShowroomDanmakuCodec.decode(
        _msgFrame(_bcsvrKey, {'t': 2, 'g': 2, 'n': 2, 'ac': ' 観客 ', 'u': 9, 'cl': 2, 'created_at': _startedAt}),
        key: _bcsvrKey,
        gifts: gifts,
      ).single;
      final gift = paid.payload! as LiveGift;
      expect(gift.giftId, '2');
      expect(gift.name, 'ハート');
      expect(gift.count, 2);
      expect(gift.iconUrl, _image('g2.png'));
      expect(gift.value.unit, LiveGiftUnit.point);
      expect(gift.value.unitPrice, 50.0);
      expect(gift.value.totalValue, 100.0);
      expect(gift.combo.comboKey, '', reason: 'the platform gives no combo');
      expect(gift.recipientName, '');
      expect(paid.text, 'ハート ×2');
      expect(paid.effectiveSender.userName, '観客');
      expect(paid.effectiveSender.userId, '9');
      expect(paid.effectiveSender.userLevel, '2');

      final free = ShowroomDanmakuCodec.decode(
        _msgFrame(_bcsvrKey, {'t': 2, 'g': 1, 'n': 1, 'ac': 'n', 'u': 1}),
        key: _bcsvrKey,
        gifts: gifts,
      ).single;
      expect((free.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect((free.payload! as LiveGift).value.unitPrice, isNull);

      // Without the table, gt 2 (the recorded stars) is free and the rest
      // keeps its id and the default picture.
      final unknownFree = ShowroomDanmakuCodec.decode(
        _msgFrame(_bcsvrKey, {'t': 2, 'g': 7, 'n': 1, 'gt': '2', 'ac': 'n', 'u': 1}),
        key: _bcsvrKey,
      ).single;
      var unknownGift = unknownFree.payload! as LiveGift;
      expect(unknownGift.value.unit, LiveGiftUnit.free);
      expect(unknownGift.iconUrl, ShowroomDanmakuCodec.giftImage('7').toString());
      final unknownPaid = ShowroomDanmakuCodec.decode(
        _msgFrame(_bcsvrKey, {'t': 2, 'g': 8, 'n': 3, 'ac': 'n', 'u': 1}),
        key: _bcsvrKey,
      ).single;
      unknownGift = unknownPaid.payload! as LiveGift;
      expect(unknownGift.name, '');
      expect(unknownGift.value.unit, LiveGiftUnit.point);
      expect(unknownGift.value.unitPrice, isNull);
      expect(unknownGift.value.totalValue, isNull);
      expect(unknownGift.count, 3);
      // A frame without a usable gift id is nothing.
      expect(ShowroomDanmakuCodec.decode(_msgFrame(_bcsvrKey, {'t': 2, 'g': 0, 'n': 1}), key: _bcsvrKey), isEmpty);
      expect(ShowroomDanmakuCodec.decode(_msgFrame(_bcsvrKey, {'t': 2, 'g': '', 'n': 1}), key: _bcsvrKey), isEmpty);
    });

    test('a frame of another key, or no MSG at all, is nothing', () {
      expect(ShowroomDanmakuCodec.decode(_msgFrame('other', {'t': 1, 'cm': 'x'}), key: _bcsvrKey), isEmpty);
      expect(ShowroomDanmakuCodec.decode('ACK\tshowroom', key: _bcsvrKey), isEmpty);
      expect(ShowroomDanmakuCodec.decode('SUB\t$_bcsvrKey', key: _bcsvrKey), isEmpty);
      expect(ShowroomDanmakuCodec.decode('MSG\tnojson', key: _bcsvrKey), isEmpty);
      expect(ShowroomDanmakuCodec.decode('MSG\t$_bcsvrKey\tnot json', key: _bcsvrKey), isEmpty);
      expect(ShowroomDanmakuCodec.decode('MSG\t$_bcsvrKey\t[1]', key: _bcsvrKey), isEmpty);
      expect(ShowroomDanmakuCodec.decode(5, key: _bcsvrKey), isEmpty);
      expect(
        ShowroomDanmakuCodec.decode(
          utf8.encode(_msgFrame(_bcsvrKey, {'t': 1, 'cm': 'ばいと', 'ac': 'n', 'u': 1})),
          key: _bcsvrKey,
        ),
        hasLength(1),
        reason: 'the bytes are read as utf-8',
      );
    });
  });

  group('gift catalog', () {
    test('the table is asked once and reused', () async {
      final adapter = _adapter();
      final first = await adapter.site.giftCatalog('$_roomId');
      final second = await adapter.site.giftCatalog('$_roomId');
      expect(first.length, 3);
      expect(identical(first, second), isTrue);
      expect(adapter.http.sent.where((seen) => seen.url.path == '/api/live/gift_list'), hasLength(1));
    });

    test('a failed table counts as empty and is asked again after the pause', () async {
      var clock = _at;
      final adapter = _adapter(
        onSend: (request) => request.url.path == '/api/live/gift_list' ? _resp(500, 'no') : _ordinary(request),
        now: () => clock,
      );
      expect(await adapter.site.giftCatalog('$_roomId'), ShowroomGiftCatalog.empty);
      expect(await adapter.site.giftCatalog('$_roomId'), ShowroomGiftCatalog.empty);
      expect(adapter.http.sent.where((seen) => seen.url.path == '/api/live/gift_list'), hasLength(1));
      clock = _at.add(const Duration(minutes: 6));
      await adapter.site.giftCatalog('$_roomId');
      expect(adapter.http.sent.where((seen) => seen.url.path == '/api/live/gift_list'), hasLength(2));
    });
  });

  group('comment session', () {
    test('a session subscribes at the open and pings every minute', () async {
      final chat = await _chat();
      expect(chat.connector.endpoints.single.host, _bcsvrHost);
      expect(chat.connector.endpoints.single.scheme, 'wss');
      expect(chat.socket.sentText, 'SUB\t$_bcsvrKey', reason: 'the subscription goes out at once');
      chat.timers.ring(index: chat.timers.every.length - 1);
      expect(chat.socket.sentText, endsWith(ShowroomDanmakuCodec.ping), reason: 'the ping');
      expect(chat.timers.every.single.period, ShowroomDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        contains(ShowroomDanmakuCodec.silenceTimeout),
        reason: 'the watchdog: the server confirms nothing, so there is no join timer',
      );
      await chat.session.dispose();
    });

    test('the gift table is asked in the background and names the gifts', () async {
      final chat = await _chat();
      final after = _next(chat.session.events, 1);
      chat.socket.push(_msgFrame(_bcsvrKey, {'t': 2, 'g': 2, 'n': 1, 'ac': 'n', 'u': 1}));
      final gift = (await after).single;
      expect((gift.payload! as LiveGift).name, 'ハート', reason: 'the table came before the gift');
      await chat.session.dispose();
    });

    test('comments are reported', () async {
      final chat = await _chat();
      final after = _next(chat.session.events, 1);
      chat.socket.push(_msgFrame(_bcsvrKey, {'t': 1, 'cm': 'はろー', 'ac': 'n', 'u': 1}));
      expect((await after).single.text, 'はろー');
      await chat.session.dispose();
    });

    test('a silent or closed socket is replaced, and replacements re-arm the watches', () async {
      final chat = await _chat();
      final first = chat.socket;
      // No frame in time: the socket is replaced.
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.timers.after.last.delay, ShowroomDanmakuCodec.reconnectBaseDelay, reason: 'the backoff of run 1');
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(first.closed, isTrue);
      // The replacement answers, so the watchdog is renewed, then goes silent
      // in turn: replaced again.
      chat.connector.latest.push(ShowroomDanmakuCodec.ack);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      // A run that opened has joined, so its budget is its own: silent runs
      // keep being replaced.
      await chat.connector.latest.ended();
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(4));
      await chat.session.dispose();
    });

    test('eight runs that never come to live end the session', () async {
      final down = _DownConnector();
      final timers = FakeTimers();
      final session = ShowroomDanmakuSession(
        args: const ShowroomDanmakuArgs(roomId: '$_roomId', host: _bcsvrHost, key: _bcsvrKey),
        site: _adapter(connect: down.call).site,
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      await _settle();
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 1; attempt <= ShowroomDanmakuCodec.maxReconnects; attempt++) {
        expect(timers.after.last.delay, ShowroomDanmakuCodec.reconnectBaseDelay * attempt, reason: 'attempt $attempt');
        timers.fire(index: timers.after.length - 1);
        await _settle();
      }
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      expect(down.attempts, ShowroomDanmakuCodec.maxReconnects + 1, reason: 'the first run and its eight retries');
      await session.dispose();
    });

    test('an unusable server or key is refused before any socket', () async {
      final connector = _Connector();
      final session = ShowroomDanmakuSession(
        args: const ShowroomDanmakuArgs(roomId: '$_roomId', host: 'evil.com', key: _bcsvrKey),
        site: _adapter(connect: connector.call).site,
        timers: FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the capabilities the reference has', () async {
      final site = _adapter().site;
      expect(site.manifest.id, 'showroom');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveHotProvider>(), isNull, reason: 'the reference has no hot list');
      expect(site.capability<LiveAnchorProvider>(), isNull, reason: 'the reference has no anchor lookup');
      await site.dispose();
    });

    test('the directory is sliced locally over one snapshot', () async {
      var clock = _at;
      final adapter = _adapter(now: () => clock);
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.items.map((room) => room.roomId), ['$_roomId', '102']);
      expect(first.hasMore, isFalse);
      final second = _right(await rooms.getRooms(const LivePageRequest(page: 2)));
      expect(second.items, isEmpty);
      expect(
        adapter.http.sent.where((seen) => seen.url.path == '/api/live/onlives'),
        hasLength(1),
        reason: 'page 2 comes from the page 1 snapshot',
      );
      // Page 1 is the pull to refresh: it asks anew at once, young snapshot
      // or not; page 2 keeps sharing the snapshot while it is young.
      clock = _at.add(const Duration(seconds: 10));
      await rooms.getRooms(const LivePageRequest());
      expect(adapter.http.sent.where((seen) => seen.url.path == '/api/live/onlives'), hasLength(2));
      await rooms.getRooms(const LivePageRequest(page: 2));
      expect(adapter.http.sent.where((seen) => seen.url.path == '/api/live/onlives'), hasLength(2));
      clock = _at.add(const Duration(seconds: 41));
      await rooms.getRooms(const LivePageRequest(page: 2));
      expect(
        adapter.http.sent.where((seen) => seen.url.path == '/api/live/onlives'),
        hasLength(3),
        reason: 'a snapshot older than its lifetime is asked anew, even for page 2',
      );
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(page: 0))), isA<LiveSiteInvalidArgument>());
    });

    test('the genres are the areas, and the rooms under each', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      final areas = _right(await area.getAreas());
      expect(areas.map((entry) => entry.areaId), ['0', '1', '2']);
      expect(areas.first.areaName, 'Popularity');
      expect(areas.first.parentAreaId, 'showroom');
      expect(areas.last.areaName, 'Music', reason: 'the empty genre is kept');
      final page = _right(await area.getAreaRooms(areaId: '1'));
      expect(page.items.single.roomId, '$_otherRoom');
      expect(_leftOf(await area.getAreaRooms(areaId: 'dance')), isA<LiveSiteInvalidArgument>());
      expect(_leftOf(await area.getAreaRooms(areaId: '99')), isA<LiveSiteNotFound>());
    });

    test('the recommendations are the Popularity genre, sliced as asked', () async {
      final adapter = _adapter();
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final page = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 1)));
      expect(page.items.single.roomId, '$_roomId');
      expect(page.hasMore, isTrue, reason: 'the Popularity genre has another room');
      final rest = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2, pageSize: 1)));
      expect(rest.items.single.roomId, '102');
      expect(rest.hasMore, isFalse);
      expect(
        _right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 101))).items,
        isEmpty,
        reason: 'a size over the largest slice gives nothing',
      );
    });

    test('the search filters the snapshot, page 1 anew', () async {
      var clock = _at;
      final adapter = _adapter(now: () => clock);
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final hit = await search.search(const LiveSearchRequest(query: _otherKey, target: LiveSearchTarget.rooms));
      expect((_right(hit).items.single as RoomSearchResult).room.roomId, '$_otherRoom');
      expect(_right(hit).hasMore, isFalse);
      // Page 2 comes from the page 1 snapshot, so it does not repeat page 1.
      final second = await search.search(
        const LiveSearchRequest(query: 'ルーム', target: LiveSearchTarget.rooms, page: 2, pageSize: 1),
      );
      expect((_right(second).items.single as RoomSearchResult).room.roomId, '102');
      expect(_right(second).hasMore, isTrue, reason: 'three rooms match, one a page');
      expect(adapter.http.sent.where((seen) => seen.url.path == '/api/live/onlives'), hasLength(1));
      clock = _at.add(const Duration(seconds: 41));
      await search.search(const LiveSearchRequest(query: 'ルーム', target: LiveSearchTarget.rooms, page: 2, pageSize: 1));
      expect(
        adapter.http.sent.where((seen) => seen.url.path == '/api/live/onlives'),
        hasLength(2),
        reason: 'the snapshot grew old, so even page 2 asks anew',
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: ' ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
        reason: 'a blank keyword finds nothing, without a request',
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, pageSize: 101)))
            .items,
        isEmpty,
      );
    });

    test('an entry is the profile and the live info, with its handles', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_roomKey));
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/api/room/status',
        '/api/room/profile',
        '/api/live/live_info',
        '/api/live/streaming_url',
      ]);
      expect(room.roomId, '$_roomId', reason: 'the key named this room');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.content.introduction, 'よろしくね');
      expect(room.runtime.danmakuHandle, isA<ShowroomDanmakuArgs>());
      expect(room.runtime.streamHandle, isA<ShowroomStreamData>());
      // The qualities and lines come from the entry, without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: '$_roomId'));
      expect(qualities.map((quality) => quality.label), ['原画', '中画质']);
      final lines = _right(await playback.getLines(roomId: '$_roomId'));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.headers, ShowroomEndpoints.mediaHeaders);
      expect(lines.single.lease, isNull);
      final auto = _right(
        await playback.getLines(
          roomId: '$_roomId',
          quality: const LivePlayQuality(label: 'x', qualityId: 'hls:1:200'),
        ),
      );
      expect(Uri.parse(auto.single.url).path, '/live/1.m3u8');
      expect(
        _leftOf(
          await playback.getLines(
            roomId: '$_roomId',
            quality: const LivePlayQuality(label: 'x', qualityId: 'hls:9:9'),
          ),
        ),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the rows');
    });

    test('an offline room opens, and its playback says so without a request', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/api/live/live_info' => _resp(200, _liveInfoFixture(liveStatus: 0)),
          _ => _ordinary(request),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom('$_roomId'));
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/api/room/profile',
        '/api/live/live_info',
      ], reason: 'an offline room is not asked for streams');
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.audience.totalViewers, isNull);
      expect(room.broadcast.startedAt, isNull);
      expect(room.runtime.danmakuHandle, isNull);
      final before = adapter.http.sent.length;
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '$_roomId')),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(adapter.http.sent.length, before, reason: 'entry already said the room is offline');
      expect(
        _leftOf(await adapter.site.capability<LiveDanmakuProvider>()!.createSession(roomId: '$_roomId')),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a room whose streams cannot be read still opens, and asks again', () async {
      final adapter = _adapter(
        onSend: (request) => request.url.path == '/api/live/streaming_url' ? _resp(500, 'no') : _ordinary(request),
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom('$_roomId'));
      expect(room.broadcast.liveStatus, LiveStatus.live, reason: 'the room still opens');
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '$_roomId')),
        isA<LiveSiteNetworkError>(),
        reason: 'the qualities ask again, and fail again',
      );
    });

    test('a room never entered asks for its streams', () async {
      final adapter = _adapter();
      final qualities = _right(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '$_roomId'));
      expect(qualities, hasLength(2));
      expect(adapter.http.sent.single.url.path, '/api/live/streaming_url');
    });

    test('a link is canonicalized, a key needs its room', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      final page = Uri.parse('${ShowroomEndpoints.origin}/room/profile?room_id=$_roomId');
      expect(_right(await link.resolve(page)), page);
      expect(adapter.http.sent, isEmpty, reason: 'a profile page needs no request');
      expect(_right(await link.resolve(Uri.parse('${ShowroomEndpoints.origin}/r/$_roomKey'))), page);
      expect(adapter.http.sent.single.url.path, '/api/room/status');
      // A key made of digits only is never read as a room id.
      adapter.http.sent.clear();
      expect(
        _right(await link.resolve(Uri.parse('${ShowroomEndpoints.origin}/r/7779344804'))),
        Uri.parse('${ShowroomEndpoints.origin}/room/profile?room_id=$_roomId'),
      );
      expect(adapter.http.sent.single.url.queryParameters['room_url_key'], '7779344804');
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/r/x'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('${ShowroomEndpoints.origin}/onlive'))), isA<LiveSiteNotFound>());
      expect(
        _leftOf(await link.resolve(Uri.parse('${ShowroomEndpoints.origin}/r/unknownkey'))),
        isA<LiveSiteNotFound>(),
      );
    });

    test('a status the gate refuses is mapped', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(
        _leftOf(await refused.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest())),
        isA<LiveSiteRateLimitError>(),
      );
      final gone = _adapter(onSend: (_) => _resp(404, 'nope'));
      expect(
        _leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom('!!')),
        isA<LiveSiteNotFound>(),
        reason: 'not a room id or key: refused without a request',
      );
      expect(gone.http.sent, isEmpty, reason: 'the junk id never went out');
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_roomKey)), isA<LiveSiteNotFound>());
    });

    test('the chat provider builds a session only for an entered broadcast', () async {
      final opened = _Connector();
      final adapter = _adapter(connect: opened.call);
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _roomKey));
      expect(session, isA<ShowroomDanmakuSession>());
      await _settle();
      expect(opened.endpoints.single.host, _bcsvrHost, reason: 'the entry resolved the comment server');
      await session.dispose();
    });
  });
}

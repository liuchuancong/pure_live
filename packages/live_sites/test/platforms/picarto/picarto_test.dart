import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_http.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_codec.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_session.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_json.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_link.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_room_parser.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: the start of the broadcast on air.
final DateTime _at = DateTime.parse('2026-09-28T16:12:10.000Z').toUtc();

const String _name = 'TheBaker';
const String _lower = 'thebaker';
const int _channelId = 12345;
const String _edge = 'use1-1';
const String _token = 'eyJh.eyJi.c3ln';

String _json(Object? data) => jsonEncode(data);

/// An explore row, a detail's channel or a search profile; the fields each
/// answer carries differ.
Map<String, Object?> _channel({
  int id = _channelId,
  String name = _name,
  Object? online = true,
  Object? adult = false,
  Object? private,
  String title = '今晚画点东西',
  String avatar = 'https://images.picarto.tv/a.png',
  String thumbnail = 'https://images.picarto.tv/thumb.png',
  Object? viewers = 4211,
  Object? totalViews,
  Object? followers,
  List<Object?>? categories,
  List<Object?>? descriptions,
}) => {
  'id': id,
  'name': name,
  'online': online,
  'adult': adult,
  'private': ?private,
  'title': title,
  'avatar': avatar,
  'image_thumbnail': thumbnail,
  'viewers': viewers,
  'total_views': ?totalViews,
  'followers_count': ?followers,
  'categories':
      categories ??
      [
        {'id': 5, 'name': 'Draw'},
      ],
  'descriptions': ?descriptions,
};

String _exploreFixture({
  required int page,
  required int pageSize,
  List<Object?>? rows,
  int lastPage = 3,
  int? total = 90,
  Object? currentPage,
  Object? perPage,
}) => _json({
  'data': rows ?? [_channel()],
  'current_page': currentPage ?? page,
  'per_page': perPage ?? pageSize,
  'last_page': lastPage,
  'total': total,
});

Map<String, Object?> _profile({
  int id = _channelId,
  String name = _name,
  Object? online = false,
  String bio = '画画的 &amp; 睡觉的',
  Object? followers = 9876,
}) => {
  'id': id,
  'name': name,
  'online': online,
  'avatar': 'https://images.picarto.tv/a.png',
  'bio': bio,
  'follower_count': followers,
};

String _searchFixture({List<Object?>? rows}) => _json({
  'searchProfiles': {
    'data': rows ?? [_profile()],
  },
});

String _detailFixture({
  Map<String, Object?>? channel,
  List<Object?>? streams,
  Object? edge = _edge,
  bool channelNull = false,
}) => _json({
  if (channelNull)
    'channel': null
  else
    'channel':
        channel ??
        _channel(
          private: false,
          totalViews: 500000,
          followers: 9876,
          descriptions: [
            {'body': '第一段'},
            {'body': '第二段'},
          ],
        ),
  'getMultiStreams': {
    'streams':
        streams ??
        [
          {
            'channelId': _channelId,
            'stream_name': '${_lower}_1080p60',
            'thumbnail_image': 'https://images.picarto.tv/live.png',
          },
        ],
  },
  'getLoadBalancerUrl': {'origin': edge},
});

String _categoriesFixture({List<Object?>? categories}) => _json({
  'categories':
      categories ??
      [
        {'id': 1, 'label': 'Drawing'},
        {'id': 2, 'label': 'Gaming'},
      ],
});

String _publicFixture({String name = _name, Object? online = true, String lastLive = '2026-09-28 16:12:10'}) =>
    _json({'name': name, 'online': online, 'last_live': lastLive});

const String _master =
    '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.64002A,mp4a.40.2"
https://$_edge.picarto.tv/stream/hls/${_lower}_1080p60/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720,FRAME-RATE=30.000,CODECS="avc1.64001F,mp4a.40.2"
https://$_edge.picarto.tv/stream/hls/${_lower}_720p30/index.m3u8
''';

/// The master playlist URL the detail's load balancer named.
final Uri _masterUri = Uri.parse('https://$_edge.picarto.tv/stream/hls/${_lower}_1080p60/index.m3u8');

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : method = request.method, url = request.url;
  final String method;
  final Uri url;

  @override
  String toString() => '$method $url';
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

/// The answers of the site: catalog, explore, search, detail, the public
/// record, the master playlist and the chat token.
Future<LiveResponse> _ordinary(_Seen seen) async {
  final url = seen.url;
  if (url.path == '/ptvapi') {
    return _resp(
      200,
      _json({
        'data': {
          'generateJwtToken': {'key': _token},
        },
      }),
    );
  }
  if (url.host == PicartoEndpoints.publicApiHost) {
    return _resp(200, _publicFixture());
  }
  if (url.host.endsWith('picarto.tv') && url.path.endsWith('index.m3u8')) {
    return _resp(200, _master);
  }
  switch (url.path) {
    case '/api/languages-categories':
      return _resp(200, _categoriesFixture());
    case '/api/explore':
      return _resp(
        200,
        _exploreFixture(
          page: int.parse(url.queryParameters['page']!),
          pageSize: int.parse(url.queryParameters['first']!),
          rows: [
            _channel(
              categories: [
                {'id': 1, 'name': 'Drawing'},
              ],
            ),
          ],
        ),
      );
    case '/api/search':
      return _resp(200, _searchFixture());
    case '/api/channel/detail/$_lower':
    case '/api/channel/detail/$_name':
      return _resp(200, _detailFixture());
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

  /// The peer went away: the stream is done.
  Future<void> end() => _stream.close();
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

/// A connector whose handshake hangs: the join budget is what replaces it.
final class _HangingConnector {
  final List<Completer<SocketChannel>> pending = [];
  int asked = 0;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) {
    asked += 1;
    final done = Completer<SocketChannel>();
    pending.add(done);
    return done.future;
  }

  void completeAll() {
    for (final done in pending) {
      if (!done.isCompleted) done.complete(_FakeSocket());
    }
    pending.clear();
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

  PicartoTimers get timers => (after: _after, every: _every);

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

({PicartoSite site, _FakeHttp http}) _adapter({FutureOr<LiveResponse> Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: PicartoSite(http: PicartoHttp(http), connect: _refuseSocket), http: http);
}

void main() {
  group('gates and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, PicartoFailureKind kind) {
        try {
          PicartoJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on PicartoFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, PicartoFailureKind.riskControl);
      expectKind(403, PicartoFailureKind.riskControl);
      expectKind(404, PicartoFailureKind.notFound);
      expectKind(429, PicartoFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, PicartoFailureKind.network);
      }
      PicartoJson.checkStatus(200, 'x');
    });

    test('failures map onto the Either errors, transiently only for network', () {
      for (final kind in PicartoFailureKind.values) {
        final failure = PicartoFailure(kind, 'x');
        final error = failure.toLiveSiteError('picarto');
        expect(error.siteId, 'picarto');
        switch (kind) {
          case PicartoFailureKind.notFound:
            expect(error, isA<LiveSiteNotFound>());
          case PicartoFailureKind.apiChanged:
            expect(error, isA<LiveSiteParseError>());
          case PicartoFailureKind.network:
            expect(error, isA<LiveSiteNetworkError>());
          case PicartoFailureKind.riskControl || PicartoFailureKind.rateLimited:
            expect(error, isA<LiveSiteRateLimitError>(), reason: 'the refusal folds into the rate limit');
          case PicartoFailureKind.streamUnavailable:
            expect(error, isA<LiveSiteContentUnavailable>());
          case PicartoFailureKind.invalidArgument:
            expect(error, isA<LiveSiteInvalidArgument>());
        }
        expect(failure.isTransient, kind == PicartoFailureKind.network || kind == PicartoFailureKind.rateLimited);
      }
    });

    test('the body is bounded and must be a JSON object', () {
      expect(
        () => PicartoJson.json('<html>', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('expected an object'))),
      );
      expect(
        () => PicartoJson.json('{"a":"${'x' * 1100000}"}', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(PicartoJson.json('{"a":1}', 'x', 200), {'a': 1});
    });

    test('readers are strict about what they accept', () {
      expect(PicartoJson.integer(42), 42);
      expect(PicartoJson.integer('42'), 42);
      expect(PicartoJson.integer(4.5), isNull);
      expect(PicartoJson.count(-1), isNull);
      expect(PicartoJson.count('0'), 0);
      expect(PicartoJson.string('  x  '), 'x');
      expect(PicartoJson.string(''), isNull);
      expect(PicartoJson.string(5), '5');
      expect(PicartoEndpoints.isChannelName('The_Baker-1'), isFalse, reason: 'no dash in a channel name');
      expect(PicartoEndpoints.isChannelName('The_Baker1'), isTrue);
      expect(PicartoEndpoints.isChannelName('explore'), isFalse, reason: 'a site path is no channel');
      expect(PicartoEndpoints.isChannelName('a' * 51), isFalse);
    });
  });

  group('catalog', () {
    test('the public directory comes first, then the categories', () {
      final areas = PicartoRoomParser.areas(_categoriesFixture());
      expect(areas.map((area) => area.areaId), ['live', '1', '2']);
      expect(areas.every((area) => area.parentAreaId == 'picarto'), isTrue);
      expect(PicartoRoomParser.categoryIdOf('live'), isNull);
      expect(PicartoRoomParser.categoryIdOf('5'), 5);
      expect(() => PicartoRoomParser.categoryIdOf('05'), throwsA(isA<PicartoFailure>()));
      expect(() => PicartoRoomParser.categoryIdOf('explore'), throwsA(isA<PicartoFailure>()));
    });

    test('a broken entry costs only itself, none usable is api-changed', () {
      final withBroken = PicartoRoomParser.areas(
        _categoriesFixture(
          categories: [
            {'id': 0, 'label': 'no id'},
            {'id': 3, 'label': ''},
            {'id': 4, 'label': 'x' * 101},
            {'id': 3, 'label': 'repeat'},
            {'id': 5, 'label': 'Music'},
          ],
        ),
      );
      expect(withBroken.map((area) => area.areaId), ['live', '3', '5'], reason: 'only ids already taken repeat');
      expect(
        () => PicartoRoomParser.areas(
          _categoriesFixture(
            categories: [
              {'id': 0, 'label': 'no id'},
            ],
          ),
        ),
        throwsA(predicate((e) => '$e'.contains('no valid category'))),
      );
      expect(() => PicartoRoomParser.areas(_json({})), throwsA(predicate((e) => '$e'.contains('no category list'))));
      expect(
        () => PicartoRoomParser.areas(_categoriesFixture(categories: List.filled(201, {'id': 1, 'label': 'x'}))),
        throwsA(isA<PicartoFailure>()),
      );
    });
  });

  group('directory page', () {
    test('the live public rows are read, adult and offline ones left out', () {
      final page = PicartoRoomParser.directoryPage(
        _exploreFixture(
          page: 1,
          pageSize: 30,
          rows: [
            _channel(),
            _channel(id: 2, name: 'AdultOne', adult: true),
            _channel(id: 3, name: 'Sleepy', online: false),
            _channel(id: 4, name: 'NoTitle', title: 'My Channel Title'),
            _channel(name: _lower, id: 9, title: 'the repeated one', viewers: 1),
          ],
        ),
        page: 1,
        pageSize: 30,
      );
      expect(page.rooms, hasLength(2), reason: 'adult, offline and the lower-case repeat are left out');
      expect(page.hasMore, isTrue);
      final room = page.rooms.first;
      expect(room.platform, 'picarto');
      expect(room.roomId, _name);
      expect(room.content.title, '今晚画点东西');
      expect(room.content.coverUrl, 'https://images.picarto.tv/thumb.png');
      expect(room.anchor?.anchorId, '$_channelId');
      expect(room.anchor?.name, _name);
      expect(room.audience.onlineViewers, 4211);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, isNull, reason: 'explore rows carry no private flag');
      expect(room.content.platformTags, ['Draw']);
      expect(room.links.webUrl, 'https://picarto.tv/$_name');
      expect(page.rooms[1].content.title, '', reason: 'the placeholder title is left empty');
    });

    test('a page that does not echo its request is api-changed', () {
      for (final (body, page, size) in [
        (_exploreFixture(page: 2, pageSize: 30), 1, 30),
        (_exploreFixture(page: 1, pageSize: 20), 1, 30),
        (_exploreFixture(page: 1, pageSize: 30, currentPage: 'x'), 1, 30),
        (_exploreFixture(page: 1, pageSize: 30, perPage: 10), 1, 30),
        (_exploreFixture(page: 1, pageSize: 30, lastPage: 0), 1, 30),
        (_exploreFixture(page: 1, pageSize: 30, total: -1), 1, 30),
        (_exploreFixture(page: 5, pageSize: 30, lastPage: 4, total: 1), 5, 30),
        (_exploreFixture(page: 1, pageSize: 30, rows: List.filled(31, _channel())), 1, 30),
      ]) {
        expect(() => PicartoRoomParser.directoryPage(body, page: page, pageSize: size), throwsA(isA<PicartoFailure>()));
      }
    });

    test('a category page keeps only its rows, none usable is api-changed', () {
      final page = PicartoRoomParser.directoryPage(
        _exploreFixture(
          page: 1,
          pageSize: 30,
          rows: [
            _channel(
              categories: [
                {'id': 5, 'name': 'Draw'},
              ],
            ),
            _channel(
              id: 2,
              name: 'Other',
              categories: [
                {'id': 6, 'name': 'Chat'},
              ],
            ),
          ],
        ),
        page: 1,
        pageSize: 30,
        categoryId: 5,
      );
      expect(page.rooms, hasLength(1));
      expect(
        () => PicartoRoomParser.directoryPage(
          _exploreFixture(
            page: 1,
            pageSize: 30,
            rows: [_channel(id: 2, name: 'Other', categories: [])],
          ),
          page: 1,
          pageSize: 30,
          categoryId: 5,
        ),
        throwsA(predicate((e) => '$e'.contains('of category 5'))),
      );
      expect(
        () => PicartoRoomParser.directoryPage(
          _exploreFixture(
            page: 1,
            pageSize: 30,
            rows: [
              {'nope': 1},
            ],
          ),
          page: 1,
          pageSize: 30,
        ),
        throwsA(predicate((e) => '$e'.contains('no usable row'))),
      );
    });

    test('the last page is known from last_page, not the row count', () {
      expect(
        PicartoRoomParser.directoryPage(_exploreFixture(page: 3, pageSize: 30), page: 3, pageSize: 30).hasMore,
        isFalse,
      );
      expect(
        PicartoRoomParser.directoryPage(
          _exploreFixture(page: 4, pageSize: 30, rows: [], total: 1),
          page: 4,
          pageSize: 30,
        ).hasMore,
        isFalse,
        reason: 'an empty page past the last is an answer, not a failure',
      );
    });
  });

  group('search', () {
    test('profiles are rooms whose title is the name and bio the text', () {
      final rooms = PicartoRoomParser.searchRooms(_searchFixture(), pageSize: 30);
      expect(rooms, hasLength(1));
      final room = rooms.single;
      expect(room.roomId, _name);
      expect(room.content.title, _name);
      expect(room.content.introduction, '画画的 & 睡觉的', reason: 'the references are decoded');
      expect(room.anchor?.followerCount, 9876);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(room.audience.onlineViewers, isNull);
    });

    test('a broken profile costs only itself; a live one says live', () {
      final rooms = PicartoRoomParser.searchRooms(
        _searchFixture(
          rows: [
            _profile(online: true),
            _profile(id: 2, name: 'Bad Name!', followers: -1),
            _profile(id: 3, name: 'NoFollowers', followers: null),
          ],
        ),
        pageSize: 30,
      );
      expect(rooms.map((room) => room.roomId), [_name, 'NoFollowers']);
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
      expect(rooms.last.anchor?.followerCount, isNull, reason: 'a missing count stays missing');
      expect(
        () => PicartoRoomParser.searchRooms(
          _searchFixture(
            rows: [
              {'nope': 1},
            ],
          ),
          pageSize: 30,
        ),
        throwsA(predicate((e) => '$e'.contains('no usable profile'))),
      );
      expect(
        () => PicartoRoomParser.searchRooms(_searchFixture(rows: List.filled(31, _profile())), pageSize: 30),
        throwsA(isA<PicartoFailure>()),
      );
    });
  });

  group('room detail', () {
    test('the room is the platform spelling of the name asked for', () {
      final detail = PicartoRoomParser.roomDetail(_detailFixture(), requestedId: _lower);
      expect(detail.name, _name);
      expect(detail.requestedId, _lower);
      expect(detail.channelId, _channelId);
      expect(detail.room.roomId, _name);
      expect(detail.master, _masterUri);
      expect(detail.room.broadcast.restriction, LiveRestriction.none);
      expect(detail.room.audience.totalViewers, 500000);
      expect(detail.room.anchor?.followerCount, 9876);
      expect(detail.room.content.introduction, '第一段\n\n第二段');
      expect(detail.room.content.coverUrl, 'https://images.picarto.tv/live.png', reason: 'the stream thumbnail wins');
    });

    test('channel null is not-found, a foreign channel api-changed', () {
      expect(
        () => PicartoRoomParser.roomDetail(_detailFixture(channelNull: true), requestedId: _lower),
        throwsA(isA<PicartoFailure>()),
      );
      expect(
        () => PicartoRoomParser.roomDetail(
          _detailFixture(channel: _channel(name: 'SomeoneElse')),
          requestedId: _lower,
        ),
        throwsA(predicate((e) => '$e'.contains('without a valid name'))),
      );
      expect(
        () => PicartoRoomParser.roomDetail(_detailFixture(channel: _channel(online: 1)), requestedId: _lower),
        throwsA(isA<PicartoFailure>()),
      );
      expect(
        () => PicartoRoomParser.roomDetail(_json({'nope': 1}), requestedId: _lower),
        throwsA(isA<PicartoFailure>()),
      );
    });

    test('a private channel is entered with its restriction and no stream', () {
      final detail = PicartoRoomParser.roomDetail(
        _detailFixture(channel: _channel(private: true), streams: []),
        requestedId: _lower,
      );
      expect(detail.room.broadcast.restriction, LiveRestriction.private);
      expect(detail.room.broadcast.liveStatus, LiveStatus.live);
      expect(detail.master, isNull);
    });

    test('the own stream of a multistream group is picked, strictly', () {
      final other = {'channelId': _channelId + 1, 'stream_name': 'other_720p30', 'thumbnail_image': ''};
      final own = {'channelId': _channelId, 'stream_name': '${_lower}_1080p60', 'thumbnail_image': ''};
      expect(
        PicartoRoomParser.roomDetail(_detailFixture(streams: [other, own]), requestedId: _lower).master,
        _masterUri,
      );
      expect(
        () => PicartoRoomParser.roomDetail(_detailFixture(streams: [own, own]), requestedId: _lower),
        throwsA(predicate((e) => '$e'.contains('2 streams of channel'))),
      );
      expect(
        () => PicartoRoomParser.roomDetail(_detailFixture(edge: 'Bad_Edge'), requestedId: _lower),
        throwsA(predicate((e) => '$e'.contains('no load balancer edge'))),
      );
      expect(
        () => PicartoRoomParser.roomDetail(_detailFixture(edge: ''), requestedId: _lower),
        throwsA(isA<PicartoFailure>()),
      );
      expect(
        () => PicartoRoomParser.roomDetail(
          _detailFixture(
            streams: [
              {'channelId': _channelId, 'stream_name': 'bad name!', 'thumbnail_image': ''},
            ],
          ),
          requestedId: _lower,
        ),
        throwsA(predicate((e) => '$e'.contains('bad stream name'))),
      );
      expect(
        () => PicartoRoomParser.roomDetail(_detailFixture(streams: []), requestedId: _lower),
        throwsA(predicate((e) => '$e'.contains('0 streams of channel'))),
      );
    });

    test('a state-only refresh checks no stream fields', () {
      final detail = PicartoRoomParser.roomDetail(
        _detailFixture(streams: [], edge: null),
        requestedId: _lower,
        stream: false,
      );
      expect(detail.master, isNull);
      expect(detail.room.broadcast.liveStatus, LiveStatus.live);
    });
  });

  group('the start of the broadcast', () {
    test('last_live is read as UTC', () {
      expect(PicartoRoomParser.liveSince(_publicFixture(), name: _name), DateTime.utc(2026, 9, 28, 16, 12, 10));
      expect(PicartoRoomParser.liveSince(_publicFixture(name: 'Other'), name: _name), isNull);
      expect(PicartoRoomParser.liveSince(_publicFixture(online: false), name: _name), isNull);
      expect(PicartoRoomParser.liveSince(_publicFixture(lastLive: 'not a time'), name: _name), isNull);
      expect(PicartoRoomParser.liveSince(_publicFixture(lastLive: '1970-01-01 00:00:00'), name: _name), isNull);
      expect(() => PicartoRoomParser.liveSince('nope', name: _name), throwsA(isA<PicartoFailure>()));
    });
  });

  group('master playlist', () {
    test('one quality per profile, tallest first, labelled', () {
      final qualities = PicartoRoomParser.qualities(_master, master: _masterUri);
      expect(qualities, hasLength(2));
      expect(qualities.first.quality.label, '1080p 60fps');
      expect(qualities.first.quality.codec, LiveStreamCodec.avc);
      expect(qualities.first.urls.single, contains('/${_lower}_1080p60/'));
      expect(qualities.last.quality.label, '720p 30fps');
      expect(
        qualities.first.quality.platformOrder,
        1080 * PicartoRoomParser.heightWeight + 2000000,
        reason: 'height weighs more than the bandwidth',
      );
      expect(qualities.first.quality.platformOrder, greaterThan(qualities.last.quality.platformOrder));
    });

    test('the same profile at two bandwidths is one quality', () {
      const doubled =
          '$_master'
          '#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.64002A,mp4a.40.2"\n'
          'https://$_edge.picarto.tv/stream/hls/${_lower}_1080p60_alt/index.m3u8\n';
      final qualities = PicartoRoomParser.qualities(doubled, master: _masterUri);
      expect(qualities, hasLength(2));
      expect(qualities.first.urls, hasLength(2));
      expect(qualities.first.quality.label, '1080p 60fps', reason: 'the first label stays');
    });

    test('separate audio renditions are played as one auto quality', () {
      const withAudio =
          '#EXTM3U\n'
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="en",URI="audio.m3u8"\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080,AUDIO="aud"\n'
          'video.m3u8\n';
      final qualities = PicartoRoomParser.qualities(withAudio, master: _masterUri);
      expect(qualities.single.quality.qualityId, PicartoRoomParser.autoQualityId);
      expect(qualities.single.quality.label, PicartoRoomParser.autoQualityName);
      expect(qualities.single.urls.single, _masterUri.toString(), reason: 'the master itself plays, sound included');
    });

    test('a media playlist is one auto quality', () {
      const media = '#EXTM3U\n#EXTINF:6.0,\nseg-1.ts\n';
      expect(
        PicartoRoomParser.qualities(media, master: _masterUri).single.quality.qualityId,
        PicartoRoomParser.autoQualityId,
      );
    });

    test('a playlist that is none, or a bad variant, is refused', () {
      expect(
        () => PicartoRoomParser.qualities('<html>', master: _masterUri),
        throwsA(predicate((e) => '$e'.contains('not a playlist'))),
      );
      expect(
        () => PicartoRoomParser.qualities(_master, master: _masterUri, status: 404),
        throwsA(predicate((e) => '$e'.contains('HTTP 404'))),
      );
      expect(
        () => PicartoRoomParser.qualities(_master, master: _masterUri, status: 500),
        throwsA(isA<PicartoFailure>()),
      );
      const noBandwidth = '#EXTM3U\n#EXT-X-STREAM-INF:RESOLUTION=1280x720\nv.m3u8\n';
      expect(() => PicartoRoomParser.qualities(noBandwidth, master: _masterUri), throwsA(isA<PicartoFailure>()));
      const badResolution = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280\nv.m3u8\n';
      expect(() => PicartoRoomParser.qualities(badResolution, master: _masterUri), throwsA(isA<PicartoFailure>()));
      const badFps = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,FRAME-RATE=x\nv.m3u8\n';
      expect(() => PicartoRoomParser.qualities(badFps, master: _masterUri), throwsA(isA<PicartoFailure>()));
      const bareVariant = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\n#EXT-X-STREAM-INF:BANDWIDTH=2\nv.m3u8\n';
      expect(
        () => PicartoRoomParser.qualities(bareVariant, master: _masterUri),
        throwsA(predicate((e) => '$e'.contains('without a URL'))),
      );
      expect(
        () => PicartoRoomParser.qualities('#EXTM3U\n', master: _masterUri),
        throwsA(predicate((e) => '$e'.contains('no variant or media'))),
      );
    });

    test('lines carry the headers, the format and the edge as the label', () {
      final qualities = PicartoRoomParser.qualities(_master, master: _masterUri);
      final lines = PicartoRoomParser.lines(qualities.first, master: _masterUri);
      expect(lines.first.format, LiveStreamFormat.hls);
      expect(lines.first.headers['origin'], PicartoEndpoints.origin);
      expect(lines.first.headers['referer'], '${PicartoEndpoints.origin}/');
      expect(lines.first.lineLabel, _masterUri.host);
      expect(lines.first.codec, LiveStreamCodec.avc);
      expect(lines.first.lease, isNull, reason: 'the URLs are unsigned');
    });

    test('the codec is read from the quality id', () {
      final hevcId = jsonEncode(['1920x1080', 60.0, 'hvc1.1.6.L153.B0', null, null]);
      expect(PicartoRoomParser.codecOfId(hevcId), LiveStreamCodec.hevc);
      expect(PicartoRoomParser.codecOfId(jsonEncode(['', 0.0, 'mp4a.40.2', null, null])), isNull);
      expect(PicartoRoomParser.codecOfId(PicartoRoomParser.autoQualityId), isNull);
    });
  });

  group('links', () {
    test('a channel page is read under both hosts', () {
      expect(PicartoLink.channelFromUrl(Uri.parse('https://picarto.tv/$_name')), _name);
      expect(PicartoLink.channelFromUrl(Uri.parse('https://www.picarto.tv/$_name')), _name);
      expect(PicartoLink.channelFromUrl(Uri.parse('http://picarto.tv/$_name')), _name);
      expect(PicartoLink.channelFromUrl(Uri.parse('https://picarto.tv/$_name/')), _name);
      expect(PicartoLink.channelFromUrl(Uri.parse('https://picarto.tv/$_name?x=1')), _name);
    });

    test('a page that is no channel page is no link', () {
      for (final bad in [
        'https://picarto.tv/',
        'https://picarto.tv/explore',
        'https://picarto.tv/name/videos',
        'https://picarto.tv//$_name',
        'https://picarto.tv/videos',
        'https://evil.tv/$_name',
        'ftp://picarto.tv/$_name',
        'https://u:l@picarto.tv/$_name',
        'https://picarto.tv:8080/$_name',
        'https://picarto.tv/$_name/sub/chain',
      ]) {
        expect(PicartoLink.channelFromUrl(Uri.parse(bad)), isNull, reason: bad);
      }
    });

    test("one of Picarto's hosts is this site's, another is foreign", () {
      expect(PicartoLink.ownsHost('picarto.tv'), isTrue);
      expect(PicartoLink.ownsHost('www.picarto.tv'), isTrue);
      expect(PicartoLink.ownsHost('stream.picarto.tv'), isTrue);
      expect(PicartoLink.ownsHost('picarto.tv.evil.com'), isFalse);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the capabilities the platform can serve', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'picarto');
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
      await site.dispose();
    });

    test('the areas are the catalog, an unknown one is refused', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      final areas = _right(await area.getAreas());
      expect(areas.map((entry) => entry.areaId), ['live', '1', '2']);
      expect(adapter.http.sent.single.url.host, PicartoEndpoints.apiHost);
      final rooms = _right(await area.getAreaRooms(areaId: '1', request: const LivePageRequest(page: 2)));
      expect(rooms.items.single.roomId, _name);
      expect(rooms.hasMore, isTrue);
      final sent = adapter.http.sent.last;
      expect(sent.url.queryParameters['page'], '2');
      expect(sent.url.queryParameters['first'], '20');
      expect(sent.url.queryParameters['filter_params[categories]'], '1: true');
      expect(sent.url.queryParameters['filter_params[adult]'], 'false');
      expect(sent.url.queryParameters['order_by[field]'], 'viewers');
      expect(_right(await area.getAreaRooms(areaId: 'live')).items, hasLength(1));
      expect(adapter.http.sent.last.url.queryParameters.containsKey('filter_params[categories]'), isFalse);
      final before = adapter.http.sent.length;
      expect(_leftOf(await area.getAreaRooms(areaId: 'dance')), isA<LiveSiteInvalidArgument>());
      expect(adapter.http.sent.length, before, reason: 'refused before any request');
    });

    test('the public directory is the recommendations and the room list', () async {
      final adapter = _adapter();
      final rooms = _right(await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(rooms.items.single.roomId, _name);
      expect(rooms.hasMore, isTrue);
      final listed = _right(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest()));
      expect(listed.items.single.roomId, _name);
    });

    test('an entry is detail, master playlist and start, with its handles', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_lower));
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/api/channel/detail/$_lower',
        '/api/v1/channel/name/$_name',
        '/stream/hls/${_lower}_1080p60/index.m3u8',
      ]);
      expect(room.roomId, _name, reason: 'the room id is the platform spelling');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 28, 16, 12, 10));
      expect(room.broadcast.restriction, LiveRestriction.none);
      final stream = room.runtime.streamHandle;
      expect(stream, isA<PicartoStreamData>());
      expect((stream! as PicartoStreamData).qualities, hasLength(2));
      expect(
        room.runtime.danmakuHandle,
        isA<PicartoDanmakuArgs>()
            .having((args) => args.channelName, 'channelName', _name)
            .having((args) => args.channelId, 'channelId', _channelId),
      );
      // The qualities and lines come from the entry, without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _name));
      expect(qualities.first.label, '1080p 60fps');
      final lines = _right(await playback.getLines(roomId: _name, quality: qualities.first));
      expect(lines, hasLength(1));
      expect(lines.single.url, contains('_1080p60'));
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the playlist');
      // A quality the playlist has no more plays the best one instead.
      const stale = LivePlayQuality(label: 'gone', qualityId: 'gone');
      expect(_right(await playback.getLines(roomId: _name, quality: stale)).single.url, contains('_1080p60'));
    });

    test('an offline channel is entered without a stream', () async {
      final adapter = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/api/channel/detail/$_lower' => _resp(200, _detailFixture(channel: _channel(online: false, private: false))),
          _ => _resp(404, 'nope'),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_lower));
      expect(adapter.http.sent, hasLength(1), reason: 'the detail alone: no playlist, no start');
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.streamHandle, isNull);
      expect(room.runtime.danmakuHandle, isNotNull);
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _lower)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test("a private channel says it needs the streamer's key", () async {
      final adapter = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/api/channel/detail/$_lower' => _resp(200, _detailFixture(channel: _channel(private: true), streams: [])),
          _ => _resp(404, 'nope'),
        },
      );
      final left = _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _lower));
      expect(left, isA<LiveSiteContentUnavailable>());
      expect((left as LiveSiteContentUnavailable).message, contains('private'));
    });

    test('a room id that is no channel name is not-found without a request', () async {
      final adapter = _adapter();
      final room = adapter.site.capability<LiveRoomProvider>()!;
      expect(_leftOf(await room.getRoom('not a name!')), isA<LiveSiteNotFound>());
      expect(_leftOf(await room.getRoom('explore')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty);
    });

    test('a status the gate refuses is mapped', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(
        _leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_lower)),
        isA<LiveSiteRateLimitError>(),
      );
      final gone = _adapter(onSend: (_) => _resp(404, 'nope'));
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_lower)), isA<LiveSiteNotFound>());
      final broken = _adapter(onSend: (_) => _resp(200, '<html>'));
      expect(_leftOf(await broken.site.capability<LiveRoomProvider>()!.getRoom(_lower)), isA<LiveSiteParseError>());
    });

    test('search finds the keyword, and a blank one asks for nothing', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final page = await search.search(const LiveSearchRequest(query: '  baker  ', target: LiveSearchTarget.rooms));
      expect(_right(page).items.cast<RoomSearchResult>().single.room.roomId, _name);
      expect(_right(page).hasMore, isTrue);
      final sent = adapter.http.sent.single;
      expect(sent.url.path, '/api/search');
      expect(sent.url.queryParameters['q'], 'baker');
      expect(sent.url.queryParameters['type'], 'searchProfiles');
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(adapter.http.sent, hasLength(1));
      // A page that read nothing ends the keyword.
      final empty = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/api/search' => _resp(200, _searchFixture(rows: [])),
          _ => _resp(404, 'nope'),
        },
      );
      final last = await empty.site.capability<LiveSearchProvider>()!.search(
        const LiveSearchRequest(query: 'baker', target: LiveSearchTarget.rooms),
      );
      expect(_right(last).hasMore, isFalse);
    });

    test('a channel link is canonicalized, another site is unsupported', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://www.picarto.tv/$_name'))),
        Uri.parse('https://picarto.tv/$_name'),
      );
      expect(adapter.http.sent, isEmpty, reason: 'a channel page needs no request');
      expect(_leftOf(await link.resolve(Uri.parse('https://picarto.tv/explore'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/$_name'))), isA<LiveSiteUnsupported>());
    });
  });

  group('chat protocol', () {
    test('the token request names the channel, the socket carries the token', () {
      expect(PicartoDanmakuCodec.tokenBody(_name)['variables'], {'name': _name});
      expect(
        PicartoDanmakuCodec.token({
          'data': {
            'generateJwtToken': {'key': _token},
          },
        }),
        _token,
      );
      expect(
        PicartoDanmakuCodec.token({
          'data': {
            'generateJwtToken': {'key': null},
          },
        }),
        isNull,
      );
      expect(
        PicartoDanmakuCodec.token({
          'data': {
            'generateJwtToken': {'key': 'not-a-jwt'},
          },
        }),
        isNull,
      );
      expect(PicartoDanmakuCodec.token({'data': <String, Object?>{}}), isNull);
      expect(PicartoDanmakuCodec.token('nope'), isNull);
      final endpoint = PicartoDanmakuCodec.endpoint(_token);
      expect(endpoint.host, 'chat.picarto.tv');
      expect(endpoint.path, '/chat/token=$_token');
      expect(PicartoDanmakuCodec.handshakeHeaders['origin'], PicartoEndpoints.origin);
    });

    PicartoDanmakuFrame frame(Object? text) => PicartoDanmakuCodec.decode(
      text is String ? text : _json(text),
      channelId: _channelId,
      channelName: _name,
      now: _at,
    );

    test('a chat line is read with its name colour and ids', () {
      final chat = frame({
        'type': 'c',
        'messages': [
          {'t': 'c', 'n': 'Viewer', 'u': 77, 'm': '  hi  ', 'id': 'm-1', 'd': 1727700000000, 'k': '66AFFF'},
        ],
      }).messages.single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, 'hi');
      expect(chat.effectiveSender.userName, 'Viewer');
      expect(chat.effectiveSender.userId, '77');
      expect(chat.effectiveSender.nameColor, LiveMessageColor.numberToColor(0x66AFFF));
      expect(chat.messageId, 'm-1');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1727700000000));
      // The t/m spelling, an _id fallback, a short colour and a blank line.
      final second = frame({
        't': 'c',
        'm': [
          {'n': 'x', 'u': 1, 'm': 'ok', '_id': 'm-2', 'k': '#F00'},
        ],
      }).messages.single;
      expect(second.messageId, 'm-2');
      expect(second.effectiveSender.nameColor, LiveMessageColor.numberToColor(0xFF0000));
      expect(
        frame({
          't': 'c',
          'm': [
            {'n': 'x', 'm': '   '},
          ],
        }).messages,
        isEmpty,
        reason: 'a blank line is nothing',
      );
      expect(
        frame({
          't': 'c',
          'm': [
            {'n': 'x', 'm': 'ok', 'k': 'nope'},
          ],
        }).messages.single.effectiveSender.nameColor,
        LiveMessageColor.white,
      );
    });

    test('a chip tip is a super chat priced in Kudos', () {
      final tip = frame({
        'type': 'ct',
        'messages': [
          {
            't': 'ct',
            'n': 'Tipper',
            'u': 8,
            'm': 'nice!',
            'x': 25,
            'i': 'avatars/t.png',
            'id': 't-1',
            'd': 1727700000000,
          },
        ],
      }).messages.single;
      expect(tip.type, LiveMessageType.superChat);
      expect(tip.text, 'nice!');
      expect(tip.effectiveSender.userName, 'Tipper');
      expect(tip.effectiveSender.avatarUrl, 'https://images.picarto.tv/avatars/t.png');
      final superChat = tip.payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, 25);
      expect(superChat.price.currency, 'Kudos');
      expect(superChat.price.displayText, '25 Kudos');
      expect(superChat.endTime!.difference(superChat.startTime!), PicartoDanmakuCodec.tipDuration);
      // A tip to another channel of a multistream says so.
      String shown(Map<String, Object?> line) => frame({
        'type': 'ct',
        'messages': [line],
      }).messages.single.text;
      expect(shown({'t': 'ct', 'n': 'Tipper', 'm': 'for you', 'x': 5, 'rn': 'OtherCam'}), '打赏给 OtherCam：for you');
      expect(shown({'t': 'ct', 'n': 'Tipper', 'x': 5, 'rn': 'OtherCam'}), '打赏给 OtherCam');
      expect(shown({'t': 'ct', 'n': 'Tipper', 'm': 'same room', 'x': 5, 'rn': _name}), 'same room');
      expect(
        frame({
          'type': 'ct',
          'messages': [
            {'x': 0},
          ],
        }).messages,
        isEmpty,
      );
      expect(
        frame({
          'type': 'ct',
          'messages': [
            {'x': '25'},
          ],
        }).messages,
        isEmpty,
      );
    });

    test('a system line resolves its links and icons', () {
      final notice = frame({
        'type': 'system',
        'messages': [
          {
            't': 'system',
            'm': 'Welcome to {icon} {link}!\nEnjoy',
            'l': [
              'a',
              {'text': 'the rules'},
            ],
            'ic': ['x'],
          },
        ],
      }).messages.single;
      expect(notice.type, LiveMessageType.notice);
      expect(notice.payload, LiveNoticeKind.system);
      expect(notice.text, 'Welcome to  the rules! Enjoy');
      // A moderator-only frame is skipped, as are its lines without a type.
      expect(
        frame({
          'type': 'system',
          'c': 'b',
          'messages': [
            {'t': 'system', 'm': 'mods only'},
          ],
        }).messages,
        isEmpty,
      );
      expect(
        frame({
          'type': 'system',
          'messages': [
            {'m': 'no type'},
          ],
        }).messages,
        isEmpty,
      );
      // A placeholder whose list is missing stays.
      expect(
        frame({
          'type': 'system',
          'messages': [
            {'t': 'system', 'm': 'hi {link}'},
          ],
        }).messages.single.text,
        'hi {link}',
      );
    });

    test('a raid and a subscription become notices', () {
      expect(
        frame({
          'type': 'raid',
          'm': {'m': 'RAID incoming!'},
        }).messages.single.text,
        'RAID incoming!',
      );
      expect(
        frame({
          'type': 'raid',
          'm': {'n': 'Raider', 'rn': 'Raided'},
        }).messages.single.text,
        'Raider 突袭了 Raided',
      );
      expect(frame({'type': 'raid'}).messages, isEmpty);
      expect(
        frame({
          'type': 'ns',
          'm': {'sn': 'Fan', 'n': _name},
        }).messages.single.text,
        'Fan 订阅了 $_name，1 个月',
      );
      expect(
        frame({
          'type': 'ns',
          'm': {'sn': 'Fan', 'n': _name, 'md': 3},
        }).messages.single.text,
        'Fan 订阅了 $_name，3 个月',
      );
      expect(
        frame({
          'type': 'ns',
          'm': {'sn': 'Fan', 'n': _name, 'slvl': 2},
        }).messages.single.text,
        'Fan 开通了 $_name 的 2 级订阅',
      );
      expect(
        frame({
          'type': 'ns',
          'm': {'sn': 'Gifter', 'gn': 'Friend', 'md': 2, 'sg': 1},
        }).messages.single.text,
        'Gifter 赠送给 Friend 2 个月订阅',
      );
      expect(
        frame({
          'type': 'ns',
          'm': {
            'sn': 'Gifter',
            'n': _name,
            'sg': 1,
            'sc': [1, 2],
          },
        }).messages.single.text,
        'Gifter 向 Picarto 社区赠送了 2 份 $_name 的订阅',
      );
      expect(
        frame({
          'type': 'ns',
          'm': {'gn': 'Friend', 'n': _name, 'md': 2, 'sg': 1, 'ag': 1},
        }).messages.single.text,
        'Friend 收到匿名赠送的 2 个月 $_name 订阅',
      );
      expect(
        frame({
          'type': 'ns',
          'm': {
            'n': _name,
            'sg': 1,
            'ag': 1,
            'sc': [1],
          },
        }).messages.single.text,
        '有人匿名向 Picarto 社区赠送了 1 份 $_name 的订阅',
      );
      expect(frame({'type': 'ns'}).messages, isEmpty);
      expect(
        frame({
          'type': 'ns',
          'm': {'sn': 'Fan'},
        }).messages,
        isEmpty,
      );
    });

    test('a moderator takes messages back', () {
      final deleted = frame({
        'type': 'rm',
        'm': {'id': 'm-1'},
      }).messages.single;
      expect(deleted.type, LiveMessageType.retraction);
      expect(deleted.payload, isA<LiveRetraction>().having((p) => p.messageId, 'messageId', 'm-1'));
      expect(deleted.messageId, '', reason: 'the retraction is not its own message');
      final cleared = frame({
        'type': 'cm',
        'm': {'u': '77'},
      }).messages.single;
      expect(cleared.payload, isA<LiveRetraction>().having((p) => p.userId, 'userId', '77'));
      expect(
        frame({
          'type': 'rm',
          'm': {'id': '  '},
        }).messages,
        isEmpty,
      );
      expect(
        frame({
          'type': 'cm',
          'm': {'u': ''},
        }).messages,
        isEmpty,
      );
    });

    test('the stream state carries the audience of this channel', () {
      final update = frame({
        'type': 'stream',
        'm': {'id': _channelId, 'viewers': 4211},
      }).messages.single;
      expect(update.type, LiveMessageType.audienceUpdate);
      expect(
        update.payload,
        isA<LiveAudienceUpdate>()
            .having((p) => p.kind, 'kind', LiveAudienceSignalKind.onlineViewers)
            .having((p) => p.value, 'value', 4211),
      );
      expect(
        frame({
          'type': 'stream',
          'm': {'id': _channelId + 1, 'viewers': 4211},
        }).messages,
        isEmpty,
      );
      expect(
        frame({
          'type': 'stream',
          'm': {'viewers': -1},
        }).messages,
        isEmpty,
      );
      expect(
        frame({
          'type': 'stream',
          'm': {'viewers': 'many'},
        }).messages,
        isEmpty,
      );
    });

    test('history, the keep-alive answer and garbage hold nothing', () {
      expect(frame({'type': 'c', 'paginated': true, 'messages': <Object?>[]}).messages, isEmpty);
      expect(frame({'t': 'c', 'p': 1, 'm': <Object?>[]}).messages, isEmpty);
      expect(frame({'success': true, 'code': 'PONG'}), PicartoDanmakuFrame.empty);
      expect(frame({'type': 'un', 'm': <Object?>[]}), PicartoDanmakuFrame.empty);
      expect(frame('not json'), PicartoDanmakuFrame.empty);
      expect(frame('[1,2]'), PicartoDanmakuFrame.empty);
      expect(PicartoDanmakuCodec.decode('[]', channelId: _channelId), PicartoDanmakuFrame.empty);
    });

    test('a refused token is flagged', () {
      final refused = frame({'success': false, 'code': 'JWT_TOKEN'});
      expect(refused.tokenRefused, isTrue);
      expect(refused.messages, isEmpty);
      expect(frame({'success': false, 'code': 'OTHER'}).tokenRefused, isFalse);
    });
  });

  group('comment session', () {
    Future<({PicartoDanmakuSession session, _Connector connector, FakeTimers timers})> open() async {
      final connector = _Connector();
      final timers = FakeTimers();
      final session = PicartoDanmakuSession(
        args: const PicartoDanmakuArgs(channelName: _name, channelId: _channelId),
        site: PicartoSite(http: PicartoHttp(_FakeHttp(_ordinary)), connect: connector.call),
        timers: timers.timers,
        now: () => _at,
      );
      expect(await session.connect(), isNull);
      await _settle();
      return (session: session, connector: connector, timers: timers);
    }

    test('a session asks a token and joins the channel socket', () async {
      final chat = await open();
      final token = chat.connector.endpoints.single;
      expect(token.host, 'chat.picarto.tv');
      expect(token.path, '/chat/token=$_token');
      expect(chat.timers.every.single.period, PicartoDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        containsAll([PicartoDanmakuCodec.joinTimeout, PicartoDanmakuCodec.silenceTimeout]),
      );
      chat.timers.ring();
      expect(chat.connector.sockets.single.sentList.single, PicartoDanmakuCodec.heartbeat);
      await chat.session.dispose();
      expect(chat.connector.sockets.single.closed, isTrue);
    });

    test('chat and the audience flow through', () async {
      final chat = await open();
      final seen = _next(chat.session.events, 2);
      chat.connector.latest.push(
        _json({
          'type': 'c',
          'messages': [
            {'t': 'c', 'n': 'Viewer', 'u': 77, 'm': 'hi'},
          ],
        }),
      );
      chat.connector.latest.push(
        _json({
          'type': 'stream',
          'm': {'id': _channelId, 'viewers': 5000},
        }),
      );
      final messages = await seen;
      expect(messages.first.type, LiveMessageType.chat);
      expect(messages.first.text, 'hi');
      expect(messages.last.type, LiveMessageType.audienceUpdate);
      await chat.session.dispose();
    });

    test('a refused token is replaced, and the refusal after the last ends it', () async {
      final chat = await open();
      final refusal = _json({'success': false, 'code': 'JWT_TOKEN'});
      for (var attempt = 0; attempt < PicartoDanmakuCodec.maxTokenRefreshes; attempt++) {
        chat.connector.latest.push(refusal);
        await _settle();
      }
      expect(chat.connector.sockets, hasLength(PicartoDanmakuCodec.maxTokenRefreshes + 1));
      // The next refusal finds the budget spent: a terminal system message.
      final seen = <LiveMessage>[];
      final done = chat.session.events.listen(seen.add).asFuture<void>();
      chat.connector.latest.push(refusal);
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
    });

    test('a chat that answers resets the refresh budget', () async {
      final chat = await open();
      final refusal = _json({'success': false, 'code': 'JWT_TOKEN'});
      chat.connector.latest.push(refusal);
      await _settle();
      chat.connector.latest.push(_json({'success': true, 'code': 'PONG'}));
      await _settle();
      chat.connector.latest.push(refusal);
      await _settle();
      chat.connector.latest.push(refusal);
      await _settle();
      expect(chat.connector.sockets, hasLength(4), reason: 'refused, proved, refused, refused');
      await chat.session.dispose();
    });

    test('no token in three tries is retried within the reconnect budget', () async {
      final timers = FakeTimers();
      final connector = _Connector();
      final session = PicartoDanmakuSession(
        args: const PicartoDanmakuArgs(channelName: _name, channelId: _channelId),
        site: PicartoSite(
          http: PicartoHttp(
            _FakeHttp(
              (_) => _resp(
                200,
                _json({
                  'data': {
                    'generateJwtToken': {'key': null},
                  },
                }),
              ),
            ),
          ),
          connect: connector.call,
        ),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      await _settle();
      // The token attempts wait 0.5 s and then 1 s between them.
      expect(timers.after[0].delay, PicartoDanmakuCodec.tokenRetryDelay);
      timers.fire();
      await _settle();
      expect(timers.after[1].delay, PicartoDanmakuCodec.tokenRetryDelay * 2);
      timers.fire(index: 1);
      await _settle();
      // Without a token the handshake is retried after the backoff's step.
      expect(timers.after[2].delay, PicartoDanmakuCodec.reconnectBaseDelay);
      timers.fire(index: 2);
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'no socket without a token');
      await session.dispose();
    });

    test('a socket that never opens is replaced within the join budget', () async {
      final timers = FakeTimers();
      final hanging = _HangingConnector();
      final session = PicartoDanmakuSession(
        args: const PicartoDanmakuArgs(channelName: _name, channelId: _channelId),
        site: PicartoSite(http: PicartoHttp(_FakeHttp(_ordinary)), connect: hanging.call),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      await _settle();
      expect(hanging.asked, 1);
      timers.fire();
      await _settle();
      // The join budget spent counts as one failure: the retry is scheduled.
      expect(timers.after[1].delay, PicartoDanmakuCodec.reconnectBaseDelay);
      // The late socket of the abandoned handshake is closed.
      hanging.completeAll();
      await _settle();
      timers.fire(index: 1);
      await _settle();
      expect(hanging.asked, 2, reason: 'the second handshake is on its way');
      hanging.completeAll();
      await _settle();
      await session.dispose();
    });

    test('a socket that goes silent or closes is replaced', () async {
      final chat = await open();
      // Silence: the watchdog replaces the socket after the backoff's step.
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(chat.connector.sockets.first.closed, isTrue);
      // A close: replaced again, after the backoff's step.
      unawaited(chat.connector.latest.end());
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      await chat.session.dispose();
    });

    test('the failure budget is eight reconnects', () async {
      final timers = FakeTimers();
      final session = PicartoDanmakuSession(
        args: const PicartoDanmakuArgs(channelName: _name, channelId: _channelId),
        site: PicartoSite(
          http: PicartoHttp(_FakeHttp(_ordinary)),
          connect: (_, {required headers, required protocols, required connectTimeout, pingInterval}) async =>
              throw StateError('refused'),
        ),
        timers: timers.timers,
      );
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      expect(await session.connect(), isNull);
      await _settle();
      // Every failure steps the backoff once; the ninth run ends the session.
      for (var failure = 0; failure < PicartoDanmakuCodec.maxReconnects; failure++) {
        timers.fire(index: timers.after.length - 1);
        await _settle();
      }
      expect(
        timers.after.where(
          (wait) => wait.delay == PicartoDanmakuCodec.reconnectBaseDelay * PicartoDanmakuCodec.maxReconnects,
        ),
        isNotEmpty,
      );
      timers.fire(index: timers.after.length - 1);
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
    });

    test('an id that is no channel is refused before any request', () async {
      final connector = _Connector();
      final session = PicartoDanmakuSession(
        args: const PicartoDanmakuArgs(channelName: 'not a name!', channelId: 1),
        site: PicartoSite(http: PicartoHttp(_FakeHttp(_ordinary)), connect: connector.call),
        timers: FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);
    });
  });

  group('the chat provider', () {
    test('builds a session for an entered channel', () async {
      final adapter = _adapter();
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _lower));
      expect(session, isA<PicartoDanmakuSession>());
      expect(adapter.http.sent.map((seen) => seen.url.path), contains('/api/channel/detail/$_lower'));
      await session.dispose();
    });

    test('an unknown channel is not-found', () async {
      final adapter = _adapter(
        onSend: (seen) => switch (seen.url.path) {
          '/api/channel/detail/$_lower' => _resp(200, _detailFixture(channelNull: true)),
          _ => _resp(404, 'nope'),
        },
      );
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      expect(_leftOf(await danmaku.createSession(roomId: _lower)), isA<LiveSiteNotFound>());
    });
  });
}

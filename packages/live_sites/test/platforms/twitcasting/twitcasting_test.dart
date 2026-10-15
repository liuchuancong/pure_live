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
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_http.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_session.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_json.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_room_parser.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _channel = 'twuser1';
const String _otherChannel = 'twuser2';
const int _movie = 1001;

/// A tier playlist the stream server answers with: the variant number is the
/// only thing that differs between the tiers, as the site's paths allow.
String _tier(int movie, int variant) =>
    'https://hls.twitcasting.tv/tc.livehls/v1/streams/$movie/hls/3.$variant/media.m3u8';

String _json(Object? data) => jsonEncode(data);

Map<String, Object?> _movieRow({
  String userId = _channel,
  Object? movie,
  bool live = true,
  bool locked = false,
  bool group = false,
  bool deleted = false,
  Object? viewers = 42,
  Object? elapsed = 90,
  String telop = '夜の配信',
  String title = '落ち着く配信',
  String? liveUrl,
  String name = '配信者一',
}) => {
  'is_live': live,
  'is_locked': locked,
  'is_group': group,
  'is_deleted': deleted,
  'user_id': userId,
  'id': movie ?? _movie,
  'live_url': liveUrl ?? '/$userId/movie/${movie ?? _movie}',
  'current_viewer_count': viewers,
  'elapsed_time': elapsed,
  'telop': telop,
  'title': title,
  'user_name': name,
  'thumbnail_url': 'https://image.twitcasting.tv/thumb/${movie ?? _movie}.jpg',
  'user_icon_url': 'https://image.twitcasting.tv/u/$userId.png',
};

String _directoryFixture({List<Object?>? rows}) => _json({
  'movies': rows ?? [_movieRow()],
});

String _homeFixture({String tabs = 'default'}) => [
  '<html><head><title>TwitCasting</title>',
  r'<script>var injected = "<a class=\"tw-top-tab-item\" data-channel=\"scripted\">bad</a>";</script>',
  '</head><body><nav>',
  if (tabs == 'default') ...[
    '<a class="tw-top-tab-item" data-channel="casting">Casting</a> ',
    '<a class="tw-top-tab-item">For You</a> ',
    '<a class="tw-top-tab-item" data-channel="category">Category</a> ',
    '<a class="tw-top-tab-item" data-channel="casting">Casting</a>',
  ] else
    tabs,
  '</nav></body></html>',
].join();

/// One search row of [channel]; the fixture keeps the site's class names.
String _searchRowFixture({
  String channel = _channel,
  int movie = _movie,
  bool playable = true,
  bool liveBadge = true,
  String badgeText = 'LIVE',
  String title = '配信タイトル',
  String name = '配信者一',
  String? movieHref,
  String? channelHref,
  String date = 'Sun, 27 Sep 2026 23:26:34 +0900',
}) => [
  '<div class="tw-search-result-row">',
  '<a class="tw-movie-thumbnail2" href="${movieHref ?? '/$channel/movie/$movie'}">',
  '<span class="tw-movie-thumbnail2-image-wrapper" data-can-play="$playable">',
  '<img class="tw-movie-thumbnail2-image" src="https://image.twitcasting.tv/thumb/$movie.jpg"/>',
  '</span>',
  '<span class="tw-movie-thumbnail2-badge" data-status="${liveBadge ? 'live' : 'recording'}">$badgeText</span>',
  '</a>',
  '<span class="tw-movie-thumbnail-title">$title</span>',
  '<div class="tw-search-result-row-user-name">',
  '<span class="usertext"><a href="${channelHref ?? '/$channel'}"><span class="username">$name</span></a></span>',
  '</div>',
  '<span class="userimage32"><img src="https://image.twitcasting.tv/$channel.png"/></span>',
  '<time class="tw-movie-thumbnail-date" datetime="$date">1時間</time>',
  '</div>',
].join();

String _searchPageFixture({Object rows = 'default'}) => [
  '<html><body>',
  '<div id="tw-search-other">users, premier, recordings</div>',
  '<div id="tw-search-result-live">',
  '${rows == 'default' ? _searchRowFixture() : rows}',
  '</div></body></html>',
].join();

/// The channel page of [_channel]: creator and header name it, the telop
/// holds a hashtag of its own, the timer counts the live broadcast.
String _channelPageFixture({
  String channel = _channel,
  String? creator,
  String? headerId,
  String startedAt = '1791000000000',
  String liveType = 'live',
}) => [
  '<html><head>',
  '<meta name="twitter:card" content="player"/>',
  '<meta name="twitter:creator" content="${creator ?? channel}"/>',
  '<meta name="twitter:title" content="Live #落ち着く配信"/>',
  '<meta property="og:image" content="https://image.twitcasting.tv/big.png"/>',
  '</head><body>',
  '<div class="tw-user-header" data-user-id="${headerId ?? channel}">header</div>',
  '<div class="tw-user-nav2">',
  '<span class="tw-user-nav2-name">配信者一</span>',
  '<span class="tw-user-nav2-icon"><img src="https://image.twitcasting.tv/$channel.png"/></span>',
  '</div>',
  '<div class="tw-player-page-title">',
  '<span class="tw-player-page-title-description">今日も配信<span class="hashtag">#ドッキリ</span></span>',
  '</div>',
  '<span class="tw-player-duration-time" id="updatetimer" data-started-at="$startedAt" data-live-type="$liveType">0:10:00</span>',
  '<div class="tw-player-movie" data-movie-id="$_movie"></div>',
  '</body></html>',
].join();

String _streamFixture({bool live = true, bool streams = true, Object movie = _movie}) => _json({
  'movie': {'id': movie, 'live': live, 'created': 1791000000},
  if (live && streams)
    'tc-hls': {
      'streams': {'high': _tier(_movie, 0), 'medium': _tier(_movie, 1), 'low': _tier(_movie, 2)},
    },
});

String _pubsubFixture({Object url = 'default'}) => _json({
  'url': url == 'default' ? 'wss://node.twitcasting.tv/event.pubsub/v1/streams/$_movie/events?token=abc&n=1' : url,
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

/// The answers of the site: the homepage, the window, the search page, the
/// channel page, the stream server and the comment socket's URL.
LiveResponse _ordinary(_Seen request) {
  if (request.url.path == '/' || request.url.path.isEmpty) return _resp(200, _homeFixture());
  if (request.url.path == '/top/category') return _resp(200, _directoryFixture());
  if (request.url.host == 'search.twitcasting.tv') return _resp(200, _searchPageFixture());
  if (request.url.path == '/$_channel') return _resp(200, _channelPageFixture());
  if (request.url.path == '/streamserver.php') return _resp(200, _streamFixture());
  if (request.url.path == '/eventpubsuburl.php') return _resp(200, _pubsubFixture());
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

/// A connector whose handshakes fail, naming the signed url as a socket
/// error would.
Future<SocketChannel> _failingSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw StateError('handshake to $endpoint failed');

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

  /// The text frames sent, for a search through them.
  String get sentText => sentList.whereType<String>().join('\n');
}

/// Sockets handed out in order, oldest first.
final class _Connector {
  final List<_FakeSocket> sockets = [];
  final List<Uri> endpoints = [];
  final List<Map<String, String>> headers = [];

  _FakeSocket get latest => sockets.last;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
    this.headers.add(headers);
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

/// The watches a session sets, so a test can ring them by hand.
final class FakeTimers {
  final List<({Duration delay, void Function() callback})> after = [];

  TwitcastingTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) => _IdleTimer();

  /// Rings the [index]th wait.
  void fire({int index = 0}) => after[index].callback();
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The next [count] messages a session reports.
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

/// Lets the microtasks of a handshake run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// A comment connection over a socket and clocks the test holds.
Future<
  ({TwitcastingDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector, _FakeHttp http})
>
_chat({
  LiveResponse Function(_Seen request)? onSend,
  Future<SocketChannel> Function(
    Uri, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  })?
  connect,
}) async {
  final connector = _Connector();
  final timers = FakeTimers();
  final http = _FakeHttp(onSend ?? _ordinary);
  final session = TwitcastingDanmakuSession(
    args: const TwitcastingDanmakuArgs(channel: _channel, movieId: _movie),
    site: TwitcastingSite(http: TwitcastingHttp(http), connect: connect ?? connector.call, now: () => _at),
    timers: timers.timers,
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (
    session: session,
    socket: connector.sockets.isEmpty ? _FakeSocket() : connector.latest,
    timers: timers,
    connector: connector,
    http: http,
  );
}

/// One frame of the socket: a JSON array of events.
String _frame(Object? events) => _json(events);

Map<String, Object?> _commentEvent({
  Object? id = 555,
  String message = 'こんばんは',
  Object? createdAt = 1727700000000,
  String name = '視聴者甲',
  String screenName = 'viewer_a',
  Object? authorId = 'c:tw123',
}) => {
  'type': 'comment',
  'id': id,
  'message': message,
  'createdAt': createdAt,
  'author': {'id': authorId, 'name': name, 'screenName': screenName},
};

Map<String, Object?> _giftEvent({
  Object? id = 777,
  String name = 'お茶ｘ10',
  String image = 'https://image.twitcasting.tv/item.png',
  Object? showsSenderInfo = true,
  String plainMessage = 'ありがとう',
  Object? createdAt = 1727700000000,
}) => {
  'type': 'gift',
  'id': id,
  'createdAt': createdAt,
  'isPaidGift': true,
  'plainMessage': plainMessage,
  'item': {'name': name, 'image': image, 'showsSenderInfo': showsSenderInfo},
  'sender': {'id': 'c:tw9', 'name': '視聴者乙', 'screenName': 'viewer_b'},
};

void main() {
  group('ids, statuses and dates', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, TwitcastingFailureKind kind) {
        try {
          TwitcastingJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on TwitcastingFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, TwitcastingFailureKind.riskControl);
      expectKind(403, TwitcastingFailureKind.riskControl);
      expectKind(404, TwitcastingFailureKind.notFound);
      expectKind(429, TwitcastingFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, TwitcastingFailureKind.network);
      }
      TwitcastingJson.checkStatus(200, 'x');
    });

    test('a failure is transient only when asking again can mend it', () {
      expect(const TwitcastingFailure(TwitcastingFailureKind.network, 'x').isTransient, isTrue);
      expect(const TwitcastingFailure(TwitcastingFailureKind.rateLimited, 'x').isTransient, isTrue);
      for (final kind in TwitcastingFailureKind.values.where(
        (kind) => kind != TwitcastingFailureKind.network && kind != TwitcastingFailureKind.rateLimited,
      )) {
        expect(TwitcastingFailure(kind, 'x').isTransient, isFalse, reason: kind.name);
      }
    });

    test('a channel id is lower case, prefixed, and no site page', () {
      expect(TwitcastingEndpoints.channelName('  TwUser1 '), 'twuser1');
      expect(TwitcastingEndpoints.channelName('c:Yomeko'), 'c:yomeko');
      expect(TwitcastingEndpoints.channelName('g:twuser1'), 'g:twuser1');
      expect(TwitcastingEndpoints.channelName('ig:tw_user1'), 'ig:tw_user1');
      expect(TwitcastingEndpoints.channelName('search'), isNull, reason: 'a site page');
      expect(TwitcastingEndpoints.channelName('Tw-User'), isNull, reason: 'a bad character');
      expect(TwitcastingEndpoints.channelName(''), isNull);
      expect(TwitcastingEndpoints.channelName('a' * 65), isNull, reason: 'too long');
    });

    test('a channel link is one page of one segment', () {
      expect(TwitcastingEndpoints.channelFromUri(Uri.parse('https://www.twitcasting.tv/twuser1/')), 'twuser1');
      expect(TwitcastingEndpoints.channelFromUri(Uri.parse('http://twitcasting.tv/twuser1?x=1')), 'twuser1');
      expect(
        TwitcastingEndpoints.channelFromUri(Uri.parse('https://twitcasting.tv/$_channel/movie/$_movie')),
        isNull,
        reason: 'a movie link names one old broadcast (REG-TWITCASTING-003)',
      );
      expect(TwitcastingEndpoints.channelFromUri(Uri.parse('https://twitcasting.tv/search')), isNull);
      expect(TwitcastingEndpoints.channelFromUri(Uri.parse('https://evil.com/twuser1')), isNull);
      expect(TwitcastingEndpoints.channelFromUri(Uri.parse('https://twitcasting.tv:8080/twuser1')), isNull);
      expect(TwitcastingEndpoints.channelFromUri(Uri.parse('https://u@twitcasting.tv/twuser1')), isNull);
      expect(TwitcastingEndpoints.channelFromUri(Uri.parse('ftp://twitcasting.tv/twuser1')), isNull);
    });

    test('a page date is read to UTC', () {
      expect(TwitcastingRoomParser.pageDate('Sun, 27 Sep 2026 23:26:34 +0900'), DateTime.utc(2026, 9, 27, 14, 26, 34));
      expect(TwitcastingRoomParser.pageDate('27 Sep 2026'), isNull);
      expect(TwitcastingRoomParser.pageDate('Sun, 31 Feb 2026 23:26:34 +0900'), isNull, reason: 'not a day');
      expect(TwitcastingRoomParser.pageDate('Sun, 27 Sep 2026 23:26:34 +9090'), isNull, reason: 'not an offset');
    });

    test('a start time is the clock less the elapsed seconds, whole', () {
      expect(TwitcastingRoomParser.startedBefore(_at, 90), DateTime.utc(2026, 9, 30, 13, 58, 30));
      expect(
        TwitcastingRoomParser.startedBefore(DateTime.parse('2026-09-30T14:00:00.500Z'), 0),
        DateTime.utc(2026, 9, 30, 14),
      );
    });
  });

  group('catalog', () {
    test('the homepage tabs are the areas, once each, scripts ignored', () {
      final areas = TwitcastingRoomParser.areas(_homeFixture());
      expect(areas.map((area) => area.areaId), ['casting', 'category']);
      expect(areas.map((area) => area.areaName), ['Casting', 'Category']);
      expect(areas.first.platform, 'twitcasting');
      expect(areas.first.parentAreaId, 'twitcasting');
      expect(areas.first.parentAreaName, 'TwitCasting');
    });

    test('a tab without a key or label, no tab, too many: api-changed', () {
      expect(
        () => TwitcastingRoomParser.areas(_homeFixture(tabs: '<a class="tw-top-tab-item">For You</a>')),
        throwsA(predicate((e) => '$e'.contains('0 category tabs'))),
      );
      expect(
        () =>
            TwitcastingRoomParser.areas(_homeFixture(tabs: '<a class="tw-top-tab-item" data-channel="bad key">X</a>')),
        throwsA(predicate((e) => '$e'.contains('tab "bad key"'))),
      );
      expect(
        () => TwitcastingRoomParser.areas(_homeFixture(tabs: '<a class="tw-top-tab-item" data-channel="x"> </a>')),
        throwsA(predicate((e) => '$e'.contains('tab "x"'))),
      );
      final hundred = List.generate(
        100,
        (index) => '<a class="tw-top-tab-item" data-channel="t$index">T$index</a>',
      ).join();
      expect(TwitcastingRoomParser.areas(_homeFixture(tabs: hundred)), hasLength(100));
      final many = List.generate(
        101,
        (index) => '<a class="tw-top-tab-item" data-channel="t$index">T$index</a>',
      ).join();
      expect(
        () => TwitcastingRoomParser.areas(_homeFixture(tabs: many)),
        throwsA(predicate((e) => '$e'.contains('101 category tabs'))),
      );
    });

    test('a bad status is what the status gate says', () {
      expect(
        () => TwitcastingRoomParser.areas('<html>', status: 403),
        throwsA(predicate((e) => e is TwitcastingFailure && e.kind == TwitcastingFailureKind.riskControl)),
      );
    });
  });

  group('directory', () {
    test('a live row is read whole, the telop leading the title', () {
      final rooms = TwitcastingRoomParser.directoryRows(_directoryFixture(), now: _at);
      expect(rooms, hasLength(1));
      final room = rooms.single!;
      expect(room.roomId, _channel);
      expect(room.platform, 'twitcasting');
      expect(room.content.title, '夜の配信');
      expect(room.content.coverUrl, 'https://image.twitcasting.tv/thumb/$_movie.jpg');
      expect(room.anchor?.anchorId, _channel);
      expect(room.anchor?.name, '配信者一');
      expect(room.anchor?.avatarUrl, 'https://image.twitcasting.tv/u/$_channel.png');
      expect(room.audience.onlineViewers, 42);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 30, 13, 58, 30), reason: 'the clock less 90 s');
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, 'https://twitcasting.tv/$_channel');
    });

    test('a telop-less row falls back to its title', () {
      final rooms = TwitcastingRoomParser.directoryRows(
        _directoryFixture(rows: [_movieRow(telop: '')]),
        now: _at,
      );
      expect(rooms.single!.content.title, '落ち着く配信');
    });

    test('an ended, grouped or deleted row is left out', () {
      final rooms = TwitcastingRoomParser.directoryRows(
        _directoryFixture(
          rows: [
            _movieRow(live: false),
            _movieRow(userId: _otherChannel, movie: 1002, group: true),
            _movieRow(userId: _otherChannel, movie: 1003, deleted: true),
            _movieRow(userId: _otherChannel, movie: 1004),
          ],
        ),
      );
      expect(rooms.whereType<LiveRoom>().map((room) => room.roomId), [_otherChannel], reason: 'only 1004 remains');
    });

    test('a locked row is live and password-protected', () {
      final rooms = TwitcastingRoomParser.directoryRows(_directoryFixture(rows: [_movieRow(locked: true)]));
      expect(rooms.single!.broadcast.restriction, LiveRestriction.password);
    });

    test('a broken row costs only itself, unless none is usable', () {
      final rooms = TwitcastingRoomParser.directoryRows(
        _directoryFixture(
          rows: [
            _movieRow(),
            _movieRow(liveUrl: '/other/movie/1'),
          ],
        ),
      );
      expect(rooms.whereType<LiveRoom>(), hasLength(1));
      expect(
        () => TwitcastingRoomParser.directoryRows(_directoryFixture(rows: [_movieRow(liveUrl: '/other/movie/1')])),
        throwsA(predicate((e) => '$e'.contains('all 1 rows malformed'))),
      );
      for (final bad in [
        _movieRow(userId: 'no such'),
        _movieRow(movie: 0),
        _movieRow(viewers: -1),
        _movieRow(liveUrl: 'https://evil.com/x/movie/1'),
        _movieRow(liveUrl: '/$_channel/movie/$_movie?x=1'),
      ]) {
        expect(
          () => TwitcastingRoomParser.directoryRows(_directoryFixture(rows: [bad])),
          throwsA(isA<TwitcastingFailure>()),
        );
      }
      expect(
        () => TwitcastingRoomParser.directoryRows(
          _directoryFixture(
            rows: [
              {'is_live': 'yes'},
            ],
          ),
        ),
        throwsA(isA<TwitcastingFailure>()),
        reason: 'a flag that is not a boolean',
      );
    });

    test('a window that is not one, or too long, is api-changed', () {
      expect(
        () => TwitcastingRoomParser.directoryRows(_directoryFixture(rows: List.filled(61, _movieRow()))),
        throwsA(predicate((e) => '$e'.contains('61 rows'))),
      );
      expect(
        () => TwitcastingRoomParser.directoryRows(_json({'movies': 'none'})),
        throwsA(predicate((e) => '$e'.contains('movies is String'))),
      );
      expect(
        () => TwitcastingRoomParser.directoryRows('not json'),
        throwsA(predicate((e) => '$e'.contains('not JSON'))),
      );
      expect(
        () => TwitcastingRoomParser.directoryRows(_json([1, 2])),
        throwsA(predicate((e) => '$e'.contains('not an object'))),
      );
    });

    test('pages are cut from one window, a channel shown once', () {
      final window = TwitcastingRoomParser.directoryRows(
        _directoryFixture(
          rows: [
            _movieRow(),
            _movieRow(userId: _otherChannel, movie: 1002),
            _movieRow(),
          ],
        ),
      );
      expect(TwitcastingRoomParser.slice(window, offset: 0, pageSize: 2).map((room) => room.roomId), [
        _channel,
        _otherChannel,
      ], reason: 'the last row repeats the first channel and is dropped');
      expect(TwitcastingRoomParser.slice(window, offset: 2, pageSize: 2).map((room) => room.roomId), [
        _channel,
      ], reason: 'the page shows the repeated channel once');
    });
  });

  group('search page', () {
    test('a live row is read whole', () {
      final rooms = TwitcastingRoomParser.searchRows(_searchPageFixture());
      expect(rooms, hasLength(1));
      final room = rooms.single!;
      expect(room.roomId, _channel);
      expect(room.content.title, '配信タイトル');
      expect(room.content.coverUrl, 'https://image.twitcasting.tv/thumb/$_movie.jpg');
      expect(room.anchor?.name, '配信者一');
      expect(room.anchor?.avatarUrl, 'https://image.twitcasting.tv/$_channel.png');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 27, 14, 26, 34), reason: 'the row date, to UTC');
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown, reason: 'the page shows no viewers');
    });

    test('a row the site will not play is marked', () {
      final rooms = TwitcastingRoomParser.searchRows(
        _searchPageFixture(
          rows:
              '${_searchRowFixture(playable: false, badgeText: 'Private', liveBadge: false)}'
              '${_searchRowFixture(channel: _otherChannel, movie: 1002, playable: false, badgeText: 'Recording', liveBadge: false)}',
        ),
      );
      expect(rooms.first!.broadcast.restriction, LiveRestriction.private, reason: 'the first row is private');
      expect(rooms.last!.broadcast.restriction, LiveRestriction.unplayable, reason: 'cannot play, and not private');
    });

    test('a playable row without the LIVE badge is left out', () {
      final rooms = TwitcastingRoomParser.searchRows(
        _searchPageFixture(rows: _searchRowFixture(liveBadge: false, badgeText: 'Recording')),
      );
      expect(rooms.single, isNull);
    });

    test('a broken row costs only itself, unless none is usable', () {
      final withBroken = TwitcastingRoomParser.searchRows(
        _searchPageFixture(
          rows:
              '${_searchRowFixture()}'
              '${_searchRowFixture(channel: _otherChannel, movie: 1002, movieHref: '/elsewhere/movie/1002')}',
        ),
      );
      expect(withBroken.whereType<LiveRoom>(), hasLength(1));
      expect(
        () => TwitcastingRoomParser.searchRows(
          _searchPageFixture(rows: _searchRowFixture(movieHref: '/elsewhere/movie/$_movie')),
        ),
        throwsA(predicate((e) => '$e'.contains('all 1 live rows malformed'))),
      );
    });

    test('a page without the live section, or too long, is api-changed', () {
      expect(
        () => TwitcastingRoomParser.searchRows('<html><body>challenge</body></html>'),
        throwsA(predicate((e) => '$e'.contains('no live section'))),
      );
      final many = List.generate(51, (index) => _searchRowFixture(channel: 'u$index', movie: index + 1)).join();
      expect(
        () => TwitcastingRoomParser.searchRows(_searchPageFixture(rows: many)),
        throwsA(predicate((e) => '$e'.contains('51 live rows'))),
      );
      expect(
        () => TwitcastingRoomParser.searchRows('nope', status: 429),
        throwsA(predicate((e) => e is TwitcastingFailure && e.kind == TwitcastingFailureKind.rateLimited)),
      );
    });
  });

  group('channel page', () {
    test('the page names the channel and its broadcast', () {
      final page = TwitcastingRoomParser.channelPage(_channelPageFixture(), roomId: 'TwUser1', channel: _channel);
      expect(page.channel, _channel);
      expect(page.room.roomId, 'TwUser1', reason: 'the id stays as the user asked for it');
      expect(page.room.content.title, '今日も配信', reason: 'the telop, without the hashtag inside it');
      expect(page.room.content.coverUrl, 'https://image.twitcasting.tv/big.png');
      expect(page.room.anchor?.name, '配信者一');
      expect(page.room.anchor?.avatarUrl, 'https://image.twitcasting.tv/$_channel.png');
      expect(page.movieId, _movie);
      expect(page.liveStartedAt, DateTime.fromMillisecondsSinceEpoch(1791000000000, isUtc: true));
      expect(page.room.links.webUrl, 'https://twitcasting.tv/$_channel');
    });

    test('without a telop the twitter title stands in', () {
      final page = TwitcastingRoomParser.channelPage(
        _channelPageFixture().replaceAll(
          '<span class="tw-player-page-title-description">今日も配信<span class="hashtag">#ドッキリ</span></span>',
          '',
        ),
        roomId: _channel,
        channel: _channel,
      );
      expect(page.room.content.title, 'Live #落ち着く配信');
    });

    test('a recording timer, a bad timer and no timer name no start', () {
      for (final body in [
        _channelPageFixture(liveType: 'recording'),
        _channelPageFixture(startedAt: '0'),
        _channelPageFixture(startedAt: 'not a number'),
      ]) {
        expect(TwitcastingRoomParser.channelPage(body, roomId: _channel, channel: _channel).liveStartedAt, isNull);
      }
    });

    test('a redirect is an unknown channel, a secret word a protected page', () {
      expect(
        () => TwitcastingRoomParser.channelPage('', roomId: _channel, channel: _channel, status: 302),
        throwsA(predicate((e) => '$e'.contains('sent home'))),
      );
      final page = TwitcastingRoomParser.channelPage(
        '<html>Enter the secret word to access</html>',
        roomId: _channel,
        channel: _channel,
      );
      expect(page.secretWord, isTrue);
      expect(page.room.anchor, isNull, reason: 'the page shows no names that could be checked');
    });

    test('a page of another channel is api-changed', () {
      expect(
        () => TwitcastingRoomParser.channelPage(
          _channelPageFixture(creator: 'someone_else'),
          roomId: _channel,
          channel: _channel,
        ),
        throwsA(predicate((e) => '$e'.contains('twitter:creator'))),
      );
      expect(
        () => TwitcastingRoomParser.channelPage(
          _channelPageFixture(headerId: 'other'),
          roomId: _channel,
          channel: _channel,
        ),
        throwsA(predicate((e) => '$e'.contains('header of other'))),
      );
      expect(
        () => TwitcastingRoomParser.channelPage(_channelPageFixture(), roomId: _channel, channel: _otherChannel),
        throwsA(predicate((e) => '$e'.contains('twitter:creator'))),
      );
      expect(
        () => TwitcastingRoomParser.channelPage('<html></html>', roomId: _channel, channel: _channel),
        throwsA(isA<TwitcastingFailure>()),
      );
    });
  });

  group('stream server', () {
    test('the tiers of a live broadcast are kept as answered', () {
      final data = TwitcastingRoomParser.streamServer(_streamFixture());
      expect(data.live, isTrue);
      expect(data.movieId, _movie);
      expect(data.streams?.keys, ['high', 'medium', 'low']);
      expect(data.streams?['high'], _tier(_movie, 0));
    });

    test('an offline answer keeps its movie id and no streams', () {
      final data = TwitcastingRoomParser.streamServer(_streamFixture(live: false));
      expect(data.live, isFalse);
      expect(data.movieId, _movie);
      expect(data.streams, isEmpty, reason: 'the URLs of another broadcast are never kept');
    });

    test('a channel that does not exist, and an unreadable answer', () {
      expect(
        () => TwitcastingRoomParser.streamServer('{}'),
        throwsA(predicate((e) => e is TwitcastingFailure && e.kind == TwitcastingFailureKind.notFound)),
      );
      expect(
        () => TwitcastingRoomParser.streamServer(
          _json({
            'movie': {'id': 1},
          }),
        ),
        throwsA(predicate((e) => '$e'.contains('no movie.live'))),
      );
      expect(
        () => TwitcastingRoomParser.streamServer('not json'),
        throwsA(predicate((e) => '$e'.contains('not JSON'))),
      );
      expect(
        () => TwitcastingRoomParser.streamServer(_streamFixture(), status: 404),
        throwsA(predicate((e) => e is TwitcastingFailure && e.kind == TwitcastingFailureKind.notFound)),
      );
    });

    test('a live answer without the hls block names no stream', () {
      final data = TwitcastingRoomParser.streamServer(_streamFixture(streams: false));
      expect(data.streams, isNull);
    });
  });

  group('room detail', () {
    test('a live channel carries its start, restriction and handles', () {
      final page = TwitcastingRoomParser.channelPage(_channelPageFixture(), roomId: _channel, channel: _channel);
      final room = TwitcastingRoomParser.roomDetail(page, TwitcastingRoomParser.streamServer(_streamFixture()));
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1791000000000, isUtc: true));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.runtime.streamHandle, isA<TwitcastingRoomData>());
      expect(room.runtime.danmakuHandle, const TwitcastingDanmakuArgs(channel: _channel, movieId: _movie));
    });

    test('a channel that went live again between the two requests has no start', () {
      final page = TwitcastingRoomParser.channelPage(
        _channelPageFixture().replaceAll('data-movie-id="$_movie"', 'data-movie-id="999"'),
        roomId: _channel,
        channel: _channel,
      );
      final room = TwitcastingRoomParser.roomDetail(page, TwitcastingRoomParser.streamServer(_streamFixture()));
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, isNull, reason: 'the page showed the last broadcast');
      expect(room.runtime.danmakuHandle, const TwitcastingDanmakuArgs(channel: _channel, movieId: _movie));
    });

    test('a secret-word broadcast is live but password-protected', () {
      final page = TwitcastingRoomParser.channelPage(
        '<html>Enter the secret word to access</html>',
        roomId: _channel,
        channel: _channel,
      );
      final room = TwitcastingRoomParser.roomDetail(page, TwitcastingRoomParser.streamServer(_streamFixture()));
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.password);
      expect(room.anchor, isNull);
      final data = room.runtime.streamHandle! as TwitcastingRoomData;
      expect(data.secretWord, isTrue);
    });

    test('an offline channel has neither a start nor a restriction', () {
      final page = TwitcastingRoomParser.channelPage(_channelPageFixture(), roomId: _channel, channel: _channel);
      final room = TwitcastingRoomParser.roomDetail(
        page,
        TwitcastingRoomParser.streamServer(_streamFixture(live: false)),
      );
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.startedAt, isNull);
      expect(room.broadcast.restriction, isNull);
      expect(room.anchor?.liveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isNull);
      expect((room.runtime.streamHandle! as TwitcastingRoomData).live, isFalse);
    });
  });

  group('qualities and lines', () {
    TwitcastingRoomData dataWith(Map<String, String> streams) =>
        TwitcastingRoomData(live: true, movieId: _movie, streams: streams);

    test('the tiers are named, best first', () {
      final qualities = TwitcastingRoomParser.qualities(
        dataWith({'high': _tier(_movie, 0), 'medium': _tier(_movie, 1), 'low': _tier(_movie, 2)}),
      );
      expect(qualities.map((quality) => quality.qualityId), ['high', 'medium', 'low']);
      expect(qualities.map((quality) => quality.label), ['HLS high', 'HLS medium', 'HLS low']);
      expect(qualities.map((quality) => quality.platformOrder), [3, 2, 1]);
    });

    test("a tier that is not this broadcast's https playlist is dropped", () {
      final qualities = TwitcastingRoomParser.qualities(
        dataWith({
          'high': 'http://hls.twitcasting.tv/tc.livehls/v1/streams/$_movie/hls/3.0/media.m3u8',
          'medium': 'https://evil.com/tc.livehls/v1/streams/$_movie/hls/3.0/media.m3u8',
          'low': _tier(_movie, 2),
        }),
      );
      expect(qualities.map((quality) => quality.qualityId), ['low']);
      for (final bad in [
        'https://hls.twitcasting.tv/tc.livehls/v1/streams/999/hls/3.0/media.m3u8',
        'https://hls.twitcasting.tv/other/$_movie/media.m3u8',
        'https://hls.twitcasting.tv/tc.livehls/v1/streams/$_movie/hls/3.0/media.m3u8#f',
        'nonsense',
      ]) {
        expect(
          () => TwitcastingRoomParser.qualities(dataWith({'high': bad})),
          throwsA(predicate((e) => '$e'.contains('no valid tc-hls tier'))),
          reason: bad,
        );
      }
    });

    test('no valid tier at all, no movie, no streams, offline: said plainly', () {
      expect(
        () => TwitcastingRoomParser.qualities(dataWith({'high': 'https://evil.com/x'})),
        throwsA(predicate((e) => '$e'.contains('no valid tc-hls tier'))),
      );
      expect(
        () => TwitcastingRoomParser.qualities(const TwitcastingRoomData(live: true, movieId: 0)),
        throwsA(predicate((e) => '$e'.contains('movie id 0'))),
      );
      expect(
        () => TwitcastingRoomParser.qualities(const TwitcastingRoomData(live: true, movieId: _movie, streams: null)),
        throwsA(predicate((e) => '$e'.contains('no tc-hls streams'))),
      );
      expect(
        () => TwitcastingRoomParser.qualities(const TwitcastingRoomData(live: false, movieId: _movie)),
        throwsA(predicate((e) => '$e'.contains('not broadcasting'))),
      );
      expect(
        () => TwitcastingRoomParser.qualities(const TwitcastingRoomData(live: true, movieId: _movie, secretWord: true)),
        throwsA(predicate((e) => '$e'.contains('secret word'))),
      );
    });

    test('the line of a tier is its playlist with the media headers, no lease', () {
      final data = dataWith({'high': _tier(_movie, 0), 'low': _tier(_movie, 2)});
      final lines = TwitcastingRoomParser.lines(data, 'low');
      expect(lines, hasLength(1));
      expect(lines.single.url, _tier(_movie, 2));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.lineLabel, 'hls.twitcasting.tv', reason: 'the CDN node, as 3.x named its lines');
      expect(lines.single.headers, TwitcastingEndpoints.headers);
      expect(lines.single.lease, isNull, reason: 'the URL carries no signature or expiry');
      expect(
        () => TwitcastingRoomParser.lines(data, 'medium'),
        throwsA(predicate((e) => '$e'.contains('tier medium is not offered'))),
      );
    });
  });

  group('chat protocol', () {
    test('the socket address names the broadcast, the answer is gift-enabled', () {
      final endpoint = TwitcastingDanmakuCodec.endpoint(_movie);
      expect(endpoint.host, 'twitcasting.tv');
      expect(endpoint.path, '/eventpubsuburl.php');
      expect(endpoint.queryParameters['movie_id'], '$_movie');
      expect(TwitcastingDanmakuCodec.movieOf(endpoint), _movie);
      expect(TwitcastingDanmakuCodec.movieOf(Uri.parse('https://twitcasting.tv/other')), isNull);
      expect(TwitcastingDanmakuCodec.movieOf(TwitcastingDanmakuCodec.endpoint(0)), isNull);

      final socket = TwitcastingDanmakuCodec.withGifts(
        Uri.parse('wss://node.twitcasting.tv/event.pubsub/v1/streams/$_movie/events?token=abc&n=1'),
      );
      expect(socket.query, 'token=abc&n=1&gift=1');
      expect(TwitcastingDanmakuCodec.withGifts(Uri.parse('wss://node.twitcasting.tv/events?x=1')).query, 'x=1&gift=1');
      expect(
        TwitcastingDanmakuCodec.redact('handshake to wss://n.twitcasting.tv/e?token=abc&n=1 failed'),
        'handshake to wss://n.twitcasting.tv/e?token=…&n=… failed',
      );
    });

    test('a socket answer must be a wss url of the site', () {
      expect(TwitcastingDanmakuCodec.socketUrl(_pubsubFixture(), status: 200).host, 'node.twitcasting.tv');
      expect(
        () => TwitcastingDanmakuCodec.socketUrl(_pubsubFixture(), status: 403),
        throwsA(predicate((e) => e is TwitcastingFailure && e.kind == TwitcastingFailureKind.riskControl)),
      );
      expect(
        () => TwitcastingDanmakuCodec.socketUrl('not json', status: 200),
        throwsA(predicate((e) => e is TwitcastingFailure && e.kind == TwitcastingFailureKind.apiChanged)),
      );
      expect(
        () => TwitcastingDanmakuCodec.socketUrl(_pubsubFixture(url: 'https://node.twitcasting.tv/x'), status: 200),
        throwsA(predicate((e) => '$e'.contains('no socket URL'))),
      );
      expect(
        () => TwitcastingDanmakuCodec.socketUrl(_pubsubFixture(url: 'wss://evil.com/x'), status: 200),
        throwsA(predicate((e) => '$e'.contains('no socket URL'))),
      );
    });

    test('a comment is white chat', () {
      final messages = TwitcastingDanmakuCodec.decode(_frame([_commentEvent()]));
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.text, 'こんばんは');
      expect(messages.single.effectiveSender.userName, '視聴者甲');
      expect(messages.single.effectiveSender.userId, 'c:tw123');
      expect(messages.single.messageId, '555');
      expect(messages.single.sentAt, DateTime.fromMillisecondsSinceEpoch(1727700000000));
      expect(messages.single.effectiveColor, LiveMessageColor.white);
    });

    test('a comment falls back to the screen name, and a blank one is nothing', () {
      final messages = TwitcastingDanmakuCodec.decode(
        _frame([
          {
            ..._commentEvent(),
            'author': {'id': 9, 'name': '', 'screenName': 'viewer_b'},
          },
          _commentEvent(message: '   '),
          _commentEvent(createdAt: -1),
          {'type': 'other'},
        ]),
      );
      expect(messages, hasLength(2));
      expect(messages.first.effectiveSender.userName, 'viewer_b');
      expect(messages.first.effectiveSender.userId, '9');
      expect(messages.last.sentAt, isNull, reason: 'a time that is not positive is left out');
    });

    test('a gift is one named gift and then its words', () {
      final messages = TwitcastingDanmakuCodec.decode(_frame([_giftEvent()]));
      expect(messages, hasLength(2));
      expect(messages.first.type, LiveMessageType.gift);
      final gift = messages.first.payload! as LiveGift;
      expect(gift.name, 'お茶ｘ10');
      expect(gift.count, 1, reason: 'the number is part of the item');
      expect(gift.iconUrl, 'https://image.twitcasting.tv/item.png');
      expect(gift.value.unitPrice, isNull, reason: 'the event gives no price');
      expect(gift.value.totalValue, isNull);
      expect(gift.combo.comboKey, isEmpty, reason: 'the platform has no combo concept');
      expect(messages.first.text, 'お茶ｘ10 ×1');
      expect(messages.first.effectiveSender.userName, '視聴者乙');
      expect(messages.first.messageId, '777');
      expect(messages.last.type, LiveMessageType.chat);
      expect(messages.last.text, 'ありがとう');
      expect(messages.last.messageId, '777:words');
    });

    test('a gift without a picture, sender notice or name is read as far as it goes', () {
      final noImage = TwitcastingDanmakuCodec.decode(
        _frame([
          {
            ..._giftEvent(plainMessage: ''),
            'item': {'name': 'お茶', 'image': 'http://x/item.png', 'showsSenderInfo': true},
          },
        ]),
      );
      expect((noImage.single.payload! as LiveGift).iconUrl, isNull, reason: 'not https');

      final silent = TwitcastingDanmakuCodec.decode(
        _frame([
          {
            ..._giftEvent(),
            'item': {'name': 'お茶', 'image': '', 'showsSenderInfo': false},
          },
        ]),
      );
      expect(silent, isEmpty, reason: 'a score notice the player draws without a sender');

      final anonymous = TwitcastingDanmakuCodec.decode(
        _frame([
          {
            ..._giftEvent(),
            'item': {'name': '', 'image': ''},
          },
        ]),
      );
      expect(anonymous, isEmpty, reason: 'an item without a name');
    });

    test('a keep-alive, a non-array event, bytes and garbage', () {
      expect(TwitcastingDanmakuCodec.decode('[]'), isEmpty);
      expect(TwitcastingDanmakuCodec.decode(_json(_commentEvent())), hasLength(1), reason: 'a bare event');
      expect(TwitcastingDanmakuCodec.decode('not json'), isEmpty);
      expect(TwitcastingDanmakuCodec.decode(utf8.encode(_frame([_commentEvent()]))), hasLength(1));
      expect(TwitcastingDanmakuCodec.decode(1), isEmpty);
      expect(
        TwitcastingDanmakuCodec.decode(
          _frame([
            {'type': 'room'},
            _commentEvent(),
          ]),
        ),
        hasLength(1),
      );
    });
  });

  group('comment session', () {
    test('a session resolves the socket url and opens it, sending nothing', () async {
      final chat = await _chat();
      final post = chat.http.sent.single;
      expect(post.url.path, '/eventpubsuburl.php');
      expect(post.url.queryParameters['movie_id'], '$_movie');
      expect(chat.connector.endpoints.single.host, 'node.twitcasting.tv');
      expect(chat.connector.endpoints.single.path, '/event.pubsub/v1/streams/$_movie/events');
      expect(chat.connector.endpoints.single.query, 'token=abc&n=1&gift=1');
      expect(chat.connector.headers.single['origin'], TwitcastingEndpoints.origin);
      expect(chat.socket.sentText, isEmpty, reason: 'the client sends nothing');
      expect(
        chat.timers.after.map((wait) => wait.delay),
        contains(TwitcastingDanmakuCodec.silenceTimeout),
        reason: 'the silence watchdog is armed',
      );
      await chat.session.dispose();
    });

    test('the frames the socket pushes are reported', () async {
      final chat = await _chat();
      final first = _next(chat.session.events, 2);
      chat.socket.push(_frame([_commentEvent(), _giftEvent()]));
      final seen = await first;
      expect(seen.map((message) => message.type), [LiveMessageType.chat, LiveMessageType.gift]);
      await chat.session.dispose();
    });

    test('a socket that goes silent is replaced, with a fresh signed url', () async {
      final chat = await _chat();
      final first = chat.socket;
      // Silence: the watchdog replaces the socket, after the backoff's step.
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(1), reason: 'the backoff step comes first');
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(identical(chat.connector.latest, first), isFalse);
      expect(first.closed, isTrue);
      expect(chat.http.sent, hasLength(2), reason: 'the url is signed again');
      // A frame resets the watchdog; the next silence replaces again.
      chat.connector.latest.push(_frame([_commentEvent()]));
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      await chat.session.dispose();
    });

    test('a socket that closes is replaced', () async {
      final chat = await _chat();
      unawaited(chat.socket.ended());
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      await chat.session.dispose();
    });

    test('a failed handshake is retried, and the budget ends the session', () async {
      final connector = _Connector();
      final timers = FakeTimers();
      final session = TwitcastingDanmakuSession(
        args: const TwitcastingDanmakuArgs(channel: _channel, movieId: _movie),
        site: TwitcastingSite(
          http: TwitcastingHttp(_FakeHttp((_) => _resp(500, 'nope'))),
          connect: connector.call,
          now: () => _at,
        ),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      await _settle();
      expect(connector.sockets, isEmpty, reason: 'the url itself failed');
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < TwitcastingDanmakuCodec.maxReconnects; attempt++) {
        timers.fire(index: timers.after.length - 1);
        await _settle();
      }
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await session.dispose();
    });

    test('a failed socket names the url without its signature', () async {
      final chat = await _chat(connect: _failingSocket);
      final seen = <LiveMessage>[];
      final done = chat.session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < TwitcastingDanmakuCodec.maxReconnects; attempt++) {
        chat.timers.fire(index: chat.timers.after.length - 1);
        await _settle();
      }
      await done;
      final system = seen.where((message) => message.type == LiveMessageType.system).single;
      expect(system.text, contains('token=…'));
      expect(system.text, contains('n=…'));
      expect(system.text, isNot(contains('abc')));
      expect(chat.connector.sockets, isEmpty);
    });

    test('an id that is no broadcast is refused before any request', () async {
      final connector = _Connector();
      final http = _FakeHttp(_ordinary);
      final session = TwitcastingDanmakuSession(
        args: const TwitcastingDanmakuArgs(channel: _channel, movieId: 0),
        site: TwitcastingSite(http: TwitcastingHttp(http), connect: connector.call, now: () => _at),
        timers: FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(http.sent, isEmpty);
      expect(connector.sockets, isEmpty);
      final disposed = TwitcastingDanmakuSession(
        args: const TwitcastingDanmakuArgs(channel: _channel, movieId: _movie),
        site: TwitcastingSite(http: TwitcastingHttp(http), connect: connector.call, now: () => _at),
        timers: FakeTimers().timers,
      );
      await disposed.dispose();
      expect(await disposed.connect(), isA<LiveSiteUnsupported>());
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final site = TwitcastingSite(http: TwitcastingHttp(_FakeHttp(_ordinary)), connect: _refuseSocket, now: () => _at);
      expect(site.manifest.id, 'twitcasting');
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
      expect(site.capability<LiveSiteCapability>(), isNull, reason: 'no other capability');
      await site.dispose();
    });

    test('the homepage tabs are the areas, and another one is refused', () async {
      final http = _FakeHttp(_ordinary);
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      final areas = await site.capability<LiveAreaProvider>()!.getAreas();
      expect(_right(areas).map((area) => area.areaId), ['casting', 'category']);
      final rooms = _right(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'casting'));
      expect(rooms.items.single.roomId, _channel);
      expect(http.sent.last.url.host, 'frontendapi.twitcasting.tv');
      expect(http.sent.last.url.queryParameters['id'], 'casting');
      expect(http.sent.last.url.queryParameters['count'], '60');
      final before = http.sent.length;
      expect(
        _leftOf(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'bad key!')),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(http.sent.length, before, reason: 'refused before any request');
      await site.dispose();
    });

    test('a window page starts the sequence, later pages cut from it', () async {
      final http = _FakeHttp(
        (_) => _resp(
          200,
          _directoryFixture(
            rows: [
              _movieRow(),
              _movieRow(userId: _otherChannel, movie: 1002),
              _movieRow(userId: _otherChannel, movie: 1003, telop: ''),
            ],
          ),
        ),
      );
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      final rooms = site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest(pageSize: 2)));
      expect(first.items.map((room) => room.roomId), [_channel, _otherChannel]);
      expect(first.hasMore, isTrue);
      final second = _right(await rooms.getRooms(const LivePageRequest(page: 2, pageSize: 2)));
      expect(second.items.map((room) => room.roomId), [_otherChannel]);
      expect(second.hasMore, isFalse);
      expect(http.sent, hasLength(1), reason: 'the second page cut from the kept answer');
      final third = _right(await rooms.getRooms(const LivePageRequest(page: 3, pageSize: 2)));
      expect(third.items, isEmpty);
      expect(third.hasMore, isFalse);
      expect(http.sent, hasLength(1), reason: 'a page past the window is empty without a request');
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(page: 0))), isA<LiveSiteInvalidArgument>());
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(pageSize: 61))), isA<LiveSiteInvalidArgument>());
      await site.dispose();
    });

    test("the recommendations are the whole site's window", () async {
      final http = _FakeHttp(_ordinary);
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      final page = _right(await site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(page.items.single.roomId, _channel);
      expect(http.sent.single.url.queryParameters['id'], '');
      await site.dispose();
    });

    test('an entry is the channel page and the stream server, with its handles', () async {
      final http = _FakeHttp(_ordinary);
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_channel));
      expect(http.sent.map((seen) => seen.url.path), ['/$_channel', '/streamserver.php']);
      expect(http.sent.last.url.queryParameters['target'], _channel);
      expect(room.roomId, _channel);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, isNotNull);
      expect(room.runtime.danmakuHandle, const TwitcastingDanmakuArgs(channel: _channel, movieId: _movie));
      // The qualities and lines come from the entry, without a request.
      final playback = site.capability<LivePlaybackProvider>()!;
      final before = http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _channel));
      expect(qualities.map((quality) => quality.qualityId), ['high', 'medium', 'low']);
      final lines = _right(await playback.getLines(roomId: _channel));
      expect(lines.single.url, _tier(_movie, 0));
      final low = _right(await playback.getLines(roomId: _channel, quality: qualities.last));
      expect(low.single.url, _tier(_movie, 2));
      expect(http.sent.length, before, reason: 'the entry already holds the broadcast');
      expect(
        _leftOf(
          await playback.getLines(
            roomId: _channel,
            quality: qualities.first.copyWith(qualityId: 'ultra'),
          ),
        ),
        isA<LiveSiteContentUnavailable>(),
      );
      await site.dispose();
    });

    test('a channel the platform called offline is not asked again', () async {
      final http = _FakeHttp(
        (request) => switch (request.url.path) {
          '/$_channel' => _resp(200, _channelPageFixture()),
          '/streamserver.php' => _resp(200, _streamFixture(live: false)),
          _ => _resp(404, 'nope'),
        },
      );
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_channel));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isNull);
      expect(
        _leftOf(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteContentUnavailable>(),
      );
      final after = http.sent.length;
      expect(
        _leftOf(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(http.sent.length, after, reason: 'REG-TWITCASTING-001: no request for a room known offline');
      expect(
        _leftOf(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: _channel)),
        isA<LiveSiteContentUnavailable>(),
      );
      await site.dispose();
    });

    test('a room id that is no channel is not-found without a request', () async {
      final http = _FakeHttp(_ordinary);
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom('search')), isA<LiveSiteNotFound>());
      expect(
        _leftOf(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: 'no such')),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(http.sent, isEmpty);
      await site.dispose();
    });

    test('a search finds the keyword, the channel link, and refuses bad asks', () async {
      final http = _FakeHttp(_ordinary);
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      final search = site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byKeyword = await search.search(const LiveSearchRequest(query: '配信', target: LiveSearchTarget.rooms));
      expect((_right(byKeyword).items.single as RoomSearchResult).room.roomId, _channel);
      expect(http.sent.last.url.host, 'search.twitcasting.tv');
      expect(http.sent.last.url.pathSegments, ['search', 'text', '配信']);
      expect(_right(byKeyword).hasMore, isFalse);
      final byLink = await search.search(
        const LiveSearchRequest(query: 'https://www.twitcasting.tv/$_channel', target: LiveSearchTarget.rooms),
      );
      expect((_right(byLink).items.single as RoomSearchResult).room.broadcast.liveStatus, LiveStatus.live);
      expect(http.sent.last.url.path, '/streamserver.php', reason: 'the channel is entered');
      expect(
        _right(
          await search.search(
            const LiveSearchRequest(
              query: 'https://www.twitcasting.tv/$_channel',
              target: LiveSearchTarget.rooms,
              page: 2,
            ),
          ),
        ).items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, pageSize: 51))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await search.search(LiveSearchRequest(query: 'x' * 101, target: LiveSearchTarget.rooms))),
        isA<LiveSiteInvalidArgument>(),
      );
      await site.dispose();
    });

    test('a status the gate refuses is mapped', () async {
      final site = TwitcastingSite(
        http: TwitcastingHttp(_FakeHttp((_) => _resp(401, 'nope'))),
        connect: _refuseSocket,
        now: () => _at,
      );
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_channel)), isA<LiveSiteRateLimitError>());
      expect(
        _leftOf(await site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms()),
        isA<LiveSiteRateLimitError>(),
      );
      await site.dispose();
      final gone = TwitcastingSite(
        http: TwitcastingHttp(_FakeHttp((_) => _resp(404, 'nope'))),
        connect: _refuseSocket,
        now: () => _at,
      );
      expect(_leftOf(await gone.capability<LiveRoomProvider>()!.getRoom(_channel)), isA<LiveSiteNotFound>());
      await gone.dispose();
    });

    test('a link is canonicalized without a request', () async {
      final http = _FakeHttp(_ordinary);
      final site = TwitcastingSite(http: TwitcastingHttp(http), connect: _refuseSocket, now: () => _at);
      final link = site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://www.twitcasting.tv/TwUser1/'))),
        Uri.parse('https://twitcasting.tv/twuser1'),
      );
      expect(_right(await link.resolve(Uri.parse('http://twitcasting.tv/c:Yomeko?x=1'))).path, '/c:yomeko');
      expect(
        _leftOf(await link.resolve(Uri.parse('https://twitcasting.tv/$_channel/movie/$_movie'))),
        isA<LiveSiteNotFound>(),
      );
      expect(_leftOf(await link.resolve(Uri.parse('https://twitcasting.tv/search'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/twuser1'))), isA<LiveSiteUnsupported>());
      expect(http.sent, isEmpty, reason: 'a link needs no request');
      await site.dispose();
    });

    test('the chat provider builds a session for an entered broadcast', () async {
      final connector = _Connector();
      final site = TwitcastingSite(
        http: TwitcastingHttp(_FakeHttp(_ordinary)),
        connect: connector.call,
        now: () => _at,
      );
      final session = _right(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: _channel));
      expect(session, isA<TwitcastingDanmakuSession>());
      await _settle();
      expect(connector.endpoints.single.queryParameters['movie_id'], isNull, reason: 'the address resolves first');
      await session.dispose();
      await site.dispose();
    });
  });
}

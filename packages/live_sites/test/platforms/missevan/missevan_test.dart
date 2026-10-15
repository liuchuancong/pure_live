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
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_http.dart';
import 'package:live_sites/src/platforms/missevan/capabilities/missevan_link_resolver.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_json.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The room and creator the fixtures describe.
const String _roomId = '12345';
const String _creatorId = '888';
const String _otherRoom = '54321';

/// A start time the site would send: 13-digit epoch milliseconds.
const int _openTime = 1791900000000;

/// The `expires` the pull URLs carry (Unix seconds).
const int _expires = 1792000000;

String _json(Object? data) => jsonEncode(data);

String _pull(String name, String extension) =>
    'https://upos-sz-mirror08c.bilivideo.com/live/$name.$extension?expires=$_expires&psign=abc123';

Map<String, Object?> _roomRow({String id = _roomId, int open = 1, Object? openTime = _openTime, int score = 4321}) => {
  'room_id': id,
  'creator_id': _creatorId,
  'creator_username': '主播甲',
  'creator_iconurl': 'https://i0.hdslb.com/bfs/anchor.png',
  'creator_introduction': '唱歌的',
  'name': '深夜电台',
  'cover_url': 'https://i0.hdslb.com/bfs/cover.png',
  'catalog_name': '唱歌',
  'announcement': '点歌先关注',
  'status': {'open': open, 'open_time': openTime},
  'statistics': {'score': score, 'online': 0, 'attention_count': 6677},
};

String _listFixture({
  required int page,
  int maxPage = 3,
  int count = 50,
  int pageSize = MissevanEndpoints.serverPageSize,
  List<Object?>? rows,
  String rowsKey = 'Datas',
}) => _json({
  'code': 0,
  'info': {
    'pagination': {'p': page, 'pagesize': pageSize, 'maxpage': maxPage, 'count': count},
    rowsKey: rows ?? [_roomRow()],
  },
});

String _searchFixture({int page = 1, int pageSize = 30, List<Object?>? rows}) =>
    _listFixture(page: page, pageSize: pageSize, rows: rows, rowsKey: 'data');

String _detailFixture({
  String id = _roomId,
  int open = 1,
  Object? hls = '',
  Object? flv = '',
  bool withChannel = true,
  Map<String, Object?>? creator,
  Object? websocket,
}) => _json({
  'code': 0,
  'info': {
    'room': {
      ..._roomRow(id: id, open: open),
      if (withChannel) 'channel': {'hls_pull_url': hls, 'flv_pull_url': flv},
    },
    'creator':
        creator ??
        {
          'user_id': _creatorId,
          'username': '主播甲',
          'iconurl': 'https://i0.hdslb.com/bfs/big.png',
          'introduction': '每晚十点开播',
        },
    'websocket': websocket ?? <String>['wss://im.missevan.com/ws?room_id=$_roomId'],
  },
});

String _metaFixture({List<Object?>? tabs}) => _json({
  'code': 0,
  'info': {
    'tabs':
        tabs ??
        [
          {'type': 'catalog', 'catalog_id': 1, 'name': '唱见', 'icon_url': 'https://static.maoercdn.com/tab1.png'},
          {'type': 'catalog', 'catalog_id': 2, 'name': '聊天'},
          {'type': 'tag', 'tag_id': 7, 'name': '翻唱'},
          {'type': 'list', 'list_type': 3, 'name': '团播'},
          {'type': 'mystery', 'id': 9, 'name': '未知命名空间'},
          {'type': 'catalog', 'catalog_id': 1, 'name': '唱见 again'},
          {'type': 'catalog', 'catalog_id': -4, 'name': '坏 id'},
          {'type': 'catalog', 'catalog_id': 9, 'name': ''},
        ],
  },
});

LiveResponse _resp(int status, String body, {List<String> setCookies = const []}) => LiveResponse(
  statusCode: status,
  headers: const {},
  setCookies: setCookies,
  bodyBytes: Uint8List.fromList(utf8.encode(body)),
);

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

/// The answers of the site: the catalog, the list and search pages and the
/// room entries.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (path == '/api/v2/meta/data') return _resp(200, _metaFixture());
  if (path == '/api/v2/chatroom/open/list') {
    return _resp(200, _listFixture(page: int.parse(request.url.queryParameters['p']!)));
  }
  if (path == '/api/v2/chatroom/search') {
    return _resp(
      200,
      _searchFixture(
        page: int.parse(request.url.queryParameters['p']!),
        pageSize: 20,
        rows: [
          _roomRow(),
          _roomRow(id: _otherRoom),
        ],
      ),
    );
  }
  if (path.startsWith('/api/v2/live/')) {
    return _resp(
      200,
      _detailFixture(
        id: path.substring('/api/v2/live/'.length),
        hls: _pull(_roomId, 'm3u8'),
        flv: _pull(_roomId, 'flv'),
      ),
    );
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

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The site over a fake transport and no socket.
({MissevanSite site, _FakeHttp http}) _adapter({LiveResponse Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: MissevanSite(http: MissevanHttp(http), connect: _refuseSocket), http: http);
}

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, MissevanFailureKind kind) {
        try {
          MissevanJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on MissevanFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, MissevanFailureKind.riskControl);
      expectKind(403, MissevanFailureKind.riskControl);
      expectKind(404, MissevanFailureKind.notFound);
      expectKind(429, MissevanFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, MissevanFailureKind.network);
      }
      MissevanJson.checkStatus(200, 'x');
    });

    test('the body is bounded and must be JSON with a code', () {
      expect(() => MissevanJson.info('<html>', what: 'x'), throwsA(predicate((e) => '$e'.contains('not JSON'))));
      expect(
        () => MissevanJson.info('{"a":"${'x' * 1100000}"}', what: 'x'),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(() => MissevanJson.info('{}', what: 'x'), throwsA(predicate((e) => '$e'.contains('no code'))));
      expect(
        () => MissevanJson.info(_json({'code': 7}), what: 'x'),
        throwsA(predicate((e) => '$e'.contains('code 7'))),
      );
      expect(
        () => MissevanJson.info(_json({'code': 0, 'info': 'nope'}), what: 'x'),
        throwsA(predicate((e) => '$e'.contains('info: expected an object'))),
      );
      expect(
        MissevanJson.info(
          _json({
            'code': 0,
            'info': {'a': 1},
          }),
          what: 'x',
        ),
        {'a': 1},
      );
    });

    test('the only unknown-room code is not-found, any other is api-changed', () {
      expect(
        () => MissevanJson.info(_json({'code': 500030004}), what: 'x'),
        throwsA(isA<MissevanFailure>().having((f) => f.kind, 'kind', MissevanFailureKind.notFound)),
      );
      expect(
        () => MissevanJson.info(_json({'code': 500030005}), what: 'x'),
        throwsA(isA<MissevanFailure>().having((f) => f.kind, 'kind', MissevanFailureKind.apiChanged)),
      );
    });

    test('ids, texts and times are read strictly', () {
      expect(MissevanJson.id(123, 'x'), '123');
      expect(MissevanJson.id('123', 'x'), '123');
      expect(() => MissevanJson.id(0, 'x'), throwsA(anything));
      expect(MissevanJson.text(' hi '), 'hi');
      expect(MissevanJson.text(7), '');
      expect(MissevanJson.integer('42'), 42);
      expect(MissevanJson.integer(4.5), isNull);
      expect(MissevanJson.startedAt(_openTime), DateTime.fromMillisecondsSinceEpoch(_openTime, isUtc: true));
      expect(MissevanJson.startedAt(1791900000), isNull, reason: 'seconds are not milliseconds');
      expect(MissevanJson.startedAt(0), isNull);
    });
  });

  group('catalog', () {
    test('the tabs are read in the order of their namespaces, the rest skipped', () {
      final areas = MissevanRoomParser.areas(_metaFixture());
      expect(areas.map((area) => area.areaId), ['catalog:1', 'catalog:2', 'tag:7', 'list:3']);
      expect(areas.map((area) => area.areaName), ['唱见', '聊天', '翻唱', '团播']);
      expect(areas.first.parentAreaId, 'catalog');
      expect(areas.first.parentAreaName, '分区');
      expect(areas[2].parentAreaName, '标签');
      expect(areas[3].parentAreaName, '团播');
      expect(areas.first.iconUrl, 'https://static.maoercdn.com/tab1.png');
    });

    test('no usable tab is api-changed', () {
      for (final tabs in [
        <Object?>[],
        [
          {'type': 'mystery', 'id': 9, 'name': 'x'},
        ],
      ]) {
        expect(
          () => MissevanRoomParser.areas(_metaFixture(tabs: tabs)),
          throwsA(isA<MissevanFailure>().having((f) => f.kind, 'kind', MissevanFailureKind.apiChanged)),
        );
      }
    });

    test('the list parameter of a tab is its namespace query', () {
      expect(MissevanRoomParser.areaQuery('catalog:1'), {'catalog_id': '1'});
      expect(MissevanRoomParser.areaQuery('tag:7'), {'tag_id': '7'});
      expect(MissevanRoomParser.areaQuery('list:3'), {'type': '3'});
      for (final bad in ['dance', '1', 'catalog:', 'catalog:x', 'mystery:9']) {
        expect(
          () => MissevanRoomParser.areaQuery(bad),
          throwsA(isA<MissevanFailure>().having((f) => f.kind, 'kind', MissevanFailureKind.invalidArgument)),
          reason: bad,
        );
      }
    });
  });

  group('list pages', () {
    test('a directory page keeps its live rooms, once each, promoted rows in', () {
      final page = MissevanRoomParser.directoryPage(
        _listFixture(
          page: 1,
          rows: [
            _roomRow(),
            _roomRow(id: _otherRoom, open: 0),
            _roomRow(),
            _roomRow(id: '999'),
          ],
        ),
        page: 1,
      );
      expect(page.rooms.map((room) => room.roomId), [_roomId, '999'], reason: 'offline rows and repeats dropped');
      expect(page.hasMore, isTrue);
    });

    test('a page whose rooms are all offline still has a next page', () {
      final page = MissevanRoomParser.directoryPage(_listFixture(page: 2, rows: [_roomRow(open: 0)]), page: 2);
      expect(page.rooms, isEmpty);
      expect(page.hasMore, isTrue);
    });

    test('a page past the last must be empty', () {
      expect(MissevanRoomParser.directoryPage(_listFixture(page: 4, rows: []), page: 4).hasMore, isFalse);
      expect(
        () => MissevanRoomParser.directoryPage(_listFixture(page: 4), page: 4),
        throwsA(predicate((e) => '$e'.contains('unexpected pagination'))),
      );
    });

    test('a page that does not echo itself is api-changed', () {
      for (final (body, asked) in [(_listFixture(page: 2), 1), (_listFixture(page: 1, pageSize: 30), 1)]) {
        expect(
          () => MissevanRoomParser.directoryPage(body, page: asked),
          throwsA(isA<MissevanFailure>()),
          reason: body,
        );
      }
    });

    test('a broken row costs only itself, unless none is usable', () {
      final withBroken = MissevanRoomParser.directoryPage(
        _listFixture(
          page: 1,
          rows: [
            _roomRow(),
            _roomRow(id: '7', open: 2),
          ],
        ),
        page: 1,
      );
      expect(withBroken.rooms.map((room) => room.roomId), [_roomId]);
      expect(
        () => MissevanRoomParser.directoryPage(_listFixture(page: 1, rows: [_roomRow(id: '7', open: 2)]), page: 1),
        throwsA(predicate((e) => '$e'.contains('no readable row'))),
      );
      expect(MissevanRoomParser.directoryPage(_listFixture(page: 3, rows: []), page: 3).rooms, isEmpty);
    });

    test('a search page keeps offline rooms and echoes the asked page size', () {
      final page = MissevanRoomParser.searchPage(
        _searchFixture(
          rows: [
            _roomRow(),
            _roomRow(id: _otherRoom, open: 0),
          ],
        ),
        page: 1,
        pageSize: 30,
      );
      expect(page.rooms.map((room) => room.roomId), [_roomId, _otherRoom]);
      expect(page.hasMore, isTrue);
      expect(
        () => MissevanRoomParser.searchPage(_searchFixture(pageSize: 20), page: 1, pageSize: 30),
        throwsA(isA<MissevanFailure>()),
      );
    });
  });

  group('room rows and the search keyword', () {
    test('a live row carries the site view', () {
      final room = MissevanRoomParser.directoryPage(_listFixture(page: 1), page: 1).rooms.single;
      expect(room.platform, 'missevan');
      expect(room.roomId, _roomId);
      expect(room.content.title, '深夜电台');
      expect(room.content.coverUrl, 'https://i0.hdslb.com/bfs/cover.png');
      expect(room.content.notice, '点歌先关注');
      expect(room.content.introduction, '唱歌的');
      expect(room.anchor?.anchorId, _creatorId);
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.area?.areaName, '唱歌');
      expect(room.audience.popularity, 4321);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(_openTime, isUtc: true));
      expect(room.broadcast.restriction, isNot(LiveRestriction.none), reason: 'only a room entry says playable');
      expect(room.links.webUrl, MissevanEndpoints.roomUrl(_roomId));
    });

    test('an offline row keeps no start time', () {
      final room = MissevanRoomParser.searchPage(
        _searchFixture(rows: [_roomRow(open: 0)]),
        page: 1,
        pageSize: 30,
      ).rooms.single;
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.startedAt, isNull);
    });

    test('the placeholder cover is left empty', () {
      final body = _listFixture(
        page: 1,
        rows: [
          {..._roomRow(), 'cover_url': MissevanEndpoints.placeholderCover},
        ],
      );
      expect(MissevanRoomParser.directoryPage(body, page: 1).rooms.single.content.coverUrl, '');
    });

    test('a status or score the site never sends is api-changed', () {
      expect(
        () => MissevanRoomParser.directoryPage(_listFixture(page: 1, rows: [_roomRow(id: '7', open: 2)]), page: 1),
        throwsA(isA<MissevanFailure>()),
      );
      expect(
        () => MissevanRoomParser.directoryPage(_listFixture(page: 1, rows: [_roomRow(id: '7', score: -1)]), page: 1),
        throwsA(isA<MissevanFailure>()),
      );
    });

    test('a keyword is cut without cutting a surrogate pair, control is refused', () {
      expect(MissevanRoomParser.searchKeyword('  hi  '), 'hi');
      final long = 'a' * 100 + '𝄞';
      expect(MissevanRoomParser.searchKeyword(long)?.runes.length, 100);
      expect(MissevanRoomParser.searchKeyword(long)?.codeUnits.last, lessThan(0xD800));
      expect(MissevanRoomParser.searchKeyword(''), isNull);
      expect(MissevanRoomParser.searchKeyword('a\x00b'), isNull);
    });
  });

  group('room entry', () {
    test('a live room carries the creator, the followers, the pull urls and the chat', () {
      final entry = MissevanRoomParser.detail(
        _detailFixture(hls: _pull('a', 'm3u8'), flv: _pull('a', 'flv')),
        roomId: _roomId,
      );
      expect(entry.room.roomId, _roomId);
      expect(entry.room.content.introduction, '每晚十点开播', reason: 'the creator introduction wins');
      expect(entry.room.anchor?.avatarUrl, 'https://i0.hdslb.com/bfs/big.png');
      expect(entry.room.anchor?.followerCount, 6677);
      expect(entry.room.broadcast.restriction, LiveRestriction.none);
      expect(entry.data.hls, _pull('a', 'm3u8'));
      expect(entry.data.flv, _pull('a', 'flv'));
      expect(entry.args.roomId, _roomId);
      expect(entry.args.url.host, 'im.missevan.com');
      expect(entry.args.url.queryParameters['room_id'], _roomId);
      expect(entry.room.runtime.danmakuHandle, isNull, reason: 'the parser hands no handles');
    });

    test('an http pull url is upgraded', () {
      final entry = MissevanRoomParser.detail(
        _detailFixture(flv: 'http://upos-sz-mirror08c.bilivideo.com/live/a.flv?expires=$_expires'),
        roomId: _roomId,
      );
      expect(entry.data.flv, 'https://upos-sz-mirror08c.bilivideo.com/live/a.flv?expires=$_expires');
      expect(entry.data.hls, '');
    });

    test('the detail lists a usable websocket entry as the chat socket', () {
      String urls(String socket) =>
          _detailFixture(hls: _pull('a', 'm3u8'), flv: _pull('a', 'flv'), websocket: [socket]);
      final entry = MissevanRoomParser.detail(urls('wss://ws.missevan.com/im?room_id=$_roomId'), roomId: _roomId);
      expect(entry.args.url.host, 'ws.missevan.com');
      final foreign = MissevanRoomParser.detail(urls('wss://ws.missevan.com/im?room_id=999'), roomId: _roomId);
      expect(foreign.args.url.host, 'im.missevan.com', reason: 'the site form is the fallback');
      final malformed = MissevanRoomParser.detail(urls('wss://im.missevan.com/ws?room_id=%zz'), roomId: _roomId);
      expect(malformed.args.url.queryParameters['room_id'], _roomId);
    });

    test('an offline room keeps the chat and no pull urls', () {
      final entry = MissevanRoomParser.detail(
        _detailFixture(open: 0, hls: _pull('old', 'm3u8'), flv: _pull('old', 'flv')),
        roomId: _roomId,
      );
      expect(entry.room.broadcast.liveStatus, LiveStatus.offline);
      expect(entry.data.isEmpty, isTrue, reason: 'the urls of an old broadcast are ignored');
      expect(entry.args.roomId, _roomId, reason: 'the chat is handed over live or not');
    });

    test('media off reads no channel', () {
      final entry = MissevanRoomParser.detail(_detailFixture(withChannel: false), roomId: _roomId, media: false);
      expect(entry.data.isEmpty, isTrue);
    });

    test('a room or creator other than the one asked for is api-changed', () {
      expect(
        () => MissevanRoomParser.detail(_detailFixture(id: _otherRoom), roomId: _roomId),
        throwsA(predicate((e) => '$e'.contains('answered room'))),
      );
      expect(
        () => MissevanRoomParser.detail(
          _detailFixture(creator: {'user_id': 999, 'username': 'x', 'iconurl': '', 'introduction': ''}),
          roomId: _roomId,
        ),
        throwsA(predicate((e) => '$e'.contains('does not own the room'))),
      );
    });

    test('a live room without a usable pull url is api-changed', () {
      expect(
        () => MissevanRoomParser.detail(_detailFixture(), roomId: _roomId),
        throwsA(predicate((e) => '$e'.contains('live without a usable pull URL'))),
      );
    });

    test('a pull url must be a bilivideo address of its own kind', () {
      expect(MissevanRoomParser.mediaUrl(_pull('a', 'flv'), isHls: false), _pull('a', 'flv'));
      for (final bad in [
        'https://evil.com/live/a.flv?expires=$_expires',
        'https://bilivideo.com/live/a.flv',
        'https://user:pw@upos-sz-mirror08c.bilivideo.com/live/a.flv',
        'https://upos-sz-mirror08c.bilivideo.com/live/a.png',
        'https://upos-sz-mirror08c.bilivideo.com/live/a.flv#f',
        'https://upos-sz-mirror08c.bilivideo.com:8080/live/a.flv',
        'https://upos-sz-mirror08c.bilivideo.com/live/a.flv?expires=abc',
        'https://upos-sz-mirror08c.bilivideo.com/live/a.flv?expires=$_expires&expires=$_expires',
        'rtmp://upos-sz-mirror08c.bilivideo.com/live/a',
        'not a url',
      ]) {
        expect(MissevanRoomParser.mediaUrl(bad, isHls: false), isNull, reason: bad);
      }
    });
  });

  group('streams', () {
    MissevanDetail entry() => MissevanRoomParser.detail(
      _detailFixture(hls: _pull('a', 'm3u8'), flv: _pull('a', 'flv')),
      roomId: _roomId,
    );

    test('the one quality with its flv and hls lines, leased', () {
      final qualities = MissevanRoomParser.qualities(entry());
      expect(qualities.single.qualityId, MissevanEndpoints.qualityId);
      expect(qualities.single.label, '原画');
      final lines = MissevanRoomParser.lines(entry(), null);
      expect(lines, hasLength(2));
      expect(lines.first.url, _pull('a', 'flv'));
      expect(lines.first.format, LiveStreamFormat.flv);
      expect(lines.first.lineLabel, 'flv');
      expect(lines.last.format, LiveStreamFormat.hls);
      expect(lines.last.lineLabel, 'hls');
      expect(lines.first.headers['referer'], '${MissevanEndpoints.origin}/');
      expect(lines.first.headers['origin'], MissevanEndpoints.origin);
      final lease = lines.last.lease!;
      final expiresAt = lease.expiresAt!;
      expect(expiresAt, DateTime.fromMillisecondsSinceEpoch(_expires * 1000, isUtc: true));
      expect(expiresAt.difference(lease.refreshAt), MissevanEndpoints.leaseLead);
      expect(lease.requiresReconnect, isTrue, reason: 'an expired playlist ends playback');
      expect(lines.first.lease!.requiresReconnect, isFalse, reason: 'an established flv connection keeps flowing');
    });

    test('the stored transport ids name the one quality', () {
      expect(MissevanEndpoints.qualityIdFromLegacy('hls'), MissevanEndpoints.qualityId);
      expect(MissevanEndpoints.qualityIdFromLegacy('FLV'), MissevanEndpoints.qualityId);
      expect(MissevanRoomParser.lines(entry(), 'hls'), hasLength(2));
      expect(
        () => MissevanRoomParser.lines(entry(), '720p'),
        throwsA(isA<MissevanFailure>().having((f) => f.kind, 'kind', MissevanFailureKind.streamUnavailable)),
      );
    });

    test('a room that cannot play says why', () {
      final offline = MissevanRoomParser.detail(_detailFixture(open: 0), roomId: _roomId);
      expect(() => MissevanRoomParser.qualities(offline), throwsA(predicate((e) => '$e'.contains('not live'))));
      final bare = MissevanRoomParser.detail(_detailFixture(withChannel: false), roomId: _roomId, media: false);
      expect(() => MissevanRoomParser.qualities(bare), throwsA(predicate((e) => '$e'.contains('no pull URL'))));
    });
  });

  group('links', () {
    test('a room page names its room', () {
      expect(MissevanEndpoints.roomIdFromUri(Uri.parse('https://fm.missevan.com/live/$_roomId')), _roomId);
      expect(MissevanEndpoints.roomIdFromUri(Uri.parse('http://FM.MISSEVAN.COM/live/$_roomId')), _roomId);
      expect(MissevanEndpoints.roomIdFromUri(Uri.parse('https://fm.missevan.com/live/$_roomId/')), _roomId);
      expect(MissevanEndpoints.roomIdFromUri(Uri.parse('https://fm.missevan.com/live/$_roomId?from=share')), _roomId);
    });

    test('anything else names none', () {
      for (final bad in [
        'https://fm.missevan.com/',
        'https://fm.missevan.com/live/',
        'https://fm.missevan.com/live/0123',
        'https://fm.missevan.com/room/$_roomId',
        'https://fm.missevan.com/live/$_roomId/extra',
        'https://evil.com/live/$_roomId',
        'ftp://fm.missevan.com/live/$_roomId',
        'https://u:pw@fm.missevan.com/live/$_roomId',
        'https://fm.missevan.com:8080/live/$_roomId',
      ]) {
        expect(MissevanEndpoints.roomIdFromUri(Uri.parse(bad)), isNull, reason: bad);
      }
      expect(MissevanEndpoints.roomIdFromUri(null), isNull);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final adapter = _adapter();
      expect(adapter.site.manifest.id, 'missevan');
      expect(adapter.site.manifest.aliases, contains('maoer'));
      expect(adapter.site.runtimeInfo.status, LiveSiteStatus.ready);
      await adapter.site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(adapter.site.capability<LiveRoomProvider>(), isNotNull);
      expect(adapter.site.capability<LiveAreaProvider>(), isNotNull);
      expect(adapter.site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(adapter.site.capability<LiveSearchProvider>(), isNotNull);
      expect(adapter.site.capability<LivePlaybackProvider>(), isNotNull);
      expect(adapter.site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(adapter.site.capability<LiveLinkResolver>(), isNotNull);
      await adapter.site.dispose();
    });

    test('the catalog is one meta/data request', () async {
      final adapter = _adapter();
      final areas = _right(await adapter.site.capability<LiveAreaProvider>()!.getAreas());
      expect(areas.map((area) => area.areaId), ['catalog:1', 'catalog:2', 'tag:7', 'list:3']);
      expect(adapter.http.sent.single.url, Uri.https('fm.missevan.com', '/api/v2/meta/data'));
    });

    test('a directory page asks the list with the tab filter', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.items.map((room) => room.roomId), [_roomId]);
      expect(first.hasMore, isTrue);
      expect(adapter.http.sent.single.url.queryParameters, {'p': '1'});
      final area = adapter.site.capability<LiveAreaProvider>()!;
      final tagged = _right(await area.getAreaRooms(areaId: 'tag:7', request: const LivePageRequest(page: 2)));
      expect(tagged.items, hasLength(1));
      expect(adapter.http.sent.last.url.queryParameters, {'p': '2', 'tag_id': '7'});
      expect(_leftOf(await area.getAreaRooms(areaId: 'dance')), isA<LiveSiteInvalidArgument>());
      expect(adapter.http.sent, hasLength(2), reason: 'the refused area asked nothing');
    });

    test('an entry is one live/{id} request with the handles', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_roomId));
      expect(adapter.http.sent.single.url.path, '/api/v2/live/$_roomId');
      expect(room.roomId, _roomId);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.runtime.danmakuHandle, isA<MissevanDanmakuArgs>());
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _roomId));
      expect(qualities.single.qualityId, MissevanEndpoints.qualityId);
      final lines = _right(await playback.getLines(roomId: _roomId));
      expect(lines, hasLength(2));
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the pull urls');
    });

    test('playback of an unentered room reads a fresh entry', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final lines = _right(await playback.getLines(roomId: _roomId));
      expect(lines.first.url, _pull(_roomId, 'flv'));
      expect(adapter.http.sent.single.url.path, '/api/v2/live/$_roomId');
    });

    test('an offline room says why it cannot play, and still opens chat', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/api/v2/live/$_roomId' => _resp(200, _detailFixture(open: 0)),
          _ => _resp(404, 'nope'),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_roomId));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isA<MissevanDanmakuArgs>());
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _roomId)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a search answers by number, link and keyword', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byId = await search.search(const LiveSearchRequest(query: _roomId, target: LiveSearchTarget.rooms));
      expect((_right(byId).items.single as RoomSearchResult).room.roomId, _roomId);
      expect(adapter.http.sent.single.url.path, '/api/v2/live/$_roomId');
      expect(_right(byId).hasMore, isNull, reason: 'a room number is one exact answer');
      final byLink = await search.search(
        const LiveSearchRequest(query: 'https://fm.missevan.com/live/$_roomId', target: LiveSearchTarget.rooms),
      );
      expect((_right(byLink).items.single as RoomSearchResult).room.roomId, _roomId);
      expect(_right(byLink).hasMore, isNull);
      final byKeyword = await search.search(const LiveSearchRequest(query: '电台', target: LiveSearchTarget.rooms));
      expect(_right(byKeyword).items, hasLength(2));
      expect(_right(byKeyword).hasMore, isTrue);
      expect(adapter.http.sent.last.url.path, '/api/v2/chatroom/search');
      expect(adapter.http.sent.last.url.queryParameters, {'s': '电台', 'p': '1', 'page_size': '20'});
    });

    test('a search refuses the impossible and finds nothing for the rest', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: _roomId, target: LiveSearchTarget.rooms, page: 2)))
            .items,
        isEmpty,
      );
      expect(
        _right(
          await search.search(const LiveSearchRequest(query: 'https://example.com/a', target: LiveSearchTarget.rooms)),
        ).items,
        isEmpty,
      );
      expect(
        _leftOf(
          await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, pageSize: 101)),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'a\x00b', target: LiveSearchTarget.rooms))),
        isA<LiveSiteInvalidArgument>(),
      );
      final unknownRoom = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/api/v2/live/$_roomId' => _resp(404, _json({'code': 500030004})),
          _ => _resp(404, 'nope'),
        },
      );
      expect(
        _right(
          await unknownRoom.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: _roomId, target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
        reason: 'a room number that names no room finds nothing',
      );
    });

    test('a long keyword is cut for the request', () async {
      final adapter = _adapter();
      final keyword = '喵' * 120;
      await adapter.site.search(keyword, pageSize: 20);
      final sent = Uri.encodeFull(adapter.http.sent.single.url.queryParameters['s']!);
      expect(Uri.decodeComponent(sent).runes.length, MissevanEndpoints.maxKeywordLength);
    });

    test('a link is canonicalized without a request', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()! as MissevanLinkResolver;
      expect(
        _right(await link.resolve(Uri.parse('https://fm.missevan.com/live/$_roomId?from=share'))),
        Uri.parse(MissevanEndpoints.roomUrl(_roomId)),
      );
      expect(adapter.http.sent, isEmpty);
      expect(_leftOf(await link.resolve(Uri.parse('https://fm.missevan.com/user/1'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/live/$_roomId'))), isA<LiveSiteUnsupported>());
    });

    test('a status the gate refuses is mapped', () async {
      final refused = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(
        _leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_roomId)),
        isA<LiveSiteRateLimitError>(),
      );
      final gone = _adapter(onSend: (_) => _resp(200, _json({'code': 500030004})));
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_roomId)), isA<LiveSiteNotFound>());
    });

    test('a transport breakdown is a network failure, another throw unexpected', () async {
      final down = _adapter(onSend: (_) => throw const ConnectFailure('down'));
      expect(
        _leftOf(await down.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms()),
        isA<LiveSiteNetworkError>(),
      );
      final broken = _adapter(onSend: (_) => throw StateError('down'));
      expect(
        _leftOf(await broken.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms()),
        isA<LiveSiteUnexpectedError>(),
      );
    });
  });
}

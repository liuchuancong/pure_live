import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_json.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_room_parser.dart';
import 'package:test/test.dart';

/// The room of the samples.
const String _room = '201';

/// A signed pull address of the platform's CDN.
String _pull(String name, {String query = 'expires=1730003600&sign=abc', String host = 'xx.bilivideo.com'}) =>
    'https://$host/live-bvc/$name?$query';

/// A `pagination` block.
Map<String, Object?> _pagination({
  Object? p = 1,
  Object? pagesize = MissevanEndpoints.serverPageSize,
  Object? maxpage = 5,
  Object? count = 100,
}) => {'p': ?p, 'pagesize': ?pagesize, 'maxpage': ?maxpage, 'count': ?count};

/// A list answer: `open/list` writes its rows under `Datas`, search under `data`.
String _list(List<Object?> rows, {Map<String, Object?>? pagination, String key = 'Datas'}) =>
    _answer({key: rows, 'pagination': pagination ?? _pagination()});

String _answer(Object? info, {Object? code = 0}) => jsonEncode({'code': code, 'info': info});

Map<String, Object?> _row([Map<String, Object?>? override]) => {
  'room_id': 201,
  'name': '深夜电台',
  'cover_url': 'https://static.maoercdn.com/live/cover.png',
  'creator_introduction': '主播简介',
  'announcement': '公告',
  'creator_id': 3001,
  'creator_username': '猫耳主播',
  'creator_iconurl': '//static.maoercdn.com/avatar.png',
  'catalog_name': '电台',
  'status': {'open': 1, 'open_time': 1730000000000},
  'statistics': {'score': 66, 'online': 0},
  ...?override,
};

/// The row of a `live/{id}` answer: a live room with its pull URLs.
Map<String, Object?> _detailRow([Map<String, Object?>? override]) => _row({
  'channel': {'flv_pull_url': _pull('a.flv'), 'hls_pull_url': _pull('a.m3u8')},
  ...?override,
});

Map<String, Object?> _detailInfo({Map<String, Object?>? room, Map<String, Object?>? creator, Object? websocket}) => {
  'room': room ?? _detailRow(),
  'creator': ?creator,
  'websocket': ?websocket,
};

MissevanDetail _detail({
  Map<String, Object?>? room,
  Map<String, Object?>? creator,
  Object? websocket,
  bool media = true,
}) => MissevanRoomParser.detail(
  _answer(_detailInfo(room: room, creator: creator, websocket: websocket)),
  roomId: _room,
  media: media,
);

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on MissevanFailure catch (failure) {
    return failure.kind;
  }
}

MissevanFailure _failure(void Function() read) {
  try {
    read();
  } on MissevanFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the envelope', () {
    test('the status table', () {
      expect(
        {
          for (final status in [200, 401, 403, 404, 429, 500, 302])
            status: _kindOf(() => MissevanJson.info('{"code":0,"info":{}}', what: 'x', status: status)),
        },
        {
          200: null,
          401: MissevanFailureKind.riskControl,
          403: MissevanFailureKind.riskControl,
          404: MissevanFailureKind.notFound,
          429: MissevanFailureKind.rateLimited,
          500: MissevanFailureKind.network,
          302: MissevanFailureKind.network,
        },
      );
    });

    test('500030004 is the unknown room, every other code a changed answer', () {
      expect(_failure(() => MissevanJson.info('{"code":500030004,"info":{}}', what: 'x')).message, 'x: code 500030004');
      expect(
        _kindOf(() => MissevanJson.info('{"code":500030005,"info":{}}', what: 'x')),
        MissevanFailureKind.apiChanged,
      );
      expect(
        _failure(() => MissevanJson.info('{"info":{}}', what: 'x')).message,
        'x: no code',
        reason: 'an answer that does not say its code is not taken for offline',
      );
      expect(
        _failure(() => MissevanJson.info('{"code":"0","info":null}', what: 'x')).message,
        'x.info: expected an object',
      );
      expect(_kindOf(() => MissevanJson.info('[1,2]', what: 'x')), MissevanFailureKind.apiChanged);
      expect(_failure(() => MissevanJson.info('not json', what: 'x')).message, contains('not JSON (not json)'));
    });

    test('one megabyte, counted twice', () {
      expect(
        _failure(() => MissevanJson.info('x' * (MissevanEndpoints.responseLimit + 1), what: 'x')).message,
        'x: answer over ${MissevanEndpoints.responseLimit} bytes',
      );
      expect(
        _kindOf(
          () => MissevanJson.info(
            jsonEncode({
              'code': 0,
              'info': {'a': '漢' * 400000},
            }),
            what: 'x',
          ),
        ),
        MissevanFailureKind.apiChanged,
        reason: 'the cheap length check passes but the UTF-8 bytes are over the cap',
      );
    });

    test('the readers', () {
      expect(MissevanJson.integer(7), 7);
      expect(MissevanJson.integer('7'), 7);
      expect(MissevanJson.integer(7.0), isNull, reason: "a double is not this platform's number");
      expect(MissevanJson.text(' a '), 'a');
      expect(MissevanJson.text(7), isEmpty);
      expect(MissevanJson.id(201, 'x'), '201');
      expect(MissevanJson.id(' 201 ', 'x'), '201');
      expect(_kindOf(() => MissevanJson.id('0', 'x')), MissevanFailureKind.apiChanged);
      expect(_kindOf(() => MissevanJson.id('0201', 'x')), MissevanFailureKind.apiChanged);
      expect(_kindOf(() => MissevanJson.id('1' * 19, 'x')), MissevanFailureKind.apiChanged);
      expect(MissevanJson.startedAt(1730000000000), DateTime.fromMillisecondsSinceEpoch(1730000000000, isUtc: true));
      expect(MissevanJson.startedAt(1730000000), isNull, reason: 'seconds are not milliseconds');
      expect(MissevanJson.startedAt(0), isNull);
    });
  });

  group('the tabs', () {
    test('one area per tab, keyed by its namespace', () {
      final areas = MissevanRoomParser.areas(
        _answer({
          'tabs': [
            {'type': 'catalog', 'catalog_id': 1, 'name': '电台', 'icon_url': '//static.maoercdn.com/a.png'},
            {'type': 'tag', 'tag_id': '1', 'name': '声优'},
            {'type': 'list', 'list_type': 1, 'name': '团播'},
            {'type': 'catalog', 'catalog_id': 1, 'name': '重复'},
            {'type': 'unknown', 'catalog_id': 9, 'name': '别的命名空间'},
            {'type': 'catalog', 'name': '没有 id'},
            {'type': 'catalog', 'catalog_id': 0, 'name': '零号'},
            {'type': 'catalog', 'catalog_id': 2, 'name': '  '},
            '不是对象',
            {'type': 'list', 'list_type': 2, 'name': '另一个团播'},
          ],
        }),
      );
      expect(
        [for (final area in areas) (area.areaId, area.areaName, area.parentAreaId, area.parentAreaName)],
        [
          ('catalog:1', '电台', 'catalog', '分区'),
          ('tag:1', '声优', 'tag', '标签'),
          ('list:1', '团播', 'list', '团播'),
          ('list:2', '另一个团播', 'list', '团播'),
        ],
        reason: 'a catalog and a tag with the same number are different areas',
      );
      expect(areas.first.iconUrl, 'https://static.maoercdn.com/a.png');
      expect(areas[1].iconUrl, isEmpty);
    });

    test('no tabs, too many tabs, and none usable', () {
      expect(
        _failure(() => MissevanRoomParser.areas(_answer({'tabs': const <Object?>[]}))).message,
        'meta/data: no tabs',
      );
      expect(
        _kindOf(
          () => MissevanRoomParser.areas(
            _answer({
              'tabs': List.generate(101, (index) => {'type': 'catalog'}),
            }),
          ),
        ),
        MissevanFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => MissevanRoomParser.areas(
            _answer({
              'tabs': [
                {'type': 'other', 'catalog_id': 1, 'name': 'x'},
              ],
            }),
          ),
        ).message,
        'meta/data: no usable tab',
      );
      expect(_kindOf(() => MissevanRoomParser.areas(_answer({}))), MissevanFailureKind.apiChanged);
    });

    test('areaQuery: the parameter each namespace is asked with', () {
      expect(MissevanRoomParser.areaQuery('catalog:12'), {'catalog_id': '12'});
      expect(MissevanRoomParser.areaQuery('tag:3'), {'tag_id': '3'});
      expect(MissevanRoomParser.areaQuery('list:2'), {'type': '2'});
      for (final bad in ['12', ':12', 'catalog:', 'other:12', 'catalog:0', 'catalog:012']) {
        expect(_kindOf(() => MissevanRoomParser.areaQuery(bad)), MissevanFailureKind.invalidArgument, reason: bad);
      }
    });
  });

  group('the list pages', () {
    test('the rows, a room once, and the page still ahead', () {
      final (:rooms, :hasMore) = MissevanRoomParser.directoryPage(
        _list([
          _row(),
          _row({'room_id': 202}),
          _row({'room_id': 201}),
        ]),
        page: 1,
      );
      expect(rooms.map((room) => room.roomId), ['201', '202']);
      expect(hasMore, isTrue);
      expect(
        MissevanRoomParser.directoryPage(_list([_row()], pagination: _pagination(p: 5)), page: 5).hasMore,
        isFalse,
      );
    });

    test('the recommendation page keeps only the live rooms, and an all-offline page still pages', () {
      final (:rooms, :hasMore) = MissevanRoomParser.directoryPage(
        _list([
          _row({
            'room_id': 202,
            'status': {'open': 0},
          }),
          _row(),
        ]),
        page: 1,
      );
      expect(rooms.map((room) => room.roomId), ['201']);
      expect(hasMore, isTrue, reason: 'a page whose rooms were all offline still has a next one');
      expect(
        MissevanRoomParser.directoryPage(
          _list([
            _row({
              'status': {'open': 0},
            }),
          ]),
          page: 1,
        ).rooms,
        isEmpty,
      );
    });

    test('the search page keeps the offline rooms and reads its rows under data', () {
      final (:rooms, :hasMore) = MissevanRoomParser.searchPage(
        _list([
          _row({
            'status': {'open': 0},
          }),
        ], key: 'data'),
        page: 1,
        pageSize: 20,
      );
      expect(rooms.single.broadcast.liveStatus, LiveStatus.offline);
      expect(rooms.single.broadcast.startedAt, isNull, reason: 'the offline row says no start');
      expect(hasMore, isTrue);
      expect(
        _kindOf(() => MissevanRoomParser.searchPage(_list([_row()]), page: 1, pageSize: 20)),
        MissevanFailureKind.apiChanged,
        reason: 'search rows are not under Datas',
      );
    });

    test('the echo must match what was asked', () {
      for (final bad in [
        _pagination(p: 2),
        _pagination(pagesize: 30),
        _pagination(maxpage: -1),
        _pagination(count: -1),
        _pagination(maxpage: null),
        _pagination(count: null),
      ]) {
        expect(
          _failure(() => MissevanRoomParser.directoryPage(_list([_row()], pagination: bad), page: 1)).message,
          contains('open/list page 1: unexpected pagination'),
          reason: '$bad',
        );
      }
      expect(
        _kindOf(
          () => MissevanRoomParser.directoryPage(
            _list(List.generate(101, (index) => _row({'room_id': index + 1}))),
            page: 1,
          ),
        ),
        MissevanFailureKind.apiChanged,
      );
      expect(
        _failure(() => MissevanRoomParser.directoryPage(_list([_row()], pagination: _pagination(maxpage: 1)), page: 2))
            .message,
        contains('unexpected pagination'),
        reason: 'a page past maxpage must be empty',
      );
      expect(
        MissevanRoomParser.directoryPage(_list([], pagination: _pagination(p: 2, maxpage: 1)), page: 2).rooms,
        isEmpty,
      );
    });

    test('a broken row is skipped, a page of none is api-changed', () {
      expect(
        MissevanRoomParser.directoryPage(
          _list([
            _row(),
            {'name': '没有 room_id'},
          ]),
          page: 1,
        ).rooms,
        hasLength(1),
      );
      expect(
        _failure(
          () => MissevanRoomParser.directoryPage(
            _list([
              {'name': '坏行'},
              '不是对象',
            ]),
            page: 1,
          ),
        ).message,
        'open/list page 1: no readable row',
      );
      expect(MissevanRoomParser.directoryPage(_list([]), page: 1).rooms, isEmpty);
    });

    test('a row is live by status.open alone, and its heat is never a viewer count', () {
      final room = MissevanRoomParser.directoryPage(_list([_row()]), page: 1).rooms.single;
      expect(room.platform, 'missevan');
      expect(room.content.title, '深夜电台');
      expect(room.content.coverUrl, 'https://static.maoercdn.com/live/cover.png');
      expect(room.content.introduction, '主播简介', reason: "the list card carries the creator's introduction");
      expect(room.content.notice, '公告');
      expect(room.anchor?.anchorId, '3001');
      expect(room.anchor?.name, '猫耳主播');
      expect(room.anchor?.avatarUrl, 'https://static.maoercdn.com/avatar.png');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.area?.areaName, '电台');
      expect(room.audience.popularity, 66);
      expect(room.audience.onlineViewers, isNull);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1730000000000, isUtc: true));
      expect(room.links.webUrl, MissevanEndpoints.roomUrl('201'));
      expect(
        _kindOf(
          () => MissevanRoomParser.directoryPage(
            _list([
              _row({
                'status': {'open': 2},
              }),
            ]),
            page: 1,
          ),
        ),
        MissevanFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => MissevanRoomParser.directoryPage(
            _list([
              _row({
                'statistics': {'score': -1},
              }),
            ]),
            page: 1,
          ),
        ).message,
        'open/list page 1: no readable row',
        reason: 'a row whose heat is negative is dropped, and a page with only it is not an empty page',
      );
    });

    test("the site's default picture never becomes a cover", () {
      final room = MissevanRoomParser.directoryPage(
        _list([
          _row({'cover_url': 'https://static.maoercdn.com/avatars/icon01.png'}),
        ]),
        page: 1,
      ).rooms.single;
      expect(room.content.coverUrl, isEmpty);
    });
  });

  group('the keyword', () {
    test('trimmed, cut by characters, never inside an emoji', () {
      expect(MissevanRoomParser.searchKeyword(' 猫耳 '), '猫耳');
      expect(MissevanRoomParser.searchKeyword(''), isNull);
      expect(MissevanRoomParser.searchKeyword('   '), isNull);
      expect(MissevanRoomParser.searchKeyword('a\x01b'), isNull);
      expect(MissevanRoomParser.searchKeyword('字' * 101)?.length, MissevanEndpoints.maxKeywordLength);
      final emoji = '😀' * 101;
      expect(MissevanRoomParser.searchKeyword(emoji)?.runes.length, MissevanEndpoints.maxKeywordLength);
      expect(MissevanRoomParser.searchKeyword('${'a' * 100}   ')?.length, MissevanEndpoints.maxKeywordLength);
      expect(MissevanRoomParser.searchKeyword('${'a' * 99}😀 ')!.length, 101, reason: 'the emoji is one character');
    });
  });

  group('the room detail', () {
    test('the answer must be about the room asked for', () {
      expect(_detail().room.roomId, _room);
      expect(_failure(() => _detail(room: _row({'room_id': 900}))).message, 'live/$_room answered room 900');
    });

    test('the creator must own the room, and brings the avatar and the introduction', () {
      final withCreator = _detail(
        creator: {'user_id': 3001, 'iconurl': '//static.maoercdn.com/new.png', 'introduction': '主播的话'},
      );
      expect(withCreator.room.anchor?.avatarUrl, 'https://static.maoercdn.com/new.png');
      expect(withCreator.room.content.introduction, '主播的话', reason: "the creator's own words beat the row's copy");
      expect(
        _kindOf(() => _detail(creator: {'user_id': 3002, 'iconurl': 'https://a/x.png'})),
        MissevanFailureKind.apiChanged,
      );
      expect(_detail(creator: {'user_id': 3001}).room.content.introduction, isNull);
    });

    test("the follower count is the creator's, and a negative one is not read", () {
      expect(
        _detail().room.anchor?.followerCount,
        isNull,
        reason: 'the row without statistics.attention_count says none',
      );
      expect(
        _detail(
          room: _detailRow({
            'statistics': {'score': 66, 'attention_count': 500},
          }),
        ).room.anchor?.followerCount,
        500,
      );
      expect(
        _detail(
          room: _detailRow({
            'statistics': {'score': 66, 'attention_count': -1},
          }),
        ).room.anchor?.followerCount,
        isNull,
      );
    });

    test('an offline room keeps no pull URL and no restriction', () {
      final detail = _detail(
        room: _detailRow({
          'status': {'open': 0},
          'channel': {'hls_pull_url': _pull('old.m3u8'), 'flv_pull_url': _pull('old.flv')},
        }),
      );
      expect(detail.data.isEmpty, isTrue, reason: 'the addresses of a broadcast long gone are ignored');
      expect(detail.room.broadcast.restriction, isNull);
      expect(detail.args.roomId, _room);
    });

    test('a live room needs one usable pull URL, and says nothing is restricted', () {
      final both = _detail(
        room: _detailRow({
          'channel': {'hls_pull_url': _pull('a.m3u8'), 'flv_pull_url': _pull('a.flv')},
        }),
      );
      expect(both.room.broadcast.restriction, LiveRestriction.none);
      expect(both.data.hls, _pull('a.m3u8'));
      expect(both.data.flv, _pull('a.flv'));
      final oneBad = _detail(
        room: _detailRow({
          'channel': {'hls_pull_url': 'https://other.example.com/a.m3u8', 'flv_pull_url': _pull('a.flv')},
        }),
      );
      expect(oneBad.data.hls, isEmpty);
      expect(oneBad.data.flv, _pull('a.flv'));
      expect(
        _failure(
          () => _detail(
            room: _detailRow({
              'channel': {'hls_pull_url': _pull('a.mp4'), 'flv_pull_url': ''},
            }),
          ),
        ).message,
        'live/$_room: live without a usable pull URL',
      );
      expect(_kindOf(() => _detail(room: _detailRow({'channel': '不是对象'}))), MissevanFailureKind.apiChanged);
      expect(_detail(room: _row(), media: false).data.isEmpty, isTrue);
    });

    test("the chat socket is the room's own, else the site's form", () {
      expect(_detail().args.url.toString(), 'wss://im.missevan.com/ws?room_id=$_room');
      expect(
        _detail(websocket: ['wss://im.missevan.com/ws?room_id=900']).args.url.toString(),
        'wss://im.missevan.com/ws?room_id=$_room',
        reason: "a socket naming another room is not this room's",
      );
      expect(
        _detail(websocket: ['wss://live.missevan.com/chat']).args.url.toString(),
        'wss://live.missevan.com/chat',
        reason: 'a socket that names no room is taken as it came',
      );
      expect(
        _detail(websocket: ['wss://im.missevan.com/ws?room_id=900&room_id=900']).args.url.toString(),
        'wss://im.missevan.com/ws?room_id=900&room_id=900',
        reason: 'only a socket with exactly one other room is refused',
      );
      for (final rejected in [
        'ws://im.missevan.com/chat',
        'wss://im.example.com/chat',
        'wss://someone@im.missevan.com/chat',
        '不是地址',
      ]) {
        expect(_detail(websocket: [rejected]).args.url.host, 'im.missevan.com', reason: rejected);
      }
      expect(_detail(websocket: '不是列表').args.url.path, '/ws');
    });
  });

  group('the stream', () {
    MissevanDetail detail({String hls = '', String flv = '', bool live = true}) => MissevanDetail(
      room: MissevanRoomParser.searchPage(
        _list([
          _row({
            'status': {'open': live ? 1 : 0},
          }),
        ], key: 'data'),
        page: 1,
        pageSize: 20,
      ).rooms.single,
      data: MissevanRoomData(hls: hls, flv: flv),
      args: MissevanRoomParser.danmakuArgs(const <String, dynamic>{}, roomId: _room),
    );

    test("one quality, named as the CDN's code", () {
      final qualities = MissevanRoomParser.qualities(detail(flv: _pull('a.flv'), hls: _pull('a.m3u8')));
      expect(qualities, hasLength(1));
      expect(qualities.single.label, MissevanEndpoints.qualityName);
      expect(qualities.single.qualityId, MissevanEndpoints.qualityId);
      expect(
        _failure(() => MissevanRoomParser.qualities(detail(live: false, flv: _pull('a.flv')))).message,
        '$_room is not live',
      );
      expect(_failure(() => MissevanRoomParser.qualities(detail())).message, '$_room has no pull URL');
    });

    test('the lines are FLV then HLS, with the lease of their expiry', () {
      final lines = MissevanRoomParser.lines(detail(flv: _pull('a.flv'), hls: _pull('a.m3u8')), null);
      expect(lines.map((line) => line.lineLabel), ['flv', 'hls']);
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.map((line) => line.formatSource), [LivePlayFormatSource.inferred, LivePlayFormatSource.inferred]);
      expect(lines.first.headers.toMap(), MissevanEndpoints.headers);
      expect(lines.first.lease?.requiresReconnect, isFalse, reason: 'an established FLV outlives its signature');
      expect(lines.last.lease?.requiresReconnect, isTrue);
      final expires = DateTime.fromMillisecondsSinceEpoch(1730003600000, isUtc: true);
      expect(lines.last.lease?.expiresAt, expires);
      expect(lines.last.lease?.refreshAt, expires.subtract(MissevanEndpoints.leaseLead));
      expect(MissevanRoomParser.lines(detail(flv: _pull('a.flv')), 'flv'), hasLength(1));
      expect(MissevanRoomParser.lines(detail(hls: _pull('a.m3u8')), ' HLS '), hasLength(1));
      expect(
        _failure(() => MissevanRoomParser.lines(detail(flv: _pull('a.flv')), '720')).message,
        'quality 720 is not offered',
      );
    });

    test('mediaUrl: the signed bilivideo address of its own kind, made https', () {
      expect(MissevanRoomParser.mediaUrl(_pull('a.flv'), isHls: false), _pull('a.flv'));
      expect(
        MissevanRoomParser.mediaUrl('http://xx.bilivideo.com/live-bvc/a.flv?expires=1730003600', isHls: false),
        'https://xx.bilivideo.com/live-bvc/a.flv?expires=1730003600',
      );
      expect(MissevanRoomParser.mediaUrl(_pull('a.flv'), isHls: true), isNull, reason: 'an FLV is not a playlist');
      for (final rejected in [
        'ftp://xx.bilivideo.com/live-bvc/a.flv',
        'https://bilivideo.com/live-bvc/a.flv',
        'https://xx.example.com/live-bvc/a.flv',
        'https://user@xx.bilivideo.com/live-bvc/a.flv',
        'https://xx.bilivideo.com/live-bvc/a.flv#f',
        'https://xx.bilivideo.com:8443/live-bvc/a.flv',
        'https://xx.bilivideo.com/live-bvc/a.flv?expires=173000360&sign=abc',
        'https://xx.bilivideo.com/live-bvc/a.flv?expires=1730003600&expires=1730003600',
        'https://xx.bilivideo.com/live-bvc/a.flv?expires=%FF',
      ]) {
        expect(MissevanRoomParser.mediaUrl(rejected, isHls: false), isNull, reason: rejected);
      }
      expect(MissevanRoomParser.mediaUrl('https://xx.bilivideo.com/live-bvc/a.flv', isHls: false), isNotNull);
    });

    test('formatOf and lease', () {
      expect(MissevanRoomParser.formatOf(_pull('a.m3u8')), LiveStreamFormat.hls);
      expect(MissevanRoomParser.formatOf(_pull('a.flv')), LiveStreamFormat.flv);
      expect(MissevanRoomParser.formatOf('not a url'), LiveStreamFormat.flv);
      expect(
        MissevanRoomParser.lease(_pull('a.flv'))?.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1730003600000, isUtc: true),
      );
      expect(MissevanRoomParser.lease('https://xx.example.com/a.flv?expires=1730003600'), isNull);
      expect(MissevanRoomParser.lease(_pull('a.flv', query: '')), isNull);
      expect(MissevanRoomParser.lease(_pull('a.flv', query: 'expires=0')), isNull);
    });

    test('the line of a URL with no expiry has no lease', () {
      final lines = MissevanRoomParser.lines(detail(flv: _pull('a.flv', query: 'sign=abc')), null);
      expect(lines.single.lease, isNull);
      expect(lines.single.url, _pull('a.flv', query: 'sign=abc'));
      expect(lines.single, isA<LivePlayLine>());
    });
  });
}

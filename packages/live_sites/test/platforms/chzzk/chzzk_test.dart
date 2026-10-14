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
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
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
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_http.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/danmaku/chzzk_danmaku_codec.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_json.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_play_parser.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';
import 'package:test/test.dart';

/// One request as the fake transport records it.
typedef _Seen = ({String method, Uri url, Map<String, String> headers, String body});

/// The channel of the tests: 32 lower-case hex digits, as the platform writes it.
const String _channel = '0123456789abcdef0123456789abcdef';

/// Another channel, for the rules that need a second one.
const String _other = '9876543210fedcba9876543210fedcba';

/// The chat channel of the tests.
const String _chat = 'N2lpu9';

/// The fixed clock: the capture hour of the platform's own samples.
final DateTime _at = DateTime.utc(2026, 9, 27, 16);

/// A Unix expiry [seconds] after the fixed clock.
String _expiry([int seconds = 61210]) => '${_at.millisecondsSinceEpoch ~/ 1000 + seconds}';

/// A channel id built from [index], for the lists that need many.
String _hexId(int index) => index.toRadixString(16).padLeft(32, '0');

String _json(Object? value) => jsonEncode(value);

/// An answer as the chat codec's readers take it: decoded, not its text.
Object? _decoded(Object? value) => jsonDecode(_json(value));

/// The `{code, message, content}` envelope the platform answers with.
String _answer(Object? content) => _json({'code': 200, 'message': 'OK', 'content': content});

/// An answer whose `code` is not 200.
String _refused({int code = 4001, String message = 'bad'}) => _json({'code': code, 'message': message});

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $right'));

/// One row of the site-wide or an area's lives list.
Map<String, Object?> _liveRow({
  String channelId = _channel,
  String name = 'Ann',
  String title = 'Late game',
  String avatar = 'https://static.pstatic.net/a.jpg',
  String liveUrl = 'https://live.akamaized.net/chzzk/live/{type}/x.jpg',
  String? thumbnail,
  String category = '게임',
  int? viewers = 14487,
  bool exposure = true,
  bool adult = false,
  bool krOnly = false,
  String? blindType,
  Object? liveId = 424242,
  Object? openDate = '2026-09-27 17:52:04',
  Object? paidProduct,
}) => {
  'liveId': liveId,
  'liveTitle': title,
  'liveImageUrl': liveUrl,
  'defaultThumbnailImageUrl': ?thumbnail,
  'liveCategory': 'GAME',
  'liveCategoryValue': category,
  'openDate': openDate,
  'adult': adult,
  'krOnlyViewing': krOnly,
  'blindType': ?blindType,
  'paidProduct': ?paidProduct,
  'concurrentUserCount': ?viewers,
  'cvExposure': exposure,
  'channel': {'channelId': channelId, 'channelName': name, 'channelImageUrl': avatar},
};

/// The lives answer of [rows], with the platform's own `page.next` when given.
String _lives(List<Map<String, Object?>> rows, {Map<String, Object?>? next}) => _answer({
  'data': rows,
  'page': {'next': ?next},
});

/// A `livePlaybackJson` value of the given media items.
String _playback(List<Object?> items) => _json({'media': items});

/// One media item of `livePlaybackJson`.
Map<String, Object?> _mediaItem({String mediaId = 'HLS', String protocol = 'HLS', String? path}) => {
  'mediaId': mediaId,
  'protocol': protocol,
  'path': path ?? 'https://live.akamaized.net/chzzk/$mediaId/master.m3u8?hdnts=st=0~exp=${_expiry()}',
};

/// An HLS master: one `#EXT-X-STREAM-INF` per entry, with the URI after it.
String _master(List<({String inf, String uri})> variants) => [
  '#EXTM3U',
  '#EXT-X-VERSION:4',
  for (final variant in variants) ...['#EXT-X-STREAM-INF:${variant.inf}', variant.uri],
].join('\n');

/// The three video variants of a master, plus an audio-only line the platform
/// also lists.
String _threeVariants({required String host, String token = ''}) => _master([
  (
    inf: 'BANDWIDTH=8192000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2",FRAME-RATE=60.0',
    uri: token.isEmpty ? '$host/1080.m3u8' : '$host/1080.m3u8?$token',
  ),
  (inf: 'BANDWIDTH=3500000,RESOLUTION=1280x720,CODECS="avc1.640028",FRAME-RATE=60.0', uri: '$host/720.m3u8'),
  (inf: 'BANDWIDTH=1200000,RESOLUTION=854x480,CODECS="avc1.640028",FRAME-RATE=30.0', uri: '$host/480.m3u8'),
  (inf: 'BANDWIDTH=64000,CODECS="mp4a.40.2",FRAME-RATE=0', uri: '$host/audio.m3u8'),
]);

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
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// An adapter over [onSend] with a fixed clock, and the transport it records on.
({ChzzkSite site, _FakeHttp http}) _adapter(LiveResponse Function(_Seen) onSend, {DateTime Function()? now}) {
  final http = _FakeHttp(onSend);
  return (site: ChzzkSite(http: ChzzkHttp(http), now: now ?? () => _at), http: http);
}

/// The channel answer of the tests.
Map<String, Object?> _channelData({
  String channelId = _channel,
  String name = 'Ann',
  String avatar = 'https://static.pstatic.net/a.jpg',
  String description = 'hello',
  int? followers = 321,
  bool openLive = true,
}) => {
  'channelId': channelId,
  'channelName': name,
  'channelImageUrl': avatar,
  'channelDescription': description,
  'followerCount': ?followers,
  'openLive': openLive,
};

/// The `v3.1 live-detail` answer of the tests.
String _liveDetail({
  String status = 'OPEN',
  String channelId = _channel,
  String title = 'Late game',
  int? viewers = 14487,
  bool exposure = true,
  bool adult = false,
  bool krOnly = false,
  String? blindType,
  String? chatChannelId = _chat,
  Object? playback,
  bool withChannel = true,
}) => _answer({
  'status': status,
  'liveId': 424242,
  'liveTitle': title,
  'liveCategory': 'GAME',
  'liveCategoryValue': '게임',
  'liveImageUrl': 'https://live.akamaized.net/chzzk/live/{type}/x.jpg',
  'concurrentUserCount': ?viewers,
  'cvExposure': exposure,
  'adult': adult,
  'krOnlyViewing': krOnly,
  'blindType': ?blindType,
  'timeMachineActive': false,
  'chatChannelId': ?chatChannelId,
  'openDate': '2026-09-27 17:52:04',
  'livePlaybackJson': ?playback,
  if (withChannel)
    'channel': {'channelId': channelId, 'channelName': 'Ann', 'channelImageUrl': 'https://pstatic.net/c.png'},
});

/// A chat frame: [body] as the JSON of `cmd` [cmd], and [code] its `retCode`.
String _frame(int cmd, Object? body, {int? code}) => _json({'cmd': cmd, 'retCode': ?code, 'bdy': body});

/// One pushed chat line (`msg`, `uid`, `msgTime`, `msgTypeCode`).
Map<String, Object?> _liveLine({
  String msg = 'hi',
  String uid = 'u1',
  int? time = 1759000000000,
  int? type,
  Object? profile,
  Object? extras,
  String? status,
}) => {
  'msg': msg,
  'uid': uid,
  'msgTime': ?time,
  'msgTypeCode': ?type,
  'msgStatusType': ?status,
  'profile': ?profile,
  'extras': ?extras,
};

void main() {
  group('answers, cursors and readers', () {
    test('the envelope needs an HTTP 200, code 200 and an object', () {
      expect(content('{"code":200,"content":{"a":1}}', what: 'x'), isA<Map<String, Object?>>());
      expect(() => content(_refused(), what: 'x'), throwsA(predicate((e) => '$e'.contains('code 4001 bad'))));
      expect(() => content('nope', what: 'x'), throwsA(isA<ChzzkFailure>()));
      expect(() => content('[]', what: 'x'), throwsA(isA<ChzzkFailure>()));
      expect(content('{"code":200,"content":null}', what: 'x'), isNull);
      expect(() => content('{"code":200,"content":{}}', what: 'x', status: 500), throwsA(isA<ChzzkFailure>()));
      expect(
        () => content('{"code":200,"content":{"a":"${'y' * 3000000}"}}', what: 'x'),
        throwsA(predicate((e) => '$e'.contains('over'))),
      );
    });

    test('a status names its own failure', () {
      expect(statusFailure(200, 'x'), isNull);
      expect(statusFailure(400, 'x')?.kind, ChzzkFailureKind.apiChanged);
      expect(statusFailure(401, 'x')?.kind, ChzzkFailureKind.riskControl);
      expect(statusFailure(403, 'x')?.kind, ChzzkFailureKind.riskControl);
      expect(statusFailure(404, 'x')?.kind, ChzzkFailureKind.notFound);
      expect(statusFailure(429, 'x')?.kind, ChzzkFailureKind.rateLimited);
      expect(statusFailure(302, 'x')?.kind, ChzzkFailureKind.network);
      expect(statusFailure(503, 'x')?.kind, ChzzkFailureKind.network);
    });

    test('the directory cursor is the platform pair, and only that', () {
      final cursor = ChzzkEndpoints.encodeCursor(14487, 424242);
      expect(cursor, '{"v":14487,"l":424242}');
      expect(ChzzkEndpoints.decodeCursor(cursor), (viewers: 14487, liveId: 424242));
      expect(ChzzkEndpoints.livesQuery(cursor), {'size': '30', 'concurrentUserCount': '14487', 'liveId': '424242'});
      expect(ChzzkEndpoints.livesQuery(null), {'size': '30'});
      for (final bad in [
        '',
        'x',
        '{}',
        '{"v":1}',
        '{"v":1,"l":2,"x":3}',
        '{"v":-1,"l":2}',
        '{"v":1,"l":0}',
        '["v"]',
        '{"v":"x","l":2}',
      ]) {
        expect(ChzzkEndpoints.decodeCursor(bad), isNull, reason: bad);
      }
      expect(ChzzkEndpoints.decodeCursor('x' * 200), isNull);
      expect(ChzzkEndpoints.livesQuery('nope'), isNull);
    });

    test('an area id is refused only when it cannot go in a path', () {
      for (final ok in ['Mount_&_Blade2_Bannerlord', 'LoL', 'x' * 128]) {
        expect(isAreaId(ok), isTrue, reason: ok);
      }
      for (final bad in ['', '.', '..', 'a b', 'a/b', r'a\b', 'a?b', 'a#b', 'x' * 129]) {
        expect(isAreaId(bad), isFalse, reason: bad);
      }
    });

    test('an openDate is Korean time and nothing else', () {
      expect(seoulTime('2026-09-27 17:52:04'), DateTime.utc(2026, 9, 27, 8, 52, 4));
      expect(seoulTime('2026-09-27T17:52:04'), DateTime.utc(2026, 9, 27, 8, 52, 4));
      for (final bad in [
        '',
        '17:52:04',
        '2026-13-27 17:52:04',
        '2026-02-30 17:52:04',
        '1999-12-31 23:59:59',
        '2026-9-7 17:52:04',
        1759000000,
        null,
      ]) {
        expect(seoulTime(bad), isNull, reason: '$bad');
      }
    });

    test('only NAVER hosts over https are kept as images', () {
      for (final ok in [
        'https://pstatic.net/a.jpg',
        'https://static.pstatic.net/a.jpg',
        'https://live.akamaized.net/a',
      ]) {
        expect(image(ok), ok);
      }
      for (final bad in [
        '',
        'http://pstatic.net/a',
        'https://evil.test/pstatic.net',
        'https://pstatic.net.a/x',
        'https://u@pstatic.net/a',
        'https://pstatic.net/a#x',
        'notaurl',
        17,
      ]) {
        expect(image(bad), isEmpty, reason: '$bad');
      }
    });

    test('the cover fixes the width token and falls back to the thumbnail', () {
      expect(cover('https://live.akamaized.net/x/{type}/a.jpg', null), 'https://live.akamaized.net/x/480/a.jpg');
      expect(cover('https://evil.test/{type}', 'https://pstatic.net/t.jpg'), 'https://pstatic.net/t.jpg');
      expect(cover(null, null), isEmpty);
      expect(cover('', ''), isEmpty);
    });

    test('the numbers are read as written, negatives kept', () {
      expect(jsonInt(3), 3);
      expect(jsonInt(3.0), 3);
      expect(jsonInt(3.5), isNull);
      expect(jsonInt(' 4 '), 4);
      expect(jsonInt(-2), -2);
      expect(jsonInt(true), isNull);
      expect(jsonCount(-2), isNull);
      expect(jsonCount('7'), 7);
      expect(text(17), isEmpty);
      expect(stringify(' x '), 'x');
      expect(stringify(''), isNull);
      expect(channelId(_channel.toUpperCase()), isNull);
      expect(channelId(' $_channel '), _channel);
      expect(isChannelId(_other), isTrue);
    });
  });

  group('lives list', () {
    test('a row is a live card with its start, area and viewer count', () {
      final page = ChzzkRoomParser.lives(_lives([_liveRow()]));
      final card = page.rooms.single;
      expect(card.platform, 'chzzk');
      expect(card.roomId, _channel);
      expect(card.content.title, 'Late game');
      expect(card.anchor?.name, 'Ann');
      expect(card.anchor?.anchorId, _channel);
      expect(card.anchor?.liveStatus, LiveStatus.live);
      expect(card.area?.areaName, '게임');
      expect(card.audience.onlineViewers, 14487);
      expect(card.audience.primaryMetric?.name, 'onlineViewers');
      expect(card.broadcast.isLiveNow, isTrue);
      expect(card.broadcast.effectiveRestriction, LiveRestriction.none);
      expect(card.broadcast.startedAt, DateTime.utc(2026, 9, 27, 8, 52, 4));
      expect(card.links.webUrl, 'https://chzzk.naver.com/live/$_channel');
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('an empty title is the channel name and a hidden count stays unsaid', () {
      final card = ChzzkRoomParser.lives(_lives([_liveRow(title: '', viewers: 999, exposure: false)])).rooms.single;
      expect(card.content.title, 'Ann');
      expect(card.audience.onlineViewers, isNull);
      final missing = ChzzkRoomParser.lives(_lives([_liveRow(viewers: null)])).rooms.single;
      expect(missing.audience.onlineViewers, isNull);
    });

    test('region, adult and paid rows keep their own reading', () {
      final rows = ChzzkRoomParser.lives(
        _lives([
          _liveRow(krOnly: true),
          _liveRow(channelId: _other, blindType: 'ABROAD'),
          _liveRow(channelId: _hexId(2), adult: true),
          _liveRow(channelId: _hexId(3), paidProduct: {'id': 'p'}),
        ]),
      ).rooms;
      expect(rows[0].broadcast.restriction, LiveRestriction.regionBlocked);
      expect(rows[1].broadcast.restriction, LiveRestriction.regionBlocked);
      expect(rows[2].broadcast.restriction, LiveRestriction.adult);
      // A paid row of the list is left unsaid rather than guessed: none of the
      // 600 lives captured on 2026-09-29 had one.
      expect(rows[3].broadcast.restriction, isNull);
      // Region wins over adult when a row is both.
      expect(
        ChzzkRoomParser.lives(_lives([_liveRow(krOnly: true, adult: true)])).rooms.single.broadcast.restriction,
        LiveRestriction.regionBlocked,
      );
    });

    test('an unreadable row is skipped and a repeated channel is listed once', () {
      final page = ChzzkRoomParser.lives(
        _lives([
          _liveRow(),
          {..._liveRow(), 'channel': 'not an object'},
          _liveRow(channelId: 'not-hex'),
          _liveRow(liveId: 0),
          _liveRow(liveId: 'x'),
          _liveRow(liveId: 555),
          _liveRow(channelId: _other, liveId: 556),
        ]),
      );
      expect(page.rooms.map((room) => room.roomId), [_channel, _other]);
    });

    test('a cursor page starts after the row the cursor names', () {
      final cursor = ChzzkEndpoints.encodeCursor(10, 9);
      final page = ChzzkRoomParser.lives(
        _lives([_liveRow(liveId: 9, viewers: 10), _liveRow(channelId: _other, liveId: 8)]),
        cursor: cursor,
      );
      expect(page.rooms.map((room) => room.roomId), [_other]);
    });

    test('extra rows are cut and the next cursor points after the last kept row', () {
      final rows = [for (var i = 0; i < 33; i++) _liveRow(channelId: _hexId(i), liveId: 100 + i, viewers: 500 - i)];
      final page = ChzzkRoomParser.lives(_lives(rows, next: {'concurrentUserCount': 1, 'liveId': 1}));
      expect(page.rooms, hasLength(30));
      // The server's own pointer would restart the next page at row 2; the last
      // kept row does not skip anything.
      final after = ChzzkEndpoints.decodeCursor(page.nextCursor)!;
      expect(after.liveId, 129);
      expect(after.viewers, 471);
    });

    test('a cut list whose last kept row has no count has no next page', () {
      final rows = [
        for (var i = 0; i < 31; i++) _liveRow(channelId: _hexId(i), liveId: 100 + i, viewers: i == 29 ? null : 500 - i),
      ];
      expect(ChzzkRoomParser.lives(_lives(rows)).nextCursor, isNull);
    });

    test('a page.next that is not a cursor is api-changed', () {
      for (final next in [
        {'concurrentUserCount': 1},
        {'liveId': 3},
        {'concurrentUserCount': -1, 'liveId': 3},
        {'concurrentUserCount': 1, 'liveId': 0},
      ]) {
        expect(
          () => ChzzkRoomParser.lives(_lives([_liveRow()], next: next)),
          throwsA(isA<ChzzkFailure>()),
          reason: '$next',
        );
      }
    });

    test('a cursor that repeats ends the list', () {
      final cursor = ChzzkEndpoints.encodeCursor(14487, 424242);
      final page = ChzzkRoomParser.lives(
        _lives([_liveRow(liveId: 1)], next: {'concurrentUserCount': 14487, 'liveId': 424242}),
        cursor: cursor,
      );
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
    });

    test('an empty page is the end, and a broken envelope is api-changed', () {
      expect(ChzzkRoomParser.lives(_lives([])).rooms, isEmpty);
      expect(() => ChzzkRoomParser.lives(_answer({'page': <String, Object?>{}})), throwsA(isA<ChzzkFailure>()));
      expect(() => ChzzkRoomParser.lives(_answer(<Object?>[])), throwsA(isA<ChzzkFailure>()));
      expect(() => ChzzkRoomParser.lives('nope'), throwsA(isA<ChzzkFailure>()));
      expect(() => ChzzkRoomParser.lives('{}', status: 500), throwsA(isA<ChzzkFailure>()));
    });
  });

  group('catalog', () {
    test('a category page keeps the platform order and its own cursor fields', () {
      final page = ChzzkRoomParser.categoryPage(
        _answer({
          'data': [
            {
              'categoryType': 'GAME',
              'categoryId': 'LoL',
              'categoryValue': '리그 오브 레전드',
              'posterImageUrl': 'https://pstatic.net/p.jpg',
            },
            {'categoryType': 'bad type', 'categoryId': 'x'},
            {'categoryType': 'GAME', 'categoryId': 'a b'},
            {'categoryType': 'ETC', 'categoryId': 'etc1', 'categoryValue': ''},
          ],
          'page': {
            'next': {'concurrentUserCount': 12, 'openLiveCount': 3, 'categoryId': 'LoL', 'blank': ''},
          },
        }),
      );
      expect(page.areas.map((area) => area.areaId), ['LoL', 'etc1']);
      final first = page.areas.first;
      expect(first.areaName, '리그 오브 레전드');
      expect(first.parentAreaId, 'GAME');
      expect(first.parentAreaName, '游戏');
      expect(first.iconUrl, 'https://pstatic.net/p.jpg');
      // An empty name falls back to the id.
      expect(page.areas.last.areaName, 'etc1');
      expect(page.next, {'concurrentUserCount': '12', 'openLiveCount': '3', 'categoryId': 'LoL'});
    });

    test('an empty page has no next and a page of bad rows is api-changed', () {
      final empty = ChzzkRoomParser.categoryPage(
        _answer({
          'data': <Object?>[],
          'page': {
            'next': {'a': 1},
          },
        }),
      );
      expect(empty.areas, isEmpty);
      expect(empty.next, isNull);
      expect(
        () => ChzzkRoomParser.categoryPage(
          _answer({
            'data': [
              {'categoryType': 'bad type', 'categoryId': 'x'},
            ],
            'page': <String, Object?>{},
          }),
        ),
        throwsA(predicate((e) => '$e'.contains('no readable entry of 1'))),
      );
      expect(() => ChzzkRoomParser.categoryPage(_refused()), throwsA(isA<ChzzkFailure>()));
    });

    test('the catalog lists an area once, with the known types first', () {
      LiveArea of(String id, String type) =>
          LiveArea.normalized(platform: 'chzzk', areaId: id, areaName: id, parentAreaId: type);
      final areas = ChzzkRoomParser.categories([
        [of('LoL', 'GAME'), of('etc1', 'ETC'), of('LoL', 'GAME')],
        [of('s1', 'SPORTS'), of('o1', 'RAID')],
      ]);
      expect(areas.map((area) => area.areaId), ['LoL', 's1', 'etc1', 'o1']);
    });
  });

  group('channel and live', () {
    test('an unknown channel is not-found and another channel is api-changed', () {
      expect(
        () => ChzzkRoomParser.channelById(_answer({'channelId': null}), channelId: _channel),
        throwsA(isA<ChzzkFailure>()),
      );
      expect(() => ChzzkRoomParser.channelById(_answer(null), channelId: _channel), throwsA(isA<ChzzkFailure>()));
      expect(
        () => ChzzkRoomParser.channelById(_answer(_channelData(channelId: _other)), channelId: _channel),
        throwsA(predicate((e) => '$e'.contains('for $_channel'))),
      );
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      expect(owner.followers, 321);
      expect(owner.description, 'hello');
      expect(owner.isLive, isTrue);
    });

    test('a live detail reads the room side of a channel', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      final live = ChzzkRoomParser.liveDetail(_liveDetail(playback: _playback([_mediaItem()])), owner: owner)!;
      expect(live.isLive, isLiveOf(live));
      expect(live.chatChannelId, _chat);
      expect(live.media.single.id, 'HLS');
      expect(live.online, 14487);
      expect(live.startedAt, DateTime.utc(2026, 9, 27, 8, 52, 4));
      expect(live.mediaError, isNull);
      final room = ChzzkRoomParser.room(owner, live);
      expect(room.roomId, _channel);
      expect(room.anchor?.name, 'Ann');
      expect(room.anchor?.followerCount, 321);
      expect(room.content.introduction, 'hello');
      expect(room.area?.areaName, '게임');
      expect(room.broadcast.effectiveRestriction, LiveRestriction.none);
      expect(ChzzkRoomParser.danmakuArgs(owner, live)?.channelId, _channel);
    });

    test('a closed live is the offline channel card, whatever openLive says', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      final live = ChzzkRoomParser.liveDetail(_liveDetail(status: 'CLOSE'), owner: owner)!;
      expect(live.startedAt, isNull);
      final room = ChzzkRoomParser.room(owner, live);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(room.anchor?.liveStatus, LiveStatus.offline);
      expect(ChzzkRoomParser.danmakuArgs(owner, live), isNull);
      expect(ChzzkRoomParser.room(owner, null).broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(ChzzkRoomParser.restriction(live), isNull);
    });

    test('a never-broadcast channel has no live at all', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      expect(ChzzkRoomParser.liveDetail(_answer(null), owner: owner), isNull);
      final noChannel = ChzzkRoomParser.liveDetail(_answer({'status': 'CLOSE'}), owner: owner)!;
      expect(noChannel.nick, 'Ann');
      expect(noChannel.avatar, 'https://static.pstatic.net/a.jpg');
    });

    test('an unknown live status is api-changed, never a guess of offline', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      expect(
        () => ChzzkRoomParser.liveDetail(_liveDetail(status: 'PAUSED'), owner: owner),
        throwsA(predicate((e) => '$e'.contains('status PAUSED'))),
      );
      expect(
        () => ChzzkRoomParser.liveDetail(_liveDetail(channelId: _other), owner: owner),
        throwsA(isA<ChzzkFailure>()),
      );
      expect(ChzzkRoomParser.liveDetail(_answer({'status': 'CLOSED'}), owner: owner)!.isLive, isFalse);
    });

    test('unreadable playback data leaves the room standing with its reason', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      final live = ChzzkRoomParser.liveDetail(_liveDetail(playback: 'nope'), owner: owner)!;
      expect(live.media, isEmpty);
      expect(live.mediaError?.kind, ChzzkFailureKind.apiChanged);
      expect(ChzzkRoomParser.restriction(live), isNull);
      expect(ChzzkRoomParser.room(owner, live).broadcast.isLiveNow, isTrue);
      expect(ChzzkRoomParser.unavailable(live).kind, ChzzkFailureKind.apiChanged);
    });

    test('a gated live names why it cannot play', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      ChzzkFailureKind kindOf(String Function() detail) =>
          ChzzkRoomParser.unavailable(ChzzkRoomParser.liveDetail(detail(), owner: owner)).kind;
      expect(kindOf(() => _liveDetail(adult: true, chatChannelId: null)), ChzzkFailureKind.needsLogin);
      expect(kindOf(() => _liveDetail(krOnly: true, chatChannelId: null)), ChzzkFailureKind.regionBlocked);
      expect(kindOf(() => _liveDetail(blindType: 'ABROAD')), ChzzkFailureKind.regionBlocked);
      expect(kindOf(_liveDetail), ChzzkFailureKind.streamUnavailable);
      expect(ChzzkRoomParser.unavailable(null).kind, ChzzkFailureKind.streamUnavailable);
      final paid = ChzzkRoomParser.liveDetail(
        _answer({
          'status': 'OPEN',
          'liveTitle': 'x',
          'paidProductId': 'p',
          'adult': false,
          'krOnlyViewing': false,
          'cvExposure': true,
        }),
        owner: owner,
      )!;
      expect(paid.paid, isTrue);
      expect(ChzzkRoomParser.restriction(paid), LiveRestriction.paid);
      expect(ChzzkRoomParser.unavailable(paid).kind, ChzzkFailureKind.streamUnavailable);
      // Adult with playback data behind it is still not playable by name.
      final adultWithMedia = ChzzkRoomParser.liveDetail(
        _liveDetail(adult: true, playback: _playback([_mediaItem()])),
        owner: owner,
      )!;
      expect(ChzzkRoomParser.restriction(adultWithMedia), LiveRestriction.none);
      expect(adultWithMedia.chatChannelId, _chat);
    });

    test('a hidden viewer count leaves the audience unknown, not zero', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      final live = ChzzkRoomParser.liveDetail(_liveDetail(viewers: 4000, exposure: false), owner: owner)!;
      expect(live.online, isNull);
      expect(ChzzkRoomParser.room(owner, live).audience.onlineViewers, isNull);
    });

    test('room data keeps the masters or the reason, never neither', () {
      final owner = ChzzkRoomParser.channelById(_answer(_channelData()), channelId: _channel);
      final live = ChzzkRoomParser.liveDetail(_liveDetail(playback: _playback([_mediaItem()])), owner: owner)!;
      final data = ChzzkRoomParser.roomData(_channel, live, issuedAt: _at);
      expect(data.media, hasLength(1));
      expect(data.unavailable, isNull);
      expect(data.issuedAt, _at);
      final offline = ChzzkRoomParser.roomData(_channel, null, issuedAt: _at);
      expect(offline.media, isEmpty);
      expect(offline.unavailable?.kind, ChzzkFailureKind.streamUnavailable);
    });
  });

  group('search and links', () {
    test('a search card is a channel, live or offline, without an id skipped', () {
      final rooms = ChzzkRoomParser.searchRooms(
        _answer({
          'data': [
            {'channel': _channelData()},
            {
              'channel': {'channelName': 'no id'},
            },
            'not an object',
          ],
        }),
      );
      expect(rooms, hasLength(1));
      final card = rooms.single;
      expect(card.roomId, _channel);
      expect(card.content.title, 'Ann');
      expect(card.content.coverUrl, 'https://static.pstatic.net/a.jpg');
      expect(card.anchor?.followerCount, 321);
      expect(card.broadcast.effectiveLiveStatus, LiveStatus.live);
      final offline = ChzzkRoomParser.searchRooms(
        _answer({
          'data': [
            {'channel': _channelData(openLive: false)},
          ],
        }),
      ).single;
      expect(offline.broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(offline.anchor?.liveStatus, LiveStatus.offline);
    });

    test('a keyword is trimmed and cut to the platform limit, never mid-surrogate', () {
      expect(ChzzkRoomParser.searchKeyword(' Ann '), 'Ann');
      expect(ChzzkRoomParser.searchKeyword('   '), isEmpty);
      expect(ChzzkRoomParser.searchKeyword('a' * 120).length, 100);
      // Cutting must not leave half of an emoji behind.
      final cut = ChzzkRoomParser.searchKeyword('👍' * 60);
      expect(cut.length.isEven, isTrue);
      expect(cut.runes.every((rune) => rune < 0xD800 || rune > 0xDBFF), isTrue);
    });

    test('a channel link is read in any case and written in lower', () {
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/live/$_channel'), _channel);
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/$_channel'), _channel);
      expect(ChzzkRoomParser.roomIdFromUrl('http://chzzk.naver.com/$_channel/videos'), _channel);
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/live/${_channel.toUpperCase()}'), _channel);
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com//live//$_channel//'), _channel);
      expect(ChzzkRoomParser.roomIdFromUrl('https://chzzk.naver.com/live/$_channel#x'), _channel);
    });

    test('another page, host or shape is not a room', () {
      for (final url in [
        'https://chzzk.naver.com/video/12345',
        'https://chzzk.naver.com/live/$_channel/extra',
        'https://chzzk.naver.com/$_channel/videos/1',
        'https://chzzk.naver.com/not-hex',
        'https://m.chzzk.naver.com/live/$_channel',
        'https://chzzk.naver.test/live/$_channel',
        'https://u@chzzk.naver.com/live/$_channel',
        'ftp://chzzk.naver.com/live/$_channel',
        'not a url',
        '',
      ]) {
        expect(ChzzkRoomParser.roomIdFromUrl(url), isNull, reason: url);
      }
    });
  });

  group('playback', () {
    test('livePlaybackJson gives the HLS and LLHLS masters, once each', () {
      final media = ChzzkPlayParser.media(
        _playback([
          _mediaItem(),
          _mediaItem(mediaId: 'LLHLS', path: 'https://llive.akamaized.net/ll.m3u8'),
          {
            'mediaId': 'HLS',
            'protocol': 'HLS',
            'path': 'https://live.akamaized.net/chzzk/HLS/master.m3u8?hdnts=st=0~exp=${_expiry()}',
          },
          _mediaItem(mediaId: 'DASH', path: 'https://live.akamaized.net/dash.mpd'),
          {'protocol': 'HLS'},
          {'mediaId': 'HLS', 'protocol': ''},
          'not an object',
        ]),
      );
      expect(media.map((item) => item.id), ['HLS', 'LLHLS']);
      expect(media.first.url.host, 'live.akamaized.net');
    });

    test('absent playback is none and a broken answer is api-changed', () {
      expect(ChzzkPlayParser.media(null), isEmpty);
      expect(ChzzkPlayParser.media(''), isEmpty);
      expect(ChzzkPlayParser.media(_playback([])), isEmpty);
      expect(() => ChzzkPlayParser.media(17), throwsA(isA<ChzzkFailure>()));
      expect(() => ChzzkPlayParser.media('{}'), throwsA(isA<ChzzkFailure>()));
      expect(() => ChzzkPlayParser.media('nope'), throwsA(isA<ChzzkFailure>()));
      expect(() => ChzzkPlayParser.media(_json({'media': <String, Object?>{}})), throwsA(isA<ChzzkFailure>()));
      expect(
        () => ChzzkPlayParser.media(
          _playback([
            _mediaItem(path: 'http://live.akamaized.net/x.m3u8'),
            _mediaItem(mediaId: 'LLHLS', path: 'https://evil.test/x.m3u8'),
          ]),
        ),
        throwsA(predicate((e) => '$e'.contains('2 unusable media'))),
      );
      expect(
        () => ChzzkPlayParser.media(_playback([for (var i = 0; i < 17; i++) _mediaItem()])),
        throwsA(predicate((e) => '$e'.contains('17 media'))),
      );
      expect(
        () => ChzzkPlayParser.media(_playback([_mediaItem(path: 'https://a.akamaized.net/${'x' * 17000}')].toList())),
        throwsA(isA<ChzzkFailure>()),
      );
    });

    test('a master of a gone stream is stream-unavailable, not missing', () {
      expect(
        () => ChzzkPlayParser.master('', what: 'HLS master', status: 404),
        throwsA(predicate((e) => '$e'.contains('HLS master: HTTP 404'))),
      );
      expect(() => ChzzkPlayParser.master('', what: 'HLS master', status: 500), throwsA(isA<ChzzkFailure>()));
      expect(ChzzkPlayParser.master('#EXTM3U', what: 'HLS master'), '#EXTM3U');
    });

    test('the variants keep their rate, bandwidth and codec and resolve their URIs', () {
      final master = ChzzkPlayParser.media(_playback([_mediaItem()])).single;
      final variants = ChzzkPlayParser.variants(
        _threeVariants(host: 'https://live.akamaized.net/chzzk', token: 'hdntl=exp=${_expiry(7200)}~acl=*'),
        media: master,
        issuedAt: _at,
      );
      expect(variants, hasLength(3));
      expect(variants.first.height, 1080);
      expect(variants.first.frameRate, 60);
      expect(variants.first.bandwidth, 8192000);
      expect(variants.first.codec, LiveStreamCodec.avc);
      expect(variants.first.url, 'https://live.akamaized.net/chzzk/1080.m3u8?hdntl=exp=${_expiry(7200)}~acl=*');
      expect(
        variants.first.lease?.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(int.parse(_expiry(7200)) * 1000, isUtc: true),
      );
      // Without its own token the variant takes the master's.
      expect(
        variants[1].lease?.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(int.parse(_expiry()) * 1000, isUtc: true),
      );
      // A relative URI is resolved against the master.
      final relative = ChzzkPlayParser.variants(
        _threeVariants(host: 'bitrates'),
        media: master,
        issuedAt: _at,
      );
      expect(relative.first.url, 'https://live.akamaized.net/chzzk/HLS/bitrates/1080.m3u8');
    });

    test('an audio-only or malformed playlist costs that master only', () {
      final master = ChzzkPlayParser.media(_playback([_mediaItem()])).single;
      expect(
        () => ChzzkPlayParser.variants(
          _master([(inf: 'BANDWIDTH=64000,CODECS="mp4a.40.2"', uri: 'a.m3u8')]),
          media: master,
          issuedAt: _at,
        ),
        throwsA(predicate((e) => '$e'.contains('no video variant'))),
      );
      expect(
        () => ChzzkPlayParser.variants('<html>nope</html>', media: master, issuedAt: _at),
        throwsA(predicate((e) => '$e'.contains('not a playlist'))),
      );
      expect(() => ChzzkPlayParser.variants('#EXTM3U\n', media: master, issuedAt: _at), throwsA(isA<ChzzkFailure>()));
      // A variant whose URI is not http(s) is left out, and with it the master.
      expect(
        () => ChzzkPlayParser.variants(
          _master([(inf: 'BANDWIDTH=1000,RESOLUTION=640x360', uri: 'ftp://a/x.m3u8')]),
          media: master,
          issuedAt: _at,
        ),
        throwsA(predicate((e) => '$e'.contains('no video variant'))),
      );
    });

    test('qualities rank by height then bandwidth, and name the latency pair', () {
      final masters = ChzzkPlayParser.media(
        _playback([
          _mediaItem(),
          _mediaItem(
            mediaId: 'LLHLS',
            path: 'https://llive.akamaized.net/LLHLS/master.m3u8?hdnts=st=0~exp=${_expiry()}',
          ),
        ]),
      );
      final variants = [
        ...ChzzkPlayParser.variants(
          _threeVariants(host: 'https://live.akamaized.net/h'),
          media: masters.first,
          issuedAt: _at,
        ),
        ...ChzzkPlayParser.variants(
          _threeVariants(host: 'https://llive.akamaized.net/l'),
          media: masters.last,
          issuedAt: _at,
        ),
      ];
      final qualities = ChzzkPlayParser.qualities(variants);
      expect(qualities.map((quality) => quality.qualityId), ['1080p60', '720p60', '480p']);
      expect(qualities.first.label, '1080p60 · HLS');
      expect(qualities.first.platformOrder, 3);
      expect(qualities.first.codec, LiveStreamCodec.avc);
      final lines = ChzzkPlayParser.lines(variants, quality: '1080p60');
      expect(lines.map((line) => line.lineLabel), ['HLS', 'LLHLS']);
      expect(lines.first.format, LiveStreamFormat.hls);
      expect(lines.first.formatSource.name, 'declared');
      expect(lines.first.headers['referer'], 'https://chzzk.naver.com/');
      expect(lines.first.headers['accept'], isNull);
      expect(ChzzkPlayParser.lines(variants, quality: '2160p'), isEmpty);
      expect(ChzzkPlayParser.lines(variants), hasLength(6));
    });

    test('a 50 fps or faster variant is a quality of its own', () {
      final master = ChzzkPlayParser.media(_playback([_mediaItem()])).single;
      final variants = ChzzkPlayParser.variants(
        _master([
          (inf: 'BANDWIDTH=5000000,RESOLUTION=1280x720,FRAME-RATE=30.0', uri: 'a.m3u8'),
          (inf: 'BANDWIDTH=6000000,RESOLUTION=1280x720,FRAME-RATE=60.0', uri: 'b.m3u8'),
        ]),
        media: master,
        issuedAt: _at,
      );
      expect(ChzzkPlayParser.qualities(variants).map((quality) => quality.qualityId), ['720p60', '720p']);
    });

    test('the declared codec names avc, hevc, av1 and vp9', () {
      final master = ChzzkPlayParser.media(_playback([_mediaItem()])).single;
      expect(ChzzkPlayParser.codecOf('avc1.640028,mp4a.40.2'), LiveStreamCodec.avc);
      expect(ChzzkPlayParser.codecOf('avc3.640028'), LiveStreamCodec.avc);
      expect(ChzzkPlayParser.codecOf('hvc1.1.6'), LiveStreamCodec.hevc);
      expect(ChzzkPlayParser.codecOf('hev1.1.2'), LiveStreamCodec.hevc);
      expect(ChzzkPlayParser.codecOf('av01.0.08M.08'), LiveStreamCodec.av1);
      expect(ChzzkPlayParser.codecOf('vp09.00.10.08'), LiveStreamCodec.vp9);
      expect(ChzzkPlayParser.codecOf('mp4a.40.2'), isNull);
      expect(ChzzkPlayParser.codecOf(null), isNull);
      // A master that declares no CODECS at all leaves the codec undeclared.
      expect(
        ChzzkPlayParser.variants(
          _master([(inf: 'BANDWIDTH=1000,RESOLUTION=640x360', uri: 'x.m3u8')]),
          media: master,
          issuedAt: _at,
        ).single.codec,
        isNull,
      );
    });

    test('a lease renews a quarter of the lifetime ahead, capped at ten minutes', () {
      final hour = ChzzkPlayParser.lease(
        Uri.parse('https://live.akamaized.net/v.m3u8'),
        master: Uri.parse('https://live.akamaized.net/m.m3u8?hdnts=st=0~exp=${_expiry(3600)}'),
        issuedAt: _at,
      )!;
      expect(hour.expiresAt!.difference(hour.refreshAt), const Duration(minutes: 10));
      expect(hour.requiresReconnect, isTrue);
      final short = ChzzkPlayParser.lease(
        Uri.parse('https://live.akamaized.net/v.m3u8?hdntl=exp=${_expiry(1200)}~acl=*'),
        master: Uri.parse('https://live.akamaized.net/m.m3u8'),
        issuedAt: _at,
      )!;
      expect(short.expiresAt!.difference(short.refreshAt), const Duration(minutes: 5));
      // A LLHLS manifest carries its token as a path element instead.
      final inPath = ChzzkPlayParser.lease(
        Uri.parse('https://live.akamaized.net/720p/hdntl=exp=${_expiry(7200)}~acl=*~hmac=x/chunklist.m3u8'),
        master: Uri.parse('https://live.akamaized.net/m.m3u8?hdnts=st=0~exp=${_expiry()}'),
        issuedAt: _at,
      )!;
      expect(inPath.expiresAt, DateTime.fromMillisecondsSinceEpoch(int.parse(_expiry(7200)) * 1000, isUtc: true));
      final long = ChzzkPlayParser.lease(
        Uri.parse('https://live.akamaized.net/v.m3u8'),
        master: Uri.parse('https://live.akamaized.net/m.m3u8?hdnts=st=0~exp=${_expiry()}'),
        issuedAt: _at,
      )!;
      expect(long.expiresAt!.difference(long.refreshAt), const Duration(minutes: 10));
    });

    test('no token, a past token and a malformed query give no lease', () {
      expect(
        ChzzkPlayParser.lease(
          Uri.parse('https://live.akamaized.net/x'),
          master: Uri.parse('https://live.akamaized.net/m'),
          issuedAt: _at,
        ),
        isNull,
      );
      final past = _expiry(-10);
      expect(
        ChzzkPlayParser.lease(
          Uri.parse('https://live.akamaized.net/x.m3u8?hdntl=exp=$past~acl=*'),
          master: Uri.parse('https://live.akamaized.net/m.m3u8'),
          issuedAt: _at,
        ),
        isNull,
      );
      expect(ChzzkPlayParser.masterExpiry(Uri.parse('https://live.akamaized.net/m.m3u8?hdnts=st=%')), isNull);
      expect(ChzzkPlayParser.masterExpiry(Uri.parse('https://live.akamaized.net/m.m3u8')), isNull);
      // An `exp` is only read as a token of the platform's own length.
      expect(ChzzkPlayParser.masterExpiry(Uri.parse('https://x/m.m3u8?hdnts=exp=1~acl=*')), isNull);
      expect(
        ChzzkPlayParser.masterExpiry(Uri.parse('https://x/m.m3u8?hdnts=st=0~exp=${_expiry(60)}~acl=*')),
        isNotNull,
      );
    });

    test('freshness follows the leases and the master tokens', () {
      final live = ChzzkPlayParser.lines(
        ChzzkPlayParser.variants(
          _threeVariants(host: 'https://live.akamaized.net', token: 'hdntl=exp=${_expiry(7200)}'),
          media: ChzzkPlayParser.media(_playback([_mediaItem()])).single,
          issuedAt: _at,
        ),
      );
      expect(ChzzkPlayParser.linesFresh(live, _at), isTrue);
      expect(ChzzkPlayParser.linesFresh(live, _at.add(const Duration(hours: 3))), isFalse);
      expect(ChzzkPlayParser.linesFresh([live.first.copyWith(lease: null)], _at), isTrue);
      final master = ChzzkMedia('HLS', Uri.parse('https://live.akamaized.net/m.m3u8?hdnts=st=0~exp=${_expiry(600)}'));
      expect(ChzzkPlayParser.mastersFresh([master], _at), isFalse);
      expect(
        ChzzkPlayParser.mastersFresh([ChzzkMedia('HLS', Uri.parse('https://live.akamaized.net/m.m3u8'))], _at),
        isTrue,
      );
    });
  });

  group('chat protocol', () {
    test('the token, routing and live-status answers match their shapes', () {
      expect(
        ChzzkDanmakuCodec.accessToken(
          _decoded({
            'code': 200,
            'content': {'accessToken': 'tk'},
          }),
        ),
        'tk',
      );
      expect(
        ChzzkDanmakuCodec.accessToken(
          _decoded({
            'code': 200,
            'content': {'accessToken': ''},
          }),
        ),
        isNull,
      );
      expect(ChzzkDanmakuCodec.accessToken(_decoded({'code': 50001})), isNull);
      expect(ChzzkDanmakuCodec.accessToken(null), isNull);
      expect(
        ChzzkDanmakuCodec.servers(
          _decoded({
            'code': 200,
            'result': {
              'sessionServerList': [
                'kr-ss1.chat.naver.com',
                'kr-ss1.chat.naver.com',
                'kr-ss6.chat.naver.com',
                'a.b.chat.naver.com',
                'evil.test',
                17,
              ],
            },
          }),
        ),
        ['kr-ss1.chat.naver.com', 'kr-ss6.chat.naver.com'],
      );
      expect(
        ChzzkDanmakuCodec.servers(
          _decoded({
            'code': 200,
            'result': {'sessionServerList': <Object?>[]},
          }),
        ),
        isNull,
      );
      expect(ChzzkDanmakuCodec.servers(null), isNull);
      expect(
        ChzzkDanmakuCodec.liveChatChannel(
          _decoded({
            'code': 200,
            'content': {'status': 'OPEN', 'chatChannelId': _chat},
          }),
        ),
        _chat,
      );
      expect(
        ChzzkDanmakuCodec.liveChatChannel(
          _decoded({
            'code': 200,
            'content': {'status': 'CLOSE', 'chatChannelId': _chat},
          }),
        ),
        isNull,
      );
      expect(
        ChzzkDanmakuCodec.liveChatChannel(
          _decoded({
            'code': 200,
            'content': {'status': 'OPEN'},
          }),
        ),
        isNull,
      );
      for (final id in ['N2l-x_', 'N2l_uf', 'a']) {
        expect(ChzzkDanmakuCodec.isChatChannelId(id), isTrue, reason: id);
      }
      for (final id in ['', 'bad id', 'a' * 65, 'a.b']) {
        expect(ChzzkDanmakuCodec.isChatChannelId(id), isFalse, reason: id);
      }
      expect(ChzzkDanmakuCodec.endpoints(['a', 'b', 'c'], 1).map((uri) => uri.host), ['b', 'c', 'a']);
      expect(ChzzkDanmakuCodec.endpoints(['a'], 0).single, Uri.parse('wss://a/chat'));
    });

    test('the join, recent and ping frames are the SDK’s own', () {
      expect(jsonDecode(ChzzkDanmakuCodec.join(_chat, 'tk')), {
        'ver': '3',
        'cmd': 100,
        'svcid': 'game',
        'cid': _chat,
        'bdy': {'uid': null, 'devType': 2001, 'accTkn': 'tk', 'auth': 'READ'},
        'tid': 1,
      });
      expect(jsonDecode(ChzzkDanmakuCodec.recent(_chat, 'sid-1')), {
        'ver': '3',
        'cmd': 5101,
        'svcid': 'game',
        'cid': _chat,
        'sid': 'sid-1',
        'bdy': {'recentMessageCount': 50},
        'tid': 2,
      });
      expect(ChzzkDanmakuCodec.ping, '{"ver":"3","cmd":0}');
      expect(ChzzkDanmakuCodec.pong, '{"ver":"3","cmd":10000}');
    });

    test('a frame is text or bytes and junk costs only that frame', () {
      expect(ChzzkDanmakuCodec.decode('{"cmd":0}').ping, isTrue);
      expect(ChzzkDanmakuCodec.decode(utf8.encode('{"cmd":0}')).ping, isTrue);
      expect(ChzzkDanmakuCodec.decode('nope').messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode('[1,2]').messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode(null).messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode('{"cmd":99999}').messages, isEmpty);
      for (final cmd in [10000, 93006, 94005, 94015]) {
        expect(ChzzkDanmakuCodec.decode(_frame(cmd, {'x': 1})).messages, isEmpty, reason: '$cmd');
      }
    });

    test('the join answer decides joined, refused and retry', () {
      final joined = ChzzkDanmakuCodec.decode(_frame(10100, {'sid': 's1'}, code: 0));
      expect(joined.joined, isTrue);
      expect(joined.sessionId, 's1');
      expect(ChzzkDanmakuCodec.decode(_frame(10100, 'no map', code: 0)).sessionId, isEmpty);
      final refused = ChzzkDanmakuCodec.decode(_json({'cmd': 10100, 'retCode': 105, 'retMsg': 'Incorrect parameter'}));
      expect(refused.joined, isFalse);
      expect(refused.refusal, '105 Incorrect parameter');
      expect(refused.retry, isFalse);
      for (final code in [302, 303, 304]) {
        expect(ChzzkDanmakuCodec.decode(_json({'cmd': 10100, 'retCode': code})).retry, isTrue, reason: '$code');
      }
      expect(ChzzkDanmakuCodec.decode(_json({'cmd': 10100, 'retCode': 301})).retry, isFalse);
      // A join answer that names no code refused.
      expect(ChzzkDanmakuCodec.decode('{"cmd":10100}').joined, isFalse);
      expect(ChzzkDanmakuCodec.decode('{"cmd":90102}').closed, isTrue);
    });

    test('a pushed line reads its live names and a recent line its own', () {
      final live = ChzzkDanmakuCodec.decode(_frame(93101, [_liveLine(profile: '{"nickname":"Ann"}')]));
      expect(live.pushed, isTrue);
      final message = live.messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hi');
      expect(message.effectiveSender.userId, 'u1');
      expect(message.effectiveSender.userName, 'Ann');
      expect(message.messageId, 'u1:1759000000000');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1759000000000));
      expect(message.color, LiveMessageColor.white);
      final recent = ChzzkDanmakuCodec.decode(
        _frame(15101, {
          'messageList': [
            {'content': 'hi', 'userId': 'u1', 'messageTime': '1759000000000'},
          ],
        }, code: 0),
      );
      expect(recent.messages.single.text, 'hi');
      expect(recent.messages.single.messageId, 'u1:1759000000000');
      expect(recent.pushed, isFalse);
      expect(
        ChzzkDanmakuCodec.decode(_frame(93102, [_liveLine(msg: 'own')])),
        isA<ChzzkDanmakuFrame>().having((f) => f.pushed, 'pushed', true),
      );
    });

    test('a hidden line is not shown and an unknown type gives nothing', () {
      for (final status in ['BLIND', 'CBOTBLIND', 'HIDDEN']) {
        expect(ChzzkDanmakuCodec.decode(_frame(93101, [_liveLine(status: status)])).messages, isEmpty, reason: status);
      }
      for (final type in [13, 15, 99]) {
        expect(ChzzkDanmakuCodec.decode(_frame(93101, [_liveLine(type: type)])).messages, isEmpty, reason: '$type');
      }
      expect(ChzzkDanmakuCodec.decode(_frame(93101, [_liveLine(msg: '   ')])).messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode(_frame(93101, ['not an object'])).messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode(_frame(93101, 'not a list')).messages, isEmpty);
    });

    test('a line without a usable time shows without an id or a stamp', () {
      final messages = ChzzkDanmakuCodec.decode(
        _frame(93101, [_liveLine(time: 0), _liveLine(msg: 'older', uid: 'u2', time: 8640000000000001)]),
      ).messages;
      expect(messages, hasLength(2));
      expect(messages.first.messageId, isEmpty);
      expect(messages.first.sentAt, isNull);
      expect(messages.last.messageId, isEmpty);
    });

    test('an emoji code is matched to the line’s own picture table', () {
      final message = ChzzkDanmakuCodec.decode(
        _frame(93101, [
          _liveLine(
            msg: 'hi {:a:} {:b:} {:a:} {:gone:} {:no-table:}',
            extras: {
              'emojis': {
                'a': 'https://pstatic.net/a.png',
                'b': 'not a url',
                'gone': 'https://pstatic.net/g.png',
                'unused': 'https://pstatic.net/u.png',
              },
            },
          ),
        ]),
      ).messages.single;
      // In the order of the text, once each, only those the table names with a
      // picture; a table entry no code uses shows nowhere.
      expect(message.emotes.map((emote) => emote.code), ['{:a:}', '{:gone:}']);
      expect(message.emotes.map((emote) => emote.url), ['https://pstatic.net/a.png', 'https://pstatic.net/g.png']);
      // The code stays in the text, as the site's own list keeps it.
      expect(message.text, 'hi {:a:} {:b:} {:a:} {:gone:} {:no-table:}');
    });

    test('a subscription is a notice and its text as chat', () {
      final messages = ChzzkDanmakuCodec.decode(
        _frame(93102, [
          _liveLine(
            msg: 'greetings',
            type: 11,
            profile: {'nickname': 'Ann'},
            extras: {'tierName': '나나양 좋아', 'month': 32},
          ),
        ]),
      ).messages;
      expect(messages, hasLength(2));
      final notice = messages.first;
      expect(notice.type, LiveMessageType.notice);
      expect(notice.text, 'Ann 订阅了「나나양 좋아」，已订阅 32 个月');
      expect(notice.payload, LiveNoticeKind.subscription);
      expect(notice.messageId, 'subscription:u1:1759000000000');
      expect(messages.last.type, LiveMessageType.chat);
      expect(messages.last.messageId, 'u1:1759000000000');
    });

    test('a subscription falls back to the extras name, the channel and no months', () {
      LiveMessage noticeOf(Map<String, Object?> line) => ChzzkDanmakuCodec.decode(_frame(93102, [line])).messages.first;
      expect(noticeOf(_liveLine(type: 11, extras: {'nickname': 'Bea'})).text, 'Bea 订阅了频道');
      expect(noticeOf(_liveLine(type: 11, profile: {'nickname': 'Ann'}, extras: {'month': 0})).text, 'Ann 订阅了频道');
      expect(noticeOf(_liveLine(type: 11, uid: '', profile: {'nickname': 'Ann'})).messageId, isEmpty);
    });

    test('a donation is a super chat of cheese, named or anonymous', () {
      final message = ChzzkDanmakuCodec.decode(
        _frame(93102, [
          _liveLine(
            msg: 'for you',
            type: 10,
            profile: {'nickname': 'Ann', 'profileImageUrl': 'https://pstatic.net/a.png'},
            extras: {'payAmount': '12000'},
          ),
        ]),
      ).messages.single;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, 'for you');
      expect(message.effectiveSender.userName, 'Ann');
      final superChat = message.payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, 12000);
      expect(superChat.price.currency, ChzzkDanmakuCodec.cheeseCurrency);
      expect(superChat.price.displayText, '12,000 치즈');
      expect(superChat.faceUrl, 'https://pstatic.net/a.png');
      expect(superChat.userName, 'Ann');
      expect(superChat.messageId, 'u1:1759000000000');
      expect(superChat.endTime!.difference(superChat.startTime!), const Duration(minutes: 2));
      final anonymous = ChzzkDanmakuCodec.decode(
        _frame(93102, [
          _liveLine(uid: 'anonymous', type: 10, extras: {'payAmount': 40000, 'isAnonymous': true}),
        ]),
      ).messages.single;
      expect(anonymous.effectiveSender.userName, ChzzkDanmakuCodec.anonymousDonor);
      expect(anonymous.effectiveSender.userId, isEmpty);
      expect(anonymous.messageId, 'anonymous:1759000000000');
    });

    test('a donation without a time starts now and one with neither field is dropped', () {
      final received = DateTime.utc(2026, 10);
      final message = ChzzkDanmakuCodec.decode(
        _frame(93102, [
          _liveLine(time: null, msg: 'thanks', type: 10, extras: {'payAmount': 5}),
        ]),
        receivedAt: received,
      ).messages.single;
      final superChat = message.payload! as LiveSuperChatMessage;
      expect(superChat.startTime, received);
      expect(message.sentAt, isNull);
      expect(ChzzkDanmakuCodec.decode(_frame(93102, [_liveLine(msg: '', type: 10)])).messages, isEmpty);
      expect(
        (ChzzkDanmakuCodec.decode(_frame(93102, [_liveLine(msg: 'x', type: 10)])).messages.single.payload!
                as LiveSuperChatMessage)
            .price
            .amount,
        isNull,
      );
    });

    test('the super chat tiers follow the site’s five donation styles', () {
      expect(ChzzkDanmakuCodec.superChatDuration(0), const Duration(minutes: 1));
      expect(ChzzkDanmakuCodec.superChatDuration(9999), const Duration(minutes: 1));
      expect(ChzzkDanmakuCodec.superChatDuration(10000), const Duration(minutes: 2));
      expect(ChzzkDanmakuCodec.superChatDuration(100000), const Duration(minutes: 5));
      expect(ChzzkDanmakuCodec.superChatDuration(500000), const Duration(minutes: 30));
      expect(ChzzkDanmakuCodec.superChatDuration(1000000), const Duration(hours: 1));
      expect(ChzzkDanmakuCodec.cheeseText(1234567), '1,234,567 치즈');
      expect(ChzzkDanmakuCodec.cheeseText(0), '0 치즈');
    });

    test('a subscription gift names its giver, tier and receiver', () {
      LiveMessage giftOf(Map<String, Object?> extras, {Object? profile = const {'nickname': 'Giver'}}) =>
          ChzzkDanmakuCodec.decode(_frame(93102, [_liveLine(type: 12, profile: profile, extras: extras)]))
              .messages
              .single;
      final toChannel = giftOf({'giftType': 'SUBSCRIPTION_GIFT', 'quantity': 5, 'giftTierName': '팬'});
      expect(toChannel.payload, LiveNoticeKind.giftedSubscription);
      expect(toChannel.text, 'Giver 向频道赠送了 5 张「팬」订阅券');
      final toViewer = giftOf({'receiverNickname': 'Bea', 'giftTierName': '팬'});
      expect(toViewer.text, 'Giver 向 Bea 赠送了「팬」订阅券');
      expect(giftOf({'giftType': 'SUBSCRIPTION_GIFT'}).text, 'Giver 向频道赠送了订阅券');
      expect(giftOf({'giftType': 'X', 'quantity': 2}).text, 'Giver 赠送了订阅券');
      expect(
        giftOf({'giftType': 'SUBSCRIPTION_GIFT', 'anonymousToken': 'a'}).effectiveSender.userName,
        ChzzkDanmakuCodec.anonymousDonor,
      );
      expect(
        giftOf({'receiverNickname': 'Bea'}, profile: null).effectiveSender.userName,
        ChzzkDanmakuCodec.anonymousDonor,
      );
    });

    test('a system line joins the site’s title and description, and skips staff-only lines', () {
      final shown = ChzzkDanmakuCodec.decode(
        _frame(93102, [
          _liveLine(msg: '이모티콘 모드 ON', type: 30, extras: {'description': '설명'}),
        ]),
      ).messages.single;
      expect(shown.payload, LiveNoticeKind.system);
      expect(shown.text, '이모티콘 모드 ON：설명');
      final descriptionOnly = ChzzkDanmakuCodec.decode(
        _frame(93102, [
          _liveLine(msg: '', type: 30, extras: {'description': '설명'}),
        ]),
      ).messages.single;
      expect(descriptionOnly.text, '설명');
      final rolesEmpty = ChzzkDanmakuCodec.decode(
        _frame(93102, [
          _liveLine(msg: 'x', type: 30, extras: {'visibleRoles': <Object?>[]}),
        ]),
      ).messages;
      expect(rolesEmpty, hasLength(1));
      expect(
        ChzzkDanmakuCodec.decode(
          _frame(93102, [
            _liveLine(
              msg: 'x',
              type: 30,
              extras: {
                'visibleRoles': ['MASTER'],
              },
            ),
          ]),
        ).messages,
        isEmpty,
      );
      expect(ChzzkDanmakuCodec.decode(_frame(93102, [_liveLine(msg: '', type: 30)])).messages, isEmpty);
    });

    test('the pinned notice says whose line it pins, with its own id and no time', () {
      Map<String, Object?> notice({
        String? pinner,
        String? author = 'Ann',
        String pinnHash = 'h2',
        String authorHash = 'h1',
      }) => {
        'content': 'pinned text',
        'userId': 'u1',
        'messageTime': 1759000000000,
        if (author != null) 'profile': {'nickname': author, 'userIdHash': authorHash},
        'extras': {
          if (pinner != null) 'registerProfile': {'nickname': pinner, 'userIdHash': pinnHash},
        },
      };
      final byOther = ChzzkDanmakuCodec.decode(_frame(94010, notice(pinner: 'Mod'))).messages.single;
      expect(byOther.text, 'Mod 置顶了 Ann 的消息：pinned text');
      expect(byOther.messageId, 'notice:u1:1759000000000');
      expect(byOther.sentAt, isNull);
      expect(byOther.type, LiveMessageType.notice);
      expect(
        ChzzkDanmakuCodec.decode(_frame(94010, notice(pinner: 'Ann', pinnHash: 'h1'))).messages.single.text,
        'Ann 置顶了消息：pinned text',
      );
      expect(ChzzkDanmakuCodec.decode(_frame(94010, notice(author: null))).messages.single.text, '置顶消息：pinned text');
      for (final bad in [
        {'content': 'x'},
        {'content': 'x', 'messageTime': 0},
        {'content': '', 'messageTime': 1},
      ]) {
        expect(ChzzkDanmakuCodec.decode(_frame(94010, bad)).messages, isEmpty, reason: '$bad');
      }
    });

    test('the recent chat answers with its lines, then the pinned one', () {
      final messages = ChzzkDanmakuCodec.decode(
        _frame(15101, {
          'messageList': [
            {'content': 'a line', 'userId': 'u9', 'messageTime': 1759000000000},
          ],
          'notice': {
            'content': 'pinned',
            'userId': 'u1',
            'messageTime': 1759000000001,
            'profile': {'nickname': 'Ann'},
          },
        }, code: 0),
      ).messages;
      expect(messages.map((message) => message.text), ['a line', 'Ann 置顶了消息：pinned']);
      expect(ChzzkDanmakuCodec.decode(_frame(15101, {'messageList': <Object?>[]}, code: 1)).messages, isEmpty);
    });

    test('a blinded line is retracted and a cancelled one is left alone', () {
      final blind = ChzzkDanmakuCodec.decode(
        _frame(94008, {'userId': 'u1', 'messageTime': 1759000000000, 'blindType': 'BLIND'}),
      ).messages.single;
      expect(blind.type, LiveMessageType.retraction);
      expect((blind.payload! as LiveRetraction).messageId, 'u1:1759000000000');
      expect(blind.messageId, isEmpty);
      for (final type in ['CBOTBLIND', 'HIDDEN', null]) {
        expect(
          ChzzkDanmakuCodec.decode(_frame(94008, {'userId': 'u1', 'messageTime': 1, 'blindType': ?type})).messages,
          hasLength(1),
          reason: '$type',
        );
      }
      for (final bad in [
        {'userId': 'u1', 'messageTime': 1, 'blindType': 'CANCEL'},
        {'messageTime': 1},
        {'userId': 'u1'},
        {'userId': 'u1', 'messageTime': 0},
      ]) {
        expect(ChzzkDanmakuCodec.decode(_frame(94008, bad)).messages, isEmpty, reason: '$bad');
      }
    });
  });

  group('adapter wiring', () {
    test('the capabilities are wired and the ones chzzk has are not', () {
      final site = _adapter((_) => _resp(200, '{}')).site;
      expect(site.manifest.id, 'chzzk');
      expect(site.manifest.localizedName('zh-CN', 'en-US'), 'CHZZK');
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveHotProvider>(), isNull);
      expect(site.capability<LiveAnchorProvider>(), isNull);
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
    });

    test('a room read is the channel and its live, and carries both handles', () async {
      final adapter = _adapter((request) {
        if (request.url.path.endsWith('/live-detail')) {
          return _resp(200, _liveDetail(playback: _playback([_mediaItem()])));
        }
        return _resp(200, _answer(_channelData()));
      });
      final room = await adapter.site.detail(' $_channel ');
      expect(room.roomId, _channel);
      expect(room.broadcast.isLiveNow, isTrue);
      expect(room.runtime.streamHandle, isA<ChzzkRoomData>());
      expect((room.runtime.streamHandle! as ChzzkRoomData).media.single.id, 'HLS');
      expect((room.runtime.danmakuHandle! as ChzzkDanmakuArgs).chatChannelId, _chat);
      expect(adapter.http.sent.map((request) => request.url.path), [
        '/service/v1/channels/$_channel',
        '/service/v3.1/channels/$_channel/live-detail',
      ]);
      expect(adapter.http.sent.first.headers['user-agent'], ChzzkEndpoints.userAgent);
      expect(adapter.http.sent.first.headers['accept'], 'application/json, text/plain, */*');
      expect(adapter.http.sent.first.headers['referer'], 'https://chzzk.naver.com/');
    });

    test('an id that is not a channel id is refused before any request', () async {
      final adapter = _adapter((_) => _resp(200, '{}'));
      await expectLater(adapter.site.detail('not-an-id'), throwsA(isA<ChzzkFailure>()));
      await expectLater(adapter.site.detail(_channel.substring(0, 20)), throwsA(isA<ChzzkFailure>()));
      expect(adapter.http.sent, isEmpty);
    });

    test('the list is one request per cursor and a walk per page number', () async {
      var asks = 0;
      final adapter = _adapter((request) {
        asks += 1;
        final after = request.url.queryParameters['liveId'];
        final base = after == null ? 0 : int.parse(after);
        return _resp(
          200,
          _lives([
            for (var i = 1; i <= 3; i++) _liveRow(channelId: _hexId(base + i), liveId: base + i, viewers: 100 - i),
          ], next: base < 6 ? {'concurrentUserCount': 100, 'liveId': base + 3} : null),
        );
      });
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.items, hasLength(3));
      expect(first.hasMore, isTrue);
      expect(asks, 1);
      final second = _right(await rooms.getRooms(LivePageRequest(cursor: first.nextCursor)));
      expect(second.items.map((room) => room.roomId), [_hexId(4), _hexId(5), _hexId(6)]);
      expect(asks, 2);
      // A page number is walked from the first page: that many requests, and a
      // channel already shown is not repeated.
      asks = 0;
      final third = _right(await rooms.getRooms(const LivePageRequest(page: 3)));
      expect(asks, 3);
      expect(third.items, hasLength(3));
      expect(third.items.map((room) => room.roomId), contains(_hexId(7)));
    });

    test('a walk that ends early gives an empty page, and a bad argument no request', () async {
      var asks = 0;
      final adapter = _adapter((_) {
        asks += 1;
        return _resp(200, _lives([_liveRow()]));
      });
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final page = _right(await rooms.getRooms(const LivePageRequest(page: 4)));
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(asks, 1);
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(page: 21))), isA<LiveSiteInvalidArgument>());
      expect(_leftOf(await rooms.getRooms(const LivePageRequest(cursor: 'nope'))), isA<LiveSiteInvalidArgument>());
      expect(asks, 1);
    });

    test('the catalog is read once and its types name the area pages', () async {
      var asks = 0;
      final adapter = _adapter((request) {
        asks += 1;
        if (request.url.path.endsWith('/lives')) return _resp(200, _lives([_liveRow()]));
        return _resp(
          200,
          _answer({
            'data': [
              {'categoryType': 'GAME', 'categoryId': 'LoL', 'categoryValue': '리그 오브 레전드'},
              {'categoryType': 'ETC', 'categoryId': 'etc1', 'categoryValue': '기타'},
            ],
            'page': {'next': <String, Object?>{}},
          }),
        );
      });
      final areas = adapter.site.capability<LiveAreaProvider>()!;
      final list = _right(await areas.getAreas());
      expect(list.map((area) => area.areaId), ['LoL', 'etc1']);
      expect(list.first.parentAreaName, '游戏');
      final before = asks;
      final rooms = _right(await areas.getAreaRooms(areaId: 'LoL'));
      expect(rooms.items, hasLength(1));
      expect(asks, before + 1);
      expect(adapter.http.sent.last.url.path, '/service/v2/categories/GAME/LoL/lives');
      expect(adapter.http.sent.last.url.query, contains('size=30'));
      expect(_leftOf(await areas.getAreaRooms(areaId: 'no-such-area')), isA<LiveSiteInvalidArgument>());
      expect(_leftOf(await areas.getAreaRooms(areaId: 'a b')), isA<LiveSiteInvalidArgument>());
      // The types the first read cached name the areas: an unknown id asks
      // for nothing more.
      expect(asks, before + 1);
    });

    test('an area of a site that never read the catalog is looked up once', () async {
      var catalog = 0;
      final adapter = _adapter((request) {
        if (request.url.path.endsWith('/categories/live')) {
          catalog++;
          return _resp(
            200,
            _answer({
              'data': [
                {'categoryType': 'GAME', 'categoryId': 'LoL', 'categoryValue': '리그 오브 레전드'},
              ],
              'page': {'next': <String, Object?>{}},
            }),
          );
        }
        return _resp(200, _lives([_liveRow()]));
      });
      final areas = adapter.site.capability<LiveAreaProvider>()!;
      expect(_right(await areas.getAreaRooms(areaId: 'LoL')).items, hasLength(1));
      expect(catalog, 1);
      expect(_leftOf(await areas.getAreaRooms(areaId: 'nope')), isA<LiveSiteInvalidArgument>());
      expect(catalog, 1);
    });

    test('the search page is the platform’s own, by offset, cut to its limit', () async {
      final adapter = _adapter(
        (_) => _resp(
          200,
          _answer({
            'data': [
              {'channel': _channelData()},
            ],
          }),
        ),
      );
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      final page = _right(await search.search(const LiveSearchRequest(query: ' Ann ', target: LiveSearchTarget.rooms)));
      final hit = page.items.single as RoomSearchResult;
      expect(hit.room.roomId, _channel);
      expect(hit.room.content.title, 'Ann');
      expect(adapter.http.sent.single.url.queryParameters, {'keyword': 'Ann', 'offset': '0', 'size': '20'});
      await search.search(const LiveSearchRequest(query: 'ann', target: LiveSearchTarget.rooms, page: 3));
      expect(adapter.http.sent.last.url.queryParameters['offset'], '40');
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'ann', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '  ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, page: 60001))),
        isA<LiveSiteInvalidArgument>(),
      );
      await search.search(LiveSearchRequest(query: '👍' * 60, target: LiveSearchTarget.rooms));
      expect(adapter.http.sent.last.url.queryParameters['keyword']!.length, lessThanOrEqualTo(100));
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
    });

    test('qualities take the two masters and lines reuse them while fresh', () async {
      var asks = 0;
      final adapter = _adapter((request) {
        final path = request.url.path;
        if (path.endsWith('/live-detail')) {
          asks += 1;
          return _resp(
            200,
            _liveDetail(
              playback: _playback([
                _mediaItem(),
                _mediaItem(
                  mediaId: 'LLHLS',
                  path: 'https://llive.akamaized.net/LLHLS/master.m3u8?hdnts=st=0~exp=${_expiry()}',
                ),
              ]),
            ),
          );
        }
        if (path.endsWith('/channels/$_channel')) return _resp(200, _answer(_channelData()));
        asks += 1;
        // Each master lists its own addresses: the same qualities, twice.
        final host = path.contains('/LLHLS/') ? 'https://llive.akamaized.net' : 'https://live.akamaized.net';
        return _resp(200, _threeVariants(host: host, token: 'hdntl=exp=${_expiry(7200)}~acl=*'));
      });
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _channel));
      expect(qualities.map((quality) => quality.qualityId), ['1080p60', '720p60', '480p']);
      // The room's two requests, then both masters.
      expect(asks, 3);
      final lines = _right(await playback.getLines(roomId: _channel, quality: qualities.first));
      expect(lines.map((line) => line.lineLabel), ['HLS', 'LLHLS']);
      expect(asks, 3);
      expect(
        _leftOf(
          await playback.getLines(
            roomId: _channel,
            quality: const LivePlayQuality(label: 'x', qualityId: '2160p'),
          ),
        ),
        isA<LiveSiteContentUnavailable>(),
      );
      final defaultLines = _right(await playback.getLines(roomId: _channel));
      expect(defaultLines, hasLength(6));
    });

    test("a walk past a token's life takes the room again", () async {
      var asks = 0;
      var masters = 0;
      final clock = [_at];
      final adapter = _adapter((request) {
        final path = request.url.path;
        if (path.endsWith('/live-detail')) {
          asks += 1;
          return _resp(200, _liveDetail(playback: _playback([_mediaItem()])));
        }
        if (path.endsWith('/channels/$_channel')) return _resp(200, _answer(_channelData()));
        masters += 1;
        // The variant token dies an hour after issue.
        return _resp(
          200,
          _threeVariants(host: 'https://live.akamaized.net', token: 'hdntl=exp=${_expiry(3600)}~acl=*'),
        );
      }, now: () => clock.first);
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      _right(await playback.getQualities(roomId: _channel));
      expect((asks, masters), (1, 1));
      _right(await playback.getQualities(roomId: _channel));
      expect((asks, masters), (1, 1));
      // Past the renewal point the masters are read again, the room is not.
      clock[0] = _at.add(const Duration(hours: 4));
      _right(await playback.getQualities(roomId: _channel));
      expect((asks, masters), (1, 2));
      // Past the master token the room is entered again for new masters.
      clock[0] = _at.add(const Duration(days: 3));
      _right(await playback.getLines(roomId: _channel));
      expect((asks, masters), (2, 3));
    });

    test('a room that cannot be played names why, without reading a master', () async {
      final details = {
        'offline': _liveDetail(status: 'CLOSE', chatChannelId: null),
        'region': _liveDetail(krOnly: true),
        'blind': _liveDetail(blindType: 'ABROAD'),
        'paid': _liveDetail(),
      };
      for (final entry in details.entries) {
        final adapter = _adapter(
          (request) => request.url.path.endsWith('/live-detail')
              ? _resp(200, entry.value)
              : _resp(200, _answer(_channelData(openLive: false))),
        );
        expect(
          _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
          isA<LiveSiteContentUnavailable>(),
          reason: entry.key,
        );
        expect(
          adapter.http.sent.where((request) => request.url.host == 'live.akamaized.net'),
          isEmpty,
          reason: entry.key,
        );
      }
      final adult = _adapter(
        (request) => request.url.path.endsWith('/live-detail')
            ? _resp(200, _liveDetail(adult: true))
            : _resp(200, _answer(_channelData())),
      );
      expect(
        _leftOf(await adult.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteAuthenticationError>(),
      );
    });

    test('a master that is gone is content-unavailable and a bad shape a parse error', () async {
      ChzzkSite answerWith(String masterBody) => _adapter((request) {
        final path = request.url.path;
        if (path.endsWith('/live-detail')) return _resp(200, _liveDetail(playback: _playback([_mediaItem()])));
        if (path.endsWith('/channels/$_channel')) return _resp(200, _answer(_channelData()));
        return _resp(200, masterBody);
      }).site;
      expect(
        _leftOf(
          await answerWith('<html>nope</html>').capability<LivePlaybackProvider>()!.getQualities(roomId: _channel),
        ),
        isA<LiveSiteParseError>(),
      );
      final gone = _adapter((request) {
        final path = request.url.path;
        if (path.endsWith('/live-detail')) return _resp(200, _liveDetail(playback: _playback([_mediaItem()])));
        if (path.endsWith('/channels/$_channel')) return _resp(200, _answer(_channelData()));
        return _resp(404, 'gone');
      });
      expect(
        _leftOf(await gone.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _channel)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a bad status is the error the platform means', () async {
      ChzzkSite failing(int status) => _adapter(
        (request) => request.url.path.endsWith('/channels/$_channel')
            ? _resp(status, '{}')
            : _resp(200, _answer(_channelData())),
      ).site;
      expect(
        _leftOf(await failing(500).capability<LiveRoomProvider>()!.getRoom(_channel)),
        isA<LiveSiteNetworkError>(),
      );
      expect(
        _leftOf(await failing(401).capability<LiveRoomProvider>()!.getRoom(_channel)),
        isA<LiveSiteRateLimitError>(),
      );
      expect(_leftOf(await failing(404).capability<LiveRoomProvider>()!.getRoom(_channel)), isA<LiveSiteNotFound>());
      expect(
        _leftOf(await failing(429).capability<LiveRoomProvider>()!.getRoom(_channel)),
        isA<LiveSiteRateLimitError>(),
      );
      final refused = _adapter((_) => _resp(200, _refused(code: 9004)));
      expect(_leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom(_channel)), isA<LiveSiteParseError>());
    });

    test('the link resolver canonicalizes a channel page and refuses everything else', () async {
      final resolver = _adapter((_) => _resp(200, '{}')).site.capability<LiveLinkResolver>()!;
      expect(
        _right(await resolver.resolve(Uri.parse('https://chzzk.naver.com/$_channel/videos'))),
        Uri.parse('https://chzzk.naver.com/live/$_channel'),
      );
      expect(
        _leftOf(await resolver.resolve(Uri.parse('https://chzzk.naver.com/video/12345'))),
        isA<LiveSiteNotFound>(),
      );
      expect(
        _leftOf(await resolver.resolve(Uri.parse('https://m.chzzk.naver.com/live/$_channel'))),
        isA<LiveSiteUnsupported>(),
      );
    });

    test('a chat session is refused for a room the platform gives no chat to', () async {
      final site = _adapter(
        (request) => request.url.path.endsWith('/live-detail')
            ? _resp(200, _liveDetail(status: 'CLOSE', chatChannelId: null))
            : _resp(200, _answer(_channelData(openLive: false))),
      ).site;
      expect(
        _leftOf(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: _channel)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('the discovery feed is the same cursor list', () async {
      final adapter = _adapter((_) => _resp(200, _lives([_liveRow()])));
      final page = _right(await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(page.items, hasLength(1));
      expect(page.hasMore, isFalse);
      expect(adapter.http.sent.single.url.path, '/service/v1/lives');
      expect(adapter.http.sent.single.url.queryParameters, {'size': '30'});
    });
  });
}

/// Whether a live detail reports itself open (named for the tests that read it
/// twice).
bool isLiveOf(ChzzkLive live) => live.isLive;

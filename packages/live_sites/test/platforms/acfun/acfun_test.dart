import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

// The test doubles spell their class name in their one constructor; the
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_http.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_codec.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_session.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_play_parser.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_room_parser.dart';
import 'package:test/test.dart';

const _author = '12345678';

/// The request the fake transport answered.
typedef _Seen = ({String method, Uri url, Map<String, String> headers, String body});

/// Answers every request from [onSend] and records each one.
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

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

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

/// The JSON of one answer.
String _json(Map<String, Object?> data) => jsonEncode(data);

/// A site over [onSend] with an injected clock and random source.
AcfunSite _site(LiveResponse Function(_Seen request) onSend) =>
    AcfunSite(http: AcfunHttp(_FakeHttp(onSend)), now: () => DateTime(2026), random: Random(1));

T _right<T>(Either<Object?, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _left(Either<LiveSiteError, Object?> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $right'));

/// Fails with [kind].
Matcher _fails(AcfunFailureKind kind) => predicate((value) => value is AcfunFailure && value.kind == kind);

/// The visitor session every playback call needs.
Map<String, dynamic> _login({String security = 'czV4cG9ydWVrZXkzMjE0' /* 16 bytes */}) => {
  'result': 0,
  'userId': '99887766',
  'acfun.api.visitor_st': 'VISITOR-TOKEN',
  'acSecurity': security,
};

/// A `startPlay` answer for a live broadcast with two CDN manifests.
Map<String, dynamic> _startPlay({String liveId = '5555'}) => {
  'result': 1,
  'data': {
    'liveId': liveId,
    'liveStartTime': 1760000000000,
    'enterRoomAttach': 'ATTACH',
    'availableTickets': ['T1', 'T2'],
    'videoPlayRes': jsonEncode({
      'liveAdaptiveManifest': [
        {
          'adaptationSet': {
            'representation': [
              {
                'id': 1,
                'name': '蓝光 8M',
                'qualityType': 'SUPER',
                'level': 4,
                'bitrate': 8000,
                'url': 'https://cdn-a/live.flv?auth_key=1790000000-0-0-sign',
              },
              {
                'id': 2,
                'qualityType': 'STANDARD',
                'bitrate': 2000,
                'url': 'https://cdn-b/live.m3u8?auth_key=1790000000-0-0-sign',
              },
              {'id': 3, 'qualityType': 'STANDARD', 'bitrate': 2000, 'hidden': true, 'url': 'https://cdn-c/hidden.flv'},
              {'id': 4, 'qualityType': 'HIGH', 'bitrate': 4000, 'url': 'ftp://cdn-d/nope.flv'},
            ],
          },
        },
        {
          'adaptationSet': {
            'representation': [
              {
                'id': 5,
                'qualityType': 'SUPER',
                'level': 4,
                'bitrate': 9000,
                'url': 'https://cdn-e/live.flv?auth_key=1790000000-0-0-sign',
              },
            ],
          },
        },
      ],
    }),
  },
};

Map<String, dynamic> _info({String liveId = '5555', Object? paid}) => {
  'result': 0,
  'authorId': _author,
  'liveId': liveId,
  'title': '直播标题',
  'createTime': 1760000000000,
  'onlineCount': 1234,
  'coverUrls': ['https://cn/cover.jpg'],
  'user': {
    'id': _author,
    'name': '主播',
    'headUrl': '//cn/avatar.jpg',
    'signature': '签名&amp;注释',
    'fanCountValue': '353.9万',
  },
  'type': {'id': '7', 'name': '手游'},
  'paidShowUuid': ?paid,
};

void main() {
  group('endpoints', () {
    test('the directory always sends pcursor, and only sends filters when given', () {
      expect(AcfunEndpoints.channelList(count: 30).query, 'count=30&pcursor');
      final filters = AcfunEndpoints.channelList(count: 60, cursor: 'c1', filters: '[{"filterType":1,"filterId":9}]');
      expect(filters.queryParameters['pcursor'], 'c1');
      expect(filters.queryParameters['filters'], '[{"filterType":1,"filterId":9}]');
    });

    test('the kuaishou-backed calls carry the session as query parameters', () {
      const visitor = AcfunVisitor(userId: '99', deviceId: 'web_x', token: 'ST');
      expect(AcfunEndpoints.startPlay(visitor).queryParameters, {
        'subBiz': 'mainApp',
        'kpn': 'ACFUN_APP',
        'kpf': 'PC_WEB',
        'userId': '99',
        'did': 'web_x',
        'acfun.api.visitor_st': 'ST',
      });
      expect(AcfunEndpoints.giftList(visitor).path, '/rest/zt/live/web/gift/list');
    });

    test('an author id is a positive number of at most 20 digits', () {
      expect(AcfunEndpoints.isAuthorId('12345678'), isTrue);
      expect(AcfunEndpoints.isAuthorId('01234567'), isFalse);
      expect(AcfunEndpoints.isAuthorId('0'), isFalse);
      expect(AcfunEndpoints.isAuthorId(''), isFalse);
      expect(AcfunEndpoints.deviceId(Random(1)), startsWith('web_'));
      expect(AcfunEndpoints.deviceId(Random(1)), hasLength(20));
    });
  });

  group('room parsing', () {
    test('a card carries the author, the audience and the paid restriction', () {
      expect(AcfunRoomParser.directory(_json({'result': 0, 'pcursor': '', 'liveList': <Object?>[]})).rooms, isEmpty);
      final card = AcfunRoomParser.room(_info(), _author);
      expect(card.roomId, _author);
      expect(card.content.title, '直播标题');
      expect(card.anchor?.name, '主播');
      expect(card.anchor?.avatarUrl, 'https://cn/avatar.jpg');
      expect(card.area?.areaName, '手游');
      expect(card.audience.onlineViewers, 1234);
      // A count written with a unit ("1.2万") is the site's display text, not a
      // number: the card keeps it unknown rather than guessing.
      expect(AcfunRoomParser.room({..._info(), 'onlineCount': '1.2万'}, _author).audience.onlineViewers, isNull);
      expect(card.audience.primaryMetric?.name, 'onlineViewers');
      expect(card.broadcast.isLiveNow, isTrue);
      expect(card.links.webUrl, 'https://live.acfun.cn/live/$_author');
      expect(AcfunRoomParser.room(_info(paid: 'SHOW'), _author).broadcast.effectiveRestriction, LiveRestriction.paid);
      expect(AcfunRoomParser.room(_info(paid: ''), _author).broadcast.effectiveRestriction, LiveRestriction.none);
    });

    test('an offline room answers with no live state and no restriction', () {
      final offline = _info(liveId: '');
      final room = AcfunRoomParser.room(offline, _author);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.restriction, isNull);
      expect(room.broadcast.startedAt, isNull);
    });

    test('the detail decodes the signature and refuses another author', () {
      final room = AcfunRoomParser.roomDetail(_json(_info()), authorId: _author);
      expect(room.content.introduction, '签名&注释');
      expect(
        () => AcfunRoomParser.roomDetail(_json({..._info(), 'authorId': '999'}), authorId: _author),
        throwsA(_fails(AcfunFailureKind.apiChanged)),
      );
      expect(
        () => AcfunRoomParser.roomDetail(
          _json({
            'result': 0,
            'user': {'id': '0', 'name': ''},
          }),
          authorId: _author,
        ),
        throwsA(_fails(AcfunFailureKind.notFound)),
      );
      expect(
        () => AcfunRoomParser.roomDetail(_json({'result': 1}), authorId: _author),
        throwsA(_fails(AcfunFailureKind.apiChanged)),
      );
    });

    test('a directory page drops the cards that do not check out', () {
      final body = _json({
        'result': 0,
        'pcursor': 'NEXT',
        'liveList': [
          _info(),
          {..._info(), 'authorId': '999'},
          {'authorId': 'not-an-id'},
        ],
      });
      final page = AcfunRoomParser.directory(body);
      expect(page.rooms, hasLength(1));
      expect(page.next, 'NEXT');
      expect(
        AcfunRoomParser.directory(
          _json({
            'result': 0,
            'pcursor': 'no_more',
            'liveList': [_info()],
          }),
        ).next,
        isNull,
      );
      expect(() => AcfunRoomParser.directory(_json({'result': 0})), throwsA(_fails(AcfunFailureKind.apiChanged)));
    });

    test('areas are the filter tree, keyed by the type and id pair', () {
      final areas = AcfunRoomParser.areas(
        _json({
          'result': 0,
          'pcursor': '',
          'liveList': <Object?>[],
          'channelFilters': {
            'liveChannelDisplayFilters': [
              {
                'displayFilters': [
                  {'filterType': 1, 'filterId': 0, 'name': '全部'},
                  {'filterType': 1, 'filterId': 9, 'name': '手游', 'cover': 'https://cn/a.png'},
                  {'filterType': 1, 'filterId': 9, 'name': '手游'},
                  {'filterType': 2, 'filterId': 3, 'name': ''},
                ],
              },
            ],
          },
        }),
        typeName: 'AcFun 直播',
      );
      expect(areas, hasLength(1));
      expect(areas.single.areaId, '1:9');
      expect(areas.single.iconUrl, 'https://cn/a.png');
      expect(areas.single.parentAreaName, 'AcFun 直播');
    });

    test('the visitor session needs an id and a token', () {
      final visitor = AcfunRoomParser.visitor(_json(_login()), deviceId: 'web_abc');
      expect(visitor.token, 'VISITOR-TOKEN');
      expect(visitor.security, 'czV4cG9ydWVrZXkzMjE0');
      expect(
        () => AcfunRoomParser.visitor(_json({'result': 100}), deviceId: 'web_abc'),
        throwsA(_fails(AcfunFailureKind.riskControl)),
      );
      expect(
        () => AcfunRoomParser.visitor(_json({'result': 0, 'userId': '1'}), deviceId: 'web_abc'),
        throwsA(_fails(AcfunFailureKind.apiChanged)),
      );
    });

    test('startPlay names the broadcast, its tickets and its restriction', () {
      final play = AcfunRoomParser.startPlay(_json(_startPlay()), issuedAt: DateTime(2026));
      expect(play.data?.liveId, '5555');
      expect(play.tickets, ['T1', 'T2']);
      expect(play.enterRoomAttach, 'ATTACH');
      expect(play.restriction, LiveRestriction.none);
      expect(
        AcfunRoomParser.startPlay(
          _json({'result': AcfunEndpoints.paidShowResult}),
          issuedAt: DateTime(2026),
        ).restriction,
        LiveRestriction.paid,
      );
      expect(
        () => AcfunRoomParser.startPlay(
          _json({'result': AcfunEndpoints.closedResult, 'error_msg': '直播已关播'}),
          issuedAt: DateTime(2026),
        ),
        throwsA(_fails(AcfunFailureKind.streamUnavailable)),
      );
      expect(
        () => AcfunRoomParser.startPlay(_json({'result': 40105}), issuedAt: DateTime(2026)),
        throwsA(_fails(AcfunFailureKind.riskControl)),
      );
      expect(
        () => AcfunRoomParser.startPlay(_json({'result': 1, 'data': {}}), issuedAt: DateTime(2026)),
        throwsA(_fails(AcfunFailureKind.apiChanged)),
      );
    });

    test('the gift table prices AC coins and bananas apart', () {
      final catalog = AcfunRoomParser.giftList(
        _json({
          'result': 1,
          'data': {
            'giftList': [
              {
                'giftId': 1,
                'giftName': '香蕉',
                'giftPrice': 1,
                'payWalletType': 2,
                'pngPicList': [
                  {'url': 'https://cn/banana.png'},
                ],
              },
              {'giftId': 7, 'giftName': '快乐水', 'giftPrice': '10', 'payWalletType': 1},
              {'giftName': 'no id'},
            ],
          },
        }),
      );
      expect(catalog.length, 2);
      expect(catalog['1']?.banana, isTrue);
      expect(catalog['1']?.iconUrl, 'https://cn/banana.png');
      expect(catalog['7']?.price, 10);
      expect(catalog['7']?.banana, isFalse);
      expect(() => AcfunRoomParser.giftList(_json({'result': 0})), throwsA(_fails(AcfunFailureKind.riskControl)));
    });

    test('the search page reads its cards from the BigPipe fragment', () {
      final html = [
        '<div class="total-num" data-total="2">共2条结果</div>',
        '<div class="search-up" data-up-exposure-log="{&quot;up_id&quot;:12345678,&quot;is_on_live&quot;:&quot;5555&quot;}">',
        '<a class="up__main__name"><a href="//www.acfun.cn/u/12345678">主播</a></a>',
        '<img class="up__avatar" src="https://cn/a.jpg">',
        '<div class="info__danmaku-count">353.9万 粉丝</div>',
        '<div class="up__main__intro">简介</div>',
        '</div>',
      ].join();
      final page = AcfunRoomParser.searchPage('${jsonEncode({'html': html})}/*<!-- fetch-stream -->*/junk', page: 1);
      expect(page.total, 2);
      final room = page.rooms.single;
      expect(room.roomId, '12345678');
      expect(room.anchor?.name, '主播');
      expect(room.anchor?.followerCount, 3539000);
      expect(room.broadcast.isLiveNow, isTrue);
      expect(room.content.introduction, '简介');
    });

    test('an empty search page needs its marker, and the totals must add up', () {
      String answer(String fragment, {String total = '0'}) =>
          jsonEncode({'html': '<div class="total-num" data-total="$total">$total</div>$fragment'});
      expect(AcfunRoomParser.searchPage(answer('<div class="empty-page"></div>'), page: 1).rooms, isEmpty);
      expect(() => AcfunRoomParser.searchPage(answer(''), page: 1), throwsA(_fails(AcfunFailureKind.apiChanged)));
      expect(
        () => AcfunRoomParser.searchPage(jsonEncode({'html': '<p>x</p>'}), page: 1),
        throwsA(_fails(AcfunFailureKind.apiChanged)),
      );
      expect(
        () => AcfunRoomParser.searchPage(jsonEncode({'html': 1}), page: 1),
        throwsA(_fails(AcfunFailureKind.apiChanged)),
      );
    });

    test('a card whose link names another author is dropped', () {
      final html = [
        '<div class="total-num" data-total="1">1</div>',
        '<div class="search-up" data-up-exposure-log="{&quot;up_id&quot;:12345678}">',
        '<a class="up__main__name"><a href="https://www.acfun.cn/u/99999999">别人</a></a></div>',
      ].join();
      final page = AcfunRoomParser.searchPage(jsonEncode({'html': html}), page: 1);
      expect(page.rooms, isEmpty);
    });
  });

  group('stream parsing', () {
    test('qualities merge per id, drop hidden and non-http, and rank level over bitrate', () {
      final qualities = AcfunRoomParser.startPlay(_json(_startPlay()), issuedAt: DateTime(2026)).data!.qualities;
      expect(qualities, hasLength(2));
      expect(qualities.first.label, '蓝光 8M');
      expect(qualities.first.rank, greaterThan(qualities.last.rank));
      expect(qualities.last.urls, ['https://cdn-b/live.m3u8?auth_key=1790000000-0-0-sign']);
    });

    test('a videoPlayRes given as text reads the same as an object', () {
      final playRes = (_startPlay()['data']! as Map<String, Object?>)['videoPlayRes']! as String;
      expect(
        AcfunPlayParser.qualities(playRes).map((quality) => quality.id),
        AcfunPlayParser.qualities(jsonDecode(playRes)).map((quality) => quality.id),
      );
    });

    test('lines name their host, format and lease', () {
      final data = AcfunRoomParser.startPlay(_json(_startPlay()), issuedAt: DateTime.utc(2026));
      final lines = AcfunPlayParser.lines(data.data!.qualities, qualityId: 'STANDARD', issuedAt: DateTime.utc(2026));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.lineLabel, 'cdn-b');
      expect(lines.single.headers['origin'], 'https://live.acfun.cn');
      expect(lines.single.lease, isNotNull);
      expect(lines.single.lease!.expiresAt, DateTime.fromMillisecondsSinceEpoch(1790000000000, isUtc: true));
      expect(
        () => AcfunPlayParser.lines(data.data!.qualities, qualityId: 'GONE', issuedAt: DateTime.utc(2026)),
        throwsA(_fails(AcfunFailureKind.streamUnavailable)),
      );
    });

    test('an expired or unsigned URL carries no lease', () {
      final issued = DateTime.utc(2026);
      expect(AcfunPlayParser.lease(Uri.parse('https://c/a.flv'), issued), isNull);
      expect(AcfunPlayParser.lease(Uri.parse('https://c/a.flv?auth_key=1000000000-0-0-x'), issued), isNull);
    });
  });

  group('link protocol', () {
    const security = '0123456789abcdef';
    final key = base64.encode(security.codeUnits);

    test('the security key is a base64 AES-128 key or nothing', () {
      expect(AcfunDanmakuProtocol.securityKey(key), hasLength(16));
      expect(AcfunDanmakuProtocol.securityKey(null), isNull);
      expect(AcfunDanmakuProtocol.securityKey(''), isNull);
      expect(AcfunDanmakuProtocol.securityKey(base64.encode([1, 2, 3])), isNull);
      expect(AcfunDanmakuProtocol.securityKey('not base64 !!'), isNull);
    });

    test('a frame keeps its header and payload lengths', () {
      final header = (AcfunProtoWriter()..integer(10, 7)).toBytes();
      final frame = AcfunDanmakuProtocol.frame(header, Uint8List.fromList([1, 2, 3]));
      expect(frame.sublist(0, 2), [0xAB, 0xCD]);
      final parts = AcfunDanmakuProtocol.unframe(frame);
      expect(parts.header.integer(10), 7);
      expect(parts.payload, [1, 2, 3]);
      expect(() => AcfunDanmakuProtocol.unframe([0, 1, 2]), throwsFormatException);
      expect(
        () => AcfunDanmakuProtocol.unframe(Uint8List.fromList([...frame.sublist(0, frame.length - 1)])),
        throwsFormatException,
      );
    });

    test('a sealed payload opens back, and a wrong key does not', () {
      final iv = Uint8List.fromList(List.filled(16, 7));
      final plain = (AcfunProtoWriter()..string(1, 'Basic.Register')).toBytes();
      final sealed = AcfunDanmakuProtocol.seal(plain, security.codeUnits, iv);
      expect(sealed.sublist(0, 16), iv);
      expect(AcfunDanmakuProtocol.open(sealed, security.codeUnits), plain);
      expect(() => AcfunDanmakuProtocol.open(sealed, 'fedcba9876543210'.codeUnits), throwsFormatException);
      expect(() => AcfunDanmakuProtocol.open(Uint8List(20), security.codeUnits), throwsFormatException);
    });

    test('the register answer brings the session key the later frames use', () {
      final link = AcfunDanmakuLink(
        args: AcfunDanmakuArgs(
          authorId: _author,
          liveId: '5555',
          visitor: AcfunVisitor(userId: '99', deviceId: 'web_abc', token: 'ST', security: key),
          tickets: const ['T1'],
        ),
        security: security.codeUnits,
        random: Random(1),
      );
      expect(link.registered, isFalse);
      final register = link.read(link.register());
      expect(register.command, 'Basic.Register');

      // The server's answer: mode 1, the session key and the instance id.
      final answer = AcfunProtoWriter()
        ..string(1, 'Basic.Register')
        ..integer(3, 0)
        ..bytes(
          4,
          (AcfunProtoWriter()
                ..bytes(2, Uint8List.fromList('SESSIONKEY123456'.codeUnits))
                ..integer(3, 42))
              .toBytes(),
        );
      final frame = AcfunDanmakuProtocol.frame(
        (AcfunProtoWriter()
              ..integer(8, 1)
              ..integer(10, 9))
            .toBytes(),
        AcfunDanmakuProtocol.seal(answer.toBytes(), security.codeUnits, Uint8List.fromList(List.filled(16, 3))),
      );
      final packet = link.read(frame);
      expect(packet.command, 'Basic.Register');
      expect(link.registered, isTrue);

      // A mode-2 frame now opens with the session key.
      final downstream = (AcfunProtoWriter()..string(1, AcfunDanmakuProtocol.roomCommand)).toBytes();
      final joined = link.read(
        AcfunDanmakuProtocol.frame(
          (AcfunProtoWriter()
                ..integer(8, 2)
                ..integer(10, 10))
              .toBytes(),
          AcfunDanmakuProtocol.seal(downstream, 'SESSIONKEY123456'.codeUnits, Uint8List.fromList(List.filled(16, 5))),
        ),
      );
      expect(joined.command, AcfunDanmakuProtocol.roomCommand);
      expect(joined.seqId, 10);
      expect(register.payload, isNotEmpty);
    });

    test('a push decodes chat, gift, banana and audience signals', () {
      final comment = AcfunProtoWriter()
        ..string(1, 'hello')
        ..integer(2, 1760000000000)
        ..bytes(
          3,
          (AcfunProtoWriter()
                ..integer(1, 4242)
                ..string(2, '观众'))
              .toBytes(),
        );
      final gift = AcfunProtoWriter()
        ..bytes(
          1,
          (AcfunProtoWriter()
                ..integer(1, 4242)
                ..string(2, '观众'))
              .toBytes(),
        )
        ..integer(2, 1760000000000)
        ..integer(3, 7)
        ..integer(4, 2)
        ..integer(5, 3)
        ..string(7, 'combo-1');
      final actions =
          (AcfunProtoWriter()
                ..bytes(
                  1,
                  (AcfunProtoWriter()
                        ..string(1, 'CommonActionSignalComment')
                        ..bytes(2, comment.toBytes()))
                      .toBytes(),
                )
                ..bytes(
                  1,
                  (AcfunProtoWriter()
                        ..string(1, 'CommonActionSignalGift')
                        ..bytes(2, gift.toBytes()))
                      .toBytes(),
                ))
              .toBytes();
      final push =
          (AcfunProtoWriter()
                ..string(1, 'ZtLiveScActionSignal')
                ..bytes(3, actions))
              .toBytes();
      final result = AcfunDanmakuProtocol.push(
        push,
        gifts: const AcfunGiftCatalog({'7': AcfunGiftInfo(id: '7', name: '快乐水', price: 10)}),
      );
      expect(result.messages, hasLength(2));
      expect(result.messages.first.type, LiveMessageType.chat);
      expect(result.messages.first.effectiveSender.userName, '观众');
      expect(result.messages.first.sender?.userId, '4242');
      final giftMessage = result.messages.last;
      expect(giftMessage.type, LiveMessageType.gift);
      expect((giftMessage.payload! as LiveGift).count, 2);
      expect((giftMessage.payload! as LiveGift).value.unit, LiveGiftUnit.acCoin);
      expect((giftMessage.payload! as LiveGift).value.totalValue, 20);
      expect((giftMessage.payload! as LiveGift).combo.comboTotal, 6);
      expect(giftMessage.messageId, '4242:combo-1:3');

      final banana =
          (AcfunProtoWriter()
                ..bytes(
                  1,
                  (AcfunProtoWriter()
                        ..integer(1, 11)
                        ..string(2, '路人'))
                      .toBytes(),
                )
                ..integer(2, 5)
                ..integer(3, 1760000000000))
              .toBytes();
      final thrown = AcfunDanmakuProtocol.push(
        (AcfunProtoWriter()
              ..string(1, 'ZtLiveScActionSignal')
              ..bytes(
                3,
                (AcfunProtoWriter()..bytes(
                      1,
                      (AcfunProtoWriter()
                            ..string(1, 'AcfunActionSignalThrowBanana')
                            ..bytes(2, banana))
                          .toBytes(),
                    ))
                    .toBytes(),
              ))
            .toBytes(),
      );
      expect((thrown.messages.single.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect((thrown.messages.single.payload! as LiveGift).name, '香蕉');
      expect(thrown.messages.single.effectiveSender.userName, '路人');

      final state = AcfunDanmakuProtocol.push(
        (AcfunProtoWriter()
              ..string(1, 'ZtLiveScStateSignal')
              ..bytes(
                3,
                (AcfunProtoWriter()..bytes(
                      1,
                      (AcfunProtoWriter()
                            ..string(1, 'CommonStateSignalDisplayInfo')
                            ..bytes(2, (AcfunProtoWriter()..string(1, '1.2万')).toBytes()))
                          .toBytes(),
                    ))
                    .toBytes(),
              ))
            .toBytes(),
      );
      expect(state.messages.single.type, LiveMessageType.audienceUpdate);
      expect(state.messages.single.text, isEmpty);
    });

    test('a gift the table prices at zero is free', () {
      final gift =
          (AcfunProtoWriter()
                ..bytes(
                  1,
                  (AcfunProtoWriter()
                        ..integer(1, 4242)
                        ..string(2, '观众'))
                      .toBytes(),
                )
                ..integer(2, 1760000000000)
                ..integer(3, 7)
                ..integer(4, 2))
              .toBytes();
      final actions =
          (AcfunProtoWriter()..bytes(
                1,
                (AcfunProtoWriter()
                      ..string(1, 'CommonActionSignalGift')
                      ..bytes(2, gift))
                    .toBytes(),
              ))
              .toBytes();
      final result = AcfunDanmakuProtocol.push(
        (AcfunProtoWriter()
              ..string(1, 'ZtLiveScActionSignal')
              ..bytes(3, actions))
            .toBytes(),
        gifts: const AcfunGiftCatalog({'7': AcfunGiftInfo(id: '7', name: '免费礼', price: 0)}),
      );
      final value = (result.messages.single.payload! as LiveGift).value;
      expect(value.unit, LiveGiftUnit.free);
      expect(value.unitPrice, isNull);
      expect(value.totalValue, isNull);
    });

    test('gzip payloads, a dead ticket and a status change read as themselves', () {
      final signals =
          (AcfunProtoWriter()..bytes(
                1,
                (AcfunProtoWriter()
                      ..string(1, 'CommonActionSignalComment')
                      ..bytes(
                        2,
                        (AcfunProtoWriter()
                              ..string(1, '压缩的消息')
                              ..bytes(
                                3,
                                (AcfunProtoWriter()
                                      ..integer(1, 5)
                                      ..string(2, '某人'))
                                    .toBytes(),
                              ))
                            .toBytes(),
                      ))
                    .toBytes(),
              ))
              .toBytes();
      final gzipped = AcfunProtoWriter()
        ..string(1, 'ZtLiveScActionSignal')
        ..integer(2, 2)
        ..bytes(3, gzip.encode(signals));
      expect(AcfunDanmakuProtocol.push(gzipped.toBytes()).messages.single.text, '压缩的消息');

      final ticket = AcfunProtoWriter()
        ..string(1, 'ZtLiveScTicketInvalid')
        ..bytes(3, Uint8List(0));
      expect(AcfunDanmakuProtocol.push(ticket.toBytes()).ticketInvalid, isTrue);

      final status = AcfunProtoWriter()
        ..string(1, 'ZtLiveScStatusChanged')
        ..bytes(3, (AcfunProtoWriter()..integer(1, 2)).toBytes());
      expect(AcfunDanmakuProtocol.push(status.toBytes()).statusChanged, 2);

      expect(AcfunDanmakuProtocol.refreshingStatuses, {1, 2, 4});
      expect(AcfunDanmakuProtocol.ticketErrors, {2, 3, 4, 7});
      expect(AcfunDanmakuProtocol.push([0xFF]).messages, isEmpty);
    });

    test('the frames name the app, the visitor and the sequence', () {
      final securityKey = List.generate(16, (index) => index);
      final sessionKey = List.generate(16, (index) => 100 + index);
      final link = AcfunDanmakuLink(
        args: AcfunDanmakuArgs(
          authorId: _author,
          liveId: '5555',
          visitor: AcfunVisitor(userId: '99', deviceId: 'web_abc', token: 'ST', security: base64.encode(securityKey)),
          tickets: const ['T1'],
        ),
        security: securityKey,
        random: Random(1),
      );

      // The register frame: mode 1, the service token in the header, the web
      // client's own app and device description inside.
      final register = AcfunDanmakuProtocol.unframe(link.register());
      expect(register.header.integer(1), AcfunDanmakuProtocol.appId);
      expect(register.header.integer(2), 99);
      expect(register.header.integer(8), 1);
      expect(register.header.integer(10), 1);
      expect(register.header.string(12), AcfunEndpoints.kpn);
      final tokenInfo = AcfunProtoMessage.decode(register.header.bytes(9)!);
      expect(tokenInfo.integer(1), 1);
      expect(tokenInfo.string(2), 'ST');
      final upstream = AcfunProtoMessage.decode(AcfunDanmakuProtocol.open(register.payload, securityKey));
      expect(upstream.string(1), AcfunDanmakuProtocol.registerCommand);
      expect(upstream.integer(2), 1);
      expect(upstream.integer(3), 1);
      expect(upstream.string(9), AcfunEndpoints.subBiz);
      final request = AcfunProtoMessage.decode(upstream.bytes(4)!);
      expect(AcfunProtoMessage.decode(request.bytes(2)!).integer(1), 6);
      expect(AcfunProtoMessage.decode(request.bytes(11)!).string(1), AcfunEndpoints.kpn);

      // The answer brings the session key; every later frame is sealed with it.
      link.read(
        AcfunDanmakuProtocol.frame(
          (AcfunProtoWriter()..integer(8, 1)).toBytes(),
          AcfunDanmakuProtocol.seal(
            (AcfunProtoWriter()
                  ..string(1, AcfunDanmakuProtocol.registerCommand)
                  ..bytes(
                    4,
                    (AcfunProtoWriter()
                          ..bytes(2, Uint8List.fromList(sessionKey))
                          ..integer(3, 42))
                        .toBytes(),
                  ))
                .toBytes(),
            securityKey,
            Uint8List.fromList(List.filled(16, 4)),
          ),
        ),
      );
      expect(link.registered, isTrue);
      final entered = AcfunDanmakuProtocol.unframe(link.enterRoom(ticket: 'T1', reconnects: 1));
      expect(entered.header.integer(8), 2);
      expect(entered.header.integer(3), 42);
      final room = AcfunProtoMessage.decode(AcfunDanmakuProtocol.open(entered.payload, sessionKey));
      expect(room.string(1), AcfunDanmakuProtocol.roomCommand);
      expect(room.integer(2), 2);
      final command = AcfunProtoMessage.decode(room.bytes(4)!);
      expect(command.string(1), 'ZtLiveCsEnterRoom');
      expect(command.string(3), 'T1');
      expect(command.string(4), '5555');
      final enter = AcfunProtoMessage.decode(command.bytes(2)!);
      expect(enter.integer(1), 0);
      expect(enter.integer(2), 1);
      expect(enter.string(5), AcfunDanmakuProtocol.sdkVersion);

      // A push acknowledgement echoes the push's sequence and moves none of
      // the link's own.
      final acknowledged = AcfunDanmakuProtocol.unframe(
        link.pushAck(AcfunDanmakuPacket(command: 'Push.ZtLiveInteractive.Message', seqId: 77, payload: Uint8List(0))),
      );
      expect(acknowledged.header.integer(10), 77);
      expect(
        AcfunProtoMessage.decode(AcfunDanmakuProtocol.open(acknowledged.payload, sessionKey)).string(1),
        'Push.ZtLiveInteractive.Message',
      );
      expect(AcfunProtoMessage.decode(AcfunDanmakuProtocol.open(acknowledged.payload, sessionKey)).integer(2), 3);
    });

    test('chat without a register key reports it before any socket', () async {
      final session = AcfunDanmakuSession(
        args: AcfunDanmakuArgs(
          authorId: _author,
          liveId: '5555',
          visitor: const AcfunVisitor(userId: '99', deviceId: 'web_abc', token: 'ST'),
          tickets: const <String>[],
        ),
      );
      final failure = await session.connect();
      expect(failure, isA<LiveSiteAuthenticationError>());
      await session.dispose();
      expect(await session.connect(), isA<LiveSiteError>());
    });

    test('the ack names its type, code and payload', () {
      final payload =
          (AcfunProtoWriter()
                ..string(1, AcfunDanmakuProtocol.enterRoomAck)
                ..integer(2, 0)
                ..bytes(4, (AcfunProtoWriter()..integer(1, 10000)).toBytes()))
              .toBytes();
      final ack = AcfunDanmakuProtocol.ack(payload);
      expect(ack.type, AcfunDanmakuProtocol.enterRoomAck);
      expect(ack.code, 0);
      expect(AcfunDanmakuProtocol.heartbeatInterval(ack.payload)?.inSeconds, 10);
      expect(AcfunDanmakuProtocol.heartbeatInterval(Uint8List(0)), isNull);
    });
  });

  group('adapter wiring', () {
    test('the capabilities are wired and the site is registered', () {
      final site = _site((_) => _resp(200, '{}'));
      expect(site.manifest.id, 'acfun');
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveDanmakuProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      expect(site.capability<LiveRoomProvider>(), same(site.capability<LiveRoomProvider>()));
    });

    test('room entry reads the info and the play answer, and carries both handles', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        return switch (request.url.path) {
          '/api/live/info' => _resp(200, _json(_info())),
          '/rest/zt/live/web/startPlay' => _resp(200, _json(_startPlay())),
          _ => _resp(200, _json(_login())),
        };
      });
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_author));
      expect(room.broadcast.isLiveNow, isTrue);
      expect((room.runtime.streamHandle! as AcfunRoomData).liveId, '5555');
      final args = room.runtime.danmakuHandle! as AcfunDanmakuArgs;
      expect(args.tickets, ['T1', 'T2']);
      expect(args.visitor.token, 'VISITOR-TOKEN');
      expect(args.visitor.userId, '99887766');
      expect(args.enterRoomAttach, 'ATTACH');
      expect(seen.map((request) => request.url.path), [
        '/api/live/info',
        '/rest/app/visitor/login',
        '/rest/zt/live/web/startPlay',
      ]);
      expect(seen.first.headers['user-agent'], AcfunEndpoints.userAgent);
      expect(seen.last.method, 'POST');
      expect(seen.last.body, contains('authorId=$_author'));
      expect(seen.last.body, contains('pullStreamType=FLV'));
    });

    test('an offline room never asks startPlay, and a non-id is refused', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        return _resp(200, _json(_info(liveId: '')));
      });
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_author));
      expect(room.broadcast.isLiveNow, isFalse);
      expect(seen, hasLength(1));
      expect(_left(await site.capability<LiveRoomProvider>()!.getRoom('not an id')), isA<LiveSiteNotFound>());
      expect(_left(await site.capability<LiveRoomProvider>()!.getRoom('')), isA<LiveSiteNotFound>());
    });

    test('a refused session logs in again and only once', () async {
      final seen = <_Seen>[];
      var refused = 0;
      final site = _site((request) {
        seen.add(request);
        if (request.url.path == '/rest/zt/live/web/startPlay' && ++refused == 1) {
          return _resp(200, _json({'result': 40105}));
        }
        return switch (request.url.path) {
          '/api/live/info' => _resp(200, _json(_info())),
          '/rest/zt/live/web/startPlay' => _resp(200, _json(_startPlay())),
          _ => _resp(200, _json(_login())),
        };
      });
      final room = _right(await site.capability<LiveRoomProvider>()!.getRoom(_author));
      expect(room.broadcast.isLiveNow, isTrue);
      expect(seen.where((request) => request.url.path == '/rest/app/visitor/login').length, 2);
      expect(seen.where((request) => request.url.path == '/rest/zt/live/web/startPlay').length, 2);
    });

    test('qualities and lines come from the fresh detail', () async {
      final site = _site(
        (request) => switch (request.url.path) {
          '/api/live/info' => _resp(200, _json(_info())),
          '/rest/zt/live/web/startPlay' => _resp(200, _json(_startPlay())),
          _ => _resp(200, _json(_login())),
        },
      );
      final playback = site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _author));
      expect(qualities.map((quality) => quality.label), ['蓝光 8M', '高清']);
      final lines = _right(await playback.getLines(roomId: _author, quality: qualities.last));
      expect(lines.single.url, startsWith('https://cdn-b/'));
      final best = _right(await playback.getLines(roomId: _author));
      expect(best.map((line) => line.lineLabel), ['cdn-a', 'cdn-e']);
    });

    test('a paid show is content-unavailable for playback', () async {
      final site = _site(
        (request) => switch (request.url.path) {
          '/api/live/info' => _resp(200, _json(_info())),
          '/rest/zt/live/web/startPlay' => _resp(200, _json({'result': AcfunEndpoints.paidShowResult})),
          _ => _resp(200, _json(_login())),
        },
      );
      expect(
        _left(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: _author)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('an offline room is content-unavailable for playback, not an empty list', () async {
      final site = _site(
        (request) => request.url.path == '/api/live/info' ? _resp(200, _json(_info(liveId: ''))) : _resp(200, '{}'),
      );
      expect(
        _left(await site.capability<LivePlaybackProvider>()!.getQualities(roomId: _author)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('directory pages follow the cursor chain and stop at no_more', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        final cursor = request.url.queryParameters['pcursor'];
        final body = _json({
          'result': 0,
          'pcursor': cursor == ''
              ? 'C2'
              : cursor == 'C2'
              ? 'no_more'
              : 'C2',
          'liveList': [
            _info(),
            {
              ..._info(),
              'authorId': '87654321',
              'user': {'id': '87654321', 'name': 'B', 'headUrl': ''},
            },
          ],
        });
        return _resp(200, body);
      });
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      final first = _right(await discovery.getRecommendedRooms());
      expect(first.items, hasLength(2));
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, 'C2');
      final second = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2)));
      // The next page lists the same two rooms, so the chain's dedup empties
      // it: the ranking moved not at all.
      expect(second.items, isEmpty);
      expect(second.hasMore, isFalse);
      expect(seen.map((request) => request.url.queryParameters['pcursor']), ['', 'C2']);
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 3))).items, isEmpty);
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 9))).items, isEmpty);
    });

    test('a repeated cursor is api-changed, not an endless page', () async {
      final site = _site(
        (request) => _resp(
          200,
          _json({
            'result': 0,
            'pcursor': 'SAME',
            'liveList': [_info()],
          }),
        ),
      );
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      _right(await discovery.getRecommendedRooms());
      expect(
        _left(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2))),
        isA<LiveSiteParseError>(),
      );
    });

    test('the area list is read once and an area page sends its filters', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        final body = _json({
          'result': 0,
          'pcursor': '',
          'liveList': [_info()],
          'channelFilters': {
            'liveChannelDisplayFilters': [
              {
                'displayFilters': [
                  {'filterType': 1, 'filterId': 9, 'name': '手游'},
                ],
              },
            ],
          },
        });
        return _resp(200, body);
      });
      final area = site.capability<LiveAreaProvider>()!;
      final areas = _right(await area.getAreas());
      expect(areas.single.areaId, '1:9');
      _right(await area.getAreaRooms(areaId: '1:9'));
      expect(seen.last.url.queryParameters['filters'], '[{"filterType":1,"filterId":9}]');
      expect(seen.where((request) => request.url.queryParameters['count'] == '1'), hasLength(1));
      expect(_left(await area.getAreaRooms(areaId: '9')), isA<LiveSiteNotFound>());
      expect(_left(await area.getAreaRooms(areaId: 'x:9')), isA<LiveSiteNotFound>());
    });

    test('a search page is cut from the server pages, and a blank keyword asks for nothing', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        final page = int.parse(request.url.queryParameters['pCursor']!);
        String card(String id) => [
          '<div class="search-up" data-up-exposure-log="{&quot;up_id&quot;:$id}">',
          '<a class="up__main__name"><a href="https://www.acfun.cn/u/$id">主播$id</a></a></div>',
        ].join();
        final html = [
          '<div class="total-num" data-total="35">35</div>',
          ...List.generate(page == 1 ? 30 : 5, (index) => card('${10000000 + (page - 1) * 30 + index}')),
        ].join();
        return _resp(200, jsonEncode({'html': html}));
      });
      final search = site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, const {LiveSearchTarget.rooms, LiveSearchTarget.anchors});
      final first = _right(await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms)));
      expect(first.items, hasLength(20));
      expect(first.items, hasLength(20));
      final second = _right(
        await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms, page: 2)),
      );
      // 35 authors in all: page 2 holds rows 21-35 (10 left of server page 1
      // and the 5 of server page 2), and page 3 has nothing left.
      expect(second.items, hasLength(15));
      // The same rows come from the site's own page cutting, by author id.
      final rows = await site.search('主播', 2, 20);
      expect(rows.map((room) => room.roomId).take(2), ['10000020', '10000021']);
      expect(seen.map((request) => request.url.queryParameters['pCursor']), ['1', '2', '1', '2']);
      expect(
        _right(await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms, page: 3)))
            .items,
        isEmpty,
      );
      expect(
        _left(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.areas))).toString(),
        contains('unsupported'),
      );
    });

    test('the anchor target reads the same author index as the room one', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        String card(String id) => [
          '<div class="search-up" data-up-exposure-log="{&quot;up_id&quot;:$id}">',
          '<a class="up__main__name"><a href="https://www.acfun.cn/u/$id">主播$id</a></a></div>',
        ].join();
        return _resp(
          200,
          jsonEncode({
            'html': [
              '<div class="total-num" data-total="35">35</div>',
              ...List.generate(30, (index) => card('${10000000 + index}')),
            ].join(),
          }),
        );
      });
      final search = site.capability<LiveSearchProvider>()!;
      final page = _right(
        await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.anchors, pageSize: 3)),
      );
      final anchors = [for (final item in page.items) (item as AnchorSearchResult).anchor];
      expect(anchors, hasLength(3));
      expect(anchors.first.anchorId, '10000000');
      expect(anchors.first.name, '主播10000000');
      expect(seen, hasLength(1));
    });

    test('the gift table is cached and a failure is remembered as empty', () async {
      final seen = <_Seen>[];
      final site = _site((request) {
        seen.add(request);
        if (request.url.path == '/rest/zt/live/web/gift/list') return _resp(200, _json({'result': 0}));
        return _resp(200, _json(_login()));
      });
      final catalog = await site.giftCatalog(_author, liveId: '5555');
      expect(catalog.isEmpty, isTrue);
      expect(seen, hasLength(2));
      final again = await site.giftCatalog(_author, liveId: '5555');
      expect(again.isEmpty, isTrue);
      expect(seen, hasLength(2));
    });

    test('a link is canonicalized, an alien host is unsupported and a page names no author', () async {
      final site = _site((_) => _resp(200, '{}'));
      final resolver = site.capability<LiveLinkResolver>()!;
      expect(
        _right(await resolver.resolve(Uri.parse('https://live.acfun.cn/live/$_author'))).toString(),
        'https://live.acfun.cn/live/$_author',
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://m.acfun.cn/live/detail/$_author'))).toString(),
        'https://live.acfun.cn/live/$_author',
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://www.acfun.cn/u/$_author.aspx'))).toString(),
        'https://live.acfun.cn/live/$_author',
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://m.acfun.cn/upPage/$_author'))).toString(),
        'https://live.acfun.cn/live/$_author',
      );
      // Only the profile link takes the legacy `.aspx` suffix; the mobile
      // upPage does not, so an `.aspx` there names no author.
      expect(
        _left(await resolver.resolve(Uri.parse('https://m.acfun.cn/upPage/$_author.aspx'))).toString(),
        contains('no author'),
      );
      expect(
        _left(await resolver.resolve(Uri.parse('https://www.youtube.com/watch?v=1'))).toString(),
        contains('unsupported'),
      );
      expect(_left(await resolver.resolve(Uri.parse('https://live.acfun.cn/'))).toString(), contains('no author'));
      expect(
        _left(await resolver.resolve(Uri.parse('https://www.acfun.cn/u/not-an-id'))).toString(),
        contains('no author'),
      );
    });

    test('chat cannot start without a live broadcast', () async {
      final site = _site(
        (request) => request.url.path == '/api/live/info' ? _resp(200, _json(_info(liveId: ''))) : _resp(200, '{}'),
      );
      expect(
        _left(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: _author)),
        isA<LiveSiteContentUnavailable>(),
      );
    });
  });
}

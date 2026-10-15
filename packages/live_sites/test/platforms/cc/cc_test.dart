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
import 'package:live_sites/src/capabilities/live_web_search_provider.dart';
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
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/api/cc_http.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_json.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_link.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_room_parser.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, early afternoon (Beijing).
final DateTime _at = DateTime.parse('2026-09-30T06:00:00.000Z').toUtc();

const String _ccid = '341438909';
const String _otherCcid = '732923115';
const String _channel = '54321';

/// When the play URLs' `auth_key` expires.
const int _authExpiry = 1791000000;

String _json(Object? data) => jsonEncode(data);

String _playlist() => 'https://cgi.v.cc.163.com/redirect/video/$_ccid.m3u8';

String _media(String tier, String cdn) => 'https://$cdn.cc.163.com/live/$_ccid/$tier.flv?auth_key=$_authExpiry-0-0-abc';

Map<String, Object?> _typeRow(int type, String name) => {'cate_type': type, 'name': name};

Map<String, Object?> _areaRow(String gametype, String name, {Object? cover}) => {
  'gametype': gametype,
  'name': name,
  'cover': cover ?? '//p1.cc.163.com/area.png',
};

String _typesFixture({int code = 0, List<Object?>? rows}) => _json({
  'code': code,
  'data': {
    'category_info': {
      'cate_list': rows ?? [_typeRow(1, '网游'), _typeRow(4, '手游')],
    },
  },
});

String _areasFixture({int code = 0, List<Object?>? rows}) => _json({
  'code': code,
  'data': {
    'category_info': {
      'game_list': rows ?? [_areaRow('1', '梦幻西游'), _areaRow('1', '重复的'), _areaRow('02', '坏号')],
    },
  },
});

Map<String, Object?> _liveRow({
  Object? cuteid = _ccid,
  String title = '晚间直播',
  String nick = '主播甲',
  Object? status = 1,
  String gameName = '梦幻西游',
  String avatar = 'https://p1.cc.163.com/a.png',
  Object? cover = '//p1.cc.163.com/c.jpg',
  String poster = '',
  Object? heat = 12345,
  Object? viewers = 678,
  Object? startat = '2026-09-30 13:00:00',
  Map<String, Object?>? streamList,
}) => {
  'cuteid': cuteid,
  'title': title,
  'nickname': nick,
  'purl': avatar,
  'cover': cover,
  'poster': poster,
  'game_name': gameName,
  'status': status,
  'webcc_visitor': heat,
  'vision_visitor': viewers,
  'startat': startat,
  'stream_list': ?streamList,
};

String _categoryRoomsFixture({required String gametype, List<Object?>? rows}) => _json({
  'gametype': gametype,
  'lives':
      rows ??
      [
        _liveRow(),
        _liveRow(cuteid: _otherCcid, status: 0, viewers: null, startat: '2026-09-29 10:00:00'),
        _liveRow(cuteid: 'no-digits'),
      ],
});

String _recommendFixture({List<Object?>? rows}) => _json({
  'lives':
      rows ??
      [
        _liveRow(gameName: '', title: '热门房'),
        _liveRow(cuteid: _otherCcid, title: '【重播】昨天的比赛', heat: null, viewers: null, streamList: {'high': {}}),
      ],
});

String _searchFixture({List<Object?>? rows}) => _json({
  'webcc_anchor': {
    'result':
        rows ??
        [
          {
            'cuteid': _ccid,
            'nickname': '主播甲',
            'title': '晚间直播',
            'status': 1,
            'game_name': '梦幻西游',
            'portrait': 'https://p1.cc.163.com/p.png',
            'cover': '',
            'hot_score': 5000,
            'follower_num': '1.2万',
            'startat': '2026-09-30 13:00:00',
          },
          {
            'cuteid': _otherCcid,
            'nickname': '主播乙',
            'title': '回放',
            'status': 0,
            'game_name': '梦幻西游',
            'portrait': '//p1.cc.163.com/q.png',
            'hot_score': 9,
            'follower_num': '300',
          },
        ],
  },
});

String _livesFixture({String code = 'OK', Map<String, Object?>? entry, String forCcid = _ccid}) => _json({
  'code': code,
  'data': {
    forCcid: entry ?? {'channel_id': _channel},
  },
});

Map<String, Object?> _streamList() => {
  'high': {
    'CDN_FMT': {'hs': '?s=high-hs', 'ali': '?s=high-ali'},
    'vbr': 2000,
  },
  'low': {
    'CDN_FMT': {'ks': '?s=low-ks'},
    'vbr': 600,
  },
};

Map<String, Object?> _channelRow({
  Object? ccid = _ccid,
  Object? nolive,
  Object? status = 1,
  String personalLabel = '天天开播',
  Object? cid = _channel,
  Map<String, Object?>? streamList,
  Object? followerNum = 900,
  String title = '晚间直播',
}) => {
  'ccid': ccid,
  'nolive': ?nolive,
  'title': title,
  'nickname': '主播甲',
  'purl': 'https://p1.cc.163.com/a.png',
  'cover': '//p1.cc.163.com/c.jpg',
  'gamename': '梦幻西游',
  'webcc_visitor': 12345,
  'vision_visitor': 678,
  'follower_num': followerNum,
  'personal_label': personalLabel,
  'status': status,
  'startat': '2026-09-30 13:00:00',
  'cid': cid,
  'stream_list': streamList ?? _streamList(),
  'm3u8': _playlist(),
};

String _channelRoomFixture({List<Object?>? data}) => _json({
  'data': data ?? [_channelRow()],
});

String _roomPage({int code = 200, String ccid = _ccid, String nickname = '主播乙'}) =>
    '<html><head><title>cc</title></head><body><script id="__NEXT_DATA__" type="application/json">${_json({
      'props': {
        'pageProps': {
          'roomInfoInitData': {'code': code, 'ccid': ccid, 'nickname': nickname, 'announcement': '下播了，明天见', 'follower_num': '1.2万', 'gamename': '梦幻西游', 'purl': 'https://p1.cc.163.com/b.png'},
        },
      },
    })}</script></body></html>';

String _registryFixture({List<Object?>? result, int code = 200}) => _json({
  'code': code,
  'result':
      result ??
      const [
        {'appKey': '梦幻西游', 'name': '梦幻西游手游', 'icon': 'https://p1.ds.163.com/game.png'},
      ],
});

Map<String, Object?> _officialEntry(String name, String content, {bool hidden = false}) => {
  'name': name,
  'content': content,
  'hidden': hidden,
};

String _configFixture({int code = 200, Object? result}) => _json({
  'code': code,
  'result':
      result ??
      {
        'id': CcEndpoints.catalogConfigurationId,
        'itemList': [
          {
            'name': '别的组',
            'itemList': [_officialEntry('梦幻西游', 'https://cc.163.com/1/')],
          },
          {
            'name': '直播入口列表',
            'itemList': [
              _officialEntry('梦幻西游', 'https://cc.163.com/$_ccid/'),
              _officialEntry('梦幻西游', 'https://cc.163.com/$_otherCcid/', hidden: true),
              _officialEntry('查无此游', 'https://cc.163.com/998/'),
              _officialEntry('外站的', 'https://evil.com/997/'),
              _officialEntry('梦幻西游', 'https://cc.163.com/$_ccid/'),
            ],
          },
        ],
      },
});

String _tierAnswerFixture({
  List<Object?>? vbrList,
  Object? vbrSel = 'high',
  List<Object?>? cdnList,
  String videourl = '',
  String? bakvideourl,
  String cdnSel = 'hs',
  String? bakcdnSel,
}) => _json({
  'vbrname_list': ?vbrList,
  'vbrname_sel': ?vbrSel,
  'vbrname_mapping': const {'original': '原画', 'blueray_5M_avc': '蓝光5M', 'high': '高清', 'standard': '标清'},
  'cdn_list': ?cdnList,
  'videourl': videourl,
  'bakvideourl': ?bakvideourl,
  'cdn_sel': cdnSel,
  'bakcdn_sel': ?bakcdnSel,
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

/// The answers of the whole site.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (request.url.host == 'api.cc.163.com') {
    if (path == '/v1/wapcc/gamecategory') {
      final catetype = request.url.queryParameters['catetype'];
      return _resp(200, catetype == '0' ? _typesFixture() : _areasFixture());
    }
    if (path == '/v1/activitylives/anchor/lives') {
      return _resp(200, _livesFixture(forCcid: request.url.queryParameters['anchor_ccid'] ?? ''));
    }
    return _resp(404, 'nope');
  }
  if (request.url.host == 'cc.163.com') {
    if (path == '/api/category/live/') return _resp(200, _recommendFixture());
    if (path.startsWith('/api/category/')) {
      return _resp(200, _categoryRoomsFixture(gametype: path.split('/')[3]));
    }
    if (path == '/search/anchor/') return _resp(200, _searchFixture());
    if (path == '/live/channel/') return _resp(200, _channelRoomFixture());
    if (RegExp(r'^/\d+/$').hasMatch(path)) return _resp(200, _roomPage());
    return _resp(404, 'nope');
  }
  if (request.url.host == 'vapi.cc.163.com') {
    final cdn = request.url.queryParameters['cdn'];
    if (cdn != null) {
      return _resp(200, _tierAnswerFixture(vbrList: ['high'], videourl: _media('high', cdn), cdnSel: cdn));
    }
    return _resp(
      200,
      _tierAnswerFixture(
        vbrList: ['original', 'blueray_5M_avc', 'ultra', 'high', 'standard'],
        cdnList: ['hs', 'ali'],
        videourl: _media('high', 'hs'),
        bakvideourl: _media('high', 'ks'),
        bakcdnSel: 'ks',
      ),
    );
  }
  if (request.url.host == 'inf.ds.163.com') return _resp(200, _registryFixture());
  if (request.url.host == 'inf-act.ds.163.com') return _resp(200, _configFixture());
  return _resp(404, 'nope');
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

({CcSite site, _FakeHttp http}) _adapter({LiveResponse Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: CcSite(http: CcHttp(http), now: () => _at), http: http);
}

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, CcFailureKind kind) {
        try {
          CcJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on CcFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, CcFailureKind.riskControl);
      expectKind(403, CcFailureKind.riskControl);
      expectKind(429, CcFailureKind.rateLimited);
      for (final status in [500, 503]) {
        expectKind(status, CcFailureKind.network);
      }
      for (final status in [301, 400, 404, 410]) {
        expectKind(status, CcFailureKind.apiChanged);
      }
      CcJson.checkStatus(200, 'x');
      CcJson.checkStatus(299, 'x');
    });

    test('failures map onto the Either error and their transience', () {
      const cases = {
        CcFailureKind.notFound: LiveSiteNotFound,
        CcFailureKind.apiChanged: LiveSiteParseError,
        CcFailureKind.network: LiveSiteNetworkError,
        CcFailureKind.riskControl: LiveSiteRateLimitError,
        CcFailureKind.rateLimited: LiveSiteRateLimitError,
        CcFailureKind.streamUnavailable: LiveSiteContentUnavailable,
        CcFailureKind.invalidArgument: LiveSiteInvalidArgument,
      };
      for (final MapEntry(key: kind, value: error) in cases.entries) {
        final failure = CcFailure(kind, 'x');
        expect(failure.toLiveSiteError('cc').runtimeType, error);
        expect(failure.isTransient, kind == CcFailureKind.network || kind == CcFailureKind.rateLimited);
      }
    });

    test('the body is bounded and must be JSON', () {
      expect(
        () => CcJson.decode('<html>', what: 'x', status: 200),
        throwsA(predicate((e) => '$e'.contains('not JSON'))),
      );
      expect(
        () => CcJson.decode('{"a":"${'x' * 5000000}"}', what: 'x', status: 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(CcJson.decode('{"a":1}', what: 'x', status: 200), {'a': 1});
      expect(() => CcJson.decode('x', what: 'x', status: 429), throwsA(isA<CcFailure>()));
    });

    test('ids, figures and Beijing times are read strictly', () {
      expect(CcJson.cuteid(123), '123');
      expect(CcJson.cuteid('123'), '123');
      expect(CcJson.cuteid(0), isNull);
      expect(CcJson.cuteid(-1), isNull);
      expect(CcJson.cuteid('0123'), isNull, reason: 'a leading zero is no ccid');
      expect(CcJson.cuteid(9007199254740992), isNull);
      expect(CcJson.cuteid('12345678901234567890'), isNull);
      expect(CcJson.figure('1.2万'), 12000);
      expect(CcJson.figure('0'), 0, reason: 'an explicit zero is a zero');
      expect(CcJson.figure('null'), isNull);
      expect(CcJson.figure('waiting'), isNull);
      expect(CcJson.figure(null), isNull);
      expect(CcEndpoints.isCcid(_ccid), isTrue);
      expect(CcEndpoints.isCcid('0123'), isFalse);
      expect(CcEndpoints.isAreaId('0'), isTrue, reason: '0 is 其他游戏');
      expect(CcEndpoints.isAreaId('02'), isFalse);
      expect(CcJson.beijingTime('2026-09-30 13:00:00'), DateTime.parse('2026-09-30T13:00:00+08:00').toUtc());
      expect(CcJson.beijingTime('1999-09-30 13:00:00'), isNull);
      expect(CcJson.beijingTime('yesterday'), isNull);
    });
  });

  group('catalog', () {
    test('the categories are read, bad rows skipped', () {
      final types = CcRoomParser.categoryTypes(
        _typesFixture(
          rows: [
            _typeRow(1, '网游'),
            _typeRow(0, '全部'),
            _typeRow(4, '手游&amp;端游'),
            _typeRow(4, '重复的'),
            {'cate_type': 7},
            {'name': '无名'},
          ],
        ),
      );
      expect(types.map((type) => type.id), ['1', '4']);
      expect(types.last.name, '手游&端游', reason: 'the references are decoded');
      expect(
        () => CcRoomParser.categoryTypes(_typesFixture(code: 5)),
        throwsA(predicate((e) => '$e'.contains('code 5'))),
      );
      expect(
        () => CcRoomParser.categoryTypes(_json({'code': 0})),
        throwsA(predicate((e) => '$e'.contains('no category_info'))),
      );
    });

    test('the areas of a category carry their category', () {
      final areas = CcRoomParser.categoryAreas(_areasFixture(), id: '1', name: '网游');
      expect(areas, hasLength(1), reason: 'a repeated game type is listed once, a bad one skipped');
      expect(areas.single.areaId, '1');
      expect(areas.single.areaName, '梦幻西游');
      expect(areas.single.parentAreaId, '1');
      expect(areas.single.parentAreaName, '网游');
      expect(areas.single.iconUrl, 'https://p1.cc.163.com/area.png', reason: 'the picture is made absolute');
    });

    test('the official entries come from the registry and the configuration', () {
      final areas = CcRoomParser.officialAreas(_registryFixture(), _configFixture());
      expect(areas, hasLength(1), reason: 'the hidden, unknown, foreign and repeated entries are skipped');
      expect(areas.single.areaId, 'official:$_ccid');
      expect(areas.single.areaName, '梦幻西游手游');
      expect(areas.single.parentAreaId, 'official');
      expect(areas.single.parentAreaName, CcEndpoints.officialLabel);
      expect(areas.single.iconUrl, 'https://p1.ds.163.com/game.png');
    });

    test('a hidden group lists none, a wrong configuration is api-changed', () {
      expect(
        CcRoomParser.officialAreas(
          _registryFixture(),
          _configFixture(result: {'id': CcEndpoints.catalogConfigurationId, 'hidden': true}),
        ),
        isEmpty,
      );
      expect(
        () => CcRoomParser.officialAreas(_registryFixture(), _configFixture(result: {'id': 'another-id'})),
        throwsA(predicate((e) => '$e'.contains('live configuration: id'))),
      );
      expect(
        () => CcRoomParser.officialAreas(_registryFixture(code: 500), _configFixture()),
        throwsA(predicate((e) => '$e'.contains('game registry: code 500'))),
      );
      expect(
        () => CcRoomParser.officialAreas(
          _registryFixture(),
          _configFixture(result: {'id': CcEndpoints.catalogConfigurationId, 'itemList': <Object?>[]}),
        ),
        throwsA(predicate((e) => '$e'.contains('live entry groups'))),
      );
    });
  });

  group('lists', () {
    test('an area page echoes its game type and is bounded', () {
      expect(
        () => CcRoomParser.categoryRooms(_categoryRoomsFixture(gametype: 'other'), gametype: '1'),
        throwsA(predicate((e) => '$e'.contains('unexpected answer'))),
      );
      expect(
        () => CcRoomParser.categoryRooms(
          _categoryRoomsFixture(gametype: '1', rows: List.filled(1001, _liveRow())),
          gametype: '1',
        ),
        throwsA(predicate((e) => '$e'.contains('1001 rows'))),
      );
      expect(() => CcRoomParser.categoryRooms(_json({'gametype': '1'}), gametype: '1'), throwsA(isA<CcFailure>()));
    });

    test('a directory row keeps both audience figures and its state', () {
      final rooms = CcRoomParser.categoryRooms(_categoryRoomsFixture(gametype: '1'), gametype: '1');
      expect(rooms, hasLength(2), reason: 'a row without a cuteid is skipped');
      final onAir = rooms.first;
      expect(onAir.roomId, _ccid);
      expect(onAir.platform, 'cc');
      expect(onAir.content.title, '晚间直播');
      expect(
        onAir.content.coverUrl,
        'https://p1.cc.163.com/c.jpg',
        reason: 'the protocol-relative cover is made absolute',
      );
      expect(onAir.anchor?.name, '主播甲');
      expect(onAir.area?.areaName, '梦幻西游');
      expect(onAir.audience.popularity, 12345);
      expect(onAir.audience.onlineViewers, 678);
      expect(onAir.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(onAir.broadcast.liveStatus, LiveStatus.live);
      expect(onAir.broadcast.startedAt, DateTime.parse('2026-09-30T13:00:00+08:00').toUtc());
      expect(onAir.broadcast.restriction, isNull, reason: 'no tier list, so the answer does not say');
      expect(onAir.links.webUrl, CcEndpoints.roomUrl(_ccid));
      final offline = rooms.last;
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.broadcast.startedAt, isNull, reason: 'off air the start was the last broadcast’s');
    });

    test('a rebroadcast is a replay, a tier list says no restriction', () {
      final rooms = CcRoomParser.recommendRooms(_recommendFixture());
      expect(rooms, hasLength(2));
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
      final replay = rooms.last;
      expect(replay.broadcast.liveStatus, LiveStatus.replay, reason: '【重播】 is an official rebroadcast');
      expect(replay.broadcast.restriction, LiveRestriction.none, reason: 'its tier list plays like a live stream');
      expect(replay.broadcast.startedAt, isNotNull);
      expect(replay.audience.popularity, isNull, reason: 'the heat is absent');
      expect(replay.audience.onlineViewers, isNull);
      expect(replay.audience.primaryMetric, LiveAudienceMetricType.unknown);
      expect(() => CcRoomParser.recommendRooms('{}'), throwsA(predicate((e) => '$e'.contains('no lives list'))));
    });

    test('a search card is on air with its heat, or offline with its followers', () {
      final rooms = CcRoomParser.searchRooms(_searchFixture());
      expect(rooms, hasLength(2));
      final onAir = rooms.first;
      expect(onAir.broadcast.liveStatus, LiveStatus.live);
      expect(onAir.audience.popularity, 5000);
      expect(onAir.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(onAir.content.coverUrl, onAir.anchor?.avatarUrl, reason: 'no cover: the portrait stands in for it');
      expect(onAir.anchor?.followerCount, 12000);
      final offline = rooms.last;
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.audience.popularity, isNull, reason: 'hot_score of an offline streamer is not a heat');
      expect(offline.audience.primaryMetric, LiveAudienceMetricType.followers);
      expect(offline.content.coverUrl, 'https://p1.cc.163.com/q.png');
      expect(() => CcRoomParser.searchRooms('{}'), throwsA(predicate((e) => '$e'.contains('no webcc_anchor'))));
    });
  });

  group('rooms', () {
    test('the channel answer tells the channel or refuses', () {
      expect(CcRoomParser.liveChannel(_livesFixture(), ccid: _ccid), _channel);
      expect(
        CcRoomParser.liveChannel(_livesFixture(entry: {}), ccid: _ccid),
        isNull,
        reason: 'no channel_id: offline',
      );
      expect(
        () => CcRoomParser.liveChannel('x', ccid: _ccid, status: 400),
        throwsA(predicate((e) => e is CcFailure && e.kind == CcFailureKind.notFound)),
      );
      expect(
        () => CcRoomParser.liveChannel(_livesFixture(code: 'BAD'), ccid: _ccid),
        throwsA(predicate((e) => '$e'.contains('code BAD'))),
      );
      expect(
        () => CcRoomParser.liveChannel(_livesFixture(forCcid: 'someone-else'), ccid: _ccid),
        throwsA(predicate((e) => '$e'.contains('no entry for'))),
      );
    });

    test('the channel room answers under the ccid asked for', () {
      final answer = CcRoomParser.channelRoom(_channelRoomFixture(), ccid: _ccid);
      expect(answer, isNotNull);
      final room = answer!.room;
      expect(room.roomId, _ccid);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, isNotNull);
      expect(room.broadcast.restriction, LiveRestriction.none, reason: 'the tier list rides along');
      expect(room.content.introduction, '天天开播');
      expect(room.content.notice, '天天开播');
      expect(room.audience.popularity, 12345);
      expect(room.audience.onlineViewers, 678);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.anchor?.followerCount, 900);
      expect(room.area?.areaName, '梦幻西游');
      expect(room.links.webUrl, CcEndpoints.roomUrl(_ccid));
      expect(answer.data.streams, isNotNull);
      expect(answer.data.playlist, _playlist());
      expect(
        () => CcRoomParser.channelRoom(_channelRoomFixture(), ccid: _otherCcid),
        throwsA(predicate((e) => '$e'.contains('answered ccid $_ccid'))),
      );
      expect(CcRoomParser.channelRoom(_channelRoomFixture(data: [_channelRow(nolive: 1)]), ccid: _ccid), isNull);
      expect(CcRoomParser.channelRoom(_channelRoomFixture(data: []), ccid: _ccid), isNull);
      expect(
        () => CcRoomParser.channelRoom(_json({'data': 'no'}), ccid: _ccid),
        throwsA(predicate((e) => '$e'.contains('data is not a list'))),
      );
    });

    test('the room page fills an anchor without a channel', () {
      final room = CcRoomParser.pageRoom(_roomPage(), ccid: _ccid);
      expect(room.roomId, _ccid);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.startedAt, isNull);
      expect(room.anchor?.name, '主播乙');
      expect(room.anchor?.followerCount, 12000);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.followers);
      expect(room.content.introduction, '下播了，明天见');
      expect(
        () => CcRoomParser.pageRoom(_roomPage(code: 404), ccid: _ccid),
        throwsA(predicate((e) => e is CcFailure && e.kind == CcFailureKind.notFound)),
      );
      expect(
        () => CcRoomParser.pageRoom('<html></html>', ccid: _ccid),
        throwsA(predicate((e) => '$e'.contains('no roomInfoInitData'))),
      );
      expect(
        () => CcRoomParser.pageRoom(_roomPage(nickname: ''), ccid: _ccid),
        throwsA(predicate((e) => '$e'.contains('no nickname'))),
      );
      expect(CcRoomParser.offlineRoom(_ccid).broadcast.liveStatus, LiveStatus.offline);
    });
  });

  group('streams', () {
    test('a play answer without a stream says so, a broken one is api-changed', () {
      for (final status in [410, 404]) {
        expect(
          () => CcRoomParser.playData('x', status: status),
          throwsA(predicate((e) => e is CcFailure && e.kind == CcFailureKind.streamUnavailable)),
        );
      }
      expect(() => CcRoomParser.playData('[]'), throwsA(predicate((e) => '$e'.contains('not an object'))));
      expect(CcRoomParser.playData(_tierAnswerFixture()), isNotEmpty);
    });

    test('the qualities are the site’s own tiers in the server’s order', () {
      final data = CcRoomParser.playData(
        _tierAnswerFixture(vbrList: ['original', 'blueray_5M_avc', 'ultra', 'high', 'standard', 'high']),
      );
      final qualities = CcRoomParser.qualities(data);
      expect(qualities.map((quality) => quality.qualityId), [
        'original',
        'blueray_5M_avc',
        'ultra',
        'high',
        'standard',
      ], reason: 'a repeated tier is listed once');
      expect(qualities.map((quality) => quality.label), ['原画', '蓝光5M', '超清', '高清', '标清']);
      expect(qualities.first.platformOrder, greaterThan(qualities.last.platformOrder));
      expect(qualities.every((quality) => !quality.isPlaybackUnconfirmed), isTrue);
      final selected = CcRoomParser.qualities(CcRoomParser.playData(_tierAnswerFixture(vbrList: [])));
      expect(selected.single.qualityId, 'high', reason: 'vbrname_sel stands in for an empty list');
      final unconfirmed = CcRoomParser.qualities(
        CcRoomParser.playData(_tierAnswerFixture(vbrList: ['high'], vbrSel: null)),
      );
      expect(unconfirmed.single.isPlaybackUnconfirmed, isTrue);
      expect(
        () => CcRoomParser.qualities(CcRoomParser.playData('{}')),
        throwsA(predicate((e) => '$e'.contains('no vbrname_list or vbrname_sel'))),
      );
    });

    test('the lines of the answers carry headers, a label and a lease', () {
      final main = CcRoomParser.playData(
        _tierAnswerFixture(
          vbrList: ['high'],
          cdnList: ['hs', 'ali'],
          videourl: _media('high', 'hs'),
          bakvideourl: _media('high', 'ks'),
          bakcdnSel: 'ks',
        ),
      );
      final lines = CcRoomParser.resolution([
        (data: main, issuedAt: _at),
        (
          data: CcRoomParser.playData(
            _tierAnswerFixture(vbrList: ['high'], videourl: _media('high', 'ali'), cdnSel: 'ali'),
          ),
          issuedAt: _at,
        ),
      ], roomId: _ccid);
      expect(lines.map((line) => line.lineLabel), ['hs', 'ks', 'ali']);
      expect(lines.every((line) => line.format == LiveStreamFormat.flv), isTrue);
      expect(lines.first.headers, CcEndpoints.mediaHeaders(_ccid));
      expect(lines.first.headers['referer'], '${CcEndpoints.origin}/$_ccid/');
      expect(lines.first.url, _media('high', 'hs'));
      final lease = lines.first.lease!;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(_authExpiry * 1000, isUtc: true);
      expect(lease.expiresAt, expiresAt);
      expect(
        lease.refreshAt,
        expiresAt.subtract(CcEndpoints.leaseLead),
        reason: 'the lifetime is long, so the lead is 60 s',
      );
      expect(lease.requiresReconnect, isFalse, reason: 'an expired URL refuses new connections only');
      // A CDN answer at another tier is dropped, and a CDN is kept once.
      final dropped = CcRoomParser.resolution([
        (data: main, issuedAt: _at),
        (
          data: CcRoomParser.playData(
            _tierAnswerFixture(
              vbrList: ['standard'],
              vbrSel: 'standard',
              videourl: _media('high', 'ali'),
              cdnSel: 'ali',
            ),
          ),
          issuedAt: _at,
        ),
      ], roomId: _ccid);
      expect(dropped.map((line) => line.lineLabel), ['hs', 'ks']);
      expect(
        () => CcRoomParser.resolution([
          (data: CcRoomParser.playData(_tierAnswerFixture()), issuedAt: _at),
        ], roomId: _ccid),
        throwsA(predicate((e) => '$e'.contains('no playable URL'))),
      );
      expect(
        () => CcRoomParser.resolution(const [], roomId: _ccid),
        throwsA(predicate((e) => '$e'.contains('no answer'))),
      );
    });

    test('the cdns left out are asked for once more', () {
      final data = CcRoomParser.playData(
        _tierAnswerFixture(cdnList: ['hs', 'ali', 'ali'], videourl: _media('high', 'hs')),
      );
      expect(CcRoomParser.uncoveredCdns(data), ['ali']);
      expect(
        CcRoomParser.uncoveredCdns(
          CcRoomParser.playData(_tierAnswerFixture(cdnList: ['hs'], videourl: _media('high', 'hs'))),
        ),
        isEmpty,
      );
    });

    test('the channel’s tier list is the fallback, signed playlists first by cdn', () {
      final data = CcRoomData(streams: _streamList(), playlist: _playlist());
      final qualities = CcRoomParser.legacyQualities(data);
      expect(qualities.map((quality) => quality.label), ['高清', '低清'], reason: 'best first by 3.x’s rank');
      expect(qualities.first.qualityId, 'high');
      final lines = CcRoomParser.legacyLines(data, 'high', roomId: _ccid);
      expect(lines.map((line) => line.url), [
        '${_playlist()}?s=high-hs',
        '${_playlist()}?s=high-ali',
      ], reason: 'hs and ali go first');
      expect(lines.every((line) => line.format == LiveStreamFormat.hls), isTrue);
      for (final line in lines) {
        expect(line.headers, CcEndpoints.mediaHeaders(_ccid));
        expect(line.lease, isNull, reason: 'the redirect is asked on every open');
      }
      // Without a tier id, the best tier plays.
      expect(CcRoomParser.legacyLines(data, null, roomId: _ccid).first.lineLabel, 'high');
      // A tier the room does not carry is stream-unavailable.
      expect(
        () => CcRoomParser.legacyLines(data, 'blueray_20M', roomId: _ccid),
        throwsA(predicate((e) => e is CcFailure && e.kind == CcFailureKind.streamUnavailable)),
      );
      expect(
        () => CcRoomParser.legacyLines(CcRoomData(playlist: _playlist()), 'high', roomId: _ccid),
        throwsA(predicate((e) => e is CcFailure && e.kind == CcFailureKind.streamUnavailable)),
      );
      // A quickplay object carries direct urls instead of signatures.
      const quick = CcRoomData(
        streams: {
          'resolution': {
            'ultra': {
              'cdn': {'hs': 'https://hs.cc.163.com/$_ccid/ultra.m3u8'},
            },
          },
        },
      );
      expect(CcRoomParser.legacyQualities(quick).single.label, '蓝光');
      expect(
        CcRoomParser.legacyLines(quick, 'ultra', roomId: _ccid).single.url,
        'https://hs.cc.163.com/$_ccid/ultra.m3u8',
      );
      expect(CcRoomParser.legacyQualities(const CcRoomData(streams: {'high': <String, dynamic>{}})), isEmpty);
    });

    test('a lease counts from its auth_key', () {
      final issuedAt = DateTime.parse('2026-09-30T06:00:00.000Z');
      final leased = CcRoomParser.lease(Uri.parse(_media('high', 'hs')), issuedAt);
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(_authExpiry * 1000, isUtc: true);
      expect(leased!.expiresAt, expiresAt);
      expect(leased.refreshAt, expiresAt.subtract(CcEndpoints.leaseLead));
      expect(
        CcRoomParser.lease(Uri.parse('https://v.cc.163.com/live.flv'), issuedAt),
        isNull,
        reason: 'no auth_key, no lease',
      );
      expect(
        CcRoomParser.lease(Uri.parse('https://v.cc.163.com/live.flv?auth_key=100-0-0-x'), issuedAt),
        isNull,
        reason: 'already past',
      );
    });
  });

  group('links', () {
    test('the three forms of a room page', () {
      expect(CcLink.ccidOf(Uri.parse('https://cc.163.com/$_ccid/')), _ccid);
      expect(CcLink.ccidOf(Uri.parse('https://cc.163.com/$_ccid')), _ccid);
      expect(CcLink.ccidOf(Uri.parse('https://h5.cc.163.com/cc/$_ccid')), _ccid);
      expect(CcLink.ccidOf(Uri.parse('https://ds.163.com/glive/?ccid=$_ccid')), _ccid);
      expect(CcLink.ccidOf(Uri.parse('https://CC.163.COM/$_ccid/')), _ccid, reason: 'the host is case-insensitive');
      expect(CcLink.ccidOf(Uri.parse('https://cc.163.com/0123/')), '123', reason: '3.x normalized the number');
    });

    test('anything else is no room link', () {
      for (final bad in [
        'https://cc.163.com/',
        'https://cc.163.com/n/ds_category/1/',
        'https://cc.163.com/glive/',
        'https://h5.cc.163.com/cc/',
        'https://ds.163.com/glive/',
        'https://ds.163.com/glive/?ccid=abc',
        'https://evil.com/$_ccid/',
        'ftp://cc.163.com/$_ccid/',
      ]) {
        expect(CcLink.ccidOf(Uri.parse(bad)), isNull, reason: bad);
      }
    });
  });

  group('adapter wiring', () {
    test('the manifest and the six capabilities the platform can serve', () async {
      final adapter = _adapter();
      final site = adapter.site;
      expect(site.manifest.id, 'cc');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.capability<LiveRoomProvider>(), isNotNull);
      expect(site.capability<LiveAreaProvider>(), isNotNull);
      expect(site.capability<LiveDiscoveryProvider>(), isNotNull);
      expect(site.capability<LiveSearchProvider>(), isNotNull);
      expect(site.capability<LivePlaybackProvider>(), isNotNull);
      expect(site.capability<LiveLinkResolver>(), isNotNull);
      // No danmaku: CC has none, 3.x neither.
      expect(site.capability<LiveDanmakuProvider>(), isNull);
      expect(site.capability<LiveHotProvider>(), isNull);
      expect(site.capability<LiveAnchorProvider>(), isNull);
      expect(site.capability<LiveWebSearchProvider>(), isNull);
      await site.dispose();
    });

    test('the catalog asks the categories, then their areas, beside the official ones', () async {
      final adapter = _adapter();
      final areas = _right(await adapter.site.capability<LiveAreaProvider>()!.getAreas());
      expect(adapter.http.sent, hasLength(5), reason: 'catetype 0, one per category, and the two Dashen answers');
      expect(
        adapter.http.sent.map((seen) => '${seen.url.host}${seen.url.path}?${seen.url.query}'),
        containsAll([
          'api.cc.163.com/v1/wapcc/gamecategory?catetype=0',
          'api.cc.163.com/v1/wapcc/gamecategory?catetype=1',
          'api.cc.163.com/v1/wapcc/gamecategory?catetype=4',
          'inf.ds.163.com/v1/web/game-center/basic/base-info-list/by-type?gameType=NETEASE',
        ]),
      );
      expect(areas.map((area) => area.areaId), ['1', '1', 'official:$_ccid'], reason: 'one area per category');
      expect(areas.first.parentAreaName, '网游');
      expect(areas[1].parentAreaName, '手游');
      expect(areas.last.parentAreaName, CcEndpoints.officialLabel);
    });

    test('the catalog alone failing fails it, the official ones failing does not', () async {
      final official = _adapter(
        onSend: (request) => switch (request.url.host) {
          'inf.ds.163.com' || 'inf-act.ds.163.com' => _resp(500, 'down'),
          _ => _ordinary(request),
        },
      );
      final areas = _right(await official.site.capability<LiveAreaProvider>()!.getAreas());
      expect(areas.map((area) => area.areaId), ['1', '1'], reason: 'the official entries are left out');
      final dead = _adapter(
        onSend: (request) => request.url.host == 'api.cc.163.com' ? _resp(500, 'down') : _ordinary(request),
      );
      expect(_leftOf(await dead.site.capability<LiveAreaProvider>()!.getAreas()), isA<LiveSiteNetworkError>());
    });

    test('area rooms are paged by start and size, another area is a caller error', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      final page = _right(await area.getAreaRooms(areaId: '1', request: const LivePageRequest(page: 3, pageSize: 30)));
      expect(adapter.http.sent.last.url.queryParameters, {
        'format': 'json',
        'tag_id': '0',
        'start': '60',
        'size': '30',
      });
      expect(page.items.map((room) => room.roomId), [_ccid, _otherCcid]);
      expect(page.hasMore, isFalse, reason: 'a short page is the last');
      expect(_leftOf(await area.getAreaRooms(areaId: 'official:$_ccid')), isA<LiveSiteInvalidArgument>());
      expect(adapter.http.sent, hasLength(1), reason: 'a caller error sends nothing');
      expect(
        _leftOf(await area.getAreaRooms(areaId: '1', request: const LivePageRequest(page: 0))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(await area.getAreaRooms(areaId: '1', request: const LivePageRequest(page: 100001))),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('a full page of the all-live feed may have more', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final page = _right(await rooms.getRooms(const LivePageRequest(page: 2, pageSize: 30)));
      expect(adapter.http.sent.last.url.host, 'cc.163.com');
      expect(adapter.http.sent.last.url.path, '/api/category/live/');
      expect(adapter.http.sent.last.url.queryParameters, {'format': 'json', 'start': '30', 'size': '30'});
      expect(page.items, hasLength(2));
      expect(page.hasMore, isFalse, reason: 'a short page is the last');
      final one = _adapter(
        onSend: (request) => request.url.host == 'cc.163.com' && request.url.path == '/api/category/live/'
            ? _resp(200, _recommendFixture(rows: [_liveRow()]))
            : _ordinary(request),
      );
      final full = _right(
        await one.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms(
          request: const LivePageRequest(pageSize: 1),
        ),
      );
      expect(full.items, hasLength(1));
      expect(full.hasMore, isTrue, reason: 'a full page may have more');
    });

    test('the search asks the anchor search, a blank keyword none', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      expect(adapter.http.sent, isEmpty, reason: 'an unsupported target sends nothing');
      final hit = await search.search(
        const LiveSearchRequest(query: ' 主播 ', target: LiveSearchTarget.rooms, page: 2, pageSize: 100),
      );
      expect(adapter.http.sent.last.url.path, '/search/anchor/');
      expect(adapter.http.sent.last.url.queryParameters, {'query': '主播', 'size': '50', 'page': '2'});
      final page = _right(hit);
      expect(page.hasMore, isNull, reason: 'the search answer says nothing about pages');
      expect(page.items.whereType<RoomSearchResult>().map((item) => item.room.roomId), [_ccid, _otherCcid]);
      expect(adapter.http.sent, hasLength(1));
      final blank = _adapter();
      expect(
        _right(
          await blank.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: '  ', target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
      );
      expect(blank.http.sent, isEmpty);
    });

    test('a room id that is no ccid is not-found without a request', () async {
      final adapter = _adapter();
      final error = _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('abc'));
      expect(error, isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty);
    });

    test('an entry is the channel and its room, with the stream handle', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_ccid));
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/v1/activitylives/anchor/lives', '/live/channel/']);
      expect(adapter.http.sent.first.url.queryParameters['anchor_ccid'], _ccid);
      expect(adapter.http.sent.last.url.queryParameters['channelids'], _channel);
      expect(room.roomId, _ccid);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.streamHandle, isA<CcRoomData>());
    });

    test('an anchor without a channel is offline via its room page', () async {
      final adapter = _adapter(
        onSend: (request) => request.url.path == '/v1/activitylives/anchor/lives'
            ? _resp(200, _livesFixture(entry: {}))
            : _ordinary(request),
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_ccid));
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/v1/activitylives/anchor/lives', '/$_ccid/']);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.content.introduction, '下播了，明天见');
      // An unknown id is told apart on the room page.
      final unknown = _adapter(
        onSend: (request) => request.url.path == '/v1/activitylives/anchor/lives'
            ? _resp(200, _livesFixture(entry: {}))
            : _resp(200, _roomPage(code: 404)),
      );
      expect(_leftOf(await unknown.site.capability<LiveRoomProvider>()!.getRoom(_ccid)), isA<LiveSiteNotFound>());
    });

    test('the qualities come from video_play_url and its lines reuse the answer once', () async {
      final adapter = _adapter();
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_ccid);
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _ccid));
      expect(adapter.http.sent.last.url.host, 'vapi.cc.163.com');
      expect(adapter.http.sent.last.url.path, '/video_play_url/$_ccid');
      expect(adapter.http.sent.last.url.queryParameters.containsKey('vbrname'), isFalse);
      expect(qualities.map((quality) => quality.qualityId), [
        'original',
        'blueray_5M_avc',
        'ultra',
        'high',
        'standard',
      ]);
      final before = adapter.http.sent.length;
      final selected = qualities.singleWhere((quality) => quality.qualityId == 'high');
      final lines = _right(await playback.getLines(roomId: _ccid, quality: selected));
      expect(adapter.http.sent, hasLength(before + 1), reason: 'the qualities answer stood in for its own tier');
      expect(adapter.http.sent.last.url.queryParameters, {
        'src': 'webcc_h5',
        'vbrmode': '1',
        'use_new_vbrmap': '1',
        'secure': '1',
        'vbrname': 'high',
        'cdn': 'ali',
      });
      expect(lines.map((line) => line.lineLabel), ['hs', 'ks', 'ali']);
      // The reuse is spent: the next play asks the tier again, then the cdn.
      final again = _right(await playback.getLines(roomId: _ccid, quality: selected));
      expect(adapter.http.sent[before + 1].url.queryParameters['vbrname'], 'high');
      expect(adapter.http.sent[before + 1].url.queryParameters.containsKey('cdn'), isFalse);
      expect(adapter.http.sent[before + 2].url.queryParameters['cdn'], 'ali');
      expect(again.map((line) => line.lineLabel), ['hs', 'ks', 'ali']);
      // Without a quality, no tier is sent.
      final plain = _right(await playback.getLines(roomId: _ccid));
      expect(adapter.http.sent[before + 3].url.queryParameters.containsKey('vbrname'), isFalse);
      expect(plain, isNotEmpty);
      // A room id that is no ccid has no stream.
      expect(_leftOf(await playback.getQualities(roomId: 'abc')), isA<LiveSiteContentUnavailable>());
    });

    test('an anchor who is not broadcasting says stream-unavailable', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url) {
          _ when request.url.host == 'vapi.cc.163.com' => _resp(410, 'gone'),
          _ when request.url.path == '/v1/activitylives/anchor/lives' => _resp(200, _livesFixture(entry: {})),
          _ => _ordinary(request),
        },
      );
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_ccid);
      final error = _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _ccid));
      expect(error, isA<LiveSiteContentUnavailable>());
    });

    test('a failing play answer falls back to the channel’s tier list', () async {
      final adapter = _adapter(
        onSend: (request) => request.url.host == 'vapi.cc.163.com' ? _resp(500, 'down') : _ordinary(request),
      );
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_ccid);
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _ccid));
      expect(qualities.map((quality) => quality.label), ['高清', '低清']);
      expect(adapter.http.sent.where((seen) => seen.url.host == 'vapi.cc.163.com'), hasLength(1));
      // The fallback’s lines play without a request.
      final before = adapter.http.sent.length;
      final lines = _right(
        await playback.getLines(
          roomId: _ccid,
          quality: qualities.singleWhere((quality) => quality.qualityId == 'high'),
        ),
      );
      expect(adapter.http.sent, hasLength(before), reason: 'the tier list already carries the urls');
      expect(lines.first.url, '${_playlist()}?s=high-hs');
    });

    test('a refused session is a rate limit at the boundary', () async {
      final adapter = _adapter(onSend: (_) => _resp(403, 'nope'));
      expect(
        _leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest())),
        isA<LiveSiteRateLimitError>(),
      );
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_ccid)), isA<LiveSiteRateLimitError>());
      expect(
        _leftOf(
          await adapter.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms),
          ),
        ),
        isA<LiveSiteRateLimitError>(),
      );
    });

    test('a link is canonicalized without a request', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://cc.163.com/$_ccid/?from=share'))),
        Uri.parse(CcEndpoints.roomUrl(_ccid)),
      );
      expect(
        _right(await link.resolve(Uri.parse('https://h5.cc.163.com/cc/$_ccid'))),
        Uri.parse(CcEndpoints.roomUrl(_ccid)),
      );
      expect(
        _right(await link.resolve(Uri.parse('https://ds.163.com/glive/?ccid=$_ccid'))),
        Uri.parse(CcEndpoints.roomUrl(_ccid)),
      );
      expect(adapter.http.sent, isEmpty, reason: 'a room page needs no request');
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/1/'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://cc.163.com/'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://cc.163.com/n/whatever/'))), isA<LiveSiteNotFound>());
    });
  });
}

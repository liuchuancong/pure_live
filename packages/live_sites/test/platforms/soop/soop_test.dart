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
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';
import 'package:live_sites/src/platforms/soop/api/soop_http.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_codec.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_json.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_link.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_room_parser.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _id = 'loo3672';
const String _idUpper = 'LOO3672';
const String _other = 'otherbj';
const String _bno = '123456789';

String _json(Object? data) => jsonEncode(data);

String _playerFixture({
  int result = 1,
  String title = '标题&amp;测试',
  String nick = '主播&amp;甲',
  String bno = _bno,
  String bjid = _id,
  Object? btime = 3600,
  bool withPreset = true,
  bool withChat = true,
  String chdomain = 'chat-6e0a4c4e.sooplive.com',
  String chpt = '1567',
  String chip = '',
  String chatNo = '12345678',
  String bpwd = 'N',
}) => _json({
  'CHANNEL': {
    'RESULT': result,
    'TITLE': title,
    'BJNICK': nick,
    'BJID': bjid,
    'BNO': bno,
    'CATEGORY_TAGS': ['聊天', '音乐'],
    'RMD': 'https://rmd.sooplive.co.kr/api/',
    'CDN': 'gs_cdn',
    'BPWD': bpwd,
    'P_MIN_TIER': 0,
    'GRADE': 0,
    'BTIME': btime,
    'total_view_cnt': '1,234',
    if (withPreset)
      'VIEWPRESET': [
        {'name': 'original', 'bps': '8000000', 'vcodec': 'h264'},
        {'name': 'hd', 'bps': '2000000', 'vcodec': 'h264'},
        {'name': 'sd', 'bps': '500000'},
        {'name': 'auto'},
      ],
    if (withChat) ...{
      'CHATNO': chatNo,
      if (chdomain.isNotEmpty) 'CHDOMAIN': chdomain,
      if (chip.isNotEmpty) 'CHIP': chip,
      'CHPT': chpt,
    },
  },
});

String _stationFixture({
  String nick = '主播甲',
  String introduction = '한국 스트리머',
  String avatar = 'https://stimg.sooplive.co.kr/LOGO/lo/$_id/m/$_id.webp',
  String start = '2026-09-22 19:59:31',
  Map<String, Object?>? broad,
}) => _json({
  'station': {'user_nick': nick, 'station_title': introduction, 'broad_start': start},
  'profile_image': avatar,
  'broad': ?broad,
});

Map<String, Object?> _broad({String bno = _bno, String title = '방송 중', Object? viewers = 100}) => {
  'broad_no': bno,
  'broad_title': title,
  'current_sum_viewer': viewers,
  'is_password': 'N',
  'subscription_only': 0,
  'broad_grade': 0,
};

Map<String, Object?> _card({
  String id = _id,
  String nick = '主播甲',
  String title = '标题',
  Object? viewers = '2,000',
  Object? password,
  Object? subscribers,
  Object? grade,
  String? profileImage,
}) => {
  'user_id': id,
  'user_nick': nick,
  'broad_title': title,
  'broad_start': '2026-09-22 19:59:31.0',
  'total_view_cnt': viewers,
  'is_password': password,
  'subscription_only': subscribers,
  'broad_grade': grade,
  'user_profile_img': ?profileImage,
};

String _categoryFixture({required int page, bool? isMore = false, List<Object?>? areas}) => _json({
  'result': 1,
  'data': {
    'list':
        areas ??
        [
          {'category_no': '01010000000', 'category_name': '전체', 'cate_img': '//stimg.sooplive.co.kr/a.png'},
          {'category_no': '01020000000', 'category_name': '聊天&amp;交友', 'cate_img': null},
        ],
    'is_more': ?isMore,
  },
});

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : url = request.url, form = request.body;
  final Uri url;

  /// The form body, for the player API's fields.
  final String? form;
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

/// The player API's `type` of a seen request, from its form.
String _typeOf(_Seen request) => RegExp('type=([^&]+)').firstMatch(request.form ?? '')?.group(1) ?? '';

Future<SocketChannel> _refuseSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw StateError('no socket was asked for in this test');

/// The answers of the site: the player API live, the station live, one page
/// of every list.
LiveResponse _ordinary(_Seen request) {
  final url = request.url;
  if (url.path == '/afreeca/player_live_api.php') {
    return switch (_typeOf(request)) {
      'aid' => _resp(
        200,
        _json({
          'CHANNEL': {'RESULT': 1, 'AID': 'the-stream-key'},
        }),
      ),
      _ => _resp(200, _playerFixture()),
    };
  }
  if (url.path == '/api/$_id/station') return _resp(200, _stationFixture(broad: _broad()));
  if (url.path == '/api.php') {
    return switch (url.queryParameters['m']) {
      'categoryList' => _resp(200, _categoryFixture(page: int.parse(url.queryParameters['nPageNo']!))),
      'categoryContentsList' => _resp(
        200,
        _json({
          'result': 1,
          'data': {
            'list': <Object?>[_card(profileImage: 'https://stimg.sooplive.co.kr/p.png')],
          },
        }),
      ),
      'liveSearch' => _resp(
        200,
        _json({
          'RESULT': 1,
          'HAS_MORE_LIST': true,
          'TOTAL_CNT': 42,
          'REAL_BROAD': <Object?>[
            {..._card(id: _other), 'broad_img': '//liveimg.sooplive.co.kr/m/$_bno', 'broad_cate_name': '音乐'},
          ],
        }),
      ),
      _ => _resp(404, 'nope'),
    };
  }
  if (url.path == '/api/main_broad_list_api.php') {
    final page = int.parse(url.queryParameters['pageNo']!);
    return _resp(
      200,
      page == 1
          ? _json({
              'broad': <Object?>[
                {..._card(), 'broad_thumb': '//liveimg.sooplive.co.kr/m/$_bno', 'category_name': '聊天'},
              ],
            })
          : _json({'broad': <Object?>[]}),
    );
  }
  if (url.path.endsWith('/broad_stream_assign.html')) {
    return _resp(200, _json({'result': 1, 'view_url': 'https://live.sooplive.co.kr/ver/$_bno/playlist.m3u8'}));
  }
  return _resp(404, 'nope');
}

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

({SoopSite site, _FakeHttp http}) _adapter({LiveResponse Function(_Seen request)? onSend}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: SoopSite(http: SoopHttp(http), connect: _refuseSocket, now: () => _at), http: http);
}

bool _transient(SoopFailureKind kind) => SoopFailure(kind, 'x').isTransient;

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, SoopFailureKind kind) {
        try {
          SoopJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on SoopFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(429, SoopFailureKind.rateLimited);
      expectKind(500, SoopFailureKind.network);
      expectKind(503, SoopFailureKind.network);
      expectKind(401, SoopFailureKind.riskControl);
      expectKind(403, SoopFailureKind.riskControl);
      // The reference's gate: every other non-2xx is the answer's shape.
      expectKind(404, SoopFailureKind.apiChanged);
      expectKind(301, SoopFailureKind.apiChanged);
      SoopJson.checkStatus(200, 'x');
    });

    test('the body is bounded and must be a JSON object', () {
      expect(
        () => SoopJson.root('<html>', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('not a JSON object'))),
      );
      expect(
        () => SoopJson.root('{"a":"${'x' * 1100000}"}', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(
        () => SoopJson.root('[1]', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('not a JSON object'))),
      );
      expect(SoopJson.root('{"a":1}', status: 200, what: 'x'), {'a': 1});
      expect(
        () => SoopJson.data(_json({'result': 2}), status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('result 2'))),
      );
      expect(
        () => SoopJson.data(_json({'result': 1}), status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('no data object'))),
      );
    });

    test('readers are as tolerant as 3.x was', () {
      expect(SoopJson.text(null), '');
      expect(SoopJson.text(42), '42');
      expect(SoopJson.display('a&amp;b'), 'a&b');
      expect(SoopJson.display('&#x1F600;'), '😀');
      expect(SoopJson.truthy('Y'), isTrue);
      expect(SoopJson.truthy('no'), isFalse);
      expect(SoopJson.truthy(1), isTrue);
      expect(SoopJson.truthy(2), isFalse);
      expect(SoopJson.string('  x  '), 'x');
      expect(SoopJson.string('   '), isNull);
      expect(SoopJson.integer('42'), 42);
      expect(SoopJson.integer(4.0), 4);
      expect(SoopJson.integer(4.5), isNull);
      expect(SoopJson.count('-1'), isNull);
      expect(SoopJson.url('ftp://x'), isNull);
      expect(SoopJson.url('https://x/y'), isNotNull);
      expect(SoopJson.image('//stimg.sooplive.co.kr/a.png'), 'https://stimg.sooplive.co.kr/a.png');
      expect(SoopJson.image(null), '');
    });

    test('a broad_start is Korean time in UTC', () {
      expect(SoopRoomParser.koreanTime('2026-09-22 19:59:31'), DateTime.utc(2026, 9, 22, 10, 59, 31));
      expect(SoopRoomParser.koreanTime('2026-09-22 19:59:31.0'), DateTime.utc(2026, 9, 22, 10, 59, 31));
      expect(SoopRoomParser.koreanTime('2026-09-22T19:59:31'), DateTime.utc(2026, 9, 22, 10, 59, 31));
      expect(SoopRoomParser.koreanTime('nope'), isNull);
      expect(SoopRoomParser.koreanTime('1969-01-01 00:00:00'), isNull, reason: 'not after 1970');
      expect(SoopRoomParser.koreanTime('2026-13-40 19:59:31'), isNull, reason: 'not a date');
    });

    test('a start time is BTIME seconds before now', () {
      expect(SoopRoomParser.startedBefore(3600, _at), _at.subtract(const Duration(hours: 1)));
      expect(SoopRoomParser.startedBefore(0, _at), isNull);
      expect(SoopRoomParser.startedBefore(-5, _at), isNull);
      expect(SoopRoomParser.startedBefore('x', _at), isNull);
    });

    test('the audience is the first total that counts', () {
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': '1,234'}), '1234');
      expect(SoopRoomParser.onlineViewers({'view_cnt': 42}), '42');
      expect(SoopRoomParser.onlineViewers({'VIEW_CNT': '7'}), '7');
      expect(SoopRoomParser.onlineViewers({'pc_view_cnt': 3, 'mobile_view_cnt': 4}), '7');
      expect(SoopRoomParser.onlineViewers({'current_view_cnt': 5, 'm_current_view_cnt': 0}), '5');
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': '0'}), '0');
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': '0', 'pc_view_cnt': '0'}), '0');
      expect(SoopRoomParser.onlineViewers(const {}), '');
      expect(SoopRoomParser.onlineViewers({'total_view_cnt': 'null'}), '');
      expect(SoopRoomParser.onlineViewers({'current_view_cnt': '5'}), '5', reason: 'the last resort');
    });
  });

  group('lists', () {
    test('the category page reads the areas under the one parent', () {
      final page = SoopRoomParser.categoryPage(_categoryFixture(page: 1, isMore: true));
      expect(page.areas, hasLength(2));
      expect(page.areas.first.areaId, '01010000000');
      expect(page.areas.first.areaName, '전체');
      expect(page.areas.first.parentAreaId, SoopEndpoints.category.id);
      expect(page.areas.first.parentAreaName, SoopEndpoints.category.name);
      expect(page.areas.first.iconUrl, 'https://stimg.sooplive.co.kr/a.png');
      expect(page.areas.last.areaName, '聊天&交友', reason: 'the entities are decoded');
      expect(page.hasMore, isTrue);
      expect(SoopRoomParser.categoryPage(_categoryFixture(page: 2)).hasMore, isFalse);
      // Without is_more, a full page continues and a short one ends.
      expect(
        SoopRoomParser.categoryPage(
          _categoryFixture(
            page: 1,
            isMore: null,
            areas: List.filled(SoopEndpoints.categoryPageSize, {'category_no': '1', 'category_name': 'x'}),
          ),
        ).hasMore,
        isTrue,
      );
      expect(SoopRoomParser.categoryPage(_categoryFixture(page: 1, areas: [])).hasMore, isFalse);
    });

    test('a broken list row costs only itself', () {
      final page = SoopRoomParser.categoryPage(
        _categoryFixture(
          page: 1,
          areas: <Object?>[
            'not-an-object',
            {'no_category_no': 1},
            {'category_no': '01030000000', 'category_name': 'ok'},
          ],
        ),
      );
      expect(page.areas.single.areaId, '01030000000');
      // A list that is not a list is api-changed.
      expect(
        () => SoopRoomParser.categoryPage(
          _json({
            'result': 1,
            'data': {'list': 5, 'is_more': false},
          }),
        ),
        throwsA(predicate((e) => '$e'.contains('not a list'))),
      );
    });

    test('list cards carry their start, restriction and audience', () {
      final rooms = SoopRoomParser.areaRooms(
        _json({
          'result': 1,
          'data': {
            'list': <Object?>[
              _card(profileImage: 'https://stimg.sooplive.co.kr/p.png'),
              {..._card(id: _other), 'is_password': 'Y'},
              {..._card(id: 'subonly'), 'subscription_only': 1},
              {..._card(id: 'adult'), 'broad_grade': 19},
              {'user_id': null},
            ],
          },
        }),
        areaName: '聊天',
      );
      expect(rooms, hasLength(4));
      final first = rooms.first;
      expect(first.roomId, _id);
      expect(first.broadcast.liveStatus, LiveStatus.live);
      expect(first.broadcast.startedAt, DateTime.utc(2026, 9, 22, 10, 59, 31));
      expect(first.broadcast.restriction, isNull, reason: 'the card named no flag');
      expect(first.audience.onlineViewers, 2000);
      expect(first.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(first.anchor?.avatarUrl, 'https://stimg.sooplive.co.kr/p.png');
      expect(first.area?.areaName, '聊天');
      expect(first.links.webUrl, SoopEndpoints.roomPageUrl(_id));
      expect(rooms[1].broadcast.restriction, LiveRestriction.password);
      expect(rooms[2].broadcast.restriction, LiveRestriction.subscribersOnly);
      expect(rooms[3].broadcast.restriction, LiveRestriction.adult);
      // Restricted broadcasts stay live on the lists, as 3.x listed them.
      expect(rooms[1].broadcast.liveStatus, LiveStatus.live);
      // The area name is optional.
      final nameless = SoopRoomParser.areaRooms(
        _json({
          'result': 1,
          'data': {
            'list': <Object?>[_card()],
          },
        }),
        areaName: '',
      );
      expect(nameless.single.area, isNull);
    });

    test('the recommendation and search cards read their own cover and area', () {
      final recommend = SoopRoomParser.recommendRooms(
        _json({
          'broad': <Object?>[
            {..._card(), 'broad_thumb': '//liveimg.sooplive.co.kr/m/$_bno', 'category_name': '聊天'},
            {'no_user_id': true},
          ],
        }),
      );
      expect(recommend.single.content.coverUrl, 'https://liveimg.sooplive.co.kr/m/$_bno');
      expect(recommend.single.area?.areaName, '聊天');

      final search = SoopRoomParser.searchRooms(
        _json({
          'RESULT': 1,
          'REAL_BROAD': <Object?>[
            {..._card(), 'broad_img': 'https://liveimg.sooplive.co.kr/m/1', 'broad_cate_name': '音乐'},
            {..._card(id: _other), 'standard_broad_cate_name': '전체'},
          ],
        }),
      );
      expect(search.first.area?.areaName, '音乐');
      expect(search.last.area?.areaName, '전체');
      // A business result other than 1 is api-changed.
      expect(
        () => SoopRoomParser.searchRooms(_json({'RESULT': -1, 'REAL_BROAD': <Object?>[]})),
        throwsA(predicate((e) => '$e'.contains('RESULT -1'))),
      );
    });
  });

  group('room answers', () {
    test('a live room carries its broadcast and its presets', () {
      final detail = SoopRoomParser.roomDetail(_playerFixture(), requestedId: _id, now: _at, withDanmaku: true);
      final room = detail.room;
      expect(room.roomId, _id);
      expect(room.content.title, '标题&测试');
      expect(room.anchor?.name, '主播&甲');
      expect(room.anchor?.avatarUrl, 'https://stimg.sooplive.co.kr/LOGO/lo/$_id/$_id.jpg');
      expect(room.content.coverUrl, 'https://liveimg.sooplive.co.kr/m/$_bno?_t=${_at.millisecondsSinceEpoch}');
      expect(room.area?.areaName, '聊天');
      expect(room.audience.onlineViewers, 1234);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, _at.subtract(const Duration(hours: 1)));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, SoopEndpoints.roomPageUrl(_id));
      expect(detail.data?.bno, _bno);
      expect(detail.data?.rmd, 'https://rmd.sooplive.co.kr/api/', reason: 'kept as written; assignUrl drops it');
      expect(detail.data?.cdn, 'gs_cdn');
      expect(detail.data?.password, isFalse);
      expect(detail.data?.presets.map((preset) => preset.name), ['original', 'hd', 'sd', 'auto']);
      expect(detail.data?.presets.first.codec, 'avc');
      expect(detail.danmaku, isNotNull);
      expect(detail.danmaku?.chatNo, '12345678');
      expect(detail.danmaku?.url.host, 'chat-6e0a4c4e.sooplive.com');
      expect(detail.danmaku?.url.port, 1568, reason: 'the TLS port is CHPT + 1');
      expect(detail.danmaku?.plainUrl.port, 1567);
      expect(detail.danmaku?.url.path, '/Websocket/$_id');
    });

    test('the chat host falls back to the CHIP as hex, or nothing', () {
      final fromIp = SoopRoomParser.roomDetail(
        _playerFixture(withPreset: false, chdomain: '', chip: '110.10.76.78'),
        requestedId: _id,
        now: _at,
        withDanmaku: true,
      );
      expect(fromIp.danmaku?.url.host, 'chat-6e0a4c4e.sooplive.com');
      for (final body in [
        _playerFixture(withChat: false),
        _playerFixture(chpt: '0'),
        _playerFixture(chpt: '70000'),
        _playerFixture(chatNo: ''),
        _playerFixture(chdomain: '', chip: '999.999.999.999'),
      ]) {
        expect(
          SoopRoomParser.roomDetail(body, requestedId: _id, now: _at).danmaku,
          isNull,
          reason: body,
        );
      }
    });

    test('the other RESULTs are states, not failures', () {
      expect(
        SoopRoomParser.roomDetail(_playerFixture(result: 0), requestedId: _id, now: _at).room.broadcast.liveStatus,
        LiveStatus.offline,
      );
      expect(
        SoopRoomParser.roomDetail(_playerFixture(result: -2), requestedId: _id, now: _at).room.broadcast.liveStatus,
        LiveStatus.banned,
      );
      // RESULT 1 without VIEWPRESET is offline, as 3.x read it.
      final idle = SoopRoomParser.roomDetail(_playerFixture(withPreset: false), requestedId: _id, now: _at);
      expect(idle.room.broadcast.liveStatus, LiveStatus.offline);
      expect(idle.data, isNull);
      // A request for another streamer keeps the identity asked for.
      final renamed = SoopRoomParser.roomDetail(
        _playerFixture(bjid: 'someone'),
        requestedId: _id,
        now: _at,
      );
      expect(renamed.room.roomId, _id);
      expect(renamed.room.anchor?.avatarUrl, contains('someone'));
      // Restricted broadcasts are live with their restriction.
      final adult = SoopRoomParser.roomDetail(_playerFixture(result: -6, btime: null), requestedId: _id, now: _at);
      expect(adult.room.broadcast.liveStatus, LiveStatus.live);
      expect(adult.room.broadcast.restriction, LiveRestriction.adult);
      expect(adult.data, isNull);
      expect(adult.danmaku, isNull);
      expect(
        SoopRoomParser.roomDetail(_playerFixture(result: -8), requestedId: _id, now: _at).room.broadcast.restriction,
        LiveRestriction.password,
      );
      expect(
        SoopRoomParser.roomDetail(_playerFixture(result: -14), requestedId: _id, now: _at).room.broadcast.restriction,
        LiveRestriction.subscribersOnly,
      );
      // A password flag on a plain answer is the stricter mark.
      expect(
        SoopRoomParser.roomDetail(
          _playerFixture(bpwd: 'Y'),
          requestedId: _id,
          now: _at,
        ).room.broadcast.restriction,
        LiveRestriction.password,
      );
      // Anything else is api-changed.
      expect(
        () => SoopRoomParser.roomDetail(_playerFixture(result: -99), requestedId: _id, now: _at),
        throwsA(predicate((e) => '$e'.contains('RESULT -99'))),
      );
      expect(
        () => SoopRoomParser.roomDetail(_json({}), requestedId: _id, now: _at),
        throwsA(predicate((e) => '$e'.contains('no CHANNEL'))),
      );
    });

    test('the station is the profile, and its broadcast the state', () {
      final station = SoopRoomParser.station(_stationFixture(broad: _broad()));
      expect(station.nick, '主播甲');
      expect(station.introduction, '한국 스트리머');
      expect(station.avatar, 'https://stimg.sooplive.co.kr/LOGO/lo/$_id/m/$_id.webp');
      expect(station.broadcast?.bno, _bno);
      expect(station.broadcast?.viewers, 100);
      expect(station.broadcast?.startedAt, DateTime.utc(2026, 9, 22, 10, 59, 31));
      expect(station.broadcast?.restriction, LiveRestriction.none);
      // An unknown streamer is not-found, whatever the HTTP status said.
      expect(
        () => SoopRoomParser.station(_json({'code': 9000}), status: 515),
        throwsA(predicate((e) => e is SoopFailure && e.kind == SoopFailureKind.notFound)),
      );
      // Without a broadcast, only the profile.
      expect(SoopRoomParser.station(_stationFixture()).broadcast, isNull);
      expect(() => SoopRoomParser.station(_json({})), throwsA(predicate((e) => '$e'.contains('no station object'))));
    });

    test('the station completes the room the player API started', () {
      final detail = SoopRoomParser.roomDetail(_playerFixture(), requestedId: _id, now: _at);
      final station = SoopRoomParser.station(_stationFixture(broad: _broad()));
      final room = SoopRoomParser.withStation(detail.room, detail.data, station, now: _at);
      // The player answer already named everything it has.
      expect(room.anchor?.name, '主播&甲', reason: 'the answer had a name');
      expect(room.content.introduction, '한국 스트리머', reason: 'the tagline is the introduction');
      expect(room.audience.onlineViewers, 100, reason: "the station's figure is the fresher");
      expect(room.broadcast.startedAt, _at.subtract(const Duration(hours: 1)));
      expect(room.broadcast.restriction, LiveRestriction.none);

      // A broadcast numbered differently from the answer's means it ended
      // between the two answers: the room stands as the answer read it.
      final other = SoopRoomParser.station(_stationFixture(broad: _broad(bno: '999')));
      final stale = SoopRoomParser.withStation(detail.room, detail.data, other, now: _at);
      expect(stale.audience.onlineViewers, 1234, reason: "not the station's viewers");
      expect(stale.broadcast.restriction, LiveRestriction.none, reason: "the answer's own flags");
      expect(stale.broadcast.startedAt, _at.subtract(const Duration(hours: 1)));
      expect(stale.content.introduction, '한국 스트리머', reason: 'the profile still came along');

      // A player answer without a profile (a restricted one) is completed.
      final restricted = SoopRoomParser.roomDetail(_playerFixture(result: -6, btime: null), requestedId: _id, now: _at);
      final completed = SoopRoomParser.withStation(restricted.room, restricted.data, station, now: _at);
      expect(completed.anchor?.name, '主播甲');
      expect(completed.anchor?.avatarUrl, 'https://stimg.sooplive.co.kr/LOGO/lo/$_id/m/$_id.webp');
      expect(completed.audience.onlineViewers, 100);
      // The stricter of the two restrictions holds.
      expect(completed.broadcast.restriction, LiveRestriction.adult);
      expect(completed.broadcast.startedAt, DateTime.utc(2026, 9, 22, 10, 59, 31));

      // A room the player API calls offline but the station names is live,
      // unplayable, with the broadcast's title, cover and viewers.
      final offline = SoopRoomParser.roomDetail(_playerFixture(result: 0), requestedId: _id, now: _at);
      final revived = SoopRoomParser.withStation(offline.room, offline.data, station, now: _at);
      expect(revived.broadcast.liveStatus, LiveStatus.live);
      expect(revived.broadcast.restriction, LiveRestriction.unplayable);
      expect(revived.content.title, '방송 중');
      expect(revived.content.coverUrl, 'https://liveimg.sooplive.co.kr/m/$_bno?_t=${_at.millisecondsSinceEpoch}');
      expect(revived.audience.onlineViewers, 100);
      expect(revived.broadcast.startedAt, DateTime.utc(2026, 9, 22, 10, 59, 31));

      // A banned room stays banned.
      final banned = SoopRoomParser.roomDetail(_playerFixture(result: -2), requestedId: _id, now: _at);
      expect(
        SoopRoomParser.withStation(banned.room, banned.data, station, now: _at).broadcast.liveStatus,
        LiveStatus.banned,
      );

      // A station without a broadcast leaves the room as it is.
      final plain = SoopRoomParser.withStation(
        detail.room,
        detail.data,
        SoopRoomParser.station(_stationFixture()),
        now: _at,
      );
      expect(plain.broadcast.liveStatus, LiveStatus.live);
    });

    test('a room without a stream explains why', () {
      LiveRoom roomWith(int result) => SoopRoomParser.roomDetail(
        _playerFixture(result: result),
        requestedId: _id,
        now: _at,
      ).room;
      expect(SoopRoomParser.noStream(roomWith(-6)).kind, SoopFailureKind.needsLogin);
      expect(SoopRoomParser.noStream(roomWith(-8)).kind, SoopFailureKind.streamUnavailable);
      expect(SoopRoomParser.noStream(roomWith(-14)).kind, SoopFailureKind.streamUnavailable);
      expect(SoopRoomParser.noStream(roomWith(0)).message, contains('offline'));
      expect(SoopRoomParser.noStream(roomWith(-2)).message, contains('banned'));
    });
  });

  group('streams', () {
    final data = SoopRoomParser.roomDetail(_playerFixture(), requestedId: _id, now: _at).data!;

    test('the qualities are the presets, best first, auto left out', () {
      final qualities = SoopRoomParser.qualities(data.presets);
      expect(qualities.map((quality) => quality.qualityId), ['original', 'hd', 'sd']);
      expect(qualities.map((quality) => quality.platformOrder), [0, 1, 2]);
      expect(qualities.first.label, '原画');
      // The transcodes are named on the same scale.
      expect(
        SoopRoomParser.qualities([
          const SoopPreset(name: 'hd8k'),
          const SoopPreset(name: 'HD4K'),
          const SoopPreset(name: 'low', bps: 300000),
          const SoopPreset(name: 'mystery'),
        ]).map((quality) => quality.label),
        ['蓝光', '超清', '流畅', 'mystery'],
      );
      // Names rank by bitrate alone, below every tier.
      final odd = SoopRoomParser.qualities([
        const SoopPreset(name: 'weird', bps: 9000000),
        const SoopPreset(name: 'sd'),
        const SoopPreset(name: 'weird2', bps: 1),
      ]);
      expect(odd.map((quality) => quality.qualityId), ['sd', 'weird', 'weird2']);
      // A repeated name (case ignored) keeps one entry.
      expect(
        SoopRoomParser.qualities([const SoopPreset(name: 'hd', bps: 1), const SoopPreset(name: 'HD', bps: 2)]),
        hasLength(1),
      );
    });

    test('the assignment is asked per quality, the key appended to its answer', () {
      final url = SoopRoomParser.assignUrl(rmd: data.rmd, cdn: data.cdn, bno: _bno, quality: 'original');
      expect(url.host, 'rmd.sooplive.co.kr');
      expect(url.path, '/api/broad_stream_assign.html', reason: 'the trailing slash goes');
      expect(url.queryParameters['return_type'], 'gs_cdn_pc_web');
      expect(url.queryParameters['broad_key'], '$_bno-common-original-hls');
      expect(
        SoopRoomParser.assignUrl(
          rmd: 'https://x/y',
          cdn: 'lg_cdn',
          bno: '1',
          quality: 'hd',
        ).queryParameters['return_type'],
        'lg_cdn_pc_web',
      );
      expect(
        SoopRoomParser.assignUrl(
          rmd: 'https://x/y',
          cdn: 'other',
          bno: '1',
          quality: 'hd',
        ).queryParameters['return_type'],
        'other',
      );
      expect(
        () => SoopRoomParser.assignUrl(rmd: 'not a url', cdn: '', bno: '', quality: ''),
        throwsA(predicate((e) => '$e'.contains('not a URL'))),
      );

      expect(
        SoopRoomParser.assignedPlaylist(_json({'result': 1, 'view_url': 'https://cdn/x.m3u8'})),
        'https://cdn/x.m3u8',
      );
      expect(
        () => SoopRoomParser.assignedPlaylist(_json({'result': 0})),
        throwsA(predicate((e) => e is SoopFailure && e.kind == SoopFailureKind.streamUnavailable)),
      );
      expect(
        () => SoopRoomParser.assignedPlaylist(_json({'result': 1})),
        throwsA(predicate((e) => '$e'.contains('no view_url'))),
      );

      expect(
        SoopRoomParser.aid(
          _json({
            'CHANNEL': {'RESULT': 1, 'AID': 'key'},
          }),
        ),
        'key',
      );
      expect(
        () => SoopRoomParser.aid(
          _json({
            'CHANNEL': {'RESULT': -6},
          }),
        ),
        throwsA(predicate((e) => e is SoopFailure && e.kind == SoopFailureKind.needsLogin)),
      );
      expect(
        () => SoopRoomParser.aid(
          _json({
            'CHANNEL': {'RESULT': 0},
          }),
          password: true,
        ),
        throwsA(predicate((e) => '$e'.contains('password-protected'))),
      );

      // The line carries the media headers and the key; its format follows
      // the playlist's suffix, and it has no lease.
      final line = SoopRoomParser.resolution(
        playlist: 'https://cdn/x.m3u8',
        aid: 'key',
        roomId: _id,
        cdn: 'gs_cdn',
        codec: 'hevc',
      );
      expect(line.url, 'https://cdn/x.m3u8?aid=key');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.codec, isNotNull);
      expect(line.lineLabel, 'gs_cdn');
      expect(line.headers['referer'], SoopEndpoints.roomPageUrl(_id));
      expect(line.headers['user-agent'], SoopEndpoints.mediaUserAgent);
      expect(line.lease, isNull, reason: 'a playlist with its key keeps working');
      final flv = SoopRoomParser.resolution(playlist: 'https://cdn/x.flv?a=b', aid: 'k', roomId: _id, cdn: '');
      expect(flv.format, LiveStreamFormat.flv);
      expect(flv.url, 'https://cdn/x.flv?a=b&aid=k');
      expect(flv.lineLabel, 'cdn', reason: 'without a CDN code, the host names the line');
    });
  });

  group('links', () {
    test('a streamer page names its id, in any case', () {
      expect(SoopLink.roomIdFromUrl(Uri.parse('https://play.sooplive.co.kr/$_id/$_bno')), _id);
      expect(SoopLink.roomIdFromUrl(Uri.parse('https://ch.sooplive.co.kr/$_id')), _id);
      expect(SoopLink.roomIdFromUrl(Uri.parse('http://www.sooplive.com/$_idUpper')), _id);
      expect(SoopLink.roomIdFromUrl(Uri.parse('https://www.afreecatv.com/$_id')), _id);
      expect(SoopLink.roomIdFromUrl(Uri.parse('https://play.afreecatv.com/$_id/vod/1')), _id);
      expect(SoopLink.roomIdFromUrl(Uri.parse('https://www.sooplive.co.kr/station/$_id')), _id);
      expect(SoopLink.roomIdFromUrl(Uri.parse('https://v.naver.com/$_id')), isNull);
      expect(SoopLink.roomIdFromUrl(Uri.parse('sooplive://player/live?user_id=$_id')), isNull);
    });

    test('a page that is no room is no id', () {
      for (final bad in [
        'https://play.sooplive.co.kr/',
        'https://play.sooplive.co.kr/live',
        'https://play.sooplive.co.kr/vod',
        'https://play.sooplive.co.kr/search',
        'https://play.sooplive.co.kr/station',
        'https://play.sooplive.co.kr/station/',
        'https://play.sooplive.co.kr/a%20b',
        'ftp://www.sooplive.co.kr/$_id',
      ]) {
        expect(SoopLink.roomIdFromUrl(Uri.parse(bad)), isNull, reason: bad);
      }
    });

    test('app links are read the way list entries carry them', () {
      expect(SoopEndpoints.appLink(_id, bno: _bno), 'sooplive://player/live?broad_no=$_bno&user_id=$_id');
      expect(SoopEndpoints.appLinkRoomId(SoopEndpoints.appLink(_id, bno: _bno)), _id);
      expect(SoopEndpoints.appLinkRoomId(SoopEndpoints.appLink(_id)), _id);
      expect(SoopEndpoints.appLinkRoomId('https://player/live?user_id=$_id'), isNull);
      expect(SoopEndpoints.appLinkRoomId('sooplive://player/vod?user_id=$_id'), isNull);
      expect(SoopEndpoints.appLinkRoomId('sooplive://player/live'), isNull);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final adapter = _adapter();
      expect(adapter.site.manifest.id, 'soop');
      expect(adapter.site.manifest.aliases, contains('afreecatv'));
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
      expect(adapter.site.capability<LiveSiteCapability>(), isNull);
      await adapter.site.dispose();
    });

    test('the catalog is the one category, paged while is_more says so', () async {
      var page = 0;
      final adapter = _adapter(
        onSend: (request) => _resp(
          200,
          _categoryFixture(
            page: ++page,
            isMore: page < 2,
            areas: [
              {'category_no': 'area$page', 'category_name': 'area $page'},
            ],
          ),
        ),
      );
      expect((await adapter.site.areas()).map((area) => area.areaId), ['area1', 'area2']);
      expect(adapter.http.sent, hasLength(2));
      // A later page failing ends the catalog with what was read.
      var calls = 0;
      final partial = _adapter(
        onSend: (request) => ++calls == 1
            ? _resp(
                200,
                _categoryFixture(
                  page: 1,
                  isMore: true,
                  areas: [
                    {'category_no': 'kept', 'category_name': 'kept'},
                  ],
                ),
              )
            : _resp(500, 'boom'),
      );
      expect((await partial.site.areas()).single.areaId, 'kept');
      // A failing first page fails the catalog.
      final broken = _adapter(onSend: (_) => _resp(500, 'boom'));
      expect(_leftOf(await broken.site.capability<LiveAreaProvider>()!.getAreas()), isA<LiveSiteNetworkError>());
    });

    test('an area page carries the area name the catalog named', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      await area.getAreas();
      final page = _right(await area.getAreaRooms(areaId: '01010000000'));
      expect(page.items.single.roomId, _id);
      expect(page.items.single.area?.areaName, '전체', reason: 'the name came from the catalog');
      expect(page.hasMore, isTrue, reason: 'the page had a card');
      final url = adapter.http.sent.last.url;
      expect(url.queryParameters['m'], 'categoryContentsList');
      expect(url.queryParameters['szCateNo'], '01010000000');
      expect(url.queryParameters['nPageNo'], '1');
      expect(url.queryParameters['nListCnt'], '20');
      // An empty page is the last.
      final empty = _adapter(
        onSend: (request) => _resp(
          200,
          _json({
            'result': 1,
            'data': {'list': <Object?>[]},
          }),
        ),
      );
      final last = _right(await empty.site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'x'));
      expect(last.items, isEmpty);
      expect(last.hasMore, isFalse);
      // An empty area id is a caller error, without a request.
      final before = adapter.http.sent.length;
      expect(_leftOf(await area.getAreaRooms(areaId: ' ')), isA<LiveSiteInvalidArgument>());
      expect(adapter.http.sent.length, before);
    });

    test('the recommendations and the directory end with an empty page', () async {
      final adapter = _adapter();
      final rooms = _right(await adapter.site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest()));
      expect(rooms.items.single.roomId, _id);
      expect(rooms.hasMore, isTrue);
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final second = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2)));
      expect(second.items, isEmpty, reason: 'an empty page is the last');
      expect(second.hasMore, isFalse);
      expect(adapter.http.sent.last.url.host, 'live.sooplive.co.kr');
      expect(adapter.http.sent.last.url.queryParameters['pageNo'], '2');
    });

    test('search is one page a request, a blank keyword none', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final page = _right(await search.search(const LiveSearchRequest(query: '키워드', target: LiveSearchTarget.rooms)));
      expect((page.items.single as RoomSearchResult).room.roomId, _other);
      expect(page.hasMore, isTrue);
      final url = adapter.http.sent.last.url;
      expect(url.queryParameters['m'], 'liveSearch');
      expect(url.queryParameters['szKeyword'], '키워드');
      expect(url.queryParameters['nListCnt'], '20');
      expect(
        _right(await search.search(const LiveSearchRequest(query: '  ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
        reason: 'a blank keyword finds nothing, without a request',
      );
      expect(adapter.http.sent, hasLength(1));
    });

    test('an entry is the player answer completed with the station', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_id));
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/afreeca/player_live_api.php', '/api/$_id/station']);
      expect(room.roomId, _id);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.content.introduction, '한국 스트리머');
      expect(room.audience.onlineViewers, 100, reason: "the station's figure is the fresher");
      expect(room.runtime.streamHandle, isA<SoopRoomData>());
      expect(room.runtime.danmakuHandle, isA<SoopDanmakuArgs>());
      // The qualities and the line come from the entry.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _id));
      expect(qualities.map((quality) => quality.qualityId), ['original', 'hd', 'sd']);
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the broadcast');
      final lines = _right(await playback.getLines(roomId: _id));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.url, 'https://live.sooplive.co.kr/ver/$_bno/playlist.m3u8?aid=the-stream-key');
      expect(adapter.http.sent.length, before + 2);
      final assign = adapter.http.sent[before];
      final aid = adapter.http.sent[before + 1];
      expect(assign.url.path, '/api/broad_stream_assign.html', reason: "RMD's own path");
      expect(assign.url.queryParameters['broad_key'], '$_bno-common-original-hls');
      expect(_typeOf(aid), 'aid');
      expect(aid.form, contains('bno=$_bno'));
      // A named quality is asked for by its request name.
      await playback.getLines(roomId: _id, quality: qualities.last);
      final sdAssign = adapter.http.sent[adapter.http.sent.length - 2];
      expect(sdAssign.url.queryParameters['broad_key'], '$_bno-common-sd-hls');
    });

    test('a streamer the platform does not know is not-found', () async {
      final adapter = _adapter(
        onSend: (request) => request.url.path.endsWith('/station')
            ? _resp(515, _json({'code': 9000}))
            : _resp(200, _playerFixture(result: 0, withChat: false)),
      );
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_id)), isA<LiveSiteNotFound>());
      // An id that is no streamer id is refused without a request.
      final before = adapter.http.sent.length;
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('bad id!')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent.length, before);
    });

    test('a station that fails leaves the room standing', () async {
      final adapter = _adapter(
        onSend: (request) => request.url.path.endsWith('/station') ? _resp(500, 'boom') : _resp(200, _playerFixture()),
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_id));
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.anchor?.name, '主播&甲', reason: 'the answer had its own profile');
      expect(room.content.introduction, isNull);
    });

    test('a room without a broadcast explains its streams', () async {
      final offline = _adapter(
        onSend: (request) => request.url.path.endsWith('/station')
            ? _resp(200, _stationFixture())
            : _resp(200, _playerFixture(result: 0, withChat: false)),
      );
      final room = _right(await offline.site.capability<LiveRoomProvider>()!.getRoom(_id));
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isNull);
      expect(
        _leftOf(await offline.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _id)),
        isA<LiveSiteContentUnavailable>(),
      );
      // An age-restricted broadcast needs the platform's own login.
      final adult = _adapter(
        onSend: (request) => request.url.path.endsWith('/station')
            ? _resp(200, _stationFixture())
            : _resp(200, _playerFixture(result: -6)),
      );
      await adult.site.capability<LiveRoomProvider>()!.getRoom(_id);
      expect(
        _leftOf(await adult.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _id)),
        isA<LiveSiteAuthenticationError>(),
      );
      // A broadcast that ended since the entry keeps its number on the held
      // stream data: the key request is refused, and recovery re-enters.
      var keys = 0;
      final ended = _adapter(
        onSend: (request) {
          if (_typeOf(request) == 'aid') {
            keys++;
            return _resp(
              200,
              _json({
                'CHANNEL': {'RESULT': 0},
              }),
            );
          }
          if (request.url.path == '/api/$_id/station') return _resp(200, _stationFixture());
          if (request.url.path.endsWith('/broad_stream_assign.html')) {
            return _resp(200, _json({'result': 1, 'view_url': 'https://live.sooplive.co.kr/ver/$_bno/playlist.m3u8'}));
          }
          return _resp(200, _playerFixture());
        },
      );
      await ended.site.capability<LiveRoomProvider>()!.getRoom(_id);
      expect(
        _leftOf(await ended.site.capability<LivePlaybackProvider>()!.getLines(roomId: _id)),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(keys, 1, reason: 'the held broadcast was asked, not a fresh entry');
    });

    test('a link resolves to the room page, or says why not', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://ch.sooplive.co.kr/$_id'))),
        Uri.parse(SoopEndpoints.roomPageUrl(_id)),
      );
      expect(adapter.http.sent, isEmpty, reason: 'no request is needed');
      expect(
        _right(await link.resolve(Uri.parse('https://www.afreecatv.com/$_idUpper/vod/1'))),
        Uri.parse(SoopEndpoints.roomPageUrl(_id)),
      );
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/$_id'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://play.sooplive.co.kr/vod'))), isA<LiveSiteNotFound>());
    });

    test('a status the gate refuses is mapped', () async {
      expect(
        _leftOf(await _adapter(onSend: (_) => _resp(401, 'nope')).site.capability<LiveRoomProvider>()!.getRoom(_id)),
        isA<LiveSiteRateLimitError>(),
      );
      expect(
        _leftOf(await _adapter(onSend: (_) => _resp(429, 'slow')).site.capability<LiveRoomProvider>()!.getRoom(_id)),
        isA<LiveSiteRateLimitError>(),
      );
      // An array is not an answer's object: api-changed.
      final arrayAdapter = _adapter(onSend: (_) => _resp(200, '["array"]'));
      expect(_leftOf(await arrayAdapter.site.capability<LiveRoomProvider>()!.getRoom(_id)), isA<LiveSiteParseError>());
      // The transient kinds are exactly the transport and the throttle.
      expect(_transient(SoopFailureKind.network), isTrue);
      expect(_transient(SoopFailureKind.rateLimited), isTrue);
      expect(_transient(SoopFailureKind.riskControl), isFalse);
      expect(_transient(SoopFailureKind.notFound), isFalse);
      expect(_transient(SoopFailureKind.needsLogin), isFalse);
    });
  });
}

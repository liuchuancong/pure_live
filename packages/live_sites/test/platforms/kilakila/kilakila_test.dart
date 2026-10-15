import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/internal/built_in_sites.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
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
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_http.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_session.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_json.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_link.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _uid = '12345';
const String _otherUid = '67890';
const String _broadcast = '98765432';

String _json(Object? data) => jsonEncode(data);

Map<String, Object?> _user({String id = _uid, String nick = '主播甲', String avatar = 'https://img.kilakila.cn/a.png'}) =>
    {'id': id, 'nickname': nick, 'headPortraitUrl': avatar, 'introduction': '唱歌的'};

Map<String, Object?> _room({
  String broadcastId = _broadcast,
  String uid = _uid,
  String title = '晚间弹唱',
  int status = 4,
  int goldPrice = 0,
  Object? actualTime = 1727700000000,
  Object? online = 42,
  Object? watch = 9001,
  String backPic = 'https://img.kilakila.cn/cover.png',
  String defaultBack = 'https://img.kilakila.cn/default.png',
  String flv = '',
  String hls = '',
}) => {
  'roomIdStr': broadcastId,
  'uid': uid,
  'title': title,
  'status': status,
  'goldPrice': goldPrice,
  'backPic': backPic,
  'defaultBackgroundPicUrl': defaultBack,
  'actualTime': actualTime,
  'onlineNumber': online,
  'watchNumber': watch,
  'flvPlayUrl': flv,
  'hlsPlayUrl': hls,
};

Map<String, Object?> _timelineRow({Map<String, Object?>? room, Map<String, Object?>? user, int dataType = 8}) => {
  'dataType': dataType,
  'roomResq': room ?? _room(),
  'userResp': user ?? _user(),
};

String _timelineFixture({
  required int page,
  required int pageSize,
  List<Object?>? rows,
  Object? isLastPage = false,
  bool withEcho = true,
}) => _json({
  'code': 200,
  'data': {
    'body': {
      'h': {'code': 200, 'success': true},
      'b': {
        if (withEcho) 'pageNo': page,
        if (withEcho) 'pageSize': pageSize,
        'isLastPage': isLastPage,
        'data': rows ?? [_timelineRow()],
      },
    },
  },
});

String _profileFixture({Map<String, Object?>? liveCard, Map<String, Object?>? user, int code = 200}) => _json({
  'code': code,
  'data': {
    'userResp':
        user ??
        {
          ..._user(),
          'statisticInfo': {'followerNumber': 5678},
        },
    'liveCard': liveCard ?? _room(),
  },
});

String _roomInfoFixture({int code = 200, Map<String, Object?>? room, String uid = _uid}) => _json({
  'h': {'code': code, 'success': code == 200},
  'b': room ?? {..._room(flv: _pull(_broadcast, 'flv'), hls: _pull(_broadcast, 'm3u8')), 'userInfo': _user(id: uid)},
});

String _pull(String broadcastId, String extension) =>
    'https://pull.live.hongrenshuo.com.cn/hrs/$broadcastId.$extension?auth_key=1792000000-0-0-abcdef0123456789abcdef0123456789';

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

/// The answers of the site: the timeline, the profile, the broadcast and the
/// search page.
LiveResponse _ordinary(_Seen request) {
  final path = request.url.path;
  if (path == '/pcLive/timeline') {
    return _resp(
      200,
      _timelineFixture(
        page: int.parse(request.url.queryParameters['pageNo']!),
        pageSize: int.parse(request.url.queryParameters['pageSize']!),
      ),
    );
  }
  if (path == '/Tg/personalH5') {
    return _resp(
      200,
      _profileFixture(
        liveCard: _room(flv: _pull(_broadcast, 'flv'), hls: _pull(_broadcast, 'm3u8')),
      ),
    );
  }
  if (path == '/LiveRoom/getRoomInfo') {
    return _resp(200, _roomInfoFixture());
  }
  if (path.startsWith('/aboutus/serach/')) {
    return _resp(200, _searchPageFixture());
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

  /// The text frames sent, for a search through them.
  String get sentText => sentList.whereType<String>().join('\n');
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

  KilakilaTimers get timers => (after: _after, every: _every);

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

Future<({KilakilaDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector})> _chat() async {
  final connector = _Connector();
  final timers = FakeTimers();
  final session = KilakilaDanmakuSession(
    args: const KilakilaDanmakuArgs(roomId: _broadcast),
    site: KilakilaSite(http: KilakilaHttp(_FakeHttp(_ordinary)), connect: connector.call, now: () => _at),
    timers: timers.timers,
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (session: session, socket: connector.latest, timers: timers, connector: connector);
}

String _searchPageFixture({String body = '', String entries = 'default'}) =>
    '<html><head><title>search</title></head><body>'
    '<div class="userList">'
    '${entries == 'default' ? '<a href="/zhubo/$_uid"><span class="anchorHeaderImg"><img src="https://img.kilakila.cn/a.png"/></span><span class="anchor-name">主播甲</span></a> '
              '<a href="/zhubo/$_otherUid"><span class="anchor-name">主播&amp;乙</span></a>' : entries}'
    '$body'
    '</div></body></html>';

/// An encrypted share link with the website's codec: [plain] is the signed
/// payload text.
String _sealedLink({
  required String host,
  required String path,
  required String plain,
  String? parameter,
  String key = '7cdyGRc6Sa93ilPt',
}) {
  const iv = '93x0ue23c2c9h8km';
  final encrypted = base64Url
      .encode(AesCbc.encrypt(utf8.encode(plain), key: utf8.encode(key), iv: utf8.encode(iv)))
      .replaceAll('/', '_')
      .replaceAll('+', '-');
  return parameter == null ? 'https://$host$path$encrypted' : 'https://$host$path?$parameter=$encrypted';
}

String _md5(String value) => crypto.md5.convert(utf8.encode(value)).toString();

/// A full `text_message` frame of [event], as the wire carries it.
String _eventFrame(String event) => '42${KilakilaDanmakuCodec.namespace},$event';

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, KilakilaFailureKind kind) {
        try {
          KilakilaJson.checkStatus(status, 'x');
          fail('no throw for $status');
        } on KilakilaFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, KilakilaFailureKind.riskControl);
      expectKind(403, KilakilaFailureKind.riskControl);
      expectKind(404, KilakilaFailureKind.notFound);
      expectKind(429, KilakilaFailureKind.rateLimited);
      for (final status in [301, 500, 503]) {
        expectKind(status, KilakilaFailureKind.network);
      }
      KilakilaJson.checkStatus(200, 'x');
    });

    test('the body is bounded and must be JSON', () {
      expect(() => KilakilaJson.json('<html>', 'x', 200), throwsA(predicate((e) => '$e'.contains('not JSON'))));
      expect(
        () => KilakilaJson.json('{"a":"${'x' * 1100000}"}', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(KilakilaJson.json('{"a":1}', 'x', 200), {'a': 1});
    });

    test('a business code must be 200, a header must say success', () {
      expect(() => KilakilaJson.code(1013, 'x'), throwsA(predicate((e) => '$e'.contains('code 1013'))));
      expect(() => KilakilaJson.code(null, 'x'), throwsA(predicate((e) => '$e'.contains('no code'))));
      expect(
        () => KilakilaJson.header({
          'h': {'code': 200, 'success': false},
        }, 'x'),
        throwsA(predicate((e) => '$e'.contains('h.success'))),
      );
      KilakilaJson.header({
        'h': {'code': 200, 'success': true},
      }, 'x');
    });

    test('ids, counts and times are read strictly', () {
      expect(KilakilaJson.id(123, 'x'), '123');
      expect(KilakilaJson.id('123', 'x'), '123');
      expect(() => KilakilaJson.id(0, 'x'), throwsA(anything));
      expect(() => KilakilaJson.id(9007199254740992 + 1, 'x'), throwsA(anything));
      expect(KilakilaJson.count('42'), 42);
      expect(KilakilaJson.count(-1), isNull);
      expect(KilakilaJson.startedAt(1727700000000), DateTime.fromMillisecondsSinceEpoch(1727700000000, isUtc: true));
      expect(KilakilaJson.startedAt(1727700000), isNull, reason: 'seconds are not milliseconds');
      expect(KilakilaJson.startedAt(0), isNull);
    });
  });

  group('timeline', () {
    test('the live rows are read, the other kinds skipped', () {
      final page = KilakilaRoomParser.timelinePage(
        _timelineFixture(
          page: 1,
          pageSize: 10,
          rows: [
            _timelineRow(),
            _timelineRow(dataType: 3),
            _timelineRow(
              room: _room(uid: _otherUid, broadcastId: '87654321'),
              user: _user(id: _otherUid, nick: '主播乙'),
            ),
            _timelineRow(room: _room(), user: _user(), dataType: 2),
          ],
        ),
        page: 1,
        pageSize: 10,
        type: 0,
      );
      expect(page.rooms.map((room) => room.uid), [_uid, _otherUid], reason: 'other kinds and repeats skipped');
      expect(page.hasMore, isTrue);
    });

    test('the rising stars take their own rows', () {
      final page = KilakilaRoomParser.timelinePage(
        _timelineFixture(page: 1, pageSize: 10, rows: [_timelineRow(dataType: 2)]),
        page: 1,
        pageSize: 10,
        type: 107,
      );
      expect(page.rooms, hasLength(1));
      expect(
        KilakilaRoomParser.timelinePage(
          _timelineFixture(page: 1, pageSize: 10, rows: [_timelineRow(dataType: 2)]),
          page: 1,
          pageSize: 10,
          type: 0,
        ).rooms,
        isEmpty,
        reason: 'the hot timeline skips them',
      );
    });

    test('a broken row costs only itself, unless none is usable', () {
      final page = KilakilaRoomParser.timelinePage(
        _timelineFixture(
          page: 1,
          pageSize: 10,
          rows: [
            _timelineRow(),
            _timelineRow(room: _room(title: '')),
          ],
        ),
        page: 1,
        pageSize: 10,
        type: 0,
      );
      expect(page.rooms, hasLength(1));
      expect(
        () => KilakilaRoomParser.timelinePage(
          _timelineFixture(
            page: 1,
            pageSize: 10,
            rows: [_timelineRow(room: _room(title: ''))],
          ),
          page: 1,
          pageSize: 10,
          type: 0,
        ),
        throwsA(predicate((e) => '$e'.contains('broken rows, none usable'))),
      );
    });

    test('a page that does not echo itself, or ends oddly, is api-changed', () {
      for (final body in [
        _timelineFixture(page: 2, pageSize: 10),
        _timelineFixture(page: 1, pageSize: 20),
        _timelineFixture(page: 1, pageSize: 10, withEcho: false),
        _timelineFixture(page: 1, pageSize: 10, isLastPage: 'yes'),
        _timelineFixture(page: 1, pageSize: 10, rows: List.filled(1001, _timelineRow())),
      ]) {
        expect(
          () => KilakilaRoomParser.timelinePage(body, page: 1, pageSize: 10, type: 0),
          throwsA(isA<KilakilaFailure>()),
        );
      }
    });

    test('the timeline ends at isLastPage, an empty page and the last page', () {
      expect(
        KilakilaRoomParser.timelinePage(
          _timelineFixture(page: 1, pageSize: 10, isLastPage: true),
          page: 1,
          pageSize: 10,
          type: 0,
        ).hasMore,
        isFalse,
      );
      expect(
        KilakilaRoomParser.timelinePage(
          _timelineFixture(page: 41, pageSize: 10, rows: []),
          page: 41,
          pageSize: 10,
          type: 0,
        ).hasMore,
        isFalse,
        reason: 'the rising stars end with an empty page and no isLastPage',
      );
      expect(
        KilakilaRoomParser.timelinePage(
          _timelineFixture(page: 100, pageSize: 10),
          page: 100,
          pageSize: 10,
          type: 0,
        ).hasMore,
        isFalse,
        reason: 'the platform has a last page',
      );
    });
  });

  group('search page', () {
    test('the anchors of the user list, once each', () {
      final rooms = KilakilaRoomParser.searchPage(_searchPageFixture());
      expect(rooms.map((room) => room.roomId), [_uid, _otherUid]);
      expect(rooms.first.anchor?.name, '主播甲');
      expect(rooms.first.content.title, '主播甲', reason: 'the name is also the title');
      expect(rooms.first.anchor?.avatarUrl, 'https://img.kilakila.cn/a.png');
      expect(rooms.last.anchor?.name, '主播&乙', reason: 'the references are decoded');
      expect(rooms.every((room) => room.broadcast.liveStatus == LiveStatus.unknown), isTrue);
    });

    test('a broken entry costs only itself, unless none is usable', () {
      final withBroken = KilakilaRoomParser.searchPage(
        _searchPageFixture(body: '<a href="/zhubo/x"><span class="anchor-name">no id</span></a>'),
      );
      expect(withBroken, hasLength(2));
      expect(
        () => KilakilaRoomParser.searchPage(
          _searchPageFixture(body: '<a href="/zhubo/x"><span class="anchor-name">no id</span></a>', entries: ''),
        ),
        throwsA(predicate((e) => '$e'.contains('broken entries, none usable'))),
      );
      expect(
        () => KilakilaRoomParser.searchPage('<html><body>nothing</body></html>'),
        throwsA(predicate((e) => '$e'.contains('no user list'))),
      );
    });

    test('a keyword is cut without cutting a surrogate pair', () {
      expect(KilakilaRoomParser.searchKeyword('  hi  '), 'hi');
      final long = 'a' * 100 + '𝄞';
      expect(KilakilaRoomParser.searchKeyword(long).length, 100);
      expect(KilakilaRoomParser.searchKeyword(long).codeUnits.last, lessThan(0xD800));
    });
  });

  group('profile and broadcast', () {
    test('the profile of an anchor with a current broadcast', () {
      final profile = KilakilaRoomParser.profile(_profileFixture(), uid: _uid);
      expect(profile.uid, _uid);
      expect(profile.nick, '主播甲');
      expect(profile.introduction, '唱歌的');
      expect(profile.followers, 5678);
      expect(profile.current?.broadcastId, _broadcast);
    });

    test('a liveCard of only routing defaults means no broadcast', () {
      final profile = KilakilaRoomParser.profile(
        _profileFixture(liveCard: {'roomSourceType': 1, 'recommendSource': 2}),
        uid: _uid,
      );
      expect(profile.current, isNull);
      expect(KilakilaRoomParser.profile(_profileFixture(liveCard: {}), uid: _uid).current, isNull);
      expect(
        () => KilakilaRoomParser.profile(_profileFixture(liveCard: {'roomSourceType': -1}), uid: _uid),
        throwsA(isA<KilakilaFailure>()),
      );
    });

    test('a card of another anchor, an empty name and code 1013 are refused', () {
      expect(
        () => KilakilaRoomParser.profile(
          _profileFixture(liveCard: _room(uid: _otherUid)),
          uid: _uid,
        ),
        throwsA(predicate((e) => '$e'.contains('another anchor'))),
      );
      expect(
        () => KilakilaRoomParser.profile(_profileFixture(user: {..._user(), 'nickname': ''}), uid: _uid),
        throwsA(predicate((e) => '$e'.contains('not the anchor'))),
      );
      expect(
        () => KilakilaRoomParser.profile(_profileFixture(code: 1013), uid: _uid),
        throwsA(predicate((e) => e is KilakilaFailure && e.kind == KilakilaFailureKind.notFound)),
      );
    });

    test('the broadcast answer names its ids and its pull urls', () {
      final broadcast = KilakilaRoomParser.roomInfo(_roomInfoFixture(), broadcastId: _broadcast, uid: _uid);
      expect(broadcast.broadcastId, _broadcast);
      expect(broadcast.isLive, isTrue);
      expect(broadcast.flv, _pull(_broadcast, 'flv'));
      expect(broadcast.hls, _pull(_broadcast, 'm3u8'));
      expect(broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000000, isUtc: true));
      expect(broadcast.online, 42);
      expect(broadcast.total, 9001);
      expect(broadcast.restriction, LiveRestriction.none);
      expect(
        () => KilakilaRoomParser.roomInfo(_roomInfoFixture(), broadcastId: '1', uid: _uid),
        throwsA(predicate((e) => '$e'.contains('another broadcast'))),
      );
      expect(
        () => KilakilaRoomParser.roomInfo(_roomInfoFixture(code: 5201), broadcastId: _broadcast),
        throwsA(predicate((e) => e is KilakilaFailure && e.kind == KilakilaFailureKind.notFound)),
      );
      expect(
        () => KilakilaRoomParser.roomInfo(_roomInfoFixture(code: 5966), broadcastId: _broadcast),
        throwsA(predicate((e) => e is KilakilaFailure && e.kind == KilakilaFailureKind.streamUnavailable)),
      );
    });

    test('a pull url must be the cdn https address of its own broadcast', () {
      expect(KilakilaRoomParser.mediaUrl(_pull('1', 'flv'), broadcastId: '1', isHls: false), _pull('1', 'flv'));
      for (final bad in [
        'http://pull.live.hongrenshuo.com.cn/hrs/1.flv?auth_key=x',
        'https://evil.com/hrs/1.flv?auth_key=x',
        'https://pull.live.hongrenshuo.com.cn/other/1.flv?auth_key=x',
        'https://pull.live.hongrenshuo.com.cn/hrs/1.png?auth_key=x',
        'https://pull.live.hongrenshuo.com.cn/hrs/2.flv?auth_key=x',
        'https://pull.live.hongrenshuo.com.cn/hrs/1.flv',
        'rtmp://pull.live.hongrenshuo.com.cn/hrs/1',
      ]) {
        expect(KilakilaRoomParser.mediaUrl(bad, broadcastId: '1', isHls: false), isNull, reason: bad);
      }
    });

    test('a paid broadcast is marked, an ended one is offline', () {
      final paid = KilakilaRoomParser.room(
        KilakilaRoomParser.roomInfo(
          _roomInfoFixture(room: {..._room(goldPrice: 100), 'userInfo': _user()}),
          broadcastId: _broadcast,
        ),
      );
      expect(paid.broadcast.restriction, LiveRestriction.paid);
      final ended = KilakilaRoomParser.room(
        KilakilaRoomParser.roomInfo(
          _roomInfoFixture(room: {..._room(status: 10), 'userInfo': _user()}),
          broadcastId: _broadcast,
        ),
      );
      expect(ended.broadcast.liveStatus, LiveStatus.offline);
      expect(ended.audience.primaryMetric, LiveAudienceMetricType.unknown);
    });
  });

  group('streams', () {
    test('the one quality with its flv and hls lines, leased', () {
      final issuedAt = _at;
      final data = KilakilaRoomData(
        issuedAt: issuedAt,
        broadcast: KilakilaRoomParser.roomInfo(_roomInfoFixture(), broadcastId: _broadcast, uid: _uid),
      );
      final qualities = KilakilaRoomParser.qualities(data);
      expect(qualities.single.qualityId, KilakilaEndpoints.qualityId);
      expect(qualities.single.label, '原画');
      final lines = KilakilaRoomParser.lines(data, KilakilaEndpoints.qualityId);
      expect(lines, hasLength(2));
      expect(lines.first.format, LiveStreamFormat.flv);
      expect(lines.first.lineLabel, 'flv');
      expect(lines.last.format, LiveStreamFormat.hls);
      expect(lines.first.headers['referer'], '${KilakilaEndpoints.origin}/');
      // The lease stops at the auth_key's first field, renewed early.
      final lease = lines.last.lease!;
      final expiresAt = lease.expiresAt!;
      expect(expiresAt, DateTime.fromMillisecondsSinceEpoch(1792000000 * 1000, isUtc: true));
      expect(lease.refreshAt.isBefore(expiresAt), isTrue);
      expect(lease.requiresReconnect, isTrue, reason: 'an expired playlist ends playback');
      expect(lines.first.lease!.requiresReconnect, isFalse, reason: 'an established flv connection keeps flowing');
      // 3.x's quality ids name the same quality.
      expect(KilakilaEndpoints.qualityIdFromLegacy('flv'), KilakilaEndpoints.qualityId);
      expect(KilakilaEndpoints.qualityIdFromLegacy('HLS'), KilakilaEndpoints.qualityId);
      expect(() => KilakilaRoomParser.lines(data, '720p'), throwsA(predicate((e) => '$e'.contains('not offered'))));
    });

    test('a broadcast that cannot play says why', () {
      KilakilaRoomData withRoom(Map<String, Object?> room) => KilakilaRoomData(
        issuedAt: _at,
        broadcast: KilakilaRoomParser.roomInfo(
          _roomInfoFixture(room: {...room, 'userInfo': _user()}),
          broadcastId: _broadcast,
        ),
      );
      expect(
        () => KilakilaRoomParser.qualities(KilakilaRoomData(issuedAt: _at)),
        throwsA(predicate((e) => '$e'.contains('no current broadcast'))),
      );
      expect(
        () => KilakilaRoomParser.qualities(withRoom(_room(goldPrice: 5))),
        throwsA(predicate((e) => '$e'.contains('restricted'))),
      );
      expect(
        () => KilakilaRoomParser.qualities(withRoom(_room(status: 10))),
        throwsA(predicate((e) => '$e'.contains('status 10'))),
      );
      expect(
        () => KilakilaRoomParser.qualities(withRoom(_room())),
        throwsA(predicate((e) => '$e'.contains('no pull URL'))),
      );
    });
  });

  group('links', () {
    test('plain anchor and broadcast pages', () {
      expect(KilakilaLink.parse('https://live.kilakila.cn/zhubo/$_uid')?.kind, KilakilaLinkKind.owner);
      expect(KilakilaLink.parse('https://live.kilakila.cn/zhubo/$_uid')?.id, _uid);
      expect(KilakilaLink.parse('http://www.hongdoufm.com/zhubo/$_uid')?.kind, KilakilaLinkKind.owner);
      expect(KilakilaLink.parse('https://live.kilakila.cn/room/$_broadcast')?.kind, KilakilaLinkKind.broadcast);
      expect(KilakilaLink.parse('https://live.kilakila.cn/PcLive/index/detail?id=$_broadcast')?.id, _broadcast);
      expect(
        KilakilaLink.parse('https://live.hongrenshuo.com.cn/index/roomuser/uid/$_uid')?.kind,
        KilakilaLinkKind.owner,
      );
    });

    test('a page that is no room, or an id with a leading zero, is no link', () {
      for (final bad in [
        'https://live.kilakila.cn/',
        'https://live.kilakila.cn/zhubo/',
        'https://live.kilakila.cn/zhubo/0123',
        'https://live.kilakila.cn/zhubo/$_uid?x=1',
        'https://live.kilakila.cn/room/$_broadcast#f',
        'https://u:lives.jd.com/zhubo/$_uid',
        'https://live.kilakila.cn:8080/zhubo/$_uid',
        'https://evil.com/zhubo/$_uid',
        'ftp://live.kilakila.cn/zhubo/$_uid',
      ]) {
        expect(KilakilaLink.parse(bad), isNull, reason: bad);
      }
    });

    test('an encrypted share link is decrypted and its signature checked', () {
      // The canonical signed text: prefix + origin + pathPrefix + id? + sorted
      // pairs.
      final good = _sealedLink(
        host: 'live.kilakila.cn',
        path: '/zhubo/',
        plain:
            '$_uid?from=share&t=1&sign=${_md5('pR@Wv%Wju@Pl&bKc\$GyUrPeOhttps://live.kilakila.cn/zhubo/$_uid?from=share&t=1')}',
      );
      final parsed = KilakilaLink.parse(good);
      expect(parsed?.kind, KilakilaLinkKind.owner);
      expect(parsed?.id, _uid);
      // A second key also opens it.
      expect(
        KilakilaLink.parse(
          _sealedLink(
            host: 'live.kilakila.cn',
            path: '/zhubo/',
            key: 'c98be79a4347bc97',
            plain:
                '$_uid?from=share&t=1&sign=${_md5('pR@Wv%Wju@Pl&bKc\$GyUrPeOhttps://live.kilakila.cn/zhubo/$_uid?from=share&t=1')}',
          ),
        )?.id,
        _uid,
      );
      // A tampered signature is no link.
      expect(
        KilakilaLink.parse(
          _sealedLink(host: 'live.kilakila.cn', path: '/zhubo/', plain: '$_uid?from=share&t=1&sign=${'0' * 32}'),
        ),
        isNull,
      );
    });

    test('an encrypted detail page is read from _specific_parameter', () {
      final link = _sealedLink(
        host: 'live.kilakila.cn',
        path: '/PcLive/index/detail',
        parameter: '_specific_parameter',
        plain:
            'gift=1&sign=${_md5('pR@Wv%Wju@Pl&bKc\$GyUrPeOhttps://live.kilakila.cn/PcLive/index/detail?gift=1&id=$_broadcast')}&id=$_broadcast',
      );
      final parsed = KilakilaLink.parse(link);
      expect(parsed?.kind, KilakilaLinkKind.broadcast);
      expect(parsed?.id, _broadcast);
    });
  });

  group('chat protocol', () {
    test('the socket address and the join frame name the broadcast', () {
      final endpoint = KilakilaDanmakuCodec.endpoint(_broadcast);
      expect(endpoint.host, 'wim.hongrenshuo.com.cn');
      expect(endpoint.queryParameters['roomId'], _broadcast);
      expect(endpoint.queryParameters['EIO'], '3');
      expect(
        KilakilaDanmakuCodec.join(_broadcast),
        '40/live_chat_room_guest?roomId=$_broadcast&appId=111&clientType=1,',
      );
    });

    KilakilaDanmakuFrame frame(String text) => KilakilaDanmakuCodec.decode(text, roomId: _broadcast);

    test('the engine.io and socket.io packets are told apart', () {
      expect(frame('1').dropped, isTrue, reason: 'engine.io closing');
      expect(frame('3'), KilakilaDanmakuFrame.empty, reason: 'a pong');
      expect(frame('6'), KilakilaDanmakuFrame.empty, reason: 'a noop');
      expect(frame('40/live_chat_room_guest,').joined, isTrue);
      expect(frame('41/live_chat_room_guest,').dropped, isTrue);
      expect(frame('44/live_chat_room_guest,"boom"').refusal, 'boom');
      expect(frame('40/other,').joined, isFalse, reason: 'another namespace');
      expect(frame('42/live_chat_room_guest,not json'), KilakilaDanmakuFrame.empty);
      expect(KilakilaDanmakuCodec.decode(1, roomId: _broadcast), KilakilaDanmakuFrame.empty);
    });

    test('connect_error code 0 is the join, another code a refusal', () {
      expect(
        frame(
          '42/live_chat_room_guest,${_json([
            'connect_error',
            _json({'code': 0}),
          ])}',
        ).joined,
        isTrue,
      );
      final refusal = frame(
        '42/live_chat_room_guest,${_json([
          'connect_error',
          _json({'code': 1, 'message': 'full'}),
        ])}',
      );
      expect(refusal.refusal, 'full');
      expect(
        frame(
          '42/live_chat_room_guest,${_json([
            'connect_error',
            _json({'code': 2}),
          ])}',
        ).refusal,
        'code 2',
      );
    });

    test('a chat line is read from the double json', () {
      final text = _json([
        'text_message',
        _json({
          'body': {
            'response': {
              'room_id': _broadcast,
              'mid': 'm-1',
              'created_at': 1727700000000,
              'content': _json({'t': 200, 'c': '大家好', 'n': '观众甲', 'u': 777, 'l': 8}),
            },
          },
        }),
      ]);
      final chat = frame(_eventFrame(text)).messages.single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, '大家好');
      expect(chat.effectiveSender.userName, '观众甲');
      expect(chat.effectiveSender.userId, '777');
      expect(chat.effectiveSender.userLevel, '8');
      expect(chat.messageId, 'm-1');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1727700000000));
      // Another broadcast's line is not this room's.
      final other = _json([
        'text_message',
        _json({
          'body': {
            'response': {
              'room_id': '9',
              'content': _json({'t': 200, 'c': 'x', 'n': 'y'}),
            },
          },
        }),
      ]);
      expect(frame(_eventFrame(other)).messages, isEmpty);
    });

    test('the room state carries the listeners now', () {
      final text = _json([
        'text_message',
        _json({
          'body': {
            'response': {
              'room_id': _broadcast,
              'content': _json({
                't': 637,
                'c': Uri.encodeQueryComponent(_json({'watchNumber': 123})).replaceAll('+', '%20'),
              }),
            },
          },
        }),
      ]);
      final audience = frame(_eventFrame(text)).messages.single;
      expect(audience.type, LiveMessageType.audienceUpdate);
      expect(
        audience.payload,
        isA<LiveAudienceUpdate>()
            .having((p) => p.kind, 'kind', LiveAudienceSignalKind.onlineViewers)
            .having((p) => p.value, 'value', 123),
      );
    });

    test('a gift is priced in red beans, a combo counted', () {
      LiveMessage giftOf(Map<String, Object?> content) => frame(
        _eventFrame(
          _json([
            'text_message',
            _json({
              'body': {
                'response': {
                  'room_id': _broadcast,
                  'mid': 'm-2',
                  'created_at': 1727700000000,
                  'content': _json(content),
                },
              },
            }),
          ]),
        ),
      ).messages.single;

      final hit = giftOf({
        't': 220,
        'c': {
          'id': 5,
          'name': ' 飞天小猪 ',
          'pic': 'https://img.kilakila.cn/g.png',
          'isDoubleHit': true,
          'doubleCount': 3,
          'price': 204,
          'no': 901,
          'giftReceiverName': ' 主播甲 ',
        },
        'n': '观众丙',
        'u': 888,
        'l': '12',
      });
      final gift = hit.payload! as LiveGift;
      expect(gift.name, '飞天小猪');
      expect(gift.count, 3);
      expect(gift.value.unit, LiveGiftUnit.gold);
      expect(gift.value.totalValue, 204);
      expect(gift.value.unitPrice, 68, reason: '204 divides by 3');
      expect(gift.combo.comboKey, '901');
      expect(gift.combo.comboTotal, 3);
      expect(gift.recipientName, '主播甲');
      expect(hit.text, '飞天小猪 ×3');
      expect(hit.effectiveSender.userLevel, '12');

      final line = giftOf({
        't': 10004,
        'c': {'id': 5, 'name': '飞天小猪', 'doubleCount': 3, 'price': 68, 'no': 901},
        'n': '观众丙',
        'u': 888,
      });
      final lineGift = line.payload! as LiveGift;
      expect(lineGift.value.unitPrice, 68, reason: 'the line prices one gift');
      expect(lineGift.combo.comboTotal, 3);

      final free = giftOf({
        't': 220,
        'c': {'id': 6, 'name': '克拉之星', 'doubleCount': 1, 'price': 0, 'no': 902},
        'n': '观众丙',
        'u': 888,
      });
      expect((free.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect(
        KilakilaDanmakuCodec.decode(
          _json([
            'text_message',
            _json({
              'body': {
                'response': {
                  'room_id': _broadcast,
                  'content': _json({
                    't': 220,
                    'c': {'id': 6, 'name': '', 'no': 903},
                    'n': 'x',
                    'u': 1,
                  }),
                },
              },
            }),
          ]),
          roomId: _broadcast,
        ).messages,
        isEmpty,
        reason: 'a gift without a name is nothing',
      );
    });

    test('a paid question on the board is a super chat', () {
      LiveMessage? questionOf(Map<String, Object?> uc) => frame(
        _eventFrame(
          _json([
            'text_message',
            _json({
              'body': {
                'response': {
                  'room_id': _broadcast,
                  'created_at': 1727700000000,
                  'content': _json({'t': 240, 'uc': uc}),
                },
              },
            }),
          ]),
        ),
      ).messages.firstOrNull;

      final shown = questionOf({
        'uiType': 2,
        'question': {
          'questionId': 42,
          'questionNickname': '观众丁',
          'questionHeadUrl': 'https://img.kilakila.cn/d.png',
          'questionUid': 999,
          'content': Uri.encodeQueryComponent('唱一首晴天'),
          'goldPrice': 6000,
        },
      });
      expect(shown, isNotNull);
      expect(shown!.type, LiveMessageType.superChat);
      expect(shown.text, '唱一首晴天');
      expect(shown.effectiveSender.userName, '观众丁');
      final superChat = shown.payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, 6000);
      expect(superChat.price.displayText, '6,000红豆');
      final start = superChat.startTime;
      final end = superChat.endTime;
      expect(end!.difference(start!), KilakilaDanmakuCodec.questionDisplay);
      // A cleared board, a free question and a board without a question give
      // nothing.
      expect(
        questionOf({
          'uiType': 8,
          'question': {'content': 'x', 'goldPrice': 1},
        }),
        isNull,
      );
      expect(
        questionOf({
          'uiType': 2,
          'question': {'content': 'x', 'goldPrice': 0},
        }),
        isNull,
      );
      expect(questionOf({'uiType': 2}), isNull);
    });

    test('an amount is written with thousands separated', () {
      expect(KilakilaDanmakuCodec.amount(6000), '6,000');
      expect(KilakilaDanmakuCodec.amount(999), '999');
      expect(KilakilaDanmakuCodec.amount(1234567), '1,234,567');
    });
  });

  group('combo filter', () {
    LiveMessage comboHit(String key, int count) {
      final frameText = _json([
        'text_message',
        _json({
          'body': {
            'response': {
              'room_id': _broadcast,
              'content': _json({
                't': 220,
                'c': {
                  'id': 5,
                  'name': '飞天小猪',
                  'isDoubleHit': true,
                  'doubleCount': count,
                  'price': count * 10,
                  'no': key,
                },
                'n': '观众',
                'u': 1,
              }),
            },
          },
        }),
      ]);
      return KilakilaDanmakuCodec.decode(_eventFrame(frameText), roomId: _broadcast).messages.single;
    }

    test('a hit or line that only repeats a count is left out', () {
      final combos = KilakilaGiftCombos();
      expect(combos.report(comboHit('1', 1)), isTrue);
      expect(combos.report(comboHit('1', 2)), isTrue);
      expect(combos.report(comboHit('1', 2)), isFalse, reason: 'the same count again');
      expect(combos.report(comboHit('2', 1)), isTrue, reason: 'a new combo');
      // The capacity forgets the oldest.
      for (var index = 0; index < KilakilaGiftCombos.capacity + 1; index++) {
        combos.report(comboHit('fill-$index', 1));
      }
      expect(combos.report(comboHit('1', 2)), isTrue, reason: 'the forgotten combo reports again');
    });
  });

  group('comment session', () {
    test('a session joins the namespace and pings', () async {
      final chat = await _chat();
      expect(chat.connector.endpoints.single.host, 'wim.hongrenshuo.com.cn');
      expect(chat.connector.endpoints.single.queryParameters['roomId'], _broadcast);
      expect(chat.socket.sentText, KilakilaDanmakuCodec.join(_broadcast), reason: 'the join goes out at once');
      chat.timers.ring(index: chat.timers.every.length - 1);
      expect(chat.socket.sentText, endsWith(KilakilaDanmakuCodec.ping), reason: 'the engine.io ping');
      expect(chat.timers.every.single.period, KilakilaDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        containsAll([KilakilaDanmakuCodec.joinTimeout, KilakilaDanmakuCodec.silenceTimeout]),
      );
      await chat.session.dispose();
    });

    test('the join is confirmed by the 40 or by connect_error 0', () async {
      final chat = await _chat();
      final after = _next(chat.session.events, 1);
      chat.socket.push('40/live_chat_room_guest,');
      chat.socket.push(
        _eventFrame(
          _json([
            'text_message',
            _json({
              'body': {
                'response': {
                  'room_id': _broadcast,
                  'content': _json({'t': 200, 'c': 'hi', 'n': 'x', 'u': 1}),
                },
              },
            }),
          ]),
        ),
      );
      expect((await after).single.text, 'hi');
      await chat.session.dispose();
    });

    test('a refused join is retried, and the next refusal ends the session', () async {
      final connector = _Connector();
      final timers = FakeTimers();
      final session = KilakilaDanmakuSession(
        args: const KilakilaDanmakuArgs(roomId: _broadcast),
        site: KilakilaSite(http: KilakilaHttp(_FakeHttp(_ordinary)), connect: connector.call, now: () => _at),
        timers: timers.timers,
      );
      expect(await session.connect(), isNull);
      await _settle();
      final refusal =
          '42/live_chat_room_guest,${_json([
            'connect_error',
            _json({'code': 1, 'message': 'full'}),
          ])}';
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < KilakilaDanmakuCodec.maxRefusals; attempt++) {
        connector.latest.push(refusal);
        await _settle();
        timers.fire(index: timers.after.length - 1);
        await _settle();
      }
      expect(connector.sockets, hasLength(KilakilaDanmakuCodec.maxRefusals + 1), reason: 'three replacements');
      connector.latest.push(refusal);
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await session.dispose();
    });

    test('a socket that never joins, goes silent or is dropped is replaced', () async {
      final chat = await _chat();
      final first = chat.socket;
      // No join in time: the socket is replaced.
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(identical(chat.connector.latest, first), isFalse);
      expect(first.closed, isTrue);
      // The join is confirmed, then the server leaves: replaced again.
      chat.connector.latest.push('40/live_chat_room_guest,');
      chat.connector.latest.push('41/live_chat_room_guest,');
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      // Silence: replaced again, and the answered frames keep the count down.
      for (var attempt = 0; attempt < 2; attempt++) {
        chat.connector.latest.push('40/live_chat_room_guest,');
        chat.connector.latest.push('3');
        await _settle();
        chat.timers.fire(index: chat.timers.after.length - 1);
        await _settle();
        chat.connector.latest.push('3');
        await _settle();
      }
      expect(chat.session, isNotNull);
      await chat.session.dispose();
    });

    test('an id that is no broadcast is refused before any request', () async {
      final connector = _Connector();
      final session = KilakilaDanmakuSession(
        args: const KilakilaDanmakuArgs(roomId: 'x'),
        site: KilakilaSite(http: KilakilaHttp(_FakeHttp(_ordinary)), connect: connector.call, now: () => _at),
        timers: FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      expect(connector.sockets, isEmpty);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final site = KilakilaSite(http: KilakilaHttp(_FakeHttp(_ordinary)), connect: _refuseSocket, now: () => _at);
      expect(site.manifest.id, 'kilakila');
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
      final built = createBuiltInLiveSites(http: _FakeHttp((_) => _resp(200, '{}')));
      expect(built.map((entry) => entry.manifest.id), contains('kilakila'));
    });

    test('a timeline page starts the sequence, repeats are left out', () async {
      final adapter = _adapter();
      final rooms = adapter.site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.items.map((room) => room.roomId), [_uid]);
      expect(first.hasMore, isTrue);
      expect(adapter.http.sent.single.url.queryParameters, {
        'tag': '0',
        'type': '0',
        'genderType': '0',
        'pageNo': '1',
        'pageSize': '20',
      });
      final second = _right(await rooms.getRooms(const LivePageRequest(page: 2)));
      expect(second.items, isEmpty, reason: 'the page repeats its anchors, which are left out');
      expect(_right(await rooms.getRooms(const LivePageRequest(page: 3))).hasMore, isTrue);
      expect(
        _right(await rooms.getRooms(const LivePageRequest(page: 4))).hasMore,
        isFalse,
        reason: 'three idle pages end it',
      );
    });

    test('the timelines are the areas, and another one is refused', () async {
      final adapter = _adapter();
      final area = adapter.site.capability<LiveAreaProvider>()!;
      expect(_right(await area.getAreas()).map((entry) => entry.areaId), ['0', '107']);
      expect(_right(await area.getAreaRooms(areaId: '107')).items, hasLength(1));
      expect(adapter.http.sent.last.url.queryParameters['type'], '107');
      expect(_leftOf(await area.getAreaRooms(areaId: 'dance')), isA<LiveSiteInvalidArgument>());
      // Past the platform's last page: an empty last page, without a request.
      final before = adapter.http.sent.length;
      final past = _right(await area.getAreaRooms(areaId: '0', request: const LivePageRequest(page: 101)));
      expect(past.items, isEmpty);
      expect(past.hasMore, isFalse);
      expect(adapter.http.sent.length, before);
    });

    test('an entry is the profile and the broadcast, with its handles', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid));
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/Tg/personalH5', '/LiveRoom/getRoomInfo']);
      expect(room.roomId, _uid, reason: 'the anchor is the room');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.danmakuHandle, isA<KilakilaDanmakuArgs>());
      expect(room.content.introduction, '唱歌的');
      expect(room.anchor?.followerCount, 5678);
      expect(room.audience.onlineViewers, 42);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.startedAt, isNotNull);
      // The qualities and lines come from the entry, without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final before = adapter.http.sent.length;
      final qualities = _right(await playback.getQualities(roomId: _uid));
      expect(qualities.single.qualityId, 'original');
      final lines = _right(await playback.getLines(roomId: _uid));
      expect(lines, hasLength(2));
      expect(adapter.http.sent.length, before, reason: 'the entry already holds the pull urls');
    });

    test('an anchor without a broadcast is offline and names no chat', () async {
      final adapter = _adapter(
        onSend: (request) => switch (request.url.path) {
          '/Tg/personalH5' => _resp(200, _profileFixture(liveCard: {'roomSourceType': 1})),
          _ => _resp(200, '{}'),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid));
      expect(adapter.http.sent, hasLength(1), reason: 'the profile alone');
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isNull);
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _uid)),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('a search finds the uid, the broadcast link and the keyword', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final byUid = await search.search(const LiveSearchRequest(query: _uid, target: LiveSearchTarget.rooms));
      expect((_right(byUid).items.single as RoomSearchResult).room.roomId, _uid);
      expect(adapter.http.sent, hasLength(1), reason: 'one profile request');
      final byLink = await search.search(
        const LiveSearchRequest(query: 'https://live.kilakila.cn/room/$_broadcast', target: LiveSearchTarget.rooms),
      );
      expect((_right(byLink).items.single as RoomSearchResult).room.roomId, _uid);
      expect(
        adapter.http.sent.last.url.path,
        '/Tg/personalH5',
        reason: 'the broadcast names its anchor, whose profile is read',
      );
      final byKeyword = await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms));
      expect(_right(byKeyword).items.map((item) => (item as RoomSearchResult).room.roomId), [_uid, _otherUid]);
      expect(adapter.http.sent.last.url.pathSegments.take(3), ['aboutus', 'serach', 'kw']);
      expect(_right(byKeyword).hasMore, isNull, reason: 'the search page says nothing about pages');
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: _uid, target: LiveSearchTarget.rooms, page: 2)))
            .items,
        isEmpty,
      );
      expect(
        _leftOf(
          await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms, pageSize: 101)),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('a link is canonicalized, a broadcast link needs its anchor', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('https://live.kilakila.cn/zhubo/$_uid'))),
        Uri.parse('https://live.hongrenshuo.com.cn/index/roomuser/uid/$_uid'),
      );
      expect(adapter.http.sent, isEmpty, reason: 'an anchor page needs no request');
      expect(
        _right(await link.resolve(Uri.parse('https://live.kilakila.cn/room/$_broadcast'))).path,
        '/index/roomuser/uid/$_uid',
      );
      expect(adapter.http.sent.last.url.path, '/LiveRoom/getRoomInfo');
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/x'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://live.kilakila.cn/'))), isA<LiveSiteNotFound>());
    });

    test('a status the gate refuses is mapped', () async {
      final adapter = _adapter(onSend: (_) => _resp(401, 'nope'));
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_uid)), isA<LiveSiteRateLimitError>());
      final gone = _adapter(
        onSend: (request) =>
            request.url.path == '/Tg/personalH5' ? _resp(200, _profileFixture(code: 1013)) : _resp(200, '{}'),
      );
      expect(_leftOf(await gone.site.capability<LiveRoomProvider>()!.getRoom(_uid)), isA<LiveSiteNotFound>());
    });

    test('the chat provider builds a session only for an entered broadcast', () async {
      final opened = _Connector();
      final adapter = _adapter(connect: opened.call);
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: _uid));
      expect(session, isA<KilakilaDanmakuSession>());
      await session.dispose();
      final idle = _adapter(
        connect: opened.call,
        onSend: (request) => switch (request.url.path) {
          '/Tg/personalH5' => _resp(200, _profileFixture(liveCard: {'roomSourceType': 1})),
          _ => _resp(200, '{}'),
        },
      );
      expect(
        _leftOf(await idle.site.capability<LiveDanmakuProvider>()!.createSession(roomId: _uid)),
        isA<LiveSiteContentUnavailable>(),
      );
    });
  });
}

/// The site over a fake transport, with a fixed clock and no socket.
({KilakilaSite site, _FakeHttp http}) _adapter({
  LiveResponse Function(_Seen request)? onSend,
  Future<SocketChannel> Function(
    Uri, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  })?
  connect,
}) {
  final http = _FakeHttp(onSend ?? _ordinary);
  return (site: KilakilaSite(http: KilakilaHttp(http), connect: connect ?? _refuseSocket, now: () => _at), http: http);
}

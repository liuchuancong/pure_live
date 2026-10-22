import 'dart:async';
import 'dart:convert';
import 'dart:io' show ZLibEncoder;
import 'dart:math';
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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_endpoints.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_http.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku_session.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_json.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_room_parser.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const String _roomId = '12345';
const String _userId = '67890';
const String _liveId = '999';
const String _flvTitle = 'v$_userId-$_liveId';
const String _flvUrl = 'https://wlive.6rooms.com/httpflv/$_flvTitle.flv';

String _json(Object? data) => jsonEncode(data);

Map<String, Object?> _rows(Object? rows, {required String type, Object? total}) => {
  type: rows,
  'roomListCount': {type: total},
};

/// A list card row, as the homepage's `typeList`, a mobile list and a web
/// subarea carry it.
Map<String, Object?> _card({
  String rid = _roomId,
  String uid = _userId,
  String username = '主播甲',
  String liveid = _liveId,
  String livetitle = '晚间弹唱',
  String userMood = '爱唱歌',
  String picuser = 'https://img.6.cn/u.png',
  String pospic = 'https://img.6.cn/c.png',
  String anchorArea = '歌区',
  Object? count = 3456,
  Object? realstarttime = 1727700000,
}) => {
  'rid': rid,
  'uid': uid,
  'username': username,
  'liveid': liveid,
  'livetitle': livetitle,
  'userMood': userMood,
  'picuser': picuser,
  'pospic': pospic,
  'anchor_area': anchorArea,
  'count': count,
  'realstarttime': realstarttime,
};

/// The homepage: every live room in `window.__SMARTY_ALL_VARIABLES__`.
String _homepageFixture({Object? typeList, bool quoted = false, bool present = true}) {
  final value = typeList ?? [_card()];
  final list = quoted ? _json(_json(value)) : _json(value);
  final embedded = '{"typeList": $list}';
  final line = present ? 'window.__SMARTY_ALL_VARIABLES__ = $embedded;' : 'var page = 1;';
  return '<html><head><title>6.cn</title></head><body><script>\n$line\n</script><p>直播</p></body></html>';
}

/// A mobile list answer of [type]: the default card wrapped in the
/// envelope, or [content] as the whole `content`.
String _listFixture({String flag = '001', Object? content, String type = 'u0', Object? total = 35}) => _json({
  'flag': flag,
  'content': content ?? _rows(<Object?>[_card()], type: type, total: total),
});

/// The web's subarea list of 星颜.
String _subareaFixture({Object? featured, Object? others}) {
  final content = <String, Object?>{
    'bigLiveList': featured == null ? null : {'list': featured},
    'liveList': others,
  };
  return _json({'flag': '001', 'content': content});
}

/// The search page: the cards of the user list, or a prompt page.
String _searchFixture({String cards = '', bool remind = false, String message = '输入内容过长'}) {
  if (remind) {
    return '<html><body><div class="remind"><div class="rcontent">$message</div></div></body></html>';
  }
  return '<html><head></head><body><div class="page-search-user"> '
      '<ul class="search-user">$cards</ul></div></body></html>';
}

/// One search card of [roomId] (its profile link when [live] is false).
String _searchCard({
  String uid = _userId,
  String roomId = _roomId,
  String name = '主播甲',
  bool live = true,
  bool profile = false,
  String src = 'https://img.6.cn/s.png',
}) =>
    '<li data-uid="$uid"><a class="user-box" href="${profile ? '/profile/$roomId' : '/$roomId'}"> '
    '<span class="pic"><img data-src="$src" src="https://img.6.cn/direct.png"/></span> '
    '<span class="alias">$name</span> ${live ? '<i class="live">直播中</i>' : ''}</a></li>';

/// The room page of [_roomId], with its canonical link and its script ids.
String _roomPageFixture({
  String rid = _userId,
  String roomid = _roomId,
  String canonical = _roomId,
  bool prompt = false,
}) {
  final head = '<html><head><link rel="canonical" href="${SixroomEndpoints.origin}/$canonical"/></head><body>';
  if (prompt) {
    return '<html><head></head><body><div class="remind"><div class="rcontent">房间不存在</div></div></body></html>';
  }
  final padding = '<!-- ${'filler ' * 650} -->';
  return "$head$padding<script>var chat = {rid: '$rid', roomid: $roomid};</script></body></html>";
}

/// The inroom answer of [_roomId]: the whole [content], or the full shape of
/// [uid]'s live broadcast [liveId].
String _inroomFixture({
  String flag = '001',
  Object? content,
  String roomId = _roomId,
  String uid = _userId,
  String liveId = _liveId,
  String flvtitle = _flvTitle,
  Object? isPriveRoom,
  Object? blackScreen,
  bool streamInfo = true,
}) {
  final body =
      content ??
      {
        'roominfo': {
          'rid': roomId,
          'id': uid,
          'alias': '主播甲',
          'userMood': '爱唱歌',
          'headPicUrl': 'https://img.6.cn/h.png',
          'anchor_area': '歌区',
          'uoption': {'picuser': 'https://img.6.cn/u.png'},
        },
        'liveinfo': {
          'id': liveId,
          'flvtitle': flvtitle,
          'title': '晚间弹唱',
          'starttime': 1727700000,
          'spredPic': 'https://img.6.cn/c.png',
          if (streamInfo)
            'content': {
              'lane1': {
                'streamInfo': {
                  flvtitle: {'resolution': '1024x768', 'videoBitrate': 2652, 'videoCodec': 'avc'},
                },
              },
            },
        },
        'roomParamInfo': {
          'uid': uid,
          'fans_num': 4321,
          'operation': {'userMood': '运营签名'},
        },
        'isPriveRoom': ?isPriveRoom,
        if (blackScreen != null) 'blackScreenInfo': {'msg': blackScreen},
      };
  return _json({'flag': flag, 'content': body});
}

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

final class _Seen {
  new(LiveRequest request) : url = request.url, method = request.method, body = request.body, headers = request.headers;
  final Uri url;
  final String method;
  final String? body;
  final Map<String, String> headers;
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

/// The answers of the site: the homepage, the mobile lists, the subarea, the
/// search and room pages, the inroom POST and the chat servers.
final class _Answers {
  String homepage = _homepageFixture();
  List<Object?> listRows = [_card()];
  Object? listTotal = 35;
  String subarea = _subareaFixture(
    featured: [_card(username: '星颜主播')],
    others: {_userId: _card(rid: '54321')},
  );
  String search = _searchFixture(cards: _searchCard());
  String roomPage = _roomPageFixture();
  String inroom = _inroomFixture();
  String chatServers = _json({
    'websock': ['wss.6rooms.com:7281'],
  });

  LiveResponse answer(_Seen request) {
    final path = request.url.path;
    if (path == '/') return _resp(200, homepage);
    if (path == '/coop/mobile/index.php') {
      if (request.url.queryParameters['padapi'] == 'coop-mobile-inroom.php') return _resp(200, inroom);
      final type = request.url.queryParameters['type'] ?? 'u0';
      return _resp(
        200,
        _listFixture(
          content: _rows(listRows, type: type, total: listTotal),
        ),
      );
    }
    if (path == '/subareaIndex/getSubareaIndexNew.php') return _resp(200, subarea);
    if (path == '/search.php') return _resp(200, search);
    if (path == '/$_roomId') return _resp(200, roomPage);
    if (path == '/room/getChat.php') return _resp(200, chatServers);
    return _resp(404, 'nope');
  }
}

/// The site over a fake transport, with a fixed clock and no socket.
({SixroomSite site, _FakeHttp http, _Answers answers}) _adapter(
  _Answers? answers, {
  _Connector? connector,
  DateTime Function()? now,
}) {
  final prepared = answers ?? _Answers();
  final http = _FakeHttp(prepared.answer);
  return (
    site: SixroomSite(http: SixroomHttp(http), connect: connector?.call ?? _refuseSocket, now: now ?? (() => _at)),
    http: http,
    answers: prepared,
  );
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

  SixroomTimers get timers => (after: _after, every: _every);

  Timer _after(Duration delay, void Function() callback) {
    after.add((delay: delay, callback: callback));
    return _IdleTimer();
  }

  Timer _every(Duration period, void Function(Timer timer) callback) {
    every.add((period: period, callback: callback));
    return _IdleTimer();
  }

  void fire({int index = 0}) => after[index].callback();

  void fireLast() => after.last.callback();

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

/// The deflated `content` of a `receivemessage` frame, in the site's Base64
/// alphabet.
String _deflated(Object? json) {
  final bytes = ZLibEncoder(raw: true).convert(utf8.encode(_json(json)));
  return base64.encode(bytes).replaceAll('+', '(').replaceAll('/', ')').replaceAll('=', '@');
}

/// A full `receivemessage` frame carrying [message] under flag `001`,
/// deflated like the wire carries it.
String _messageFrame(Object? message) => _frameOf({'flag': '001', 'content': message});

/// A full `receivemessage` frame whose top-level [root] the server wrote,
/// deflated like the wire carries it.
String _frameOf(Object? root) => '100\r\ncommand=receivemessage\r\nenc=yes\r\ncontent=${_deflated(root)}\r\n';

const String _loginSuccess = 'command=result\r\ncontent=login.success\r\n';
const String _loginFailed = 'command=result\r\ncontent=login.failed\r\n';

void main() {
  group('answers and readers', () {
    test('a status says what kind of answer it is', () {
      void expectKind(int status, SixroomFailureKind kind, {String? reason}) {
        try {
          SixroomJson.checkStatus(status, 'x');
          fail(reason ?? 'no throw for $status');
        } on SixroomFailure catch (failure) {
          expect(failure.kind, kind);
        }
      }

      expectKind(401, SixroomFailureKind.riskControl);
      expectKind(403, SixroomFailureKind.riskControl);
      expectKind(302, SixroomFailureKind.riskControl, reason: 'a redirect is the site refusing');
      expectKind(404, SixroomFailureKind.notFound);
      expectKind(410, SixroomFailureKind.notFound);
      expectKind(429, SixroomFailureKind.rateLimited);
      for (final status in [500, 503]) {
        expectKind(status, SixroomFailureKind.network);
      }
      SixroomJson.checkStatus(200, 'x');
      SixroomJson.checkStatus(204, 'x');
    });

    test('only a transport breakdown or a throttle is transient', () {
      for (final kind in SixroomFailureKind.values) {
        expect(
          SixroomFailure(kind, 'x').isTransient,
          kind == SixroomFailureKind.network || kind == SixroomFailureKind.rateLimited,
          reason: kind.name,
        );
      }
    });

    test('the failure kinds map onto the Either-side errors', () {
      const site = 'sixroom';
      expect(const SixroomFailure(SixroomFailureKind.notFound, 'x').toLiveSiteError(site), isA<LiveSiteNotFound>());
      expect(const SixroomFailure(SixroomFailureKind.apiChanged, 'x').toLiveSiteError(site), isA<LiveSiteParseError>());
      expect(const SixroomFailure(SixroomFailureKind.network, 'x').toLiveSiteError(site), isA<LiveSiteNetworkError>());
      for (final kind in [SixroomFailureKind.riskControl, SixroomFailureKind.rateLimited]) {
        expect(SixroomFailure(kind, 'x').toLiveSiteError(site), isA<LiveSiteRateLimitError>(), reason: kind.name);
      }
      expect(
        const SixroomFailure(SixroomFailureKind.streamUnavailable, 'x').toLiveSiteError(site),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(
        const SixroomFailure(SixroomFailureKind.invalidArgument, 'x').toLiveSiteError(site),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('the body is bounded and must be JSON', () {
      expect(() => SixroomJson.json('<html></html>', 'x', 200), throwsA(predicate((e) => '$e'.contains('not JSON'))));
      expect(
        () => SixroomJson.json('{"a":"${'x' * (8 * 1024 * 1024 + 2)}"}', 'x', 200),
        throwsA(predicate((e) => '$e'.contains('answer over'))),
      );
      expect(SixroomJson.json('{"a":1}', 'x', 200), {'a': 1});
      expect(() => SixroomJson.json('[1]', 'x', 200), throwsA(isA<SixroomFailure>()), reason: 'an object is required');
    });

    test('counts, times, images and truthiness are read strictly', () {
      expect(SixroomJson.count(42), 42);
      expect(SixroomJson.count('1,234'), 1234);
      expect(SixroomJson.count(3.9), 3);
      expect(SixroomJson.count(-1), isNull);
      expect(SixroomJson.count('many'), isNull);
      expect(SixroomJson.time(1727700000), DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
      expect(SixroomJson.time(0), isNull);
      expect(SixroomJson.time(-5), isNull);
      expect(SixroomJson.time('later'), isNull);
      expect(SixroomJson.truthy(true), isTrue);
      expect(SixroomJson.truthy(1), isTrue);
      expect(SixroomJson.truthy('1'), isTrue);
      expect(SixroomJson.truthy('yes'), isFalse);
      expect(SixroomJson.truthy(0), isFalse);
      expect(SixroomJson.image('//img.6.cn/a.png'), 'https://img.6.cn/a.png');
      expect(SixroomJson.image('http://img.6rooms.com/a.png'), 'https://img.6rooms.com/a.png');
      expect(SixroomJson.image('https://img.xiu123.cn/a.png'), 'https://img.xiu123.cn/a.png');
      for (final bad in [
        'https://evil.com/a.png',
        'ftp://img.6.cn/a.png',
        'https://img.6.cn:8080/a.png',
        'https://u:img.6.cn/a.png',
        'https://img.6.cn/a.png#x',
        'not a url',
      ]) {
        expect(SixroomJson.image(bad), '', reason: bad);
      }
    });
  });

  group('links', () {
    test('a room number and the room pages of v.6.cn and m.6.cn', () {
      expect(SixroomEndpoints.roomIdOf(_roomId), _roomId);
      expect(SixroomEndpoints.roomIdOf(' 12 '), '12');
      expect(SixroomEndpoints.roomIdOf('https://v.6.cn/$_roomId'), _roomId);
      expect(SixroomEndpoints.roomIdOf('http://v.6.cn/$_roomId'), _roomId);
      expect(SixroomEndpoints.roomIdOf('https://m.6.cn/$_roomId'), _roomId);
      expect(SixroomEndpoints.roomIdOf('https://V.6.CN/$_roomId'), _roomId);
      expect(SixroomEndpoints.roomIdOf('https://v.6.cn/profile/$_roomId'), _roomId);
      expect(SixroomEndpoints.roomIdOf('https://v.6.cn:80/$_roomId'), _roomId);
      expect(SixroomEndpoints.roomIdOf('${SixroomEndpoints.origin}/$_roomId?x=1'), _roomId);
    });

    test('anything that is no room page is no room', () {
      for (final bad in [
        '0123',
        '1',
        '1234567890123456',
        '',
        'https://evil.com/$_roomId',
        'https://v.6.cn/live/$_roomId',
        'https://v.6.cn/',
        'https://u:v.6.cn/$_roomId',
        'https://v.6.cn:8080/$_roomId',
        'https://v.6.cn/$_roomId#frag',
        'ftp://v.6.cn/$_roomId',
        'https://v.6.cn/profile/0',
      ]) {
        expect(SixroomEndpoints.roomIdOf(bad), isNull, reason: bad);
      }
    });

    test('a broadcaster id is 2–13 digits without a leading zero', () {
      expect(SixroomEndpoints.isUserId(_userId), isTrue);
      expect(SixroomEndpoints.isUserId(' 42 '), isTrue);
      expect(SixroomEndpoints.isUserId('0123'), isFalse);
      expect(SixroomEndpoints.isUserId('7'), isFalse);
      expect(SixroomEndpoints.isUserId(null), isFalse);
    });

    test('the stream address names its broadcaster and broadcast', () {
      expect(SixroomEndpoints.mediaUri(userId: _userId, liveId: _liveId, flvTitle: _flvTitle), Uri.parse(_flvUrl));
      expect(SixroomEndpoints.mediaUri(userId: _userId, liveId: _liveId, flvTitle: '$_flvTitle-many'), isNotNull);
      for (final bad in ['v$_userId-1', 'v1-$_liveId', '$_flvTitle-x', 'rtmp', '']) {
        expect(
          SixroomEndpoints.mediaUri(userId: _userId, liveId: _liveId, flvTitle: bad),
          isNull,
          reason: bad,
        );
      }
    });
  });

  group('homepage directory', () {
    test('the embedded typeList is read, once per room', () {
      final rooms = SixroomRoomParser.directory(
        _homepageFixture(
          typeList: [
            _card(),
            _card(rid: '54321', uid: '111'),
            _card(),
          ],
        ),
      );
      expect(rooms.map((room) => room.roomId), [_roomId, '54321'], reason: 'repeats skipped');
      expect(rooms.first.state, SixroomState.live);
      expect(rooms.first.nick, '主播甲');
      expect(rooms.first.title, '晚间弹唱');
      expect(rooms.first.avatar, 'https://img.6.cn/u.png');
      expect(rooms.first.cover, 'https://img.6.cn/c.png');
      expect(rooms.first.category, '歌区');
      expect(rooms.first.popularity, 3456);
      expect(rooms.first.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
    });

    test('a typeList of JSON text is read too, and braces in strings survive', () {
      final rows = [_card(livetitle: '唱 "{ braces }" 歌'), _card(rid: '54321', uid: '111')];
      expect(SixroomRoomParser.directory(_homepageFixture(typeList: rows, quoted: true)), hasLength(2));
      expect(SixroomRoomParser.directory(_homepageFixture(typeList: rows)).first.title, '唱 "{ braces }" 歌');
    });

    test('a broken row costs only itself; a page without rooms is api-changed', () {
      expect(
        SixroomRoomParser.directory(
          _homepageFixture(
            typeList: [
              _card(rid: 'x'),
              _card(),
            ],
          ),
        ),
        hasLength(1),
      );
      for (final body in [
        _homepageFixture(typeList: <Object?>[]),
        _homepageFixture(typeList: [_card(rid: 'x')]),
        _homepageFixture(typeList: 'not json'),
        _homepageFixture(present: false),
        _homepageFixture().replaceAll('window.__SMARTY_ALL_VARIABLES__ = {', 'window.__SMARTY_ALL_VARIABLES__ = "'),
      ]) {
        expect(() => SixroomRoomParser.directory(body), throwsA(isA<SixroomFailure>()), reason: body);
      }
    });

    test('a status the gate refuses is refused', () {
      expect(
        () => SixroomRoomParser.directory(_homepageFixture(), status: 401),
        throwsA(predicate((e) => e is SixroomFailure && e.kind == SixroomFailureKind.riskControl)),
      );
    });
  });

  group('mobile list', () {
    test('the rows of the type are read, and the list goes on', () {
      final page = SixroomRoomParser.list(_listFixture(), type: 'u0', page: 1, size: 30);
      expect(page.rooms.single.roomId, _roomId);
      expect(page.hasMore, isTrue, reason: 'page 1 of 35 rooms');
      expect(
        SixroomRoomParser.list(
          _listFixture(content: _rows([_card()], type: 'u0', total: 30)),
          type: 'u0',
          page: 1,
          size: 30,
        ).hasMore,
        isFalse,
      );
      expect(
        SixroomRoomParser.list(_listFixture(total: null), type: 'u0', page: 1, size: 1).hasMore,
        isTrue,
        reason: 'a full page without a total goes on',
      );
      expect(SixroomRoomParser.list(_listFixture(total: null), type: 'u0', page: 1, size: 30).hasMore, isFalse);
    });

    test('an empty content is an empty page, a broken list is api-changed', () {
      final empty = SixroomRoomParser.list(_listFixture(content: <Object?>[]), type: 'u0', page: 1, size: 30);
      expect(empty.rooms, isEmpty);
      expect(empty.hasMore, isFalse);
      for (final body in [
        _listFixture(flag: '002'),
        _listFixture(
          content: {
            'other': [_card()],
          },
        ),
        _listFixture(
          content: _rows([_card(rid: 'x')], type: 'u0', total: 35),
        ),
        'not json',
      ]) {
        expect(
          () => SixroomRoomParser.list(body, type: 'u0', page: 1, size: 30),
          throwsA(isA<SixroomFailure>()),
          reason: body,
        );
      }
      expect(
        () => SixroomRoomParser.list(_listFixture(flag: '002'), type: 'u0', page: 1, size: 30),
        throwsA(predicate((e) => '$e'.contains('flag 002'))),
      );
    });
  });

  group('subarea list', () {
    test('the featured rows and the liveList are read, once per room', () {
      final rooms = SixroomRoomParser.subarea(
        _subareaFixture(
          featured: [_card(username: '星颜主播')],
          others: {_userId: _card(rid: '54321', uid: '111')},
        ),
      );
      expect(rooms.map((room) => room.roomId), [_roomId, '54321']);
      expect(rooms.first.nick, '星颜主播', reason: 'a featured row is named by alias');
    });

    test('a liveList array is read, and neither list is api-changed', () {
      expect(
        SixroomRoomParser.subarea(
          _subareaFixture(
            others: [_card(rid: '54321', uid: '111')],
          ),
        ),
        hasLength(1),
      );
      expect(
        SixroomRoomParser.subarea(_subareaFixture(featured: <Object?>[], others: <String, Object?>{})),
        isEmpty,
        reason: 'no readable row at all is an empty list',
      );
      for (final body in [
        _subareaFixture(),
        _subareaFixture(featured: [_card(rid: 'x')]),
      ]) {
        expect(() => SixroomRoomParser.subarea(body), throwsA(isA<SixroomFailure>()), reason: body);
      }
    });
  });

  group('search page', () {
    test('the cards are read with their state', () {
      final rooms = SixroomRoomParser.search(
        _searchFixture(
          cards:
              '${_searchCard()}'
              '${_searchCard(uid: '111', roomId: '54321', name: '主播&amp;乙', live: false, profile: true)}'
              '${_searchCard(uid: '222', roomId: '98765', name: '主播丙', live: false)}',
        ),
      );
      expect(rooms, hasLength(3));
      expect(rooms[0].state, SixroomState.live, reason: 'the page marks it 直播中');
      expect(rooms[1].state, SixroomState.offline, reason: 'the link is the profile');
      expect(rooms[1].nick, '主播&乙', reason: 'the references are decoded');
      expect(rooms[1].title, '主播&乙');
      expect(rooms[2].state, SixroomState.unknown, reason: 'neither mark nor profile');
      expect(rooms[0].avatar, 'https://img.6.cn/s.png', reason: 'data-src before src');
      expect(rooms[0].userId, _userId);
    });

    test('a broken card costs only itself; a page without usable cards is empty', () {
      expect(SixroomRoomParser.search(_searchFixture(cards: '<li data-uid="x"></li>${_searchCard()}')), hasLength(1));
      expect(SixroomRoomParser.search(_searchFixture(cards: '<li data-uid="x"></li>')), isEmpty);
      expect(
        () => SixroomRoomParser.search('<html><body><p>nothing</p></body></html>'),
        throwsA(predicate((e) => '$e'.contains('no page-search-user'))),
      );
    });

    test('a prompt page is a too-long keyword or risk control', () {
      expect(SixroomRoomParser.search(_searchFixture(remind: true)), isEmpty);
      expect(
        () => SixroomRoomParser.search(_searchFixture(remind: true, message: '访问受限')),
        throwsA(predicate((e) => e is SixroomFailure && e.kind == SixroomFailureKind.riskControl)),
      );
    });
  });

  group('room page', () {
    test('the rid next to the room number is the broadcaster', () {
      expect(SixroomRoomParser.userIdOf(_roomPageFixture(), roomId: _roomId), _userId);
      expect(
        SixroomRoomParser.userIdOf(
          _roomPageFixture().replaceFirst('roomid: $_roomId', "roomid: '$_roomId'"),
          roomId: _roomId,
        ),
        _userId,
        reason: 'a quoted room number too',
      );
      expect(
        SixroomRoomParser.userIdOf(_roomPageFixture(rid: '123'), roomId: 'https://v.6.cn/$_roomId'),
        '123',
        reason: 'the room may be named by its link',
      );
    });

    test('a wrong canonical, a prompt page and a page without ids are refused', () {
      expect(
        () => SixroomRoomParser.userIdOf(_roomPageFixture(canonical: '99999'), roomId: _roomId),
        throwsA(predicate((e) => e is SixroomFailure && e.kind == SixroomFailureKind.apiChanged)),
        reason: 'a long page whose canonical names another room',
      );
      expect(
        () => SixroomRoomParser.userIdOf(_roomPageFixture(prompt: true), roomId: _roomId),
        throwsA(predicate((e) => e is SixroomFailure && e.kind == SixroomFailureKind.notFound)),
      );
      expect(
        () =>
            SixroomRoomParser.userIdOf(_roomPageFixture().replaceFirst("rid: '$_userId'", "rid: '1'"), roomId: _roomId),
        throwsA(predicate((e) => '$e'.contains('no rid/roomid'))),
      );
      expect(
        () => SixroomRoomParser.userIdOf(_roomPageFixture(), roomId: 'live'),
        throwsArgumentError,
        reason: 'a caller error before the page is read',
      );
    });
  });

  group('inroom answer', () {
    test('a live room is read with its stream, its people and its notices', () {
      final room = SixroomRoomParser.room(_inroomFixture(), roomId: _roomId, userId: _userId);
      expect(room.state, SixroomState.live);
      expect(room.roomId, _roomId);
      expect(room.userId, _userId);
      expect(room.liveId, _liveId);
      expect(room.nick, '主播甲');
      expect(room.title, '晚间弹唱', reason: 'the broadcast title first');
      expect(room.avatar, 'https://img.6.cn/h.png');
      expect(room.cover, 'https://img.6.cn/c.png');
      expect(room.category, '歌区');
      expect(room.followers, 4321);
      expect(room.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
      expect(room.restriction, isNull);
      final stream = room.stream!;
      expect(stream.url, Uri.parse(_flvUrl));
      expect(stream.resolution, '1024x768');
      expect(stream.bitrate, 2652);
      expect(stream.codec, LiveStreamCodec.avc);
    });

    test('the title, avatar and start fall back as the page does', () {
      expect(
        SixroomRoomParser.room(_inroomFixture(streamInfo: false), roomId: _roomId, userId: _userId).stream,
        isNotNull,
        reason: 'the stream does not need its streamInfo',
      );
      final bare = _json({
        'flag': '001',
        'content': {
          'roominfo': {'rid': _roomId, 'alias': '主播甲'},
          'liveinfo': {'id': _liveId, 'flvtitle': _flvTitle},
          'roomParamInfo': {'uid': _userId},
        },
      });
      final room = SixroomRoomParser.room(bare, roomId: _roomId, userId: _userId);
      expect(room.title, '主播甲', reason: 'the name last');
      expect(room.avatar, '');
      expect(room.startedAt, isNull);
      expect(
        SixroomRoomParser.room(
          _inroomFixture(
            content: {
              'roominfo': {'rid': _roomId, 'id': _userId, 'userMood': '签名'},
              'liveinfo': {'id': _liveId},
              'roomParamInfo': {
                'uid': _userId,
                'operation': {'userMood': '运营签名'},
              },
            },
          ),
          roomId: _roomId,
          userId: _userId,
        ).title,
        '签名',
        reason: 'the signature before the operation one',
      );
    });

    test('the flags say not-found, risk control and api-changed', () {
      expect(
        () => SixroomRoomParser.room(
          _inroomFixture(flag: '402', content: '暂不能进入此房间'),
          roomId: _roomId,
          userId: _userId,
        ),
        throwsA(predicate((e) => e is SixroomFailure && e.kind == SixroomFailureKind.notFound)),
      );
      expect(
        () => SixroomRoomParser.room(
          _inroomFixture(flag: '500'),
          roomId: _roomId,
          userId: _userId,
        ),
        throwsA(predicate((e) => e is SixroomFailure && e.kind == SixroomFailureKind.riskControl)),
      );
      expect(
        () => SixroomRoomParser.room(_json({'content': <String, Object?>{}}), roomId: _roomId, userId: _userId),
        throwsA(predicate((e) => '$e'.contains('flag is null'))),
      );
      expect(
        () => SixroomRoomParser.room(
          _inroomFixture(content: {'roominfo': <String, Object?>{}}),
          roomId: _roomId,
          userId: _userId,
        ),
        throwsA(predicate((e) => '$e'.contains('no roominfo, liveinfo or roomParamInfo'))),
      );
      expect(
        () => SixroomRoomParser.room(
          _inroomFixture(roomId: '99999'),
          roomId: _roomId,
          userId: _userId,
        ),
        throwsA(predicate((e) => '$e'.contains('names 99999'))),
        reason: 'the answer must be the room asked for',
      );
      expect(
        () => SixroomRoomParser.room(
          _inroomFixture(uid: '1'),
          roomId: _roomId,
          userId: _userId,
        ),
        throwsA(isA<SixroomFailure>()),
        reason: 'the answer must be the broadcaster asked for',
      );
      expect(() => SixroomRoomParser.room(_inroomFixture(), roomId: _roomId, userId: 'x'), throwsArgumentError);
    });

    test('a private room and a black screen are live and restricted', () {
      final private = SixroomRoomParser.room(_inroomFixture(isPriveRoom: 1), roomId: _roomId, userId: _userId);
      expect(private.state, SixroomState.live, reason: 'a restricted broadcast is live');
      expect(private.restriction, LiveRestriction.private);
      expect(private.stream, isNull, reason: 'a restricted room is read without its stream');
      final black = SixroomRoomParser.room(
        _inroomFixture(blackScreen: '主播暂时离开'),
        roomId: _roomId,
        userId: _userId,
      );
      expect(black.restriction, LiveRestriction.unplayable);
      expect(black.restrictionNote, '主播暂时离开');
      expect(
        SixroomRoomParser.room(_inroomFixture(isPriveRoom: 0), roomId: _roomId, userId: _userId).restriction,
        LiveRestriction.none,
      );
    });

    test('a stream name of another broadcast is a media error', () {
      final room = SixroomRoomParser.room(
        _inroomFixture(flvtitle: 'v1-2'),
        roomId: _roomId,
        userId: _userId,
      );
      expect(room.stream, isNull);
      expect(room.mediaError, isA<SixroomFailure>());
      expect('${room.mediaError}', contains('stream name v1-2'));
    });

    test('an answer without a broadcast is offline', () {
      final room = SixroomRoomParser.room(
        _inroomFixture(liveId: '', flvtitle: ''),
        roomId: _roomId,
        userId: _userId,
      );
      expect(room.state, SixroomState.offline);
      expect(room.startedAt, isNull);
      expect(SixroomRoomParser.roomData(room).streamError, isA<SixroomFailure>());
    });
  });

  group('room data', () {
    test('every reason a room cannot play is named', () {
      String why(SixroomRoomData data) => '${data.streamError}';
      expect(
        why(
          SixroomRoomParser.roomData(
            SixroomRoomParser.room(
              _inroomFixture(liveId: '', flvtitle: ''),
              roomId: _roomId,
              userId: _userId,
            ),
          ),
        ),
        contains('offline'),
      );
      expect(
        SixroomRoomParser.roomData(SixroomRoomParser.room(_inroomFixture(), roomId: _roomId, userId: _userId))
            .streamError,
        isNull,
      );
      final private = SixroomRoomParser.roomData(
        SixroomRoomParser.room(_inroomFixture(isPriveRoom: 1), roomId: _roomId, userId: _userId),
      );
      expect(why(private), contains('private room'));
      final black = SixroomRoomParser.roomData(
        SixroomRoomParser.room(
          _inroomFixture(blackScreen: '黑屏'),
          roomId: _roomId,
          userId: _userId,
        ),
      );
      expect(why(black), contains('黑屏'));
      final mismatch = SixroomRoomParser.roomData(
        SixroomRoomParser.room(
          _inroomFixture(flvtitle: 'v1-2'),
          roomId: _roomId,
          userId: _userId,
        ),
      );
      expect(mismatch.streamError, same(mismatch.mediaError));
      expect(
        why(const SixroomRoomData(roomId: '1', userId: '2', state: SixroomState.unknown)),
        contains('state unknown'),
      );
      expect(
        why(const SixroomRoomData(roomId: '1', userId: '2', state: SixroomState.live)),
        contains('read without its stream'),
      );
    });
  });

  group('enrich', () {
    final liveRoom = SixroomRoomParser.room(_inroomFixture(), roomId: _roomId, userId: _userId);
    SixroomRoom card() => SixroomRoomParser.directory(_homepageFixture()).single;

    test('a room answer is filled from the card of the same broadcast', () {
      const bare = SixroomRoom(roomId: _roomId, userId: _userId, state: SixroomState.live, liveId: _liveId);
      final merged = bare.enrich(card());
      expect(merged.nick, '主播甲');
      expect(merged.avatar, 'https://img.6.cn/u.png');
      expect(merged.category, '歌区');
      expect(merged.popularity, 3456, reason: 'the card of the same broadcast fills the heat');
      expect(merged.startedAt, isNotNull);
    });

    test('what belongs to one broadcast is taken only from the same one', () {
      const offline = SixroomRoom(roomId: _roomId, userId: _userId, state: SixroomState.offline);
      final ended = offline.enrich(liveRoom);
      expect(ended.popularity, isNull, reason: 'the offline room does not keep the old heat');
      const fresh = SixroomRoom(roomId: _roomId, userId: _userId, state: SixroomState.live, liveId: 'other');
      expect(fresh.enrich(liveRoom).startedAt, isNull, reason: 'another broadcast');
      expect(fresh.enrich(liveRoom).popularity, isNull);
      const unknown = SixroomRoom(roomId: _roomId, userId: _userId, state: SixroomState.unknown);
      expect(unknown.enrich(card()).state, SixroomState.live, reason: 'the state is taken');
      expect(unknown.enrich(card()).stream, isNull, reason: "the media stay the room's own");
    });
  });

  group('rooms, qualities and lines', () {
    test('a card becomes a v2 room', () {
      final card = SixroomRoomParser.directory(_homepageFixture()).single;
      final room = SixroomRoomParser.liveRoom(card);
      expect(room.platform, 'sixroom');
      expect(room.roomId, _roomId);
      expect(room.links.webUrl, SixroomEndpoints.link(_roomId));
      expect(room.content.title, '晚间弹唱');
      expect(room.content.notice, SixroomEndpoints.chatNotice);
      expect(room.anchor?.anchorId, _userId);
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.avatarUrl, 'https://img.6.cn/u.png');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.audience.popularity, 3456);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity, reason: 'the heat is not a head count');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, isNotNull);
      expect(room.runtime.danmakuHandle, isNull);
    });

    test('an entry carries its handles, a restricted room its notices', () {
      final room = SixroomRoomParser.room(_inroomFixture(), roomId: _roomId, userId: _userId);
      final data = SixroomRoomParser.roomData(room);
      final detail = SixroomRoomParser.liveRoom(
        room,
        data: data,
        danmaku: const SixroomDanmakuArgs(roomId: _roomId, userId: _userId),
      );
      expect(detail.runtime.streamHandle, same(data));
      expect(detail.runtime.danmakuHandle, isA<SixroomDanmakuArgs>());
      final restricted = SixroomRoomParser.liveRoom(
        SixroomRoomParser.room(_inroomFixture(isPriveRoom: 1), roomId: _roomId, userId: _userId),
      );
      expect(restricted.content.notice, startsWith(SixroomEndpoints.restrictedNotice));
      expect(restricted.content.notice, endsWith(SixroomEndpoints.chatNotice));
      expect(restricted.broadcast.restriction, LiveRestriction.private);
      final offline = SixroomRoomParser.liveRoom(
        SixroomRoomParser.room(
          _inroomFixture(liveId: '', flvtitle: ''),
          roomId: _roomId,
          userId: _userId,
        ),
      );
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.broadcast.startedAt, isNull);
      expect(offline.audience.primaryMetric, LiveAudienceMetricType.unknown);
    });

    test('the one quality and its one line', () {
      final stream = SixroomRoomParser.room(_inroomFixture(), roomId: _roomId, userId: _userId).stream!;
      final quality = SixroomRoomParser.quality(stream);
      expect(quality.qualityId, SixroomEndpoints.qualityId);
      expect(quality.label, 'FLV 原始线路 · 1024x768 · 2652 kbps');
      expect(quality.platformOrder, 2652);
      final line = SixroomRoomParser.line(stream);
      expect(line.url, _flvUrl);
      expect(line.format, LiveStreamFormat.flv);
      expect(line.lineLabel, SixroomEndpoints.lineLabel);
      expect(line.codec, LiveStreamCodec.avc);
      expect(line.headers, isEmpty, reason: 'the CDN answers without headers');
      expect(line.lease, isNull, reason: 'the address has no expiry');
      final bare = SixroomRoomParser.room(_inroomFixture(streamInfo: false), roomId: _roomId, userId: _userId).stream!;
      expect(SixroomRoomParser.quality(bare).label, SixroomEndpoints.qualityName);
      expect(SixroomRoomParser.quality(bare).platformOrder, 1);
    });

    test('the areas are the six fixed ones', () {
      final areas = SixroomRoomParser.areas();
      expect(areas.map((area) => area.areaId), ['all', 'song', 'dance', 'talk', 'face', 'party']);
      expect(areas.first.areaName, '全部');
      expect(areas.first.parentAreaId, 'sixroom');
      expect(areas.first.parentAreaName, SixroomEndpoints.siteName);
      expect(
        SixroomRoomParser.areaIdOf(LiveArea.normalized(platform: 'sixroom', areaId: ' song ', areaName: 'x')),
        'song',
        reason: 'the id is trimmed',
      );
      expect(SixroomRoomParser.areaIdOf(LiveArea.normalized(platform: 'douyu', areaId: 'song')), isNull);
      expect(SixroomRoomParser.areaIdOf(LiveArea.normalized(platform: 'sixroom', areaId: 'nope')), isNull);
    });
  });

  group('chat protocol', () {
    test("the heartbeat inflates to the page's noop", () {
      expect(SixroomDanmakuCodec.payload('y8vPLwAA', deflated: true), 'noop');
      final frame = SixroomDanmakuCodec.fields(SixroomDanmakuCodec.heartbeat);
      expect(frame['command'], 'sendmessage');
      expect(frame['content'], 'y8vPLwAA');
    });

    test("a deflated payload round-trips through the site's alphabet", () {
      final content = _deflated({'typeID': '101', 'content': '你好 &amp; 再见'});
      expect(content.contains(RegExp('[+/=]')), isFalse);
      expect(SixroomDanmakuCodec.payload(content, deflated: true), _json({'typeID': '101', 'content': '你好 &amp; 再见'}));
      // Standard Base64 reads the same.
      final standard = base64.encode(ZLibEncoder(raw: true).convert(utf8.encode(_json({'a': 1}))));
      expect(SixroomDanmakuCodec.payload(standard, deflated: true), _json({'a': 1}));
      // Plain content is not inflated.
      expect(
        SixroomDanmakuCodec.payload(base64.encode(utf8.encode(_json({'a': 1}))), deflated: false),
        _json({'a': 1}),
      );
    });

    test('a frame is its key=value lines, the length line skipped', () {
      expect(SixroomDanmakuCodec.fields('123\r\ncommand=login\r\nuid=1\r\n\r\nuid=2\r\n'), {
        'command': 'login',
        'uid': '2',
      }, reason: 'a key keeps its last value');
    });

    test('the login names the guest and the broadcaster, a guest id is in range', () {
      final id = SixroomDanmakuCodec.guestId(Random(7));
      expect(id, inInclusiveRange(1800000000, 1899999999));
      expect(SixroomDanmakuCodec.login(id, _userId), 'command=login\r\nuid=$id\r\nencpass=\r\nroomid=$_userId\r\n');
      expect(SixroomDanmakuCodec.guestId(Random(7)), id, reason: 'the same seed picks the same guest');
    });

    test('the args are checked, a room and a broadcaster required', () {
      expect(SixroomDanmakuCodec.checked(const SixroomDanmakuArgs(roomId: _roomId, userId: _userId)), isNotNull);
      expect(SixroomDanmakuCodec.checked(const SixroomDanmakuArgs(roomId: 'x', userId: _userId)), isNull);
      expect(SixroomDanmakuCodec.checked(const SixroomDanmakuArgs(roomId: _roomId, userId: '0')), isNull);
    });

    SixroomDanmakuFrame frameOf(Object? message) => SixroomDanmakuCodec.decode(_messageFrame(message), now: _at);

    test('the login results are told apart', () {
      expect(SixroomDanmakuCodec.decode('command=result\r\ncontent=login.success\r\n').joined, isTrue);
      expect(SixroomDanmakuCodec.decode('command=result\r\ncontent=login.failed\r\n').loginFailed, isTrue);
      expect(SixroomDanmakuCodec.decode('command=result\r\ncontent=send.success\r\n'), SixroomDanmakuFrame.empty);
      expect(SixroomDanmakuCodec.decode('command=other\r\ncontent=x\r\n'), SixroomDanmakuFrame.empty);
      expect(SixroomDanmakuCodec.decode(1), SixroomDanmakuFrame.empty);
      expect(SixroomDanmakuCodec.decode('command=receivemessage\r\ncontent=!!!\r\n'), SixroomDanmakuFrame.empty);
    });

    test('a stopping flag is a refusal, another flag nothing', () {
      expect(SixroomDanmakuCodec.decode(_frameOf({'flag': '204', 'content': '房间已关闭'})).refusal, 'flag 204: 房间已关闭');
      expect(SixroomDanmakuCodec.decode(_frameOf({'flag': '101'})).refusal, 'flag 101');
      expect(
        SixroomDanmakuCodec.decode(_frameOf({'flag': '205', 'content': 'ok'})),
        SixroomDanmakuFrame.empty,
        reason: 'a guest prompt',
      );
    });

    test('a chat line is white chat with its references decoded', () {
      final chat = frameOf({'typeID': '101', 'from': '观众', 'fid': 888, 'tm': 1727700000, 'content': '你好 &amp; 再见'})
          .messages
          .single;
      expect(chat.type, LiveMessageType.chat);
      expect(chat.text, '你好 & 再见');
      expect(chat.effectiveSender.userName, '观众');
      expect(chat.effectiveSender.userId, '888');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000));
      // A picture, a nameless supreme mystery, an anonymous and an empty line.
      expect(
        frameOf({
          'typeID': '101',
          'from': '观众',
          'content': 'x',
          'picEmoji': {'pic': 'https://img.6.cn/e.png'},
        }).messages.single.text,
        '[AI表情]',
      );
      expect(frameOf({'typeID': '101', 'from': '', 'supremeMystery': 1, 'content': '神秘'}).messages.single.text, '神秘');
      expect(frameOf({'typeID': '101', 'from': '', 'content': '匿名'}).messages, isEmpty);
      expect(frameOf({'typeID': '101', 'from': '观众', 'content': '  '}).messages, isEmpty);
      expect(
        frameOf({'typeID': '101', 'from': '观众', 'content': '/狂笑'}).messages.single.text,
        '/狂笑',
        reason: 'face codes stay as written',
      );
    });

    test('a list of chat and a batch are read entry by entry', () {
      final chat = {'typeID': '101', 'from': '观众', 'content': '你好'};
      expect(
        frameOf({
          'typeID': '110',
          'content': [chat, chat],
        }).messages,
        hasLength(2),
      );
      expect(
        frameOf({
          'typeID': '1413',
          'content': [
            chat,
            {
              'typeID': '1413',
              'content': [chat],
            },
          ],
        }).messages,
        hasLength(2),
      );
      // Deeper than the fourth list is not read.
      Object? deep = chat;
      for (var depth = 0; depth < 6; depth++) {
        deep = {
          'typeID': '1413',
          'content': [deep],
        };
      }
      expect(frameOf(deep).messages, isEmpty);
    });

    test('a message the page hides from a guest is not shown', () {
      expect(
        frameOf({'typeID': '101', 'from': '观众', 'content': '手机', 'cli': 2}).messages,
        isEmpty,
        reason: 'the client mask without the PC bit',
      );
      expect(frameOf({'typeID': '101', 'from': '观众', 'content': '电脑', 'cli': 1}).messages, hasLength(1));
      expect(frameOf({'typeID': '101', 'from': '观众', 'content': '会员', 'newLimitLevel': 5}).messages, isEmpty);
      expect(frameOf({'typeID': '101', 'from': '观众', 'content': '旧限', 'newLimitLevel': -1}).messages, hasLength(1));
      expect(frameOf({'typeID': '101', 'from': '观众', 'content': '星星', 'starLimitLevel': 2}).messages, isEmpty);
    });

    test('a fly-screen message is a super chat of 1000 six coins', () {
      final fly = frameOf({'typeID': '108', 'from': '观众', 'fid': 888, 'tm': 1727700000, 'content': '飞过'})
          .messages
          .single;
      expect(fly.type, LiveMessageType.superChat);
      expect(fly.text, '飞过');
      expect(fly.effectiveSender.userId, '888');
      final superChat = fly.payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, SixroomDanmakuCodec.flyScreenPrice);
      expect(superChat.price.currency, '六币');
      expect(superChat.price.displayText, '1000六币');
      expect(superChat.startTime, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000));
      expect(superChat.endTime, superChat.startTime!.add(SixroomDanmakuCodec.flyScreenDuration));
      expect(frameOf({'typeID': '108', 'from': '观众', 'content': ' '}).messages, isEmpty);
    });

    test('a gift is priced in six coins, a combo counted', () {
      final hit = frameOf({
        'typeID': '201',
        'from': '观众',
        'fid': '888',
        'to': '主播甲',
        'askId': 'a-1',
        'tm': 1727700000,
        'content': {
          'item': '1024',
          'itemName': '棒棒糖',
          'num': 3,
          'giftCoin': 30,
          'isContinue': '1',
          'keep': {'tmp_id': 't9'},
          'groupnum': 4,
          'aiGiftPic': 'http://img.6.cn/g.png',
        },
      }).messages.single;
      expect(hit.type, LiveMessageType.gift);
      expect(hit.text, '棒棒糖 ×3');
      expect(hit.messageId, 'a-1');
      final gift = hit.payload! as LiveGift;
      expect(gift.giftId, '1024');
      expect(gift.name, '棒棒糖');
      expect(gift.count, 3);
      expect(gift.value.unit, LiveGiftUnit.sixCoin);
      expect(gift.value.unitPrice, 10.0, reason: '30 six coins over 3');
      expect(gift.value.totalValue, 30.0);
      expect(gift.combo.comboKey, '888:t9');
      expect(gift.combo.comboTotal, 12, reason: 'the folded line shows 3 × 4');
      expect(gift.iconUrl, 'https://img.6.cn/g.png');
      expect(gift.recipientName, '主播甲');

      final single = frameOf({
        'typeID': '201',
        'from': '观众',
        'fid': '888',
        'content': {'item': '1024', 'itemName': '棒棒糖', 'num': 1, 'giftCoin': 0},
      }).messages.single;
      final free = single.payload! as LiveGift;
      expect(free.value.unit, LiveGiftUnit.free, reason: 'a gift from the stock');
      expect(free.value.unitPrice, isNull);
      expect(free.value.totalValue, isNull);
      expect(free.combo.comboKey, '');
    });

    test('a game prize, a fly-screen purchase and a bare gift are not gifts', () {
      for (final message in [
        {
          'typeID': '201',
          'from': '主播甲',
          'fid': '0',
          'to': '观众',
          'content': {'item': '1024', 'itemName': '棒棒糖', 'num': 1},
        },
        {
          'typeID': '201',
          'from': '观众',
          'fid': '888',
          'content': {'item': '106', 'itemName': '飞屏', 'num': 1},
        },
        {
          'typeID': '201',
          'from': '观众',
          'fid': '888',
          'content': {'item': '1516', 'itemName': '跟风飞屏', 'num': 1},
        },
        {'typeID': '201', 'from': '观众', 'fid': '888'},
        {
          'typeID': '201',
          'from': '观众',
          'fid': '888',
          'content': {'item': '', 'itemName': 'x'},
        },
      ]) {
        expect(frameOf(message).messages, isEmpty, reason: _json(message));
      }
    });

    test('a follow fly-screen is a super chat of 2000 six coins', () {
      final fly = frameOf({
        'typeID': '324',
        'tm': 1727700000,
        'content': {'type': '1', 'msg': '跟着飞', 'alias': '观众', 'uid': 888, 'id': 'f-1'},
      }).messages.single;
      expect(fly.type, LiveMessageType.superChat);
      expect(fly.messageId, 'follow-fly:f-1');
      final superChat = fly.payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, SixroomDanmakuCodec.followFlyScreenPrice);
      expect(superChat.userName, '观众');
      expect(
        frameOf({
          'typeID': '324',
          'content': {'type': '2', 'uid': 888},
        }).messages,
        isEmpty,
      );
      expect(
        frameOf({
          'typeID': '324',
          'content': {'type': '1', 'msg': ' ', 'alias': 'x'},
        }).messages,
        isEmpty,
      );
    });

    test('the chat servers are read once each, on 6rooms.com only', () {
      final servers = SixroomDanmakuCodec.servers((
        text: _json({
          'websock': [
            'wss.6rooms.com:7281',
            'Wss2.6rooms.com:7282',
            'wss.6rooms.com:7281',
            'evil.com:1234',
            'wss.6rooms.com:0',
            'wss.6rooms.com:99999',
            'wss.6rooms.com',
            5,
          ],
        }),
        status: 200,
      ));
      expect(servers, [Uri.parse('wss://wss.6rooms.com:7281'), Uri.parse('wss://wss2.6rooms.com:7282')]);
      expect(
        () => SixroomDanmakuCodec.servers(const (text: '[]', status: 200)),
        throwsA(predicate((e) => '$e'.contains('no chat server'))),
        reason: 'a missing room answers an empty list',
      );
      expect(
        () => SixroomDanmakuCodec.servers(const (text: '{"websock": []}', status: 200)),
        throwsA(isA<SixroomFailure>()),
      );
      expect(() => SixroomDanmakuCodec.servers(const (text: 'nope', status: 200)), throwsA(isA<SixroomFailure>()));
      expect(
        () => SixroomDanmakuCodec.servers(const (text: 'x', status: 404)),
        throwsA(predicate((e) => e is SixroomFailure && e.kind == SixroomFailureKind.notFound)),
      );
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities the platform can serve', () async {
      final adapter = _adapter(null);
      expect(adapter.site.manifest.id, 'sixroom');
      expect(adapter.site.manifest.name['zh-CN'], '六间房直播');
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

    test('the homepage (area all) is read whole and paged locally', () async {
      var at = _at;
      final answers = _Answers()
        ..homepage = _homepageFixture(
          typeList: [
            _card(),
            _card(rid: '22', uid: '222'),
            _card(rid: '33', uid: '333'),
          ],
        );
      final adapter = _adapter(answers, now: () => at);
      final first = await adapter.site.directoryPage(1, 2, areaId: 'all');
      expect(first.rooms.map((room) => room.roomId), [_roomId, '22']);
      expect(first.hasMore, isTrue);
      answers.homepage = _homepageFixture(
        typeList: [_card(rid: '11', uid: '111')],
      );
      final second = await adapter.site.directoryPage(2, 2, areaId: 'all');
      expect(second.rooms.single.roomId, '33', reason: 'the 90 s snapshot still serves');
      expect(second.hasMore, isFalse);
      at = _at.add(const Duration(seconds: 91));
      final fresh = await adapter.site.directoryPage(1, 2, areaId: 'all');
      expect(fresh.rooms.single.roomId, '11', reason: 'the snapshot expired');
      final past = await adapter.site.directoryPage(5, 2, areaId: 'all');
      expect(past.rooms, isEmpty);
      expect(past.hasMore, isFalse);
      await adapter.site.dispose();
    });

    test('the recommendations and the areas are the mobile lists and the homepage', () async {
      final answers = _Answers();
      final adapter = _adapter(answers);
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      final first = _right(await discovery.getRecommendedRooms());
      expect(first.items.single.roomId, _roomId);
      answers.listRows = [_card(rid: '22', uid: '222')];
      final second = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2)));
      expect(second.items.single.roomId, '22', reason: 'the next page of the list');
      final area = adapter.site.capability<LiveAreaProvider>()!;
      expect(_right(await area.getAreas()).map((entry) => entry.areaId), [
        'all',
        'song',
        'dance',
        'talk',
        'face',
        'party',
      ]);
      expect(_right(await area.getAreaRooms(areaId: 'song')).items.single.roomId, '22');
      expect(
        _right(await area.getAreaRooms(areaId: 'face')).items.first.roomId,
        _roomId,
        reason: 'the featured row first',
      );
      expect(_right(await area.getAreaRooms(areaId: 'all')).items.single.roomId, _roomId);
      expect(_leftOf(await area.getAreaRooms(areaId: 'nope')), isA<LiveSiteInvalidArgument>());
      expect(
        _leftOf(await area.getAreaRooms(areaId: 'song', request: const LivePageRequest(page: 10001))),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(_right(await area.getAreaRooms(areaId: 'song', request: const LivePageRequest(page: 0))).items, isEmpty);
      await adapter.site.dispose();
    });

    test('a room an earlier page of a list gave is left out', () async {
      final answers = _Answers()..listTotal = 40;
      final adapter = _adapter(answers);
      final discovery = adapter.site.capability<LiveDiscoveryProvider>()!;
      expect(_right(await discovery.getRecommendedRooms()).items.single.roomId, _roomId);
      expect(
        _right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 2))).items,
        isEmpty,
        reason: 'the same card again is deduplicated',
      );
      await adapter.site.dispose();
    });

    test('an entry is the room page and the inroom answer, with its handles', () async {
      final adapter = _adapter(null);
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom(_roomId));
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/$_roomId', '/coop/mobile/index.php']);
      expect(adapter.http.sent.last.url.queryParameters['padapi'], 'coop-mobile-inroom.php');
      expect(adapter.http.sent.last.body, contains('ruid=$_userId'), reason: 'the broadcaster of the entry');
      expect(room.roomId, _roomId);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.danmakuHandle, isA<SixroomDanmakuArgs>());
      expect(room.runtime.streamHandle, isA<SixroomRoomData>());
      expect(room.audience.popularity, isNull, reason: 'an inroom answer carries no heat');
      expect(room.anchor?.followerCount, 4321);
      expect(room.broadcast.startedAt, isNotNull);
      // The entry's stream serves the playback, without a request.
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: _roomId));
      expect(qualities.single.qualityId, SixroomEndpoints.qualityId);
      final lines = _right(await playback.getLines(roomId: _roomId));
      expect(lines.single.url, _flvUrl);
      expect(lines.single.format, LiveStreamFormat.flv);
      expect(_right(await playback.getLines(roomId: _roomId, quality: qualities.single)).single.url, _flvUrl);
      expect(adapter.http.sent, hasLength(2), reason: 'no request beyond the entry');
      // A second entry knows the broadcaster, so the room page is skipped.
      await adapter.site.capability<LiveRoomProvider>()!.getRoom(_roomId);
      expect(adapter.http.sent, hasLength(3));
      expect(adapter.http.sent.last.body, contains('ruid=$_userId'));
      await adapter.site.dispose();
    });

    test('a room without a stream says why at the playback', () async {
      final private = _adapter(_Answers()..inroom = _inroomFixture(isPriveRoom: 1));
      final playback = private.site.capability<LivePlaybackProvider>()!;
      expect(
        _leftOf(await playback.getQualities(roomId: _roomId)),
        isA<LiveSiteContentUnavailable>(),
        reason: 'a private room',
      );
      final offline = _adapter(_Answers()..inroom = _inroomFixture(liveId: '', flvtitle: ''));
      expect(
        _leftOf(await offline.site.capability<LivePlaybackProvider>()!.getQualities(roomId: _roomId)),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(
        _leftOf(
          await offline.site.capability<LivePlaybackProvider>()!.getLines(
            roomId: _roomId,
            quality: const LivePlayQuality(label: '720p', qualityId: '720p'),
          ),
        ),
        isA<LiveSiteContentUnavailable>(),
        reason: 'the platform offers the one quality only',
      );
      expect(
        _leftOf(await offline.site.capability<LivePlaybackProvider>()!.getQualities(roomId: 'live')),
        isA<LiveSiteNotFound>(),
        reason: 'not a room number',
      );
      await private.site.dispose();
      await offline.site.dispose();
    });

    test('the search finds a room number, a room link and a keyword', () async {
      final adapter = _adapter(null);
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      // The room number finds the room, without its stream.
      final byNumber = _right(
        await search.search(const LiveSearchRequest(query: _roomId, target: LiveSearchTarget.rooms)),
      );
      expect((byNumber.items.single as RoomSearchResult).room.roomId, _roomId);
      expect(byNumber.items.single, isA<RoomSearchResult>());
      expect(adapter.http.sent, hasLength(2), reason: 'the room page and the inroom answer');
      final room = (byNumber.items.single as RoomSearchResult).room;
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.runtime.danmakuHandle, isNull, reason: 'a search result opens no chat');
      final data = room.runtime.streamHandle! as SixroomRoomData;
      expect(data.stream, isNull, reason: 'and cannot be played until it is entered');
      // The room link finds it too; page 2 and a blank keyword find nothing.
      final byLink = _right(
        await search.search(
          const LiveSearchRequest(query: '${SixroomEndpoints.origin}/$_roomId', target: LiveSearchTarget.rooms),
        ),
      );
      expect((byLink.items.single as RoomSearchResult).room.roomId, _roomId);
      expect(adapter.http.sent, hasLength(3), reason: 'the broadcaster is known now, so only the inroom answer');
      expect(
        _right(await search.search(const LiveSearchRequest(query: _roomId, target: LiveSearchTarget.rooms, page: 2)))
            .items,
        isEmpty,
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _right(await search.search(LiveSearchRequest(query: 'x' * 81, target: LiveSearchTarget.rooms))).items,
        isEmpty,
        reason: "over the platform's keyword limit",
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms, pageSize: 101)))
            .items,
        isEmpty,
      );
      // The keyword is the web's search page.
      final byKeyword = _right(
        await search.search(const LiveSearchRequest(query: '主播', target: LiveSearchTarget.rooms)),
      );
      expect((byKeyword.items.single as RoomSearchResult).room.roomId, _roomId);
      expect(byKeyword.hasMore, isNull, reason: 'the search page says nothing about pages');
      expect(adapter.http.sent.last.url.path, '/search.php');
      await adapter.site.dispose();
    });

    test('a room that does not exist is no search result', () async {
      final adapter = _adapter(_Answers()..roomPage = _roomPageFixture(prompt: true));
      expect(
        _right(
          await adapter.site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: _roomId, target: LiveSearchTarget.rooms),
          ),
        ).items,
        isEmpty,
      );
      await adapter.site.dispose();
    });

    test('a status the gate refuses is mapped, 401 and 403 into the rate limit', () async {
      final refusing = _FakeHttp((_) => _resp(403, 'nope'));
      final site = SixroomSite(http: SixroomHttp(refusing), connect: _refuseSocket, now: () => _at);
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom(_roomId)), isA<LiveSiteRateLimitError>());
      expect(
        _leftOf(
          await site.capability<LiveSearchProvider>()!.search(
            const LiveSearchRequest(query: 'x', target: LiveSearchTarget.rooms),
          ),
        ),
        isA<LiveSiteRateLimitError>(),
      );
      final gone = _FakeHttp((_) => _resp(404, 'nope'));
      final site2 = SixroomSite(http: SixroomHttp(gone), connect: _refuseSocket, now: () => _at);
      expect(_leftOf(await site2.capability<LiveRoomProvider>()!.getRoom(_roomId)), isA<LiveSiteNotFound>());
      final broken = _FakeHttp((_) => throw const ConnectFailure('socket blew up'));
      final site3 = SixroomSite(http: SixroomHttp(broken), connect: _refuseSocket, now: () => _at);
      expect(_leftOf(await site3.capability<LiveRoomProvider>()!.getRoom(_roomId)), isA<LiveSiteNetworkError>());
      final changed = _FakeHttp((_) => _resp(200, 'not json ${'x' * 5000}'));
      final site4 = SixroomSite(http: SixroomHttp(changed), connect: _refuseSocket, now: () => _at);
      expect(_leftOf(await site4.capability<LiveRoomProvider>()!.getRoom(_roomId)), isA<LiveSiteParseError>());
      await site.dispose();
      await site2.dispose();
      await site3.dispose();
      await site4.dispose();
    });

    test('a link is canonicalized without a request', () async {
      final adapter = _adapter(null);
      final link = adapter.site.capability<LiveLinkResolver>()!;
      expect(
        _right(await link.resolve(Uri.parse('${SixroomEndpoints.origin}/$_roomId'))),
        Uri.parse(SixroomEndpoints.link(_roomId)),
      );
      expect(_right(await link.resolve(Uri.parse('https://m.6.cn/profile/$_roomId'))).path, '/$_roomId');
      expect(adapter.http.sent, isEmpty);
      expect(_leftOf(await link.resolve(Uri.parse('https://example.com/x'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('https://v.6.cn/live'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://v.6.cn/profile/0'))), isA<LiveSiteNotFound>());
      await adapter.site.dispose();
    });

    test('the chat provider builds a session for an entered room', () async {
      final opened = _Connector();
      final adapter = _adapter(null, connector: opened);
      final session = _right(await adapter.site.capability<LiveDanmakuProvider>()!.createSession(roomId: _roomId));
      await _settle();
      expect(opened.sockets, hasLength(1), reason: 'the handshake asked for the chat servers');
      expect(adapter.http.sent.last.url.path, '/room/getChat.php');
      await session.dispose();
      // A room the entry cannot name a broadcaster for opens no chat.
      final idle = _adapter(_Answers()..roomPage = _roomPageFixture(prompt: true), connector: opened);
      expect(
        _leftOf(await idle.site.capability<LiveDanmakuProvider>()!.createSession(roomId: _roomId)),
        isA<LiveSiteNotFound>(),
      );
      await idle.site.dispose();
      await adapter.site.dispose();
    });
  });

  group('comment session', () {
    const args = SixroomDanmakuArgs(roomId: _roomId, userId: _userId);

    ({SixroomDanmakuSession session, FakeTimers timers, _Connector connector, _FakeHttp http}) newChat({
      String servers = 'wss.6rooms.com:7281',
    }) {
      final connector = _Connector();
      final timers = FakeTimers();
      final http = _FakeHttp((request) {
        if (request.url.path == '/room/getChat.php') {
          return _resp(200, _json({'websock': servers.split(',').map((server) => server.trim()).toList()}));
        }
        return _resp(404, 'nope');
      });
      final site = SixroomSite(http: SixroomHttp(http), connect: connector.call, now: () => _at);
      final session = SixroomDanmakuSession(args: args, site: site, timers: timers.timers, random: Random(1));
      return (session: session, timers: timers, connector: connector, http: http);
    }

    test('the socket address, the login and the heartbeat follow the page', () async {
      final chat = newChat();
      expect(await chat.session.connect(), isNull);
      await _settle();
      expect(chat.connector.endpoints.single, Uri.parse('wss://wss.6rooms.com:7281'));
      expect(chat.http.sent.single.url.queryParameters['rid'], _userId, reason: 'the broadcaster picks the servers');
      expect(chat.http.sent.single.headers['referer'], SixroomEndpoints.link(_roomId));
      expect(chat.http.sent.single.headers['x-requested-with'], 'XMLHttpRequest');
      final expected = SixroomDanmakuCodec.login(SixroomDanmakuCodec.guestId(Random(1)), _userId);
      expect(chat.connector.latest.sentText, expected, reason: 'the login goes out at once');
      // The join is confirmed: a heartbeat at once, then the page's period.
      final after = _next(chat.session.events, 1);
      chat.connector.latest.push(_loginSuccess);
      await _settle();
      expect(chat.connector.latest.sentText, endsWith(SixroomDanmakuCodec.heartbeat));
      chat.timers.ring(index: chat.timers.every.length - 1);
      expect(chat.connector.latest.sentText.endsWith(SixroomDanmakuCodec.heartbeat), isTrue);
      expect(chat.timers.every.single.period, SixroomDanmakuCodec.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        containsAll([SixroomDanmakuCodec.joinTimeout, SixroomDanmakuCodec.silenceTimeout]),
      );
      // Chat flows.
      chat.connector.latest.push(_messageFrame({'typeID': '101', 'from': '观众', 'content': '你好'}));
      expect((await after).single.text, '你好');
      await chat.session.dispose();
    });

    test('a refused login is retried, and the next refusal ends the session', () async {
      final chat = newChat();
      expect(await chat.session.connect(), isNull);
      await _settle();
      final seen = <LiveMessage>[];
      final done = chat.session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < SixroomDanmakuCodec.maxRefusals; attempt++) {
        chat.connector.latest.push(_loginFailed);
        await _settle();
        chat.timers.fireLast();
        await _settle();
      }
      expect(chat.connector.sockets, hasLength(SixroomDanmakuCodec.maxRefusals + 1), reason: 'three replacements');
      chat.connector.latest.push(_loginFailed);
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await chat.session.dispose();
    });

    test('a stopping flag ends the session for good', () async {
      final chat = newChat();
      expect(await chat.session.connect(), isNull);
      await _settle();
      final seen = <LiveMessage>[];
      final done = chat.session.events.listen(seen.add).asFuture<void>();
      chat.connector.latest.push(_frameOf({'flag': '102', 'content': '房间已满'}));
      await done;
      expect(seen.single.text, contains('flag 102'));
      expect(chat.connector.sockets, hasLength(1), reason: 'nothing reconnects');
      await chat.session.dispose();
    });

    test('a socket that never joins, closes or goes silent is replaced', () async {
      final chat = newChat();
      expect(await chat.session.connect(), isNull);
      await _settle();
      final first = chat.connector.latest;
      // No login answer in time: the socket is replaced.
      chat.timers.fireLast();
      await _settle();
      chat.timers.fireLast();
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(identical(chat.connector.latest, first), isFalse);
      expect(first.closed, isTrue);
      // The join is confirmed, then the socket closes: replaced again.
      chat.connector.latest.push(_loginSuccess);
      await _settle();
      await chat.connector.latest.ended();
      await _settle();
      chat.timers.fireLast();
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      // Silence: replaced again; a joined run resets the budget.
      chat.connector.latest.push(_loginSuccess);
      await _settle();
      chat.timers.fireLast();
      await _settle();
      chat.timers.fireLast();
      await _settle();
      expect(chat.connector.sockets, hasLength(4));
      await chat.session.dispose();
    });

    test('the server list is rotated, and asked for again once used up', () async {
      final chat = newChat(servers: 'wss.6rooms.com:7281, wss2.6rooms.com:7282');
      expect(await chat.session.connect(), isNull);
      await _settle();
      expect(chat.connector.endpoints.single.host, 'wss.6rooms.com');
      // A refused login takes the next server of the same list.
      chat.connector.latest.push(_loginFailed);
      await _settle();
      chat.timers.fireLast();
      await _settle();
      expect(chat.connector.sockets, hasLength(2));
      expect(chat.connector.endpoints.last.host, 'wss2.6rooms.com');
      expect(chat.http.sent, hasLength(1), reason: 'the list still had a server');
      // Used up: the list is asked for again.
      chat.connector.latest.push(_loginFailed);
      await _settle();
      chat.timers.fireLast();
      await _settle();
      expect(chat.http.sent, hasLength(2));
      expect(chat.connector.endpoints.last.host, 'wss.6rooms.com');
      await chat.session.dispose();
    });

    test('eight handshakes without a joined one end the session', () async {
      final timers = FakeTimers();
      final http = _FakeHttp((_) => _resp(200, _json({'websock': <Object?>[]})));
      final site = SixroomSite(http: SixroomHttp(http), connect: _refuseSocket, now: () => _at);
      final session = SixroomDanmakuSession(args: args, site: site, timers: timers.timers, random: Random(1));
      final seen = <LiveMessage>[];
      final done = session.events.listen(seen.add).asFuture<void>();
      expect(await session.connect(), isNull);
      await _settle();
      for (var attempt = 0; attempt < SixroomDanmakuCodec.maxReconnects; attempt++) {
        timers.fireLast();
        await _settle();
      }
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), isNotEmpty);
      await session.dispose();
    });

    test('an id that is no chat room is refused before any request', () async {
      final connector = _Connector();
      final http = _FakeHttp((_) => _resp(200, '{}'));
      final site = SixroomSite(http: SixroomHttp(http), connect: connector.call, now: () => _at);
      final session = SixroomDanmakuSession(
        args: const SixroomDanmakuArgs(roomId: 'x', userId: _userId),
        site: site,
        timers: FakeTimers().timers,
        random: Random(1),
      );
      expect(await session.connect(), isA<LiveSiteNotFound>());
      await _settle();
      expect(connector.sockets, isEmpty);
      await session.dispose();
    });

    test('a disposed session refuses to connect again', () async {
      final chat = newChat();
      await chat.session.dispose();
      expect(await chat.session.connect(), isA<LiveSiteUnsupported>());
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

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
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/api/yy_http.dart';
import 'package:live_sites/src/platforms/yy/capabilities/yy_link_resolver.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku_codec.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku_session.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_packet.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_json.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_play_parser.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_room_parser.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

/// The clock of the tests: 2026-09-30, in the afternoon.
final DateTime _at = DateTime.parse('2026-09-30T14:00:00.000Z').toUtc();

const int _sid = 12345;
const int _ssid = 12345;
const int _uid = 8888;

String _json(Object? data) => jsonEncode(data);

/// A JSON object literal as an answer holds it.
Map<String, dynamic> _object(Object? data) => jsonDecode(_json(data)) as Map<String, dynamic>;

String _percent(String text) => Uri.encodeQueryComponent(text).replaceAll('+', '%20');

// HTTP fixtures ---------------------------------------------------------------

Map<String, Object?> _card({
  Object? sid = '$_sid',
  Object? ssid = '$_ssid',
  Object? uid = '$_uid',
  String name = '主播甲',
  String desc = '晚上唱歌',
  String users = '1.2万',
  String thumb = 'http://img.yy.com/t.jpg',
  String thumb2 = '',
  String avatar = '//img.yy.com/a.png',
  int startTime = 1727700000,
  String biz = 'sing',
}) => {
  'sid': sid,
  'ssid': ssid,
  'uid': uid,
  'name': name,
  'desc': desc,
  'users': users,
  'thumb': thumb,
  'thumb2': thumb2,
  'avatar': avatar,
  'startTime': startTime,
  'biz': biz,
};

/// A card as the room search carries it: `channelName` for the title, the
/// category name for the area, and no start time.
Map<String, Object?> _searchCard(Map<String, Object?> card, {Object? liveOn = 1}) =>
    {...card, 'channelName': card['desc'], 'category': '音乐', 'liveOn': liveOn}..remove('startTime');

String _listBody({required List<Map<String, Object?>> items, int resultCode = 0, Object? data = 'unset'}) => _json({
  'resultCode': resultCode,
  'data': data == 'unset' ? {'data': items} : data,
});

/// `liveInfoDetail` answers the room object directly.
String _detailBody({Map<String, Object?>? card, int resultCode = 0}) => _json({'resultCode': resultCode, 'data': card});

String _headerBody() => _json({
  'categoryTabs': [
    {'id': '1', 'title': '娱乐'},
    'junk',
    {'id': '2', 'title': '游戏'},
  ],
});

Map<String, Object?> _area({required String id, required String title, String url = '', String cover = ''}) => {
  'id': id,
  'title': title,
  'url': url,
  'cover': cover,
};

String _categoryBody(String parentId) {
  if (parentId == '1') {
    return _json({
      'data': [
        _area(id: '101', title: '音乐', url: 'https://www.yy.com/s/101', cover: '//img.yy.com/music.png'),
        _area(id: '102', title: '小视频', url: 'https://www.yy.com/sv/1'),
      ],
    });
  }
  return _json({
    'data': [_area(id: '201', title: '星秀', url: 'https://www.yy.com/s/201')],
  });
}

String _modulePage({int moduleId = 313, String biz = 'sing', String subBiz = 'idx'}) =>
    '<html><head><title>yy</title></head><body><script> '
    'var pageInfo = { moduleId: $moduleId, biz: "$biz", subBiz: "$subBiz" }; '
    '</script></body></html>';

/// An area page without a JSON listing, whose rooms render in the page.
String _cardPage() =>
    '<html><body><script> '
    'var pageInfo = { moduleId: 0, biz: "null", subBiz: "null" }; '
    '</script><ul> '
    '<li data-sid="11111" data-uid="22222" data-ssid="11111" data-pid="x_y_z_1727700000"> '
    '<div class="box" data-title="手机直播中"><span class="cover"><img data-original="https://img.yy.com/c1.jpg"/></span> '
    '<span class="avt"><img data-original="https://img.yy.com/a1.png"/></span></div> '
    '<span class="title">备用标题</span><span class="intro">主播乙</span><span class="usr">2.1万</span> '
    '</li> '
    '<li data-sid="0123"><span class="title">坏编号</span></li> '
    '<li><span class="title">无编号</span></li> '
    '</ul></body></html>';

String _searchBody({required String tab, required List<Map<String, Object?>> docs, int status = 0}) => _json({
  'success': true,
  'status': status,
  'data': {
    'searchResult': {
      'response': {
        tab: {'docs': docs},
      },
    },
  },
});

Map<String, Object?> _anchorDoc({Object? sid = '$_sid', Object? ssid, String name = '主播甲', Object? liveOn = 1}) => {
  'sid': sid,
  'ssid': ?ssid,
  'name': name,
  'headurl': '//img.yy.com/a.png',
  'liveOn': liveOn,
};

String _roomPageHtml({String sid = '$_sid', String ssid = '$_ssid', bool notFound = false, bool withNick = true}) {
  if (notFound) return '<html><script src="yycom_404.js"></script><body>404</body></html>';
  return '<html><head><title>YY</title></head><body><script> '
      'var pageInfo = { '
      'sid: "$sid", '
      'ssid: "$ssid", '
      'uid: "$_uid", '
      '${withNick ? 'nick: decodeURIComponent("${_percent('主播甲')}"), ' : 'nick: "YY用户", '}'
      'logo: "https://yystatic.com/pc/images/portrait/person/1.jpg", '
      'roomName: "晚上唱歌", '
      'stringBiz: "音乐" '
      '}; '
      '</script></body></html>';
}

final int _flvExpiry = _at.add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000;
final String _flvUrl = 'https://cdn.yy.com/live/${_sid}_2.flv?t=$_flvExpiry';
final String _flvUrl2 = 'https://cdn2.yy.com/live/${_sid}_2.flv?t=$_flvExpiry';
const String _hlsUrl = 'https://hls.yy.com/live/$_sid.m3u8';

String _streamsBody({
  required String url,
  String lineSeq = '10',
  String streamKey = 'k1',
  String gear = '2',
  String name = '蓝光',
  int rate = 4000,
  List<int> others = const [],
  bool withKey = true,
}) => _json({
  'avp_info_res': {
    'stream_line_addr': {
      streamKey: {
        'cdn_info': {'url': url},
        'line_seq': lineSeq,
      },
    },
    'stream_line_list': {
      streamKey: {
        'line_infos': [
          {'line_seq': 10},
          for (final line in others) {'line_seq': line},
        ],
      },
    },
  },
  'channel_stream_info': {
    'streams': [
      {
        'stream_key': withKey ? streamKey : null,
        'json': _json({
          'gear_info': {'gear': gear, 'name': name},
          'rate': rate,
        }),
      },
    ],
  },
});

String _mobileBody({
  required int code,
  String hls = _hlsUrl,
  int width = 1280,
  int height = 720,
  String video = 'h264',
}) => '({"code":$code,"hls":"$hls","width":$width,"height":$height,"video":"$video"})';

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(body)));

/// The `avp_parameter` of a stream-manager request the fake transport saw.
Map<String, Object?> _avpOf(_Seen request) {
  final body = jsonDecode(request.body!) as Map<String, Object?>;
  return body['avp_parameter']! as Map<String, Object?>;
}

final class _Seen {
  _Seen(LiveRequest request) : url = request.url, body = request.body, method = request.method;
  final Uri url;
  final String? body;
  final String method;
}

final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);
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

/// The site's ordinary answers: a live channel 12345 with every route serving
/// a stream.
Future<LiveResponse> _ordinary(_Seen request) async {
  final path = request.url.path;
  if (path == '/yyweb/module/data/header') return _resp(200, _headerBody());
  if (path == '/c/yycom/category/getCategory.action') {
    return _resp(200, _categoryBody(request.url.queryParameters['parentId']!));
  }
  if (path == '/more/page.action') return _resp(200, _listBody(items: [_card()]));
  if (path == '/apiSearch/doSearch.json') {
    return _resp(
      200,
      request.url.queryParameters['t'] == '120'
          ? _searchBody(
              tab: '120',
              docs: [_searchCard(_card(desc: '搜索到的房间', users: '800'))],
            )
          : _searchBody(tab: '1', docs: [_anchorDoc()]),
    );
  }
  if (path == '/api/liveInfoDetail/$_sid/$_sid/0') {
    return _resp(200, _detailBody(card: _card(users: '3456')));
  }
  if (path == '/api/liveInfoDetail/9999/9999/0' || path == '/api/liveInfoDetail/4321/4321/0') {
    return _resp(200, _detailBody());
  }
  if (path == '/$_sid') return _resp(200, _roomPageHtml());
  if (path == '/9999') return _resp(200, _roomPageHtml());
  if (path == '/4321') return _resp(200, _roomPageHtml(notFound: true));
  if (path == '/s/101') return _resp(200, _modulePage());
  if (path == '/s/201') return _resp(200, _cardPage());
  if (request.url.host == 'stream-manager.yy.com') {
    final avp = _avpOf(request);
    final gear = avp['gear']! as int;
    final line = avp['line_seq']! as int;
    if (line != -1) return _resp(200, _streamsBody(url: _flvUrl2, lineSeq: '14'));
    if (gear == 2) return _resp(200, _streamsBody(url: _flvUrl, others: [14]));
    return _resp(200, _streamsBody(url: _flvUrl.replaceFirst('_2.flv', '_1.flv'), gear: '1', name: '流畅', rate: 1000));
  }
  if (request.url.host == 'interface.yy.com') {
    return _resp(
      200,
      request.url.pathSegments.last == '1200'
          ? _mobileBody(code: 0, hls: 'https://hls.yy.com/live/${_sid}_low.m3u8', width: 640, height: 360, video: 'low')
          : _mobileBody(code: 0),
    );
  }
  return _resp(404, 'nope');
}

// Socket fixtures -------------------------------------------------------------

/// A connector that refuses: a test that needs a socket replaces it.
Future<SocketChannel> _refuseSocket(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) => Future.error(StateError('no socket was asked for in this test'));

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

  /// The uris of the packets sent, for a search through them.
  List<int> get sentUris => [
    for (final frame in sentList.whereType<Uint8List>())
      if (frame.length >= 10) ByteData.sublistView(frame).getUint32(4, Endian.little),
  ];
}

final class _Connector {
  final List<_FakeSocket> sockets = [];
  final List<Uri> endpoints = [];
  final List<Map<String, String>> headerSets = [];

  _FakeSocket get latest => sockets.last;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    endpoints.add(endpoint);
    headerSets.add(headers);
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

  YyTimers get timers => (after: _after, every: _every);

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

// Danmaku packet fixtures -----------------------------------------------------

Uint8List _udbAnswer({int envelopeCode = 0, int resultCode = 0, int uid = 61000000000, int realUri = 20078}) {
  final payload = YyPacketWriter()
    ..writeString('zh')
    ..writeUint32(resultCode)
    ..writeUint32(12345)
    ..writeUint32(777)
    ..writeString('anon-name')
    ..writeString('anon-pass')
    ..writeByteArray([1, 2, 3])
    ..writeByteArray([9, 9])
    ..writeString('s1')
    ..writeString('s2')
    ..writeUint64(uid);
  return (YyPacketWriter(uri: 778500)
        ..writeString('')
        ..writeUint32(envelopeCode)
        ..writeUint32(realUri)
        ..writeByteArray32(payload.takeBytes()))
      .takeBytes();
}

Uint8List _apAnswer({int code = 200}) =>
    (YyPacketWriter(uri: 775940)
          ..writeUint32(259)
          ..writeUint32(code)
          ..writeString('259:0'))
        .takeBytes();

Uint8List _joinAnswer({int topSid = _sid, int subSid = _ssid, int status = 4, int responseCode = 0}) {
  final payload = YyPacketWriter()
    ..writeUint32(topSid)
    ..writeUint32(1)
    ..writeUint32(subSid)
    ..writeUint32(3)
    ..writeUint32(100)
    ..writeUint8(status)
    ..writeUtf8String(status == 4 ? '' : 'full');
  return (YyPacketWriter(uri: 512011)
        ..writeString('')
        ..writeUint32(2048514)
        ..writeUint16(responseCode)
        ..writeByteArray32(payload.takeBytes()))
      .takeBytes();
}

/// A chat packet of [text], carried by the user group route or the by-sid
/// route.
Uint8List _chatPacket({
  required String text,
  String name = '观众甲',
  int topSid = _sid,
  int subSid = _ssid,
  bool bySid = false,
}) {
  final block = YyPacketWriter()
    ..writeUint32(0)
    ..writeUcs2String32('Arial')
    ..writeUint32(0xffffff)
    ..writeUint32(25)
    ..writeUcs2String32(text)
    ..writeUint32(0);
  final blockBytes = block.takeBytes();
  final chat =
      (YyPacketWriter(uri: 3104600)
            ..writeUint32(1001)
            ..writeUint32(topSid)
            ..writeUint32(subSid)
            ..writeUint16(blockBytes.length)
            ..writeBytes(blockBytes)
            ..writeString('')
            ..writeString('')
            ..writeUtf8String(name)
            ..writeUint32(0))
          .takeBytes();
  if (bySid) {
    return (YyPacketWriter(uri: 28760)
          ..writeUint16(31)
          ..writeUint32(topSid)
          ..writeByteArray(chat))
        .takeBytes();
  }
  return (YyPacketWriter(uri: 533080)
        ..writeUint64(1)
        ..writeUint64(2)
        ..writeUint32(31)
        ..writeByteArray32(chat))
      .takeBytes();
}

Uint8List _heatPacket({required int heat, int topSid = _sid, bool shortBody = false}) {
  final body = YyPacketWriter(uri: 3139586)
    ..writeUint32(heat)
    ..writeUint32(1)
    ..writeUint32(topSid)
    ..writeUint32(heat - 100);
  final bytes = shortBody ? Uint8List(4) : body.takeBytes();
  return (YyPacketWriter(uri: 533080)
        ..writeUint64(1)
        ..writeUint64(2)
        ..writeUint32(103)
        ..writeByteArray32(bytes))
      .takeBytes();
}

/// A user group packet of app 31 whose payload claims more bytes than it
/// carries: a malformed message.
Uint8List _brokenUserGroup() =>
    (YyPacketWriter(uri: 533080)
          ..writeUint64(1)
          ..writeUint64(2)
          ..writeUint32(31)
          ..writeUint32(0xffffffff))
        .takeBytes();

YyProtocolSession _protocol() => YyProtocolSession(topSid: _sid, subSid: _ssid, uuid: 'uuid-1');

/// Drives a session's socket through the whole anonymous handshake.
Future<void> _joinByHand(_FakeSocket socket) async {
  socket.push(_udbAnswer());
  await _settle();
  socket.push(_apAnswer());
  await _settle();
  socket.push(_joinAnswer());
  await _settle();
}

/// A danmaku session over a fake transport and fake timers, connected.
Future<({YyDanmakuSession session, _FakeSocket socket, FakeTimers timers, _Connector connector})> _chat() async {
  final connector = _Connector();
  final timers = FakeTimers();
  final session = YyDanmakuSession(
    args: const YyDanmakuArgs(topSid: _sid, subSid: _ssid),
    site: YySite(http: YyHttp(_FakeHttp(_ordinary)), connect: connector.call),
    timers: timers.timers,
    now: () => _at,
  );
  expect(await session.connect(), isNull);
  await _settle();
  return (session: session, socket: connector.latest, timers: timers, connector: connector);
}

YyFailureKind _kindOf(Object? Function() body) {
  try {
    body();
  } on YyFailure catch (failure) {
    return failure.kind;
  }
  fail('no failure was thrown');
}

void main() {
  group('readers and failures', () {
    test('a status says what kind of answer it is', () {
      expect(_kindOf(() => YyJson.decoded('{"a":1}', status: 429, what: 'x')), YyFailureKind.rateLimited);
      expect(_kindOf(() => YyJson.decoded('{}', status: 401, what: 'x')), YyFailureKind.riskControl);
      expect(_kindOf(() => YyJson.decoded('{}', status: 403, what: 'x')), YyFailureKind.riskControl);
      expect(_kindOf(() => YyJson.decoded('{}', status: 500, what: 'x')), YyFailureKind.network);
      expect(_kindOf(() => YyJson.decoded('{}', status: 302, what: 'x')), YyFailureKind.apiChanged);
      expect(YyJson.decoded('not json', status: 200, what: 'x'), isNull);
      expect(YyJson.decoded('{"a":1}', status: 200, what: 'x'), {'a': 1});
      expect(_kindOf(() => YyJson.checkPage(429, 'x')), YyFailureKind.rateLimited);
      expect(_kindOf(() => YyJson.checkPage(401, 'x')), YyFailureKind.riskControl);
      expect(_kindOf(() => YyJson.checkPage(502, 'x')), YyFailureKind.network);
      expect(_kindOf(() => YyJson.checkPage(404, 'x')), YyFailureKind.apiChanged);
      YyJson.checkPage(200, 'x');
    });

    test('the resultCode envelope must be 0 and an object', () {
      expect(
        () => YyJson.checked(_json({'resultCode': 1, 'data': null}), status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('resultCode 1'))),
      );
      expect(
        () => YyJson.checked('[1,2]', status: 200, what: 'x'),
        throwsA(predicate((e) => '$e'.contains('not a JSON object'))),
      );
      expect(YyJson.checked(_json({'resultCode': 0, 'data': 1}), status: 200, what: 'x')['data'], 1);
    });

    test('text, numbers and times are read tolerantly but bounded', () {
      expect(YyJson.text(' x '), 'x');
      expect(YyJson.text(12), '');
      expect(YyJson.integer('42'), 42);
      expect(YyJson.integer('x'), isNull);
      expect(YyJson.channel('$_sid'), '$_sid');
      expect(YyJson.channel('0123'), isNull, reason: 'no leading zeros');
      expect(YyJson.channel('0'), isNull);
      expect(YyJson.channel(''), isNull);
      expect(YyJson.isLive(1), isTrue);
      expect(YyJson.isLive('live'), isTrue);
      expect(YyJson.isLive('0'), isFalse);
      expect(YyJson.title('主播甲 正在直播'), '主播甲');
      expect(YyJson.title('主播甲正在直播'), '主播甲');
      expect(YyJson.title('晚上唱歌'), '晚上唱歌');
      expect(YyJson.name('YY用户'), '');
      expect(YyJson.name(' 主播甲 '), '主播甲');
      expect(YyJson.startedAt(1727700000), DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
      expect(YyJson.startedAt(0), isNull);
      expect(YyJson.startedAt(-5), isNull);
      expect(YyJson.image('//img.yy.com/a.png'), 'https://img.yy.com/a.png');
      expect(YyJson.image('http://img.yy.com/a.png'), 'https://img.yy.com/a.png');
      expect(YyJson.image('img.yy.com/a.png'), 'https://img.yy.com/a.png');
      expect(YyJson.image('nope'), '');
      expect(YyJson.snippet('a b\nc'), 'a b c');
      expect(YyJson.snippet('x' * 100).length, 81, reason: '80 characters plus the ellipsis');
    });

    test('percentDecode is decodeURIComponent without throwing', () {
      expect(YyJson.percentDecode('%E4%B8%BB%E6%92%AD%E7%94%B2'), '主播甲');
      expect(YyJson.percentDecode('a%zzb'), 'a%zzb', reason: 'a malformed escape stays as written');
      expect(YyJson.percentDecode('%E4%BD'), contains('\uFFFD'), reason: 'malformed UTF-8');
      expect(YyJson.percentDecode('100%'), '100%');
    });

    test('failures map onto the Either side and their retries are bounded', () {
      const failure = YyFailure(YyFailureKind.network, 'down', cause: 'x');
      expect(failure.isTransient, isTrue);
      expect(const YyFailure(YyFailureKind.rateLimited, 'slow').isTransient, isTrue);
      expect(const YyFailure(YyFailureKind.notFound, 'gone').isTransient, isFalse);
      expect(const YyFailure(YyFailureKind.apiChanged, 'moved').isTransient, isFalse);
      expect(failure.toLiveSiteError('yy'), isA<LiveSiteNetworkError>());
      expect(const YyFailure(YyFailureKind.riskControl, 'risk').toLiveSiteError('yy'), isA<LiveSiteRateLimitError>());
      expect(
        const YyFailure(YyFailureKind.rateLimited, 'throttled').toLiveSiteError('yy'),
        isA<LiveSiteRateLimitError>(),
      );
      expect(const YyFailure(YyFailureKind.notFound, 'gone').toLiveSiteError('yy'), isA<LiveSiteNotFound>());
      expect(const YyFailure(YyFailureKind.apiChanged, 'moved').toLiveSiteError('yy'), isA<LiveSiteParseError>());
      expect(
        const YyFailure(YyFailureKind.streamUnavailable, 'nothing').toLiveSiteError('yy'),
        isA<LiveSiteContentUnavailable>(),
      );
      expect(
        const YyFailure(YyFailureKind.invalidArgument, 'wrong').toLiveSiteError('yy'),
        isA<LiveSiteInvalidArgument>(),
      );
    });
  });

  group('catalog parsing', () {
    test('the header names the categories; a broken shape is api-changed', () {
      final tabs = YyRoomParser.categoryTabs(_headerBody());
      expect(tabs.map((tab) => tab.id), ['1', '2'], reason: 'broken rows are skipped');
      expect(
        () => YyRoomParser.categoryTabs(_json({'data': <Object?>[]})),
        throwsA(predicate((e) => '$e'.contains('no categoryTabs'))),
      );
    });

    test('the areas carry their category and page; the short-video page is known', () {
      final entries = YyRoomParser.areas(_categoryBody('1'), categoryId: '1', categoryName: '娱乐');
      expect(entries, hasLength(2));
      expect(entries.first.area.areaId, '101');
      expect(entries.first.area.areaName, '音乐');
      expect(entries.first.area.parentAreaId, '1');
      expect(entries.first.area.parentAreaName, '娱乐');
      expect(entries.first.area.iconUrl, 'https://img.yy.com/music.png');
      expect(entries.first.page, Uri.parse('https://www.yy.com/s/101'));
      expect(YyRoomParser.isShortVideoPage(entries.last.page), isTrue);
      expect(YyRoomParser.isShortVideoPage(entries.first.page), isFalse);
      expect(
        () => YyRoomParser.areas(_json({'data': <String, Object?>{}}), categoryId: '1', categoryName: '娱乐'),
        throwsA(predicate((e) => '$e'.contains('no data'))),
      );
    });

    test('the listing module survives a shortName round trip', () {
      const module = (moduleId: 313, biz: 'dance', subBiz: 'idx');
      final stored = YyRoomParser.shortName(module);
      expect(YyRoomParser.moduleOf(stored), module);
      expect(YyRoomParser.moduleOf('not json'), isNull);
      expect(YyRoomParser.moduleOf(_json({'moduleId': 1})), isNull);
      expect(YyRoomParser.hasListing(module), isTrue);
      expect(YyRoomParser.hasListing((moduleId: 0, biz: 'null', subBiz: 'null')), isFalse);
    });

    test('pageInfo reads the module out of the page', () {
      expect(YyRoomParser.pageInfo(_modulePage()), (moduleId: 313, biz: 'sing', subBiz: 'idx'));
      expect(YyRoomParser.pageInfo(_modulePage(moduleId: 0, biz: 'null', subBiz: 'null')), (
        moduleId: 0,
        biz: 'null',
        subBiz: 'null',
      ));
      expect(YyRoomParser.pageInfo('<html>nothing</html>'), isNull);
      expect(YyRoomParser.pageInfo(_modulePage(biz: '')), isNull);
    });
  });

  group('listings and search parsing', () {
    test('a list card is read with its channel, title, audience and area', () {
      final entries = YyRoomParser.roomList(_listBody(items: [_card(desc: '主播甲 正在直播')]));
      expect(entries, hasLength(1));
      final (:room, :channel) = entries.single;
      expect(room.roomId, '$_sid');
      expect(channel, (sid: '$_sid', ssid: '$_ssid'));
      expect(room.content.title, '主播甲', reason: 'the default suffix is cut');
      expect(room.content.coverUrl, 'https://img.yy.com/t.jpg', reason: 'thumb2 empty, thumb kept, http upgraded');
      expect(room.anchor?.name, '主播甲');
      expect(room.anchor?.avatarUrl, 'https://img.yy.com/a.png');
      expect(room.audience.popularity, 12000, reason: '1.2万');
      expect(room.audience.primaryMetric, LiveAudienceMetricType.popularity);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
      expect(room.links.webUrl, 'https://www.yy.com/$_sid');
      // The preset names the area by biz.
      expect(YyRoomParser.roomList(_listBody(items: [_card()])).single.room.area?.areaName, '音乐');
      // A learnt name wins; the raw other means no area.
      final learnt = YyRoomParser.roomList(
        _listBody(items: [_card(biz: 'talk')]),
        areaNames: {'talk': '唱见'},
      );
      expect(learnt.single.room.area?.areaName, '唱见');
      expect(YyRoomParser.roomList(_listBody(items: [_card(biz: 'other')])).single.room.area?.areaName, '');
      // An explicit area label wins over everything.
      final labelled = YyRoomParser.roomList(_listBody(items: [_card()]), area: '星秀');
      expect(labelled.single.room.area?.areaName, '星秀');
    });

    test('a card without a channel is dropped; a broken envelope is api-changed', () {
      expect(
        YyRoomParser.roomList(
          _listBody(
            items: [
              _card(sid: 'x'),
              _card(),
            ],
          ),
        ),
        hasLength(1),
      );
      expect(YyRoomParser.roomList(_listBody(items: [], data: null)), isEmpty, reason: 'an area without listing');
      expect(
        () => YyRoomParser.roomList(_listBody(items: [], data: 'no')),
        throwsA(predicate((e) => '$e'.contains('data is not an object'))),
      );
      expect(
        () => YyRoomParser.roomList(
          _json({
            'resultCode': 0,
            'data': {'data': 'no'},
          }),
        ),
        throwsA(predicate((e) => '$e'.contains('data.data is not a list'))),
      );
      expect(
        () => YyRoomParser.roomList(_listBody(items: [], resultCode: 7)),
        throwsA(predicate((e) => '$e'.contains('resultCode 7'))),
      );
    });

    test('the room search reads channelName, the category and liveOn', () {
      final entries = YyRoomParser.searchRooms(
        _searchBody(
          tab: '120',
          docs: [_searchCard(_card(desc: '找到的房', users: '800'))],
        ),
      );
      expect(entries, hasLength(1));
      expect(entries.single.room.content.title, '找到的房');
      expect(entries.single.room.area?.areaName, '音乐', reason: 'the search names the category');
      expect(entries.single.room.broadcast.startedAt, isNull, reason: 'search results carry no start time');
      expect(entries.single.room.broadcast.liveStatus, LiveStatus.live);

      final offline = YyRoomParser.searchRooms(
        _searchBody(
          tab: '120',
          docs: [_searchCard(_card(desc: '没播'), liveOn: 0)],
        ),
      );
      expect(offline.single.room.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.single.room.anchor?.liveStatus, LiveStatus.offline);
      expect(
        YyRoomParser.searchRooms(
          _searchBody(
            tab: '120',
            docs: [_searchCard(_card(sid: 'x'))],
          ),
        ),
        isEmpty,
      );
    });

    test('the anchor search reads streamers live or not', () {
      final anchors = YyRoomParser.searchAnchors(
        _searchBody(
          tab: '1',
          docs: [
            _anchorDoc(),
            _anchorDoc(liveOn: 0),
            _anchorDoc(name: ''),
          ],
        ),
      );
      expect(anchors, hasLength(3));
      expect(anchors.first.anchorId, '$_sid');
      expect(anchors.first.name, '主播甲');
      expect(anchors.first.liveStatus, LiveStatus.live);
      expect(anchors[1].liveStatus, LiveStatus.offline);
      final bySsid = YyRoomParser.searchAnchors(
        _searchBody(
          tab: '1',
          docs: [
            {'ssid': '4321', 'liveOn': 1},
          ],
        ),
      );
      expect(bySsid.single.anchorId, '4321');
    });

    test('a refused search is api-changed', () {
      expect(
        () => YyRoomParser.searchAnchors(_searchBody(tab: '1', docs: [], status: 3)),
        throwsA(predicate((e) => '$e'.contains('status 3'))),
      );
      expect(
        () => YyRoomParser.searchAnchors(_json({'success': true, 'status': 0, 'data': <String, Object?>{}})),
        throwsA(predicate((e) => '$e'.contains('no searchResult'))),
      );
      expect(() => YyRoomParser.searchAnchors(_json({'success': false, 'status': 0})), throwsA(isA<YyFailure>()));
    });
  });

  group('room parsing', () {
    test('the live detail keeps the requested id and the canonical channel', () {
      final entry = YyRoomParser.liveDetail(
        _detailBody(card: _card(users: '3456')),
        requestedId: '$_sid',
      );
      expect(entry, isNotNull);
      expect(entry!.room.roomId, '$_sid');
      expect(entry.channel, (sid: '$_sid', ssid: '$_ssid'));
      expect(entry.room.audience.popularity, 3456);
      // A short number keeps its identity; the canonical channel rides along.
      final short = YyRoomParser.liveDetail(
        _detailBody(
          card: _card(desc: '短号', users: '1'),
        ),
        requestedId: '9999',
      );
      expect(short!.room.roomId, '9999');
      expect(short.room.links.webUrl, 'https://www.yy.com/9999');
      // An offline channel answers data null: nothing.
      expect(YyRoomParser.liveDetail(_detailBody(), requestedId: '$_sid'), isNull);
      expect(
        () => YyRoomParser.liveDetail(_json({'resultCode': 0, 'data': 3}), requestedId: '$_sid'),
        throwsA(predicate((e) => '$e'.contains('data is not an object'))),
      );
    });

    test('the room page names the channel, streamer and area', () {
      final page = YyRoomParser.roomPage(_roomPageHtml());
      expect(page.sid, '$_sid');
      expect(page.ssid, '$_ssid');
      expect(page.uid, '$_uid');
      expect(page.nick, '主播甲');
      expect(page.avatar, '', reason: 'a default portrait is no avatar');
      expect(page.title, '晚上唱歌');
      expect(page.area, '音乐');
      // A placeholder name is none.
      expect(YyRoomParser.roomPage(_roomPageHtml(withNick: false)).nick, '');
      // The 404 shape and a page without pageInfo are told apart.
      expect(
        () => YyRoomParser.roomPage(_roomPageHtml(notFound: true)),
        throwsA(predicate((e) => e is YyFailure && e.kind == YyFailureKind.notFound)),
      );
      expect(() => YyRoomParser.roomPage('<html>gone</html>'), throwsA(predicate((e) => '$e'.contains('no pageInfo'))));
      expect(() => YyRoomParser.roomPage(_roomPageHtml(sid: '0')), throwsA(predicate((e) => '$e'.contains('no sid'))));
      expect(
        () => YyRoomParser.roomPage('fine', status: 500),
        throwsA(predicate((e) => e is YyFailure && e.kind == YyFailureKind.network)),
      );
      expect(
        () => YyRoomParser.roomPage('fine', status: 403),
        throwsA(predicate((e) => e is YyFailure && e.kind == YyFailureKind.riskControl)),
      );
    });

    test('a module-less area page lists its own cards', () {
      final entries = YyRoomParser.pageRooms(_cardPage(), area: '星秀');
      expect(entries, hasLength(1), reason: 'the broken and id-less cards are dropped');
      final (:room, :channel) = entries.single;
      expect(room.roomId, '11111');
      expect(channel.ssid, '11111');
      expect(room.content.title, '手机直播中', reason: 'the box data-title wins over the title part');
      expect(room.content.coverUrl, 'https://img.yy.com/c1.jpg');
      expect(room.anchor?.name, '主播乙');
      expect(room.anchor?.avatarUrl, 'https://img.yy.com/a1.png');
      expect(room.audience.popularity, 21000);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
      expect(YyRoomParser.pageRooms('<html>小视频</html>', area: '星秀'), isEmpty);
    });

    test('the offline room carries the page when there is one', () {
      final bare = YyRoomParser.offlineRoom(requestedId: '$_sid');
      expect(bare.roomId, '$_sid');
      expect(bare.broadcast.liveStatus, LiveStatus.offline);
      expect(bare.anchor, isNull, reason: 'without the page nobody is named');
      final page = YyRoomParser.roomPage(_roomPageHtml());
      final withPage = YyRoomParser.offlineRoom(requestedId: '$_sid', page: page);
      expect(withPage.anchor?.name, '主播甲');
      expect(withPage.content.title, '晚上唱歌');
      expect(withPage.audience.popularity, isNull, reason: 'never an audience offline');
    });
  });

  group('streams parsing', () {
    test('the qualities list the gears with a stream, best rate first', () {
      final streams = _object({
        'channel_stream_info': {
          'streams': [
            {
              'stream_key': 'a',
              'json': _json({
                'gear_info': {'gear': '2', 'name': '蓝光'},
                'rate': 4000,
              }),
            },
            {
              'stream_key': 'b',
              'json': _json({
                'gear_info': {'gear': '1', 'name': '流畅'},
                'rate': 1000,
              }),
            },
            {
              'stream_key': null,
              'json': _json({
                'gear_info': {'gear': '0', 'name': 'mix'},
                'rate': 2000,
              }),
            },
            {
              'stream_key': 'c',
              'json': _json({
                'gear_info': {'gear': '2', 'name': '蓝光'},
                'rate': 3999,
              }),
            },
          ],
        },
      });
      final qualities = YyPlayParser.qualities(streams);
      expect(qualities.map((quality) => quality.qualityId), [
        '2',
        '1',
      ], reason: 'the first stream of a gear wins, mix has none');
      expect(qualities.first.label, '蓝光');
      expect(qualities.first.platformOrder, 4000);
      // A name used by two gears gets the gear appended.
      final shared = YyPlayParser.qualities(
        _object({
          'channel_stream_info': {
            'streams': [
              {
                'stream_key': 'a',
                'json': _json({
                  'gear_info': {'gear': '2', 'name': '高清'},
                  'rate': 4000,
                }),
              },
              {
                'stream_key': 'b',
                'json': _json({
                  'gear_info': {'gear': '15', 'name': '高清'},
                  'rate': 2000,
                }),
              },
            ],
          },
        }),
      );
      expect(shared.map((quality) => quality.label), ['高清 · 2', '高清 · 15']);
    });

    test('the resolution lists every line with its lease and the applied gear', () {
      final streams = _object({
        'avp_info_res': {
          'stream_line_addr': {
            'k1': {
              'cdn_info': {'url': '//cdn.yy.com/live/a.flv?t=1792000000'},
              'line_seq': '10',
            },
            'k1b': {
              'cdn_info': {'url': _flvUrl},
              'line_seq': '14',
            },
            'bad': {
              'cdn_info': {'url': 'not a url'},
              'line_seq': '15',
            },
          },
          'stream_line_list': {
            'k1': {
              'line_infos': [
                {'line_seq': 10},
                {'line_seq': 14},
              ],
            },
          },
        },
        'channel_stream_info': {
          'streams': [
            {
              'stream_key': 'k1',
              'json': _json({
                'gear_info': {'gear': '2', 'name': '蓝光'},
                'rate': 4000,
              }),
            },
            {
              'stream_key': 'k1b',
              'json': _json({
                'gear_info': {'gear': '2', 'name': '蓝光'},
                'rate': 4000,
              }),
            },
          ],
        },
      });
      final (:lines, :appliedGear) = YyPlayParser.resolution(streams, issuedAt: _at, cookie: 'a=b');
      expect(appliedGear, '2');
      expect(lines, hasLength(2), reason: 'the protocol-relative line counts, the duplicate and the bad url do not');
      expect(lines.first.url, 'https://cdn.yy.com/live/a.flv?t=1792000000');
      expect(lines.first.format, LiveStreamFormat.flv);
      expect(lines.first.lineLabel, '10');
      expect(lines.first.headers['origin'], YyEndpoints.origin);
      expect(lines.first.headers['cookie'], 'a=b');
      // The lease: renew a minute before the t expiry.
      final lease = lines.first.lease!;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(1792000000 * 1000, isUtc: true);
      expect(lease.expiresAt, expiresAt);
      expect(lease.refreshAt, expiresAt.subtract(const Duration(minutes: 1)));
    });

    test('a lease needs a future t, and only a flv one', () {
      expect(YyPlayParser.lease(Uri.parse('https://cdn.yy.com/a.flv'), _at), isNull, reason: 'no t');
      expect(YyPlayParser.lease(Uri.parse('https://cdn.yy.com/a.flv?t=200'), _at), isNull, reason: 'no plausible t');
      expect(
        YyPlayParser.lease(Uri.parse('https://cdn.yy.com/a.flv?t=${_at.millisecondsSinceEpoch ~/ 1000}'), _at),
        isNull,
        reason: 'already past',
      );
      expect(
        YyPlayParser.lease(Uri.parse('https://cdn.yy.com/a.m3u8?t=1792000000'), _at),
        isNull,
        reason: 'mobile HLS urls carry their issue in t',
      );
      final short = YyPlayParser.lease(
        Uri.parse('https://cdn.yy.com/a.flv?t=${_at.add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000}'),
        _at,
      );
      expect(
        short!.refreshAt,
        short.expiresAt!.subtract(const Duration(seconds: 15)),
        reason: 'a quarter of the lifetime',
      );
    });

    test('the other CDN lines are those the stream is on but was not served on', () {
      final streams = _object({
        'avp_info_res': {
          'stream_line_addr': {
            'k1': {'line_seq': '10'},
          },
          'stream_line_list': {
            'k1': {
              'line_infos': [
                {'line_seq': 10},
                {'line_seq': 14},
                {'line_seq': 14},
                {'line_seq': -1},
              ],
            },
          },
        },
      });
      expect(YyPlayParser.otherLines(streams), [14]);
      expect(YyPlayParser.otherLines(_object({})), isEmpty);
    });

    test('withLines merges the answers that served the same gear', () {
      LivePlayLine line(String url) =>
          LivePlayLine(url: url, format: LiveStreamFormat.flv, formatSource: LivePlayFormatSource.inferred);
      final first = (lines: [line('a'), line('b')], appliedGear: '2');
      final otherSame = (lines: [line('c'), line('b')], appliedGear: '2');
      final otherGear = (lines: [line('d')], appliedGear: '1');
      final unknown = (lines: [line('e')], appliedGear: null);
      expect(YyPlayParser.withLines(first, [otherSame, otherGear, unknown]).map((line) => line.url), ['a', 'b', 'c']);
      expect(YyPlayParser.withLines(unknown, [otherSame]).map((line) => line.url), ['e']);
    });

    test('the stream-manager answer is gated', () {
      expect(() => YyPlayParser.streams('nope'), throwsA(predicate((e) => '$e'.contains('not a JSON object'))));
      expect(_kindOf(() => YyPlayParser.streams('{}', status: 500)), YyFailureKind.network);
      expect(_kindOf(() => YyPlayParser.streams('{}', status: 429)), YyFailureKind.rateLimited);
      expect(_kindOf(() => YyPlayParser.streams('{}', status: 403)), YyFailureKind.riskControl);
    });

    test('the mobile HLS answer is read out of its JSONP wrapper', () {
      final hls = YyPlayParser.mobileHls(_mobileBody(code: 0));
      expect(hls, isNotNull);
      expect(hls!.url, Uri.parse(_hlsUrl));
      expect(hls.width, 1280);
      expect(hls.height, 720);
      expect(hls.video, 'h264');
      expect(YyPlayParser.mobileHls(_mobileBody(code: 1)), isNull, reason: 'an offline channel');
      expect(YyPlayParser.mobileHls(_mobileBody(code: 0, hls: '')), isNull, reason: 'no playlist');
      expect(
        () => YyPlayParser.mobileHls('this is not json at all'),
        throwsA(predicate((e) => '$e'.contains('no JSON object'))),
      );
      expect(_kindOf(() => YyPlayParser.mobileHls('x', status: 503)), YyFailureKind.network);
      expect(_kindOf(() => YyPlayParser.mobileHls('x', status: 401)), YyFailureKind.riskControl);
    });

    test('the mobile qualities keep the higher request of one stream', () {
      final qualities = YyPlayParser.mobileQualities([
        (rate: '1200', hls: (url: Uri.parse('https://h.yy.com/low.m3u8'), width: 640, height: 360, video: 'low')),
        (rate: '4000', hls: (url: Uri.parse('https://h.yy.com/high.m3u8'), width: 1280, height: 720, video: 'high')),
      ]);
      expect(qualities.map((quality) => quality.qualityId), ['mobile-hls:4000', 'mobile-hls:1200']);
      expect(qualities.last.label, '流畅 · 360p');
      expect(qualities.first.label, '高清 · 720p');
      // A rate that failed is left out; a stream without an edge has no p.
      final single = YyPlayParser.mobileQualities([
        (rate: '1200', hls: (url: Uri.parse('https://h.yy.com/low.m3u8'), width: 0, height: 0, video: '')),
      ]);
      expect(single.single.label, '流畅');
      expect(YyPlayParser.mobileQualities([(rate: '1200', hls: null)]), isEmpty);
    });
  });

  group('packet codec', () {
    test('numbers, bytes and strings round trip little endian', () {
      final writer = YyPacketWriter()
        ..writeUint8(0x12)
        ..writeUint16(0x1234)
        ..writeUint32(0x12345678)
        ..writeUint64((1 << 40) | 12345)
        ..writeByteArray([1, 2, 3])
        ..writeByteArray32([4, 5])
        ..writeString('ab')
        ..writeUtf8String('中文')
        ..writeUcs2String32('中文ab');
      final reader = YyPacketReader(writer.takeBytes());
      expect(reader.readUint8(), 0x12);
      expect(reader.readUint16(), 0x1234);
      expect(reader.readUint32(), 0x12345678);
      expect(reader.readUint64(), (1 << 40) | 12345);
      expect(reader.readByteArray(), [1, 2, 3]);
      expect(reader.readByteArray32(), [4, 5]);
      expect(reader.readString(), 'ab');
      expect(reader.readUtf8String(), '中文');
      expect(reader.readUcs2String32(), '中文ab');
      expect(reader.bytesAvailable, 0);
    });

    test('a packet with a uri carries its length, uri and code', () {
      final packet = (YyPacketWriter(uri: 794116)..writeUint32(0)).takeBytes();
      expect(packet.length, 14);
      final reader = YyPacketReader(packet, hasHeader: true);
      expect(reader.packetLength, 14);
      expect(reader.uri, 794116);
      expect(reader.responseCode, 200);
      expect(reader.readUint32(), 0);
    });

    test('reads past the end and a broken header throw', () {
      expect(() => YyPacketReader(Uint8List.fromList([1, 2, 3])).readUint32(), throwsFormatException);
      expect(
        () => YyPacketReader(Uint8List.fromList([8, 0, 0, 0, 1, 2, 3, 4]), hasHeader: true),
        throwsFormatException,
        reason: 'a length below 10',
      );
      final packet = (YyPacketWriter(uri: 1)..writeUint32(0)).takeBytes();
      expect(
        () => YyPacketReader(Uint8List.sublistView(packet, 0, packet.length - 2), hasHeader: true),
        throwsFormatException,
        reason: 'a length past the end',
      );
    });

    test('an odd UCS-2 byte is ignored and malformed UTF-8 becomes U+FFFD', () {
      final odd = YyPacketWriter()
        ..writeUint32(3)
        ..writeBytes([0x61, 0, 0x62]);
      expect(YyPacketReader(odd.takeBytes()).readUcs2String32(), 'a', reason: 'the odd last byte is dropped');
      final bad = YyPacketWriter()
        ..writeUint16(2)
        ..writeBytes([0xff, 0xfe]);
      expect(YyPacketReader(bad.takeBytes()).readUtf8String(), contains('\uFFFD'));
    });
  });

  group('protocol session', () {
    test('beginHandshake sends the anonymous login', () {
      final session = _protocol();
      expect(session.phase, YyProtocolPhase.idle);
      final login = session.beginHandshake();
      final reader = YyPacketReader(login, hasHeader: true);
      expect(reader.uri, 778244);
      expect(reader.responseCode, 200);
      reader.readString();
      expect(reader.readUint32(), 19822);
      final payload = YyPacketReader(reader.readByteArray32());
      expect(payload.readString(), '');
      expect(payload.readUint32(), 0);
      expect(payload.readString(), 'B8-97-5A-17-AD-4D');
      expect(payload.readString(), 'B8-97-5A-17-AD-4D');
      expect(payload.readUint32(), 0);
      expect(payload.readString(), 'yymwebh5');
      expect(session.phase, YyProtocolPhase.waitingUdb);
    });

    test('the heartbeat starts only from the AP login on', () {
      final session = _protocol();
      expect(session.heartbeat(), isNull);
      session.beginHandshake();
      expect(session.heartbeat(), isNull);
      session.consume(_udbAnswer());
      final ping = session.heartbeat();
      expect(ping, isNotNull);
      expect(YyPacketReader(ping!, hasHeader: true).uri, 794116);
    });

    test('the anonymous answer brings the AP login, the AP answer the join', () {
      final session = _protocol()..beginHandshake();
      final batch = session.consume(_udbAnswer());
      expect(batch.outbound, hasLength(1));
      expect(YyPacketReader(batch.outbound.single, hasHeader: true).uri, 775684);
      expect(session.phase, YyProtocolPhase.waitingAp);

      final join = session.consume(_apAnswer());
      expect(join.outbound.map((frame) => YyPacketReader(frame, hasHeader: true).uri), [513035, 538456]);
      expect(session.phase, YyProtocolPhase.waitingJoin);
    });

    test('the routed join confirms the channel and subscribes the groups', () {
      final session = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer());
      final batch = session.consume(_joinAnswer());
      expect(batch.becameReady, isTrue);
      expect(session.phase, YyProtocolPhase.joined);
      expect(batch.outbound.map((frame) => YyPacketReader(frame, hasHeader: true).uri), [537944, 537944]);
    });

    test('a refused step fails the handshake', () {
      final refused = _protocol()..beginHandshake();
      expect(refused.consume(_udbAnswer(envelopeCode: 1)).failure, isNotNull);
      expect(refused.phase, YyProtocolPhase.failed);
      expect(refused.heartbeat(), isNull);
      final badCode = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer(code: 500));
      expect(badCode.phase, YyProtocolPhase.failed);
      final wrongChannel = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer())
        ..consume(_joinAnswer(topSid: 999));
      expect(wrongChannel.phase, YyProtocolPhase.failed);
      final badStatus = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer())
        ..consume(_joinAnswer(status: 1));
      expect(badStatus.phase, YyProtocolPhase.failed);
      final refusedRoute = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer())
        ..consume(_joinAnswer(responseCode: 5));
      expect(refusedRoute.phase, YyProtocolPhase.failed);
      final unknownProtocol = _protocol()..beginHandshake();
      expect(unknownProtocol.consume(_udbAnswer(realUri: 1)).failure, isNotNull);
    });

    test('chat arrives from both routes, with the name and the XML decoded', () {
      final session = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer())
        ..consume(_joinAnswer());
      final group = session.consume(_chatPacket(text: '大家好'));
      expect(group.messages.single.type, LiveMessageType.chat);
      expect(group.messages.single.text, '大家好');
      expect(group.messages.single.effectiveSender.userName, '观众甲');
      final bySid = session.consume(_chatPacket(text: '第二条', name: '', bySid: true));
      expect(bySid.messages.single.effectiveSender.userName, YyDanmakuProtocol.anonymousUserName);
      final xml = session.consume(
        _chatPacket(text: '<?xml version="1.0"?><msg><txt data="&amp;嗨" /><txt data="呀" /></msg>'),
      );
      expect(xml.messages.single.text, '&嗨呀');
      // Another channel's chat is not this room's.
      expect(session.consume(_chatPacket(text: '别家', topSid: 999)).messages, isEmpty);
      // A blank text is nothing.
      expect(session.consume(_chatPacket(text: '  ')).messages, isEmpty);
    });

    test('the channel heat arrives as popularity', () {
      final session = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer())
        ..consume(_joinAnswer());
      final heat = session.consume(_heatPacket(heat: 1459645)).messages.single;
      expect(heat.type, LiveMessageType.audienceUpdate);
      expect(
        heat.payload,
        isA<LiveAudienceUpdate>()
            .having((update) => update.kind, 'kind', LiveAudienceSignalKind.popularity)
            .having((update) => update.value, 'value', 1459645),
      );
      // Another channel's heat, and a scrubbed body, are nothing.
      expect(session.consume(_heatPacket(heat: 1, topSid: 999)).messages, isEmpty);
      final empty = session.consume(_heatPacket(heat: 1, shortBody: true));
      expect(empty.messages, isEmpty);
      expect(empty.warnings, isEmpty);
    });

    test('a frame of several packets is read in order, a broken one warns', () {
      final session = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer())
        ..consume(_joinAnswer());
      final combined = <int>[..._chatPacket(text: '一'), ..._heatPacket(heat: 42), ..._chatPacket(text: '二')];
      final batch = session.consume(combined);
      expect(batch.messages.where((message) => message.type == LiveMessageType.chat).map((message) => message.text), [
        '一',
        '二',
      ]);
      expect(batch.messages.where((message) => message.type == LiveMessageType.audienceUpdate), hasLength(1));
      // A trailer shorter than a header ends the frame with a warning.
      final truncated = session.consume(<int>[..._chatPacket(text: '三'), 1, 2]);
      expect(truncated.messages.single.text, '三');
      expect(truncated.warnings.single, contains('trailer shorter than 10 bytes'));
      // A malformed message while joined is a warning, not a failure.
      final junk = session.consume(_brokenUserGroup());
      expect(junk.failure, isNull);
      expect(junk.warnings, isNotEmpty);
    });

    test('a malformed handshake payload fails, one after the join warns', () {
      final broken = _brokenUserGroup();
      final joining = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer())
        ..consume(_joinAnswer());
      final ok = joining.consume(broken);
      expect(ok.failure, isNull);
      // While joining, the same shape is a failure.
      final waiting = _protocol()
        ..beginHandshake()
        ..consume(_udbAnswer())
        ..consume(_apAnswer());
      final batch = waiting.consume(broken);
      expect(batch.failure, isNotNull, reason: 'a broken packet while joining is a failure');
      expect(waiting.phase, YyProtocolPhase.failed);
    });

    test('the endpoint and uuid follow the web client', () {
      final uuid = YyDanmakuProtocol.uuid(Random(7));
      expect(uuid, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      final endpoint = YyDanmakuProtocol.endpoint(uuid);
      expect(endpoint.host, 'h5-sinchl.yy.com');
      expect(endpoint.queryParameters['appid'], 'yymwebh5');
      expect(endpoint.queryParameters['version'], '3.2.10');
      expect(endpoint.queryParameters['uuid'], uuid);
      final compact = YyDanmakuProtocol.compactFailure('a\n b   c');
      expect(compact, 'a b c');
      expect(YyDanmakuProtocol.compactFailure('x' * 300).length, 120);
    });
  });

  group('comment session', () {
    test('the socket opens with the handshake headers and the login goes out', () async {
      final chat = await _chat();
      expect(chat.connector.endpoints.single.host, 'h5-sinchl.yy.com');
      expect(chat.connector.endpoints.single.queryParameters['appid'], 'yymwebh5');
      expect(chat.connector.headerSets.single['Origin'], 'https://www.yy.com');
      expect(
        chat.connector.headerSets.single.keys,
        contains('User-Agent'),
        reason: 'the edge ignores a lower-cased handshake',
      );
      expect(chat.socket.sentUris, [778244], reason: 'the anonymous login goes out at once');
      expect(chat.timers.every.single.period, YyDanmakuProtocol.heartbeatInterval);
      expect(
        chat.timers.after.map((wait) => wait.delay),
        containsAllInOrder([YyDanmakuProtocol.inactivityTimeout, YyDanmakuProtocol.handshakeTimeout]),
      );
      await chat.session.dispose();
    });

    test('the join is confirmed and chat and heat are delivered', () async {
      final chat = await _chat();
      final chatLine = _next(chat.session.events, 2);
      await _joinByHand(chat.socket);
      // The group subscriptions went out after the join.
      expect(chat.socket.sentUris.sublist(chat.socket.sentUris.length - 2), [537944, 537944]);
      chat.socket.push(_chatPacket(text: '你好'));
      chat.socket.push(_heatPacket(heat: 9001));
      final seen = await chatLine;
      expect(seen.first.text, '你好');
      expect(seen.last.payload, isA<LiveAudienceUpdate>());
      await chat.session.dispose();
    });

    test('the heartbeat pings only from the AP login on', () async {
      final chat = await _chat();
      chat.timers.ring();
      expect(chat.socket.sentUris, [778244], reason: 'no heartbeat before the AP login');
      chat.socket.push(_udbAnswer());
      await _settle();
      chat.timers.ring();
      expect(chat.socket.sentUris.last, 794116);
      await chat.session.dispose();
    });

    test('a socket that never joins is replaced within the join budget', () async {
      final chat = await _chat();
      final first = chat.socket;
      chat.timers.fire();
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(2), reason: 'the join timeout replaced the socket');
      expect(first.closed, isTrue);
      expect(chat.connector.latest.sentUris, [778244], reason: 'the handshake starts over');
      // A joined socket that goes silent afterwards is replaced as well.
      final second = chat.connector.latest;
      await _joinByHand(second);
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets, hasLength(3));
      await chat.session.dispose();
    });

    test('a refused join is retried, and past the budget the session ends', () async {
      final chat = await _chat();
      final seen = <LiveMessage>[];
      final done = chat.session.events.listen(seen.add).asFuture<void>();
      for (var attempt = 0; attempt < YyDanmakuProtocol.maxReconnects; attempt++) {
        chat.connector.latest.push(_udbAnswer(resultCode: 1));
        await _settle();
        chat.timers.fire(index: chat.timers.after.length - 1);
        await _settle();
      }
      expect(chat.connector.sockets, hasLength(YyDanmakuProtocol.maxReconnects + 1), reason: 'eight replacements');
      // The ninth refused attempt ends the session.
      chat.connector.latest.push(_udbAnswer(resultCode: 1));
      await done;
      expect(seen.where((message) => message.type == LiveMessageType.system), hasLength(1));
      await chat.session.dispose();
    });

    test('a silent socket is replaced', () async {
      final chat = await _chat();
      final before = chat.connector.sockets.length;
      chat.timers.fire(index: 1);
      await _settle();
      chat.timers.fire(index: chat.timers.after.length - 1);
      await _settle();
      expect(chat.connector.sockets.length, before + 1);
      await chat.session.dispose();
    });

    test('a channel that names none is refused before any socket', () async {
      final connector = _Connector();
      final session = YyDanmakuSession(
        args: const YyDanmakuArgs(topSid: 0, subSid: 0),
        site: YySite(http: YyHttp(_FakeHttp(_ordinary)), connect: connector.call),
        timers: FakeTimers().timers,
      );
      expect(await session.connect(), isA<LiveSiteContentUnavailable>());
      await _settle();
      expect(connector.sockets, isEmpty);
      await session.dispose();
      expect(await session.connect(), isA<LiveSiteUnsupported>());
    });
  });

  group('adapter wiring', () {
    test('the manifest and the capabilities the platform serves', () async {
      final site = YySite(http: YyHttp(_FakeHttp(_ordinary)), connect: _refuseSocket, now: () => _at);
      expect(site.manifest.id, 'yy');
      expect(site.manifest.name['zh-CN'], 'YY 直播');
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
      expect(site.capability<LiveAnchorProvider>(), isNull, reason: 'no anchor lookup by id');
      expect(site.capability<LiveHotProvider>(), isNull, reason: 'no hot list');
      expect(
        site.capability<LiveDiscoveryProvider>(),
        same(site.capability<LiveDiscoveryProvider>()),
        reason: 'singletons',
      );
      await site.dispose();
    });

    test('the catalog is the header and the categories, without the short-video page', () async {
      final adapter = _adapter();
      final areas = await adapter.site.areas();
      expect(areas.map((area) => area.areaId), ['101', '201'], reason: '小视频 is no live area');
      expect(areas.first.parentAreaName, '娱乐');
      expect(adapter.http.sent.map((seen) => seen.url.path).toSet(), {
        '/yyweb/module/data/header',
        '/c/yycom/category/getCategory.action',
      });
      // A broken header is a parse error at the boundary.
      final broken = _adapter(onSend: (_) => _resp(200, '{"noTabs":1}'));
      expect(_leftOf(await broken.site.capability<LiveAreaProvider>()!.getAreas()), isA<LiveSiteParseError>());
    });

    test('an area with a module lists over page.action and teaches its biz', () async {
      final adapter = _adapter();
      await adapter.site.areas();
      final area = _right(await adapter.site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '101'));
      final pageRequest = adapter.http.sent.last;
      expect(pageRequest.url.path, '/more/page.action');
      expect(pageRequest.url.queryParameters['moduleId'], '313');
      expect(pageRequest.url.queryParameters['biz'], 'sing');
      expect(pageRequest.url.queryParameters['page'], '1');
      expect(area.items.single.roomId, '$_sid');
      // The area name the module learnt names the biz on the home listing.
      final recommended = _right(await adapter.site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(recommended.items.single.area?.areaName, '音乐');
      expect(recommended.items.single.runtime.streamHandle, isA<YyRoomData>());
      // An unknown area and a page below 1 are caller errors without a request.
      final before = adapter.http.sent.length;
      expect(
        _leftOf(await adapter.site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '666')),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(
        _leftOf(
          await adapter.site.capability<LiveAreaProvider>()!.getAreaRooms(
            areaId: '101',
            request: const LivePageRequest(page: 0),
          ),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
      expect(adapter.http.sent.length, before);
    });

    test('a module-less area lists its own page, later pages are empty', () async {
      final adapter = _adapter();
      await adapter.site.areas();
      final first = _right(await adapter.site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '201'));
      expect(first.items.single.roomId, '11111');
      expect(first.items.single.content.title, '手机直播中');
      expect(first.items.single.audience.popularity, 21000);
      expect(adapter.http.sent.map((seen) => seen.url.path), contains('/s/201'));
      final before = adapter.http.sent.length;
      expect(
        _right(
          await adapter.site.capability<LiveAreaProvider>()!.getAreaRooms(
            areaId: '201',
            request: const LivePageRequest(page: 2),
          ),
        ).items,
        isEmpty,
      );
      expect(adapter.http.sent.length, before, reason: 'later pages are empty without a request');
    });

    test('a room entry is the detail, with both handles', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom('$_sid'));
      expect(adapter.http.sent, hasLength(1), reason: 'a live canonical channel is one request');
      expect(room.roomId, '$_sid');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1727700000 * 1000, isUtc: true));
      expect(room.audience.popularity, 3456);
      final stream = room.runtime.streamHandle! as YyRoomData;
      expect(stream.sid, '$_sid');
      expect(stream.ssid, '$_ssid');
      final danmaku = room.runtime.danmakuHandle! as YyDanmakuArgs;
      expect(danmaku.topSid, _sid);
      expect(danmaku.subSid, _ssid);
    });

    test('an offline channel is told apart from an unknown one', () async {
      final adapter = _adapter(
        onSend: (request) async => switch (request.url.path) {
          '/api/liveInfoDetail/$_sid/$_sid/0' => _resp(200, _detailBody()),
          _ => await _ordinary(request),
        },
      );
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom('$_sid'));
      expect(adapter.http.sent.map((seen) => seen.url.path), ['/api/liveInfoDetail/$_sid/$_sid/0', '/$_sid']);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.anchor?.name, '主播甲', reason: 'the page names the streamer');
      expect(room.runtime.danmakuHandle, isA<YyDanmakuArgs>(), reason: 'the chat stays open offline');
      // A refresh is one request: the page is not read again.
      final before = adapter.http.sent.length;
      final refreshed = await adapter.site.refreshRoom('$_sid');
      expect(adapter.http.sent.length, before + 1);
      expect(refreshed.broadcast.liveStatus, LiveStatus.offline);
      expect(refreshed.content.title, '', reason: 'without the page there is no title');
      expect(refreshed.runtime.streamHandle, isA<YyRoomData>());
    });

    test('a short number keeps its identity and follows its canonical channel', () async {
      final adapter = _adapter();
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom('9999'));
      expect(adapter.http.sent.map((seen) => seen.url.path), [
        '/api/liveInfoDetail/9999/9999/0',
        '/9999',
        '/api/liveInfoDetail/$_sid/$_sid/0',
      ]);
      expect(room.roomId, '9999');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect((room.runtime.streamHandle! as YyRoomData).sid, '$_sid');
    });

    test('an unknown channel and a non-number are not-found', () async {
      final adapter = _adapter();
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('4321')), isA<LiveSiteNotFound>());
      final before = adapter.http.sent.length;
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('abc')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent.length, before, reason: 'a non-number is refused without a request');
    });

    test('the search serves rooms and anchors', () async {
      final adapter = _adapter();
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms, LiveSearchTarget.anchors});
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.areas))),
        isA<LiveSiteUnsupported>(),
      );
      final rooms = _right(await search.search(const LiveSearchRequest(query: '唱', target: LiveSearchTarget.rooms)));
      expect((rooms.items.single as RoomSearchResult).room.content.title, '搜索到的房间');
      final anchors = _right(
        await search.search(const LiveSearchRequest(query: '唱', target: LiveSearchTarget.anchors)),
      );
      expect((anchors.items.single as AnchorSearchResult).anchor.name, '主播甲');
      expect(anchors.hasMore, isNull, reason: 'the search API names no page count');
      // A blank keyword finds nothing without a request.
      final before = adapter.http.sent.length;
      expect(
        _right(await search.search(const LiveSearchRequest(query: ' ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(adapter.http.sent.length, before);
    });

    test('the qualities come from mobile HLS first, stream-manager standing in', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final qualities = _right(await playback.getQualities(roomId: '$_sid'));
      expect(qualities.map((quality) => quality.qualityId), ['mobile-hls:4000', 'mobile-hls:1200']);
      expect(qualities.first.label, '高清 · 720p');
      expect(adapter.http.sent.where((seen) => seen.url.host == 'interface.yy.com').length, 2);

      // Mobile HLS empty: stream-manager is asked at gear 1.
      final flv = _adapter(
        onSend: (request) async => switch (request.url.host) {
          'interface.yy.com' => _resp(200, _mobileBody(code: 1)),
          'stream-manager.yy.com' => _resp(200, _streamsBody(url: _flvUrl)),
          _ => await _ordinary(request),
        },
      );
      final fallback = _right(await flv.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '$_sid'));
      expect(fallback.single.qualityId, '2');
      expect(fallback.single.label, '蓝光');
      final gearRequest = flv.http.sent.lastWhere((seen) => seen.url.host == 'stream-manager.yy.com');
      expect(gearRequest.method, 'POST');
      expect(_avpOf(gearRequest)['gear'], 1);
    });

    test('a stream-manager quality resolves with its other CDN lines and leases', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final lines = _right(
        await playback.getLines(
          roomId: '$_sid',
          quality: const LivePlayQuality(label: '蓝光', qualityId: '2'),
        ),
      );
      final posts = adapter.http.sent.where((seen) => seen.url.host == 'stream-manager.yy.com').toList();
      expect(posts, hasLength(2), reason: 'the first line and the other CDN line 14');
      expect(_avpOf(posts.last)['line_seq'], 14);
      expect(lines, hasLength(2));
      expect(lines.first.url, _flvUrl);
      expect(lines.last.url, _flvUrl2);
      expect(lines.last.lineLabel, '14');
      expect(lines.first.format, LiveStreamFormat.flv);
      final expiresAt = _at.add(const Duration(minutes: 10));
      expect(lines.first.lease!.expiresAt, expiresAt);
      expect(lines.first.lease!.refreshAt, expiresAt.subtract(const Duration(minutes: 1)));
    });

    test('a mobile quality plays the mobile route, FLV standing in', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final lines = _right(
        await playback.getLines(
          roomId: '$_sid',
          quality: const LivePlayQuality(label: '高清 · 720p', qualityId: 'mobile-hls:4000'),
        ),
      );
      expect(lines, hasLength(1));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.headers['user-agent'], YyEndpoints.mediaUserAgent);
      expect(lines.single.lease, isNull, reason: 'the mobile t is no expiry');

      // A low rate whose mobile route has nothing stands in on gear 1.
      final low = _adapter(
        onSend: (request) async =>
            request.url.host == 'interface.yy.com' ? _resp(200, _mobileBody(code: 1)) : await _ordinary(request),
      );
      final stoodIn = _right(
        await low.site.capability<LivePlaybackProvider>()!.getLines(
          roomId: '$_sid',
          quality: const LivePlayQuality(label: '流畅', qualityId: 'mobile-hls:1200'),
        ),
      );
      expect(stoodIn.single.format, LiveStreamFormat.flv);
      final post = low.http.sent.lastWhere((seen) => seen.url.host == 'stream-manager.yy.com');
      expect(_avpOf(post)['gear'], 1);
    });

    test('the default quality is the first one, and nothing playable is a left', () async {
      final adapter = _adapter();
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      final lines = _right(await playback.getLines(roomId: '$_sid'));
      expect(lines.single.format, LiveStreamFormat.hls);
      // Neither route has a stream: content-unavailable.
      final empty = _adapter(
        onSend: (request) async => switch (request.url.host) {
          'interface.yy.com' => _resp(200, _mobileBody(code: 1)),
          'stream-manager.yy.com' => _resp(
            200,
            _json({
              'channel_stream_info': {'streams': <Object?>[]},
            }),
          ),
          _ => await _ordinary(request),
        },
      );
      expect(
        _leftOf(await empty.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '$_sid')),
        isA<LiveSiteContentUnavailable>(),
      );
      // A broken transport is a network error.
      final down = _adapter(onSend: (_) => _resp(503, 'no'));
      expect(
        _leftOf(await down.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '$_sid')),
        isA<LiveSiteNetworkError>(),
      );
      // A room id that is no channel number is not-found.
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getQualities(roomId: 'x')),
        isA<LiveSiteNotFound>(),
      );
    });

    test('a status the gates refuse is mapped at the boundary', () async {
      final throttled = _adapter(onSend: (_) => _resp(429, 'slow down'));
      expect(
        _leftOf(await throttled.site.capability<LiveRoomProvider>()!.getRoom('$_sid')),
        isA<LiveSiteRateLimitError>(),
      );
      final refused = _adapter(onSend: (_) => _resp(403, 'no'));
      expect(
        _leftOf(await refused.site.capability<LiveRoomProvider>()!.getRoom('$_sid')),
        isA<LiveSiteRateLimitError>(),
        reason: '401 and 403 fold into the rate limit',
      );
    });

    test('links are canonicalized without a request', () async {
      final adapter = _adapter();
      final link = adapter.site.capability<LiveLinkResolver>()!;
      Future<Uri> resolve(String text) => link.resolve(Uri.parse(text)).then(_right);
      expect((await resolve('https://www.yy.com/$_sid')).toString(), 'https://www.yy.com/$_sid');
      expect((await resolve('https://www.yy.com/$_sid/$_ssid')).toString(), 'https://www.yy.com/$_sid');
      expect((await resolve('https://wap.yy.com/mobileweb/$_sid/$_ssid')).toString(), 'https://www.yy.com/$_sid');
      expect(adapter.http.sent, isEmpty);
      expect(_leftOf(await link.resolve(Uri.parse('https://www.yy.com/'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://www.yy.com/music/top'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://www.yy.com/0123'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await link.resolve(Uri.parse('https://evil.com/$_sid'))), isA<LiveSiteUnsupported>());
      expect(_leftOf(await link.resolve(Uri.parse('ftp://www.yy.com/$_sid'))), isA<LiveSiteNotFound>());
      // The static helper agrees.
      expect(YyLinkResolver.roomIdFromUrl(Uri.parse('https://www.yy.com/$_sid')), '$_sid');
      expect(YyLinkResolver.roomIdFromUrl(Uri.parse('https://www.yy.com/link/1')), isNull);
    });

    test('the chat provider builds a session for any channel with a page', () async {
      final opened = _Connector();
      final adapter = _adapter(connect: opened.call);
      final danmaku = adapter.site.capability<LiveDanmakuProvider>()!;
      final session = _right(await danmaku.createSession(roomId: '$_sid')) as YyDanmakuSession;
      await _settle();
      expect(opened.sockets, hasLength(1));
      expect(opened.sockets.single.sentUris, [778244]);
      await session.dispose();
      // An unknown channel names no chat.
      final unknown = _adapter(connect: opened.call);
      expect(
        _leftOf(await unknown.site.capability<LiveDanmakuProvider>()!.createSession(roomId: '4321')),
        isA<LiveSiteNotFound>(),
      );
      expect(
        _leftOf(await unknown.site.capability<LiveDanmakuProvider>()!.createSession(roomId: 'abc')),
        isA<LiveSiteNotFound>(),
      );
    });
  });
}

/// An adapter over the fake transport with a fixed clock and no socket.
({YySite site, _FakeHttp http}) _adapter({
  FutureOr<LiveResponse> Function(_Seen request)? onSend,
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
  return (site: YySite(http: YyHttp(http), connect: connect ?? _refuseSocket, now: () => _at), http: http);
}

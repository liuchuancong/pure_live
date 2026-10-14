import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

// The test doubles spell their class name in their one constructor; the
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:crypto/crypto.dart';
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
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_http.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_token.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_chat_visitor.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_hls_protection.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_studio.dart';
import 'package:test/test.dart';

/// One request as the fake transport records it.
typedef _Seen = ({String method, Uri url, Map<String, String> headers, String body});

/// The int64 room id the chat socket enters in these tests.
const String _joinedRoom = '7232856282170115';

String _json(Object? value) => jsonEncode(value);

/// The `{code: 0, data: …}` envelope the site answers with.
String _envelope(Object? data) => _json({'code': 0, 'msg': 'ok', 'data': data});

/// A JSONP answer of [callback].
String _jsonp(String callback, Object? value) => '$callback(${_json(value)});';

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

/// The right side of an answer, or a failure that names itself.
T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

/// The left side of an answer.
LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $right'));

/// Lowercase hex.
String _hex(List<int> bytes) => [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

/// The base64 chat payload of the page's `{n, m}` JSON.
String _chatContent(String name, String message) => base64Encode(utf8.encode(_json({'n': name, 'm': message})));

/// The JSON body of a `$uri$json` frame.
Map<String, Object?> _jsonOf(String frame, int uri) =>
    jsonDecode(frame.substring('$uri'.length)) as Map<String, Object?>;

/// A frame of uri [uri] and JSON [body].
String _frame(int uri, Map<String, Object?> body) => '$uri${_json(body)}';

/// One `10|24` broadcast frame of the room the tests join.
String _textFrame(Map<String, Object?> body) => _frame(BigoDanmakuCodec.textUri, {'room_id': _joinedRoom, ...body});

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

/// An adapter over [onSend]: the fake transport it records on, and a fixed
/// clock and device-id draw.
({BigoSite site, _FakeHttp http}) _adapter(LiveResponse Function(_Seen) onSend, {DateTime? now}) {
  final http = _FakeHttp(onSend);
  return (
    site: BigoSite(http: BigoHttp(http), now: () => now ?? DateTime.utc(2026, 9, 30, 12), random: Random(7)),
    http: http,
  );
}

/// The list row the site answers with, complete enough to be read.
Map<String, Object?> _row({
  String bigoId = '414439909',
  int owner = 123456,
  int roomId = 7232856282170115,
  int sid = 987654,
  String topic = 'Late night talk',
  String nick = 'Ann',
  String cover = 'https://cover.bigo.tv/a.jpg',
  int? userCount = 2472,
  int locked = 0,
  int roomFlag = 0,
  int? timeStamp = 1759000000,
}) => {
  'bigo_id': bigoId,
  'owner': owner,
  'room_id': roomId,
  'sid': sid,
  'room_topic': topic,
  'nick_name': nick,
  'cover_m': cover,
  'user_count': ?userCount,
  'is_locked': locked,
  'room_flag': roomFlag,
  'time_stamp': ?timeStamp,
};

/// The public list as an answer body.
String _list(List<Map<String, Object?>> rows) => _envelope({'resCode': '0', 'data': rows});

/// The studio answer the site gives.
Map<String, Object?> _studioData({
  Object? uid = 123456,
  String clientBigoId = '414439909',
  Object? needLogin = false,
  bool? passRoom = false,
  String isPaidShow = '0',
  int alive = 1,
  int roomStatus = 1,
  String roomType = '0',
  Object? roomId = _joinedRoom,
  String nickName = 'Ann',
  String roomTopic = 'Late night talk',
  String gameTitle = 'Just Chatting',
  String avatar = 'https://avatar.bigo.tv/a.png',
  String snapshot = 'https://snapshot.bigo.tv/s.jpg',
  String? hlsSrc = 'https://cdn.bigo.tv/live/playlist.m3u8',
}) => {
  'uid': uid,
  'clientBigoId': clientBigoId,
  'needLogin': needLogin,
  'passRoom': ?passRoom,
  'isPaidShow': isPaidShow,
  'alive': alive,
  'roomStatus': roomStatus,
  'roomType': roomType,
  'roomId': roomId,
  'nick_name': nickName,
  'roomTopic': roomTopic,
  'gameTitle': gameTitle,
  'avatar': avatar,
  'snapshot': snapshot,
  'hls_src': ?hlsSrc,
};

/// The two token answers of an entry flow.
LiveResponse _tokenAnswer(_Seen request) {
  final callback = request.url.queryParameters['callback']!;
  if (request.url.path.endsWith('/t')) {
    return _resp(200, _jsonp(callback, {'code': 0, 'time': '1759000000000'}));
  }
  return _resp(200, _jsonp(callback, {'code': 0, 'token': 'tk-1'}));
}

/// A flow that answers the token and visitor requests and one studio [data].
LiveResponse Function(_Seen) _flow({Map<String, Object?>? data}) => (request) {
  final path = request.url.path;
  if (path.endsWith('/t') || path.endsWith('/status')) return _tokenAnswer(request);
  if (path.endsWith('getWebSocketLink')) {
    return _resp(200, _envelope({'userId': '99', 'uidToken': 'tk###VER2', 'deviceId': 'web_y'}));
  }
  return _resp(200, _envelope(data ?? _studioData()));
};

/// A room of the list, for the search filter.
LiveRoom _roomOf(String id, {String nick = '', String title = ''}) => LiveRoom.normalized(
  platform: 'bigo',
  roomId: id,
  content: RoomContent(title: title),
  anchor: LiveAnchor.normalized(platform: 'bigo', anchorId: '1', name: nick),
);

void main() {
  group('token', () {
    test("the callback name is the page's own shape", () {
      final at = DateTime.fromMicrosecondsSinceEpoch(1759000000123123, isUtc: true);
      expect(BigoToken.callbackName(at), 'jsonpcallback_1759000000123_123123');
      expect(BigoToken.isCallbackName('jsonpcallback_1_2'), isTrue);
      expect(BigoToken.isCallbackName('callback_1_2'), isFalse);
    });

    test('EVP_BytesToKey with md5 and one round gives the key then the IV', () {
      final derived = BigoToken.evpBytesToKey(utf8.encode(BigoToken.passphrase), [0, 1, 2, 3, 4, 5, 6, 7], 48);
      expect(_hex(derived.sublist(0, 32)), '399f93907237063ddf71b23293a38160032644845377ff77b98b72dc3dad972b');
      expect(_hex(derived.sublist(32, 48)), '18c0095516218cc24165643e72a0d510');
    });

    test("the token request data is the site's own OpenSSL envelope", () {
      final data = BigoToken.tokenData(
        '1759000000000',
        salt: [0, 1, 2, 3, 4, 5, 6, 7],
        nonce: '0123456789abcdef0123456789abcdef',
      );
      // The published OpenSSL envelope of that payload under that key.
      expect(
        data,
        'U2FsdGVkX18AAQIDBAUGBw9CExflNpp/+hw4FEvQ48pkY9f2hYxzYBNOjHbCB45L1kMM'
        '+njoY+ywzq8/nIukZdvMK///nfADHW0eTrVT7LFdOBDiydMHD1bQXb8LIIH6+0LOStOd'
        'SXNUwbQdz/GTEhEXLzMbXvSiJcSqAlWIjluuECk3+jnCxIpq6b1ElezB',
      );
      final bytes = base64Decode(data);
      expect(ascii.decode(bytes.sublist(0, 8)), 'Salted__');
      expect(bytes.sublist(8, 16), [0, 1, 2, 3, 4, 5, 6, 7]);
      expect((bytes.length - 16) % 16, 0);
    });

    test('the salt and the nonce are drawn when they are not given', () {
      final random = Random(11);
      final first = base64Decode(BigoToken.tokenData('1759000000000', random: random));
      final second = base64Decode(BigoToken.tokenData('1759000000000', random: random));
      expect(first.sublist(8, 16), isNot(second.sublist(8, 16)));
      expect(first.length, second.length);
    });

    test('a bad timestamp, salt or nonce is refused before any request', () {
      expect(() => BigoToken.tokenData('x'), throwsA(isA<BigoFailure>()));
      expect(() => BigoToken.tokenData('17', salt: [1, 2]), throwsA(isA<BigoFailure>()));
      expect(() => BigoToken.tokenData('17', nonce: 'ZZ'), throwsA(isA<BigoFailure>()));
    });

    test('the server time and the token come out of JSONP of the sent callback', () {
      expect(
        BigoToken.serverTime(
          _jsonp('jsonpcallback_1_2', {'code': 0, 'time': '1759000000000'}),
          callback: 'jsonpcallback_1_2',
          status: 200,
        ),
        '1759000000000',
      );
      expect(BigoToken.token(_jsonp('cb', {'token': 'abc'}), callback: 'cb', status: 200), 'abc');
    });

    test('a JSONP answer of another callback, or a bad field, is api-changed', () {
      final body = _jsonp('jsonpcallback_1_2', {'code': 0, 'time': '1759000000000'});
      expect(
        () => BigoToken.serverTime(body, callback: 'jsonpcallback_9_9', status: 200),
        throwsA(predicate((e) => '$e'.contains('not JSONP'))),
      );
      expect(
        () => BigoToken.serverTime(_jsonp('cb', {'code': 0, 'time': 'x'}), callback: 'cb', status: 200),
        throwsA(isA<BigoFailure>()),
      );
      expect(
        () => BigoToken.serverTime(_jsonp('cb', {'time': '1'}), callback: 'cb', status: 200),
        throwsA(isA<BigoFailure>()),
      );
      expect(
        () => BigoToken.token(_jsonp('cb', {'token': 'has space'}), callback: 'cb', status: 200),
        throwsA(isA<BigoFailure>()),
      );
      expect(() => BigoToken.token(_jsonp('cb', {}), callback: 'cb', status: 200), throwsA(isA<BigoFailure>()));
      expect(() => BigoToken.token('{}', callback: 'cb', status: 500), throwsA(isA<BigoFailure>()));
    });
  });

  group('HLS protection', () {
    test("the seed is read out of the tag's attribute list", () {
      const playlist = '#EXTM3U\n#EXT-X-BIGO-WEB-PROTECTION:VERSION=1,SEED=987654321\n#EXTINF:4\na.ts\n';
      expect(BigoHlsProtection.seed(playlist), 987654321);
      expect(BigoHlsProtection.seed('#EXTM3U\n#EXTINF:4\na.ts\n'), isNull);
      expect(BigoHlsProtection.seed('#ext-x-bigo-web-protection:SEED=7\n'), 7);
    });

    test('a tag without a seed, or one over 2^32-1, is a format error', () {
      expect(() => BigoHlsProtection.seed('#EXT-X-BIGO-WEB-PROTECTION:VERSION=1\n'), throwsFormatException);
      expect(() => BigoHlsProtection.seed('#EXT-X-BIGO-WEB-PROTECTION:SEED=4294967296\n'), throwsFormatException);
    });

    test('the transform is its own inverse and touches only the first two packets', () {
      final segment = Uint8List.fromList([for (var i = 0; i < 500; i++) i % 251]);
      final before = Uint8List.fromList(segment);
      final once = BigoHlsProtection.transform(segment, 987654321);
      expect(once.sublist(0, 376), isNot(before.sublist(0, 376)));
      expect(once.sublist(376), before.sublist(376));
      expect(BigoHlsProtection.transform(once, 987654321), before);
      // The sync byte of each packet is the visible part of the scramble.
      expect(once[0], isNot(0));
      expect(once[188], isNot(188 % 251));
    });

    test('the seed that cancels the packet constant takes the fixed start state', () {
      for (final seed in [0, 2654435769]) {
        final segment = Uint8List(BigoHlsProtection.prefixBytes);
        final out = BigoHlsProtection.transform(segment, seed);
        expect(BigoHlsProtection.transform(out, seed), segment);
        expect(out.any((byte) => byte != 0), isTrue);
      }
    });

    test('a truncated segment or an out-of-range seed is a format error', () {
      expect(() => BigoHlsProtection.transform(Uint8List(100), 1), throwsFormatException);
      expect(() => BigoHlsProtection.transform(Uint8List(376), -1), throwsFormatException);
    });
  });

  group('list parsing', () {
    test('a row is a live card: the topic as title, the cover as the avatar too', () {
      final card = BigoRoomParser.directory(_list([_row()])).single;
      expect(card.roomId, '414439909');
      expect(card.platform, 'bigo');
      expect(card.content.title, 'Late night talk');
      expect(card.content.coverUrl, 'https://cover.bigo.tv/a.jpg');
      expect(card.anchor?.name, 'Ann');
      expect(card.anchor?.anchorId, '123456');
      expect(card.anchor?.avatarUrl, 'https://cover.bigo.tv/a.jpg');
      expect(card.area?.areaName, 'Bigo Live');
      expect(card.audience.onlineViewers, 2472);
      expect(card.audience.primaryMetric?.name, 'onlineViewers');
      expect(card.broadcast.isLiveNow, isTrue);
      expect(card.broadcast.effectiveRestriction, LiveRestriction.none);
      expect(card.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1759000000000, isUtc: true));
      expect(card.links.webUrl, 'https://www.bigo.tv/414439909');
    });

    test('an empty topic falls back to the name and a missing count stays unknown', () {
      final card = BigoRoomParser.directory(_list([_row(topic: '', userCount: null, locked: 1, timeStamp: null)]))
          .single;
      expect(card.content.title, 'Ann');
      expect(card.audience.onlineViewers, isNull);
      expect(card.broadcast.restriction, LiveRestriction.password);
      expect(card.broadcast.startedAt, isNull);
    });

    test('an unreadable row is dropped on its own and repeats of an id or owner go', () {
      final cards = BigoRoomParser.directory(
        _list([
          _row(),
          _row(owner: 999, sid: 102),
          _row(bigoId: 'other', sid: 103),
          _row(bigoId: 'bad id!', sid: 104),
          _row(roomId: 0, sid: 105),
          _row(locked: 2, sid: 106),
          _row(bigoId: 'second', owner: 654321, sid: 107),
        ]),
      );
      expect(cards.map((card) => card.roomId), ['414439909', 'second']);
    });

    test('rows none of which can be read are api-changed, never an empty list', () {
      expect(
        () => BigoRoomParser.directory(_list([_row(bigoId: 'bad id!')])),
        throwsA(predicate((e) => '$e'.contains('none of 1 rows'))),
      );
    });

    test('the envelope, the resCode and the row budget are checked', () {
      expect(() => BigoRoomParser.directory('{"code":1,"msg":"no"}'), throwsA(isA<BigoFailure>()));
      expect(() => BigoRoomParser.directory(_envelope({'resCode': '0'})), throwsA(isA<BigoFailure>()));
      expect(
        () => BigoRoomParser.directory(_envelope({'resCode': 0, 'data': <Object?>[]})),
        throwsA(isA<BigoFailure>()),
      );
      expect(
        () => BigoRoomParser.directory(
          _envelope({
            'resCode': '0',
            'data': [for (var i = 0; i < 501; i++) _row(bigoId: 'r$i', owner: i + 1, sid: 100 + i)],
          }),
        ),
        throwsA(isA<BigoFailure>()),
      );
      expect(() => BigoRoomParser.directory('not json'), throwsA(isA<BigoFailure>()));
      expect(() => BigoRoomParser.directory('{}', status: 404), throwsA(isA<BigoFailure>()));
      expect(() => BigoRoomParser.directory('{}', status: 401), throwsA(isA<BigoFailure>()));
      expect(() => BigoRoomParser.directory('{}', status: 429), throwsA(isA<BigoFailure>()));
      expect(() => BigoRoomParser.directory('{}', status: 302), throwsA(isA<BigoFailure>()));
    });

    test('a time stamp outside 2000-2100 gives no start', () {
      expect(BigoRoomParser.startedAt(946684799), isNull);
      expect(BigoRoomParser.startedAt(4102444801), isNull);
      expect(BigoRoomParser.startedAt('1759000000'), isNull);
      expect(BigoRoomParser.startedAt(1759000000), isNotNull);
    });

    test('the snapshot pages locally, 20 a page, and a size over 100 gives nothing', () {
      final many = List<int>.generate(25, (i) => i);
      expect(BigoRoomParser.slice(many, page: 1, pageSize: 20), hasLength(20));
      expect(BigoRoomParser.slice(many, page: 2, pageSize: 20), hasLength(5));
      expect(BigoRoomParser.slice(many, page: 3, pageSize: 20), isEmpty);
      expect(BigoRoomParser.slice(many, page: 1, pageSize: 101), isEmpty);
      expect(BigoRoomParser.slice(many, page: 0, pageSize: 20), isEmpty);
      expect(BigoRoomParser.validSlice(page: 1, pageSize: 100), isTrue);
      final rooms = List.generate(21, (i) => _roomOf('r$i'));
      expect(BigoRoomParser.directoryPage(rooms, page: 1).rooms, hasLength(20));
      expect(BigoRoomParser.directoryPage(rooms, page: 1).hasMore, isTrue);
      expect(BigoRoomParser.directoryPage(rooms, page: 2).rooms, hasLength(1));
      expect(BigoRoomParser.directoryPage(rooms, page: 2).hasMore, isFalse);
    });
  });

  group('studio parsing', () {
    test('a public live answer gives the room, the playlist and the chat arguments', () {
      final studio = BigoRoomParser.studio(_envelope(_studioData()), requestedSiteId: '414439909');
      expect(studio.siteId, '414439909');
      expect(studio.access, BigoAccess.public);
      expect(studio.alive, isTrue);
      expect(studio.complete, isTrue);
      expect(studio.liveStatus, LiveStatus.live);
      expect(studio.restriction, LiveRestriction.none);
      expect(studio.streamError, isNull);
      expect(studio.opensChat, isTrue);
      expect(studio.hls.toString(), 'https://cdn.bigo.tv/live/playlist.m3u8');
      final args = BigoRoomParser.danmakuArgs(studio)!;
      expect(args.roomId, _joinedRoom);
      expect(args.ownerId, 123456);
      expect(args.siteId, '414439909');
      final room = BigoRoomParser.room(studio);
      expect(room.roomId, '414439909');
      expect(room.content.title, 'Late night talk');
      expect(room.content.coverUrl, 'https://snapshot.bigo.tv/s.jpg');
      expect(room.area?.areaName, 'Just Chatting');
      expect(room.audience.onlineViewers, isNull);
      // The parser hands out no handles; the site attaches them.
      expect(room.runtime.streamHandle, isNull);
      expect(BigoRoomParser.roomData(studio).hasStream, isTrue);
    });

    test('a login gate hides the state and is an authentication failure', () {
      final studio = BigoRoomParser.studio(
        _envelope(_studioData(needLogin: true, alive: 0, hlsSrc: null, passRoom: null)),
        requestedSiteId: '414439909',
      );
      expect(studio.access, BigoAccess.loginRequired);
      expect(studio.alive, isNull);
      expect(studio.liveStatus, LiveStatus.unknown);
      expect(studio.restriction, LiveRestriction.needsLogin);
      expect(studio.opensChat, isFalse);
      expect(studio.streamError?.kind, BigoFailureKind.needsLogin);
    });

    test('a password or paid room that says alive is still live', () {
      final locked = BigoRoomParser.studio(
        _envelope(_studioData(passRoom: true, alive: 0, hlsSrc: null)),
        requestedSiteId: '414439909',
      );
      expect(locked.access, BigoAccess.restricted);
      expect(locked.alive, isNull);
      expect(locked.restriction, LiveRestriction.password);
      expect(locked.streamError?.kind, BigoFailureKind.streamUnavailable);
      final paid = BigoRoomParser.studio(
        _envelope(_studioData(isPaidShow: '1', hlsSrc: null)),
        requestedSiteId: '414439909',
      );
      expect(paid.alive, isTrue);
      expect(paid.liveStatus, LiveStatus.live);
      expect(paid.restriction, LiveRestriction.paid);
      // The website opens a paid show's chat.
      expect(paid.opensChat, isTrue);
    });

    test("a token's later use answers without the lock flag and without a playlist", () {
      final studio = BigoRoomParser.studio(
        _envelope(_studioData(passRoom: null, hlsSrc: null)),
        requestedSiteId: '414439909',
      );
      expect(studio.complete, isFalse);
      expect(studio.restriction, isNull);
      // A live answer that says nothing about the lock is let through: the play
      // resolve asks the studio again.
      expect(studio.streamError, isNull);
      expect(BigoRoomParser.room(studio).broadcast.isLiveNow, isTrue);
    });

    test('a public live answer with no playlist is unplayable', () {
      final studio = BigoRoomParser.studio(_envelope(_studioData(hlsSrc: null)), requestedSiteId: '414439909');
      expect(studio.restriction, LiveRestriction.unplayable);
      expect(studio.streamError?.kind, BigoFailureKind.streamUnavailable);
    });

    test('an offline studio is offline and names nobody', () {
      final studio = BigoRoomParser.studio(
        _envelope(
          _studioData(
            alive: 0,
            roomId: '0',
            nickName: '',
            roomTopic: '',
            avatar: '',
            snapshot: '',
            hlsSrc: null,
            roomStatus: 0,
          ),
        ),
        requestedSiteId: '414439909',
      );
      expect(studio.liveStatus, LiveStatus.offline);
      expect(studio.broadcastId, isNull);
      expect(studio.opensChat, isFalse);
      final room = BigoRoomParser.room(studio);
      expect(room.content.title, '');
      expect(room.anchor?.name, '');
      expect(room.content.coverUrl, '');
      expect(room.links.webUrl, 'https://www.bigo.tv/414439909');
    });

    test('an id the site does not know is not-found', () {
      expect(
        () => BigoRoomParser.studio(_envelope({'alive': 0}), requestedSiteId: 'nope'),
        throwsA(isA<BigoFailure>()),
      );
      expect(
        () => BigoRoomParser.studio(_envelope(_studioData(uid: null)), requestedSiteId: '414439909'),
        throwsA(isA<BigoFailure>()),
      );
    });

    test('a roomType "1" studio opens no chat', () {
      final studio = BigoRoomParser.studio(_envelope(_studioData(roomType: '1')), requestedSiteId: '414439909');
      expect(studio.opensChat, isFalse);
      expect(BigoRoomParser.danmakuArgs(studio), isNull);
    });

    test('a field of the wrong shape is api-changed', () {
      for (final data in [
        _studioData(needLogin: 'false'),
        _studioData(isPaidShow: '2'),
        _studioData(alive: 3),
        _studioData(clientBigoId: 'bad id!'),
        _studioData(roomId: 'not-a-number'),
        _studioData(roomId: '0123'),
        _studioData(hlsSrc: 'https://cdn.bigo.tv/live/playlist.mp4'),
        _studioData(hlsSrc: 'http://cdn.bigo.tv/live/playlist.m3u8'),
        _studioData(passRoom: true),
        _studioData(alive: 0),
        _studioData(roomStatus: -1),
        _studioData(uid: 0),
      ]) {
        expect(
          () => BigoRoomParser.studio(_envelope(data), requestedSiteId: '414439909'),
          throwsA(isA<BigoFailure>()),
          reason: '$data',
        );
      }
    });

    test('a picture that is not http(s) is left out, an http one is kept', () {
      final studio = BigoRoomParser.studio(
        _envelope(_studioData(avatar: 'http://avatar.bigo.tv/a.png', snapshot: 'not a url')),
        requestedSiteId: '414439909',
      );
      expect(studio.avatar, 'http://avatar.bigo.tv/a.png');
      expect(studio.snapshot, '');
      expect(BigoRoomParser.room(studio).content.coverUrl, 'http://avatar.bigo.tv/a.png');
    });

    test('a gated first use keeps the gate with the state of the second', () {
      final later = BigoRoomParser.studio(_envelope(_studioData(passRoom: null)), requestedSiteId: '414439909');
      final gated = later.gated();
      expect(gated.access, BigoAccess.loginRequired);
      expect(gated.alive, isTrue);
      expect(gated.complete, isFalse);
      expect(gated.hls, isNull);
      expect(gated.restriction, LiveRestriction.needsLogin);
      expect(gated.siteId, later.siteId);
    });
  });

  group('search and links', () {
    test('a room link, a subdomain, a language prefix and a fragment all give the id', () {
      expect(BigoRoomParser.siteIdFromUrl('https://www.bigo.tv/414439909'), '414439909');
      expect(BigoRoomParser.siteIdFromUrl('https://bigo.tv/414439909'), '414439909');
      expect(BigoRoomParser.siteIdFromUrl('http://m.bigo.tv/qashia305'), 'qashia305');
      expect(BigoRoomParser.siteIdFromUrl('https://www.bigo.tv/en/414439909'), '414439909');
      expect(BigoRoomParser.siteIdFromUrl('https://www.bigo.tv/414439909#chat'), '414439909');
      expect(BigoRoomParser.siteIdFromUrl('https://www.bigo.tv:443/414439909'), '414439909');
      expect(BigoRoomParser.siteIdFromUrl('https://www.bigo.tv/414439909/'), '414439909');
      // One path segment is the id whatever it says: a streamer called `en` is
      // indistinguishable from the language page, exactly as the reference's own
      // rule has it.
      expect(BigoRoomParser.siteIdFromUrl('https://www.bigo.tv/en'), 'en');
    });

    test('a site page, a foreign host, a port, credentials and a deep path give nothing', () {
      for (final url in [
        'https://www.bigo.tv/live',
        'https://www.bigo.tv/download',
        'https://www.bigo.tv/about',
        'https://www.bigo.tv/414439909/extra',
        'https://www.bigo.tv/eng/414439909',
        'https://www.bigo.tv:8443/414439909',
        'https://user@www.bigo.tv/414439909',
        'https://other.tv/414439909',
        'https://notbigo.tv/414439909',
        'ftp://www.bigo.tv/414439909',
        'https://www.bigo.tv/bad id!',
        'not a url at all',
        '',
      ]) {
        expect(BigoRoomParser.siteIdFromUrl(url), isNull, reason: url);
      }
    });

    test('an id is looked up as one only when it holds a digit, dot, dash or underscore', () {
      expect(BigoRoomParser.looksLikeId('414439909'), isTrue);
      expect(BigoRoomParser.looksLikeId('qashia305'), isTrue);
      expect(BigoRoomParser.looksLikeId('qashia'), isFalse);
      expect(BigoRoomParser.siteIdOf('414439909'), '414439909');
      expect(BigoRoomParser.siteIdOf('https://www.bigo.tv/414439909'), '414439909');
      expect(BigoRoomParser.siteIdOf('hello world'), isNull);
      expect(BigoRoomParser.isSiteId('a-b.c_1'), isTrue);
      expect(BigoRoomParser.isSiteId('.starts-bad'), isFalse);
      expect(BigoRoomParser.isSiteId('a' * 65), isFalse);
    });

    test('a keyword is searched only when it is a plain word of at most 100 characters', () {
      expect(BigoRoomParser.isSearchable('Ann'), isTrue);
      expect(BigoRoomParser.isSearchable(''), isFalse);
      expect(BigoRoomParser.isSearchable('https://x.test/a'), isFalse);
      expect(BigoRoomParser.isSearchable('a\tb'), isFalse);
      expect(BigoRoomParser.isSearchable('a' * 101), isFalse);
      expect(BigoRoomParser.isSearchable('a' * 100), isTrue);
    });

    test('the filter matches name or topic case-ignored, once per id', () {
      final cards = [
        _roomOf('a1', nick: 'Ann', title: 'Talk'),
        _roomOf('A1', nick: 'Other', title: 'Other'),
        _roomOf('b2', nick: 'Bob', title: 'Announcement'),
      ];
      expect(BigoRoomParser.filter(cards, 'ann').map((card) => card.roomId), ['a1', 'b2']);
      expect(BigoRoomParser.filter(cards, 'BOB').map((card) => card.roomId), ['b2']);
      expect(BigoRoomParser.filter(cards, 'talk').map((card) => card.roomId), ['a1']);
      expect(BigoRoomParser.filter(cards, 'zzz'), isEmpty);
    });

    test('a checked id is trimmed and a bad one is refused without a request', () {
      expect(BigoRoomParser.checkedSiteId(' 414439909 '), '414439909');
      expect(() => BigoRoomParser.checkedSiteId(''), throwsA(isA<BigoFailure>()));
      expect(() => BigoRoomParser.checkedSiteId('bad id!'), throwsA(isA<BigoFailure>()));
    });

    test('the one area is the public list', () {
      final area = BigoRoomParser.area();
      expect(area.areaId, '72');
      expect(area.areaName, '公开推荐');
      expect(area.parentAreaName, 'Bigo Live');
      expect(BigoRoomParser.isAreaId('72'), isTrue);
      expect(BigoRoomParser.isAreaId(' 72 '), isTrue);
      expect(BigoRoomParser.isAreaId('other'), isFalse);
    });
  });

  group('chat protocol', () {
    test('a uri is high << 8 | low, as the page writes it', () {
      expect(BigoDanmakuCodec.uri(3, 23), 791);
      expect(BigoDanmakuCodec.uri(2001, 23), BigoDanmakuCodec.loginUri);
      expect(BigoDanmakuCodec.uri(2002, 23), BigoDanmakuCodec.loginReplyUri);
      expect(BigoDanmakuCodec.uri(5, 24), BigoDanmakuCodec.enterUri);
      expect(BigoDanmakuCodec.uri(6, 24), BigoDanmakuCodec.enterReplyUri);
      expect(BigoDanmakuCodec.uri(10, 24), BigoDanmakuCodec.textUri);
      expect(BigoDanmakuCodec.uri(40, 24), BigoDanmakuCodec.audienceUri);
      expect(BigoDanmakuCodec.uri(42, 24), BigoDanmakuCodec.usersUri);
      expect(BigoDanmakuCodec.uri(43, 24), BigoDanmakuCodec.usersReplyUri);
    });

    test("the device id is the page's own three-part form", () {
      final id = BigoDanmakuCodec.deviceId(Random(3), DateTime.fromMillisecondsSinceEpoch(1759000000123));
      expect(id, matches(RegExp(r'^web_[0-9a-f]{32}_[0-9A-Za-z]{6}_1759000000123$')));
    });

    test('the challenge answer signs the last eight characters at the second', () {
      final body = _jsonOf(
        BigoDanmakuCodec.answer('abcdefgh12345678', DateTime.fromMillisecondsSinceEpoch(1759000000999)),
        BigoDanmakuCodec.answerUri,
      );
      expect(body['timeStamp'], '1759000000');
      // Recomputed here from the page's own template.
      expect(body['sign'], md5.convert(utf8.encode('60#4#5#1759000000#1#1#1#1#12345678')).toString());
      expect(body['sign'], 'cf92afb9a350dc265bbbc1d9ecdeea08');
      expect(body['appId'], '60');
      expect(body['osType'], '4');
      expect(body['clientVersion'], '5');
    });

    test('a challenge shorter than eight characters is signed whole', () {
      final body = _jsonOf(
        BigoDanmakuCodec.answer('abc', DateTime.fromMillisecondsSinceEpoch(1759000000999)),
        BigoDanmakuCodec.answerUri,
      );
      expect(body['sign'], md5.convert(utf8.encode('60#4#5#1759000000#1#1#1#1#abc')).toString());
    });

    test("the login, enter, users and ping frames carry the page's fields", () {
      const visitor = BigoChatVisitor(userId: '99', token: 'tk', deviceId: 'web_x');
      final login = _jsonOf(BigoDanmakuCodec.login(visitor), BigoDanmakuCodec.loginUri);
      expect(login['uid'], '99');
      expect(login['cookie'], 'tk');
      expect(login['userName'], '0');
      expect(login['deviceId'], 'web_x');
      expect(login['clientType'], '7');
      expect((login['netConf']! as Map)['countryCode'], 'CN');
      final enter = _jsonOf(
        BigoDanmakuCodec.enter(_joinedRoom, visitor, DateTime.fromMillisecondsSinceEpoch(1759000000999)),
        BigoDanmakuCodec.enterUri,
      );
      expect(enter['roomId'], _joinedRoom);
      expect(enter['secretKey'], '0');
      expect(enter['seqId'], '1759000000999');
      expect(enter['deviceid'], 'web_x');
      expect(enter['version'], '15');
      const args = BigoDanmakuArgs(siteId: '414439909', ownerId: 123456, roomId: _joinedRoom);
      final users = _jsonOf(
        BigoDanmakuCodec.users(args, DateTime.fromMillisecondsSinceEpoch(1759000000999)),
        BigoDanmakuCodec.usersUri,
      );
      expect(users['uid'], '123456');
      expect(users['roomid'], _joinedRoom);
      final ping = _jsonOf(
        BigoDanmakuCodec.ping(DateTime.fromMillisecondsSinceEpoch(1759000000999)),
        BigoDanmakuCodec.pingUri,
      );
      expect(ping['seqid'], '1759000000999');
      expect(ping.keys, ['status', 'seqid', 'flag', 'roomId', 'ownerStatus', 'micUid']);
    });

    test('the visitor account needs digits and a usable token and echoes the device', () {
      final visitor = BigoDanmakuCodec.visitor(
        _envelope({'userId': '99', 'uidToken': 'tk###VER2', 'userName': 'Ann', 'deviceId': 'web_y'}),
        status: 200,
        deviceId: 'web_x',
      );
      expect(visitor.userId, '99');
      expect(visitor.token, 'tk');
      expect(visitor.userName, 'Ann');
      expect(visitor.deviceId, 'web_y');
      expect(visitor.toString(), 'BigoChatVisitor(99)');
      final bare = BigoDanmakuCodec.visitor(
        _envelope({'userId': '99', 'uidToken': 'tk'}),
        status: 200,
        deviceId: 'web_x',
      );
      expect(bare.deviceId, 'web_x');
      expect(bare.userName, '0');
      for (final body in [
        '{}',
        '{"code":1}',
        _envelope({'userId': 'x', 'uidToken': 'tk'}),
        _envelope({'userId': '9'}),
        _envelope({'userId': '9', 'uidToken': 'bad token'}),
        _envelope({'userId': '9', 'uidToken': 'a' * 4097}),
      ]) {
        expect(
          () => BigoDanmakuCodec.visitor(body, status: 200, deviceId: 'web_x'),
          throwsFormatException,
          reason: body,
        );
      }
      expect(
        () => BigoDanmakuCodec.visitor(_envelope({'userId': '9', 'uidToken': 'tk'}), status: 500, deviceId: 'x'),
        throwsFormatException,
      );
      expect(() => BigoDanmakuCodec.visitor('not json', status: 200, deviceId: 'x'), throwsFormatException);
    });

    test('a server frame may be tab-separated, byte-encoded or plain text', () {
      final frame = _textFrame({
        'payload': {'tag': '1', 'content': _chatContent('Ann', 'hello'), 'uid': '7'},
      });
      expect(BigoDanmakuCodec.decode(frame, roomId: _joinedRoom).messages, hasLength(1));
      expect(BigoDanmakuCodec.decode(utf8.encode('\t$frame'), roomId: _joinedRoom).messages, hasLength(1));
      expect(BigoDanmakuCodec.decode('nonsense', roomId: '1').messages, isEmpty);
      expect(BigoDanmakuCodec.decode(null, roomId: '1').messages, isEmpty);
      expect(BigoDanmakuCodec.decode('${BigoDanmakuCodec.pingUri}', roomId: '1').messages, isEmpty);
      expect(BigoDanmakuCodec.decode('${BigoDanmakuCodec.pingUri}{not json}', roomId: '1').messages, isEmpty);
      expect(BigoDanmakuCodec.decode('${BigoDanmakuCodec.pingUri}[1,2]', roomId: '1').messages, isEmpty);
    });

    test('chat: the base64 payload gives the name and text, the seqId the dedup id', () {
      final message = BigoDanmakuCodec.decode(
        _textFrame({
          'payload': {'tag': '2', 'content': _chatContent('  Ann  ', '  hello  '), 'uid': '7', 'grade': '3'},
          'seqId': '55',
        }),
        roomId: _joinedRoom,
      ).messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.effectiveSender.userName, 'Ann');
      expect(message.effectiveSender.userId, '7');
      expect(message.effectiveSender.userLevel, '3');
      expect(message.messageId, '7:55');
      expect(message.color, LiveMessageColor.white);
      expect(message.payload, isNull);
    });

    test('chat: another room, a non-chat tag, undecodable content and empty text give nothing', () {
      for (final frame in [
        _textFrame({
          'room_id': 'other',
          'payload': {'tag': '1', 'content': _chatContent('Ann', 'hi')},
        }),
        _textFrame({
          'payload': {'tag': '6', 'content': _chatContent('Ann', 'hi')},
        }),
        _textFrame({
          'payload': {'tag': '1', 'content': 'not base64 at all !!'},
        }),
        _textFrame({
          'payload': {'tag': '1', 'content': _chatContent('Ann', '   ')},
        }),
        _textFrame({'payload': _chatContent('Ann', 'hi')}),
        _textFrame({
          'payload': {'tag': '1'},
        }),
        _textFrame({
          'payload': {'tag': 'x', 'content': _chatContent('Ann', 'hi')},
        }),
      ]) {
        expect(BigoDanmakuCodec.decode(frame, roomId: _joinedRoom).messages, isEmpty, reason: frame);
      }
    });

    test('chat: the uid falls back to from_uid and a non-numeric level is left out', () {
      final message = BigoDanmakuCodec.decode(
        _textFrame({
          'from_uid': '8',
          'payload': {'tag': '1', 'content': _chatContent('Ann', 'hi'), 'uid': 'not-digits', 'grade': 'x'},
          'seqId': '9',
        }),
        roomId: _joinedRoom,
      ).messages.single;
      expect(message.effectiveSender.userId, '8');
      expect(message.effectiveSender.userLevel, '');
      expect(message.messageId, '8:9');
    });

    test('a gift animation names nobody, carries the combo and has no price', () {
      final message = BigoDanmakuCodec.decode(
        _textFrame({
          'oriUri': BigoDanmakuCodec.giftOriUri,
          'seqId': '21',
          'payload': {
            'from_uid': '77',
            'vgift_typeid': '5',
            'vgift_name': 'Flower',
            'vgift_count': '2',
            'send_times': '3',
            'ticket_num': '900',
          },
        }),
        roomId: _joinedRoom,
      ).messages.single;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'Flower x2');
      expect(message.effectiveSender.userId, '77');
      expect(message.effectiveSender.userName, '');
      expect(message.messageId, '77:21');
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, '5');
      expect(gift.name, 'Flower');
      expect(gift.count, 2);
      expect(gift.combo.comboTotal, 6);
      // The gift table is not asked for: the value stays unknown, never a
      // fabricated zero.
      expect(gift.value.unit.name, 'other');
      expect(gift.value.unitPrice, isNull);
      expect(gift.value.totalValue, isNull);
    });

    test('a gift of another room or without a name gives nothing; counts fall back to 1', () {
      expect(
        BigoDanmakuCodec.decode(
          _textFrame({
            'oriUri': BigoDanmakuCodec.giftOriUri,
            'payload': {'room_id': '999', 'vgift_name': 'Flower'},
          }),
          roomId: _joinedRoom,
        ).messages,
        isEmpty,
      );
      expect(
        BigoDanmakuCodec.decode(
          _textFrame({
            'oriUri': BigoDanmakuCodec.giftOriUri,
            'payload': {'vgift_name': '   '},
          }),
          roomId: _joinedRoom,
        ).messages,
        isEmpty,
      );
      final gift =
          BigoDanmakuCodec.decode(
                _textFrame({
                  'oriUri': BigoDanmakuCodec.giftOriUri,
                  'payload': {'room_id': _joinedRoom, 'vgift_name': 'Flower', 'vgift_count': '0', 'send_times': '0'},
                }),
                roomId: _joinedRoom,
              ).messages.single.payload!
              as LiveGift;
      expect(gift.count, 1);
      expect(gift.combo.comboTotal, isNull);
    });

    test('the gift line names the sender of the gift that waited for it', () {
      final frame = BigoDanmakuCodec.decode(
        _textFrame({
          'payload': {'tag': '6', 'content': _chatContent('Sender', ''), 'uid': '77', 'grade': '4'},
        }),
        roomId: _joinedRoom,
      );
      expect(frame.giftSender, (userId: '77', name: 'Sender', level: '4'));
      expect(frame.messages, isEmpty);
      final fallback = BigoDanmakuCodec.decode(
        _textFrame({
          'from_uid': '78',
          'payload': {'tag': '6', 'content': 'nonsense !!'},
        }),
        roomId: _joinedRoom,
      );
      expect(fallback.giftSender, (userId: '78', name: '', level: ''));
      expect(
        BigoDanmakuCodec.decode(
          _textFrame({
            'payload': {'tag': '6'},
          }),
          roomId: _joinedRoom,
        ).giftSender,
        isNull,
      );
    });

    test('the audience arrives as 40|24 by gid and as the 43|24 answer by room_id', () {
      final update = BigoDanmakuCodec.decode(
        _frame(BigoDanmakuCodec.audienceUri, {'gid': _joinedRoom, 'totalUserCount': '2472'}),
        roomId: _joinedRoom,
      ).messages.single;
      expect(update.type, LiveMessageType.audienceUpdate);
      expect(update.payload, isA<LiveAudienceUpdate>());
      expect((update.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.onlineViewers);
      expect((update.payload! as LiveAudienceUpdate).value, 2472);
      final reply = BigoDanmakuCodec.decode(
        _frame(BigoDanmakuCodec.usersReplyUri, {'room_id': _joinedRoom, 'total': 30}),
        roomId: _joinedRoom,
      ).messages.single;
      expect((reply.payload! as LiveAudienceUpdate).value, 30);
      for (final frame in [
        _frame(BigoDanmakuCodec.audienceUri, {'gid': 'other', 'totalUserCount': '10'}),
        _frame(BigoDanmakuCodec.audienceUri, {'gid': _joinedRoom, 'totalUserCount': '-3'}),
        _frame(BigoDanmakuCodec.audienceUri, {'gid': _joinedRoom, 'totalUserCount': 'x'}),
        _frame(BigoDanmakuCodec.usersReplyUri, {'room_id': _joinedRoom}),
      ]) {
        expect(BigoDanmakuCodec.decode(frame, roomId: _joinedRoom).messages, isEmpty, reason: frame);
      }
    });

    test('the handshake frames: challenge, login answer, entry answer, idle', () {
      expect(
        BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.challengeUri, {'challenge': 'abc'}), roomId: '1').challenge,
        'abc',
      );
      expect(BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.challengeUri, {}), roomId: '1').challenge, isNull);
      expect(
        BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.loginReplyUri, {'res': '200'}), roomId: '1').loggedIn,
        isTrue,
      );
      expect(
        BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.loginReplyUri, {'res': '500'}), roomId: '1').refusal,
        'login: res 500',
      );
      final entered = BigoDanmakuCodec.decode(
        _frame(BigoDanmakuCodec.enterReplyUri, {'resCode': '200', 'sid': _joinedRoom}),
        roomId: _joinedRoom,
      );
      expect(entered.entered, isTrue);
      expect(entered.idle, isFalse);
      for (final sid in ['0', '']) {
        expect(
          BigoDanmakuCodec.decode(
            _frame(BigoDanmakuCodec.enterReplyUri, {'resCode': '200', 'sid': sid}),
            roomId: _joinedRoom,
          ).idle,
          isTrue,
          reason: sid,
        );
      }
      expect(
        BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.enterReplyUri, {'resCode': 403}), roomId: '1').refusal,
        'enter: resCode 403',
      );
    });

    test('an unsigned frame is a refusal whatever its uri, and the ping gives nothing', () {
      expect(
        BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.loginUri, {'info': 'unsigned'}), roomId: '1').refusal,
        contains('unsigned'),
      );
      expect(
        BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.pingUri, {'errUri': 5}), roomId: '1').refusal,
        'unsigned: 5',
      );
      expect(BigoDanmakuCodec.decode(BigoDanmakuCodec.ping(DateTime.utc(2026)), roomId: '1').messages, isEmpty);
      expect(BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.pingUri, {}), roomId: '1').refusal, isNull);
      // Likes, entrance notices, heat and seats give nothing.
      for (final uri in [1234, 5678, BigoDanmakuCodec.uri(20, 24), BigoDanmakuCodec.uri(30, 24)]) {
        expect(BigoDanmakuCodec.decode(_frame(uri, {'room_id': _joinedRoom}), roomId: _joinedRoom).messages, isEmpty);
      }
    });

    test('the join arguments need a Bigo id, an account and a room id of digits', () {
      const good = BigoDanmakuArgs(siteId: '414439909', ownerId: 1, roomId: _joinedRoom);
      expect(BigoDanmakuCodec.checks(good), isTrue);
      expect(BigoDanmakuCodec.checks(const BigoDanmakuArgs(siteId: 'bad id!', ownerId: 1, roomId: '123')), isFalse);
      expect(BigoDanmakuCodec.checks(const BigoDanmakuArgs(siteId: 'a', ownerId: 0, roomId: '123')), isFalse);
      expect(
        BigoDanmakuCodec.checks(const BigoDanmakuArgs(siteId: 'a', ownerId: 9007199254740991, roomId: '123')),
        isTrue,
      );
      expect(BigoDanmakuCodec.checks(const BigoDanmakuArgs(siteId: 'a', ownerId: 1, roomId: '0123')), isFalse);
      expect(BigoDanmakuCodec.checks(const BigoDanmakuArgs(siteId: 'a', ownerId: 1, roomId: '')), isFalse);
      expect(BigoDanmakuCodec.checks(BigoDanmakuArgs(siteId: 'a', ownerId: 1, roomId: '1' * 21)), isFalse);
    });
  });

  group('adapter wiring', () {
    test('the manifest and the seven capabilities are wired, the rest are not', () async {
      final site = _adapter(_flow()).site;
      expect(site.manifest.id, 'bigo');
      expect(site.manifest.localizedName('zh-CN', 'en-US'), 'Bigo Live');
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
      await site.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      expect(site.runtimeInfo.status.name, 'ready');
    });

    test('a room read is a fresh token and the studio, and carries both handles', () async {
      final adapter = _adapter(_flow());
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom('414439909'));
      expect(room.roomId, '414439909');
      expect(room.broadcast.isLiveNow, isTrue);
      expect((room.runtime.streamHandle! as BigoRoomData).access, BigoAccess.public);
      expect((room.runtime.danmakuHandle! as BigoDanmakuArgs).roomId, _joinedRoom);
      final sent = adapter.http.sent;
      expect(sent.map((request) => request.url.path), [
        '/v1/webjs/t',
        '/v1/webjs/status',
        '/official_website/studio/getInternalStudioInfo',
      ]);
      expect(sent[0].method, 'GET');
      expect(sent[2].method, 'POST');
      expect(sent[2].body, '');
      expect(sent[2].url.queryParameters['siteId'], '414439909');
      expect(sent[2].url.queryParameters['token'], 'tk-1');
      expect(sent[2].url.queryParameters['verify'], '');
      expect(sent[0].headers['user-agent'], BigoEndpoints.userAgent);
      expect(sent[0].headers['origin'], BigoEndpoints.webOrigin);
      expect(sent[0].headers['x-requested-with'], 'XMLHttpRequest');
      // Each token request carries its own callback name, and the second the
      // encrypted data of the server time.
      for (final request in sent.take(2)) {
        expect(request.url.queryParameters['callback'], startsWith('jsonpcallback_'));
      }
      final data = base64Decode(sent[1].url.queryParameters['data']!);
      expect(utf8.decode(data.sublist(0, 8)), 'Salted__');
      expect((data.length - 16) % 16, 0);
    });

    test('a quality list reuses the kept token and asks the studio once', () async {
      final adapter = _adapter(_flow());
      final playback = adapter.site.capability<LivePlaybackProvider>()!;
      expect(_right(await playback.getQualities(roomId: '414439909')).single.qualityId, 'live');
      // With no token kept, even a refresh pays for the token's two requests.
      expect(adapter.http.sent, hasLength(3));
      final qualities = _right(await playback.getQualities(roomId: '414439909'));
      expect(qualities.single.label, '直播自动');
      // The kept token answers with one request.
      expect(adapter.http.sent, hasLength(4));
      final last = adapter.http.sent.last;
      expect(last.url.path, '/official_website/studio/getInternalStudioInfo');
      expect(last.url.queryParameters['token'], 'tk-1');
    });

    test('a play resolve takes a fresh token and says the line is good for one open', () async {
      final adapter = _adapter(_flow());
      final line = _right(await adapter.site.capability<LivePlaybackProvider>()!.getLines(roomId: '414439909')).single;
      expect(line.url, 'https://cdn.bigo.tv/live/playlist.m3u8');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.lineLabel, 'cdn.bigo.tv');
      expect(line.singleUse, isTrue);
      expect(line.lease, isNull);
      expect(line.headers['referer'], 'https://www.bigo.tv/');
      // A resolve never shares the room read's token answer.
      expect(adapter.http.sent, hasLength(3));
      expect(
        _leftOf(
          await adapter.site.capability<LivePlaybackProvider>()!.getLines(
            roomId: '414439909',
            quality: const LivePlayQuality(label: 'x', qualityId: 'other'),
          ),
        ),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('a gated room is an authentication failure and an offline one is content-unavailable', () async {
      final gated = _adapter(_flow(data: _studioData(needLogin: true, alive: 0, hlsSrc: null, passRoom: null)));
      final error = _leftOf(await gated.site.capability<LivePlaybackProvider>()!.getQualities(roomId: '414439909'));
      expect(error, isA<LiveSiteAuthenticationError>());
      expect((error as LiveSiteAuthenticationError).siteId, 'bigo');
      final offline = _adapter(_flow(data: _studioData(alive: 0, roomId: '0', hlsSrc: null)));
      expect(
        _leftOf(await offline.site.capability<LivePlaybackProvider>()!.getLines(roomId: '414439909')),
        isA<LiveSiteContentUnavailable>(),
      );
      final room = _right(await offline.site.capability<LiveRoomProvider>()!.getRoom('414439909'));
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(room.runtime.danmakuHandle, isNull);
    });

    test('a login gate that clears on the second ask keeps the gate with the state', () async {
      var asks = 0;
      final adapter = _adapter((request) {
        if (request.url.path.endsWith('getInternalStudioInfo')) {
          asks += 1;
          return _resp(
            200,
            _envelope(
              asks == 1
                  ? _studioData(needLogin: true, alive: 0, hlsSrc: null, passRoom: null)
                  : _studioData(hlsSrc: null, passRoom: true),
            ),
          );
        }
        return _tokenAnswer(request);
      });
      final room = _right(await adapter.site.capability<LiveRoomProvider>()!.getRoom('414439909'));
      expect(asks, 2);
      // The gate stays and the state is the second answer's.
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect((room.runtime.streamHandle! as BigoRoomData).access, BigoAccess.loginRequired);
      expect(room.runtime.danmakuHandle, isNull);
    });

    test('a play resolve that finds no playlist is content-unavailable', () async {
      final adapter = _adapter(_flow(data: _studioData(hlsSrc: null)));
      expect(
        _leftOf(await adapter.site.capability<LivePlaybackProvider>()!.getLines(roomId: '414439909')),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('the public list is fetched for page one and reused for the later pages', () async {
      var lists = 0;
      final clock = [DateTime.utc(2026, 9, 30, 12)];
      final http = _FakeHttp((_) {
        lists += 1;
        return _resp(200, _list([for (var i = 0; i < 25; i++) _row(bigoId: 'r$i', owner: 100 + i, sid: 100 + i)]));
      });
      final site = BigoSite(http: BigoHttp(http), now: () => clock.single);
      final rooms = site.capability<LiveRoomProvider>()!;
      final first = _right(await rooms.getRooms(const LivePageRequest()));
      expect(first.items, hasLength(20));
      expect(first.hasMore, isTrue);
      final second = _right(await rooms.getRooms(const LivePageRequest(page: 2)));
      expect(second.items, hasLength(5));
      expect(second.hasMore, isFalse);
      expect(lists, 1);
      expect(_right(await rooms.getRooms(const LivePageRequest(page: 3))).items, isEmpty);
      expect(lists, 1);
      // Past the 30 s window page one asks again, and a later page keeps that
      // fresh list.
      clock[0] = clock[0].add(const Duration(seconds: 31));
      await rooms.getRooms(const LivePageRequest());
      expect(lists, 2);
      await rooms.getRooms(const LivePageRequest(page: 2));
      expect(lists, 2);
      // The area pages read the same snapshot: a later page shares it, page one
      // asks again.
      await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '72', request: const LivePageRequest(page: 2));
      expect(lists, 2);
      await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '72');
      expect(lists, 3);
    });

    test('a failed list fetch is forgotten, not kept as an empty page', () async {
      var asks = 0;
      final site = _adapter((_) {
        asks += 1;
        return asks == 1 ? _resp(500, 'boom') : _resp(200, _list([_row()]));
      }).site;
      expect((await site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest())).isLeft(), isTrue);
      expect(_right(await site.capability<LiveRoomProvider>()!.getRooms(const LivePageRequest())).items, hasLength(1));
      expect(asks, 2);
    });

    test('the one area is the public list and any other id is a caller error', () async {
      final site = _adapter((_) => _resp(200, _list([_row()]))).site;
      expect(_right(await site.capability<LiveAreaProvider>()!.getAreas()), hasLength(1));
      expect(_right(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '72')).items, hasLength(1));
      expect(
        _leftOf(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: 'other')),
        isA<LiveSiteInvalidArgument>(),
      );
    });

    test('the discovery feed slices the same snapshot and reports the rest of it', () async {
      final site = _adapter((_) => _resp(200, _list([_row(), _row(bigoId: 'x', owner: 2, sid: 4242)]))).site;
      final discovery = site.capability<LiveDiscoveryProvider>()!;
      final page = _right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 1)));
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(pageSize: 101))).items, isEmpty);
      expect(_right(await discovery.getRecommendedRooms(request: const LivePageRequest(page: 3))).hasMore, isFalse);
    });

    test('a keyword that looks like an id is looked up first; a name filters the list', () async {
      final adapter = _adapter((request) {
        final path = request.url.path;
        if (path.endsWith('/t') || path.endsWith('/status')) return _tokenAnswer(request);
        if (path.endsWith('getInternalStudioInfo')) {
          final asked = request.url.queryParameters['siteId'];
          return _resp(200, asked == '414439909' ? _envelope(_studioData()) : _envelope({'alive': 0}));
        }
        return _resp(
          200,
          _list([
            _row(bigoId: 'a1', owner: 1, sid: 101, topic: 'Ann night'),
            _row(bigoId: 'b2', owner: 2, sid: 102, nick: 'Bob', topic: 'Other'),
          ]),
        );
      });
      final search = adapter.site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms});
      final byId = _right(
        await search.search(const LiveSearchRequest(query: '414439909', target: LiveSearchTarget.rooms)),
      );
      expect(byId.items.single, isA<RoomSearchResult>());
      expect((byId.items.single as RoomSearchResult).room.roomId, '414439909');
      final byName = _right(await search.search(const LiveSearchRequest(query: 'ann', target: LiveSearchTarget.rooms)));
      expect(byName.items.map((item) => (item as RoomSearchResult).room.roomId), ['a1']);
      final byLink = _right(
        await search.search(
          const LiveSearchRequest(query: 'https://www.bigo.tv/414439909', target: LiveSearchTarget.rooms),
        ),
      );
      expect(byLink.items, hasLength(1));
      // An unknown id is no result, not an error.
      expect(
        _right(await search.search(const LiveSearchRequest(query: 'zz9', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
      expect(
        _leftOf(await search.search(const LiveSearchRequest(query: 'ann', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      expect(
        _right(await search.search(const LiveSearchRequest(query: '   ', target: LiveSearchTarget.rooms))).items,
        isEmpty,
      );
    });

    test('a search of another page asks for nothing', () async {
      final adapter = _adapter((_) => _resp(200, _list([_row()])));
      final page = _right(
        await adapter.site.capability<LiveSearchProvider>()!.search(
          const LiveSearchRequest(query: 'ann', target: LiveSearchTarget.rooms, page: 2),
        ),
      );
      expect(page.items, isEmpty);
      expect(adapter.http.sent, isEmpty);
    });

    test('a chat session is refused for a room whose chat the website does not open', () async {
      final site = _adapter(_flow(data: _studioData(alive: 0, roomId: '0', hlsSrc: null))).site;
      expect(
        _leftOf(await site.capability<LiveDanmakuProvider>()!.createSession(roomId: '414439909')),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('the link resolver canonicalizes a room page and refuses everything else', () async {
      final resolver = _adapter(_flow()).site.capability<LiveLinkResolver>()!;
      expect(
        _right(await resolver.resolve(Uri.parse('https://m.bigo.tv/en/qashia305#x'))),
        Uri.parse('https://www.bigo.tv/qashia305'),
      );
      expect(_leftOf(await resolver.resolve(Uri.parse('https://www.bigo.tv/live'))), isA<LiveSiteNotFound>());
      expect(_leftOf(await resolver.resolve(Uri.parse('https://live.douyu.com/123'))), isA<LiveSiteUnsupported>());
    });

    test('a bad status is a network failure and a bad shape a parse failure', () async {
      expect(
        _leftOf(await _adapter((_) => _resp(503, 'nope')).site.capability<LiveRoomProvider>()!.getRoom('414439909')),
        isA<LiveSiteNetworkError>(),
      );
      expect(
        _leftOf(
          await _adapter((request) => request.url.path.endsWith('/t') ? _resp(200, 'not jsonp') : _resp(200, '{}')).site
              .capability<LiveRoomProvider>()!
              .getRoom('414439909'),
        ),
        isA<LiveSiteParseError>(),
      );
      expect(
        _leftOf(await _adapter((_) => _resp(403, '{}')).site.capability<LiveRoomProvider>()!.getRoom('414439909')),
        isA<LiveSiteRateLimitError>(),
      );
      expect(
        _leftOf(await _adapter((_) => _resp(404, '{}')).site.capability<LiveRoomProvider>()!.getRoom('414439909')),
        isA<LiveSiteNotFound>(),
      );
      expect(
        _leftOf(
          await _adapter((_) => _resp(200, _envelope(_studioData(needLogin: 'oops')))).site
              .capability<LiveRoomProvider>()!
              .getRoom('414439909'),
        ),
        isA<LiveSiteParseError>(),
      );
    });

    test('a bad room id is refused before any request', () async {
      final adapter = _adapter(_flow());
      expect(_leftOf(await adapter.site.capability<LiveRoomProvider>()!.getRoom('bad id!')), isA<LiveSiteNotFound>());
      expect(adapter.http.sent, isEmpty);
    });

    test('a transport breakdown is reported as a network failure', () async {
      final site = BigoSite(
        http: BigoHttp(_FakeHttp((_) => throw const TimeoutFailure('bigo timeout'))),
        now: () => DateTime.utc(2026),
      );
      expect(_leftOf(await site.capability<LiveRoomProvider>()!.getRoom('414439909')), isA<LiveSiteNetworkError>());
    });
  });
}

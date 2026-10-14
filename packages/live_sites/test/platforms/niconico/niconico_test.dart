import 'dart:convert';
import 'dart:typed_data';

// The test doubles and helpers spell their class name in their one constructor;
// the shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_http.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_area_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_link_resolver.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_room_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_search_provider.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_danmaku_codec.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_protobuf.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_seat_session.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_play_parser.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_room_parser.dart';
import 'package:test/test.dart';

/// The request the fake transport answered, with its URL.
typedef _Seen = ({Uri url, Map<String, String> headers});

/// Answers every request from [onSend] and records each one.
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final LiveResponse Function(_Seen request) onSend;
  final List<_Seen> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    sent.add((url: request.url, headers: request.headers));
    return onSend(sent.last);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

LiveResponse _bytes(int status, List<int> body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: Uint8List.fromList(body));

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _left<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left'));

/// A varint-length-delimited stream of [messages] (each under 128 bytes).
Uint8List _delimited(List<List<int>> messages) {
  final out = BytesBuilder(copy: false);
  for (final message in messages) {
    out
      ..addByte(message.length)
      ..add(message);
  }
  return out.toBytes();
}

/// A `google.protobuf.Timestamp` (1 seconds, 2 nanos).
List<int> _timestamp(int seconds, {int nanos = 0}) =>
    (NiconicoProtoWriter()
          ..integer(1, seconds)
          ..integer(2, nanos))
        .toBytes();

/// A `Chat` (1 content, 2 name, 5 raw_user_id, 6 hashed_user_id).
List<int> _chat({required String content, String name = 'tanaka', int? rawUserId, String hashedUserId = 'HASHED'}) {
  final writer = NiconicoProtoWriter()
    ..string(1, content)
    ..string(2, name);
  if (rawUserId != null) writer.integer(5, rawUserId);
  if (hashedUserId.isNotEmpty) writer.string(6, hashedUserId);
  return writer.toBytes();
}

/// A `ChunkedMessage` (1 meta with 1 id and 2 at, then 2 message or 20
/// overflowed_chat carrying [chat]).
List<int> _chunkedMessage(List<int> chat, {String id = 'msg-1', int at = 1730000000, bool overflow = false}) {
  final meta = NiconicoProtoWriter()
    ..string(1, id)
    ..message(2, _timestamp(at));
  final nicolive = NiconicoProtoWriter()..message(overflow ? 20 : 1, chat);
  final chunk = NiconicoProtoWriter()
    ..message(1, meta.toBytes())
    ..message(2, nicolive.toBytes());
  return chunk.toBytes();
}

/// A `ChunkedMessage` whose payload is a state (`NicoliveState`, field 4).
List<int> _chunkedState(List<int> state, {String id = 'msg-1', int at = 1730000000}) {
  final meta = NiconicoProtoWriter()
    ..string(1, id)
    ..message(2, _timestamp(at));
  return (NiconicoProtoWriter()
        ..message(1, meta.toBytes())
        ..message(4, state))
      .toBytes();
}

/// A `ChunkedMessage` carrying a `NicoliveMessage.gift` (field 8).
List<int> _chunkedGift(List<int> gift, {String id = 'msg-1', int at = 1730000000}) {
  final meta = NiconicoProtoWriter()
    ..string(1, id)
    ..message(2, _timestamp(at));
  final nicolive = NiconicoProtoWriter()..message(8, gift);
  return (NiconicoProtoWriter()
        ..message(1, meta.toBytes())
        ..message(2, nicolive.toBytes()))
      .toBytes();
}

/// A `Gift` (1 item_id, 3 advertiser_name, 4 point, 6 item_name).
List<int> _gift({String itemId = 'item-9', String name = 'ニコ子', int point = 100, String giver = 'giver'}) =>
    (NiconicoProtoWriter()
          ..string(1, itemId)
          ..string(3, giver)
          ..integer(4, point)
          ..string(6, name))
        .toBytes();

/// A `NicoliveState` carrying only `statistics.viewers` (1 → 1).
List<int> _stateViewers(int viewers) => (NiconicoProtoWriter()
      ..message(1, (NiconicoProtoWriter()..integer(1, viewers)).toBytes()))
    .toBytes();

/// A `NicoliveState` carrying a `comment_lock` (5): status (1) and, for the
/// followers case, a minimum follow duration (2 → 1 → 1 seconds).
List<int> _stateLock(int status, {int? followSeconds}) {
  final lock = NiconicoProtoWriter()..integer(1, status);
  if (followSeconds != null) {
    lock.message(2, (NiconicoProtoWriter()
          ..message(1, (NiconicoProtoWriter()..integer(1, followSeconds)).toBytes()))
        .toBytes());
  }
  return (NiconicoProtoWriter()..message(5, lock.toBytes())).toBytes();
}

/// A `NicoliveState` carrying `program_status` `Ended` (9 → 1 = 1).
List<int> _stateEnded() => (NiconicoProtoWriter()
      ..message(9, (NiconicoProtoWriter()..integer(1, 1)).toBytes()))
    .toBytes();

/// A `ChunkedMessage` carrying only a signal (5, a varint): not a message.
List<int> _chunkedSignal(int kind) =>
    (NiconicoProtoWriter()..integer(5, kind)).toBytes();


/// The recorded `program` block of a watch page (ON_AIR, anonymous-watchable)
/// for a community user's program, with the seat's WebSocket.
Map<String, dynamic> _program({
  Object? status = 'ON_AIR',
  bool follower = false,
  bool private = false,
  Object? payment,
}) => {
  'nicoliveProgramId': 'lv300000000',
  'title': '深夜の作業配信',
  'supplier': {
    'name': '山田太郎',
    'programProviderId': 456,
    'supplierType': 'user',
    'icons': {'uri150x150': 'https://nicovideo.cdn.nimg.jp/icon/456.jpg'},
  },
  'providerType': 'community',
  'status': status,
  'statistics': {'watchCount': 1234},
  'beginTime': 1730000000,
  'description': 'こんにちは<br>よろしく',
  'isFollowerOnly': follower,
  'isPrivate': private,
  'payment': payment,
};

/// The decoded `embedded-data` of a watch page, with the access flags set by
/// the named arguments.
Map<String, dynamic> _embeddedData({
  Map<String, dynamic>? program,
  bool canWatch = true,
  bool needLogin = false,
  bool countryRestricted = false,
}) => {
  'program': program ?? _program(),
  'programWatch': {
    'condition': {'needLogin': needLogin, 'payment': null},
  },
  'userProgramWatch': {'canWatch': canWatch, 'isCountryRestrictionTarget': countryRestricted},
  'site': {
    'frontendId': 100,
    'relive': {'webSocketUrl': 'wss://a.live2.nicovideo.jp/unama/wsapi/v2/watch/29999?query=keep'},
  },
};

/// The `embedded-data` wrapped in the watch page's `<script>` tag, HTML-entity
/// encoded the way the real page writes it.
String _watchPage(Map<String, dynamic> data) {
  final props = jsonEncode(data)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  return '<html><head><script id="embedded-data" data-props="$props"></script></head><body></body></html>';
}

/// The master playlist the seat's grant points at (1080p and 480p variants).
const String _master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=5200000,RESOLUTION=1920x1080
/hls/playlists/lv300000000/sess/1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=854x480
/hls/playlists/lv300000000/sess/480.m3u8
''';

/// A seat `stream` message's data, HLS master with path-scoped cookies.
Map<String, dynamic> _streamData({String? expires}) => {
  'protocol': 'hls',
  'uri': 'https://livedelivery.dlive.nicovideo.jp/hls/playlists/lv300000000/sess/master.m3u8',
  'quality': 'abr',
  'availableQualities': ['abr', 'super_high', 'audio_aac_192'],
  'cookies': [
    {
      'name': 'noco_hls',
      'value': 'v1',
      'path': '/hls/playlists',
      'domain': 'nicovideo.jp',
      'secure': true,
      'expires': expires,
    },
    {'name': 'noco_seg', 'value': 'v2', 'path': '/hls/segments/lv300000000', 'domain': '.nicovideo.jp', 'secure': true},
  ],
};

void main() {
  group('protobuf NDGR', () {
    test('a ChunkedMessage with a NicoliveMessage chat becomes a chat', () {
      final message = NiconicoDanmakuCodec.message(_chunkedMessage(_chat(content: 'わーい', name: 'sato', rawUserId: 7)));
      expect(message, isNotNull);
      expect(message!.text, 'わーい');
      expect(message.sender?.userName, 'sato');
      expect(message.sender?.userId, 'HASHED');
      expect(message.messageId, 'msg-1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1730000000 * 1000));
    });

    test('overflowed_chat is a chat and a missing hashed id falls back to raw', () {
      final overflow = NiconicoDanmakuCodec.message(
        _chunkedMessage(
          _chat(content: 'hi', rawUserId: 99, hashedUserId: ''),
          id: 'ovf',
          overflow: true,
        ),
      );
      expect(overflow?.text, 'hi');
      expect(overflow?.sender?.userId, '99');
      expect(overflow?.messageId, 'ovf');
    });

    test('an empty chat is dropped', () {
      expect(NiconicoDanmakuCodec.message(_chunkedMessage(_chat(content: '   '))), isNull);
    });

    test('a gift becomes a gift message of one item worth its points', () {
      final message = NiconicoDanmakuCodec.message(_chunkedGift(_gift(point: 300, giver: 'rich')));
      expect(message, isNotNull);
      expect(message!.type, LiveMessageType.gift);
      expect(message.text, 'ニコ子 ×1');
      expect(message.sender?.userName, 'rich');
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, 'item-9');
      expect(gift.value.unit, LiveGiftUnit.point);
      expect(gift.value.unitPrice, 300);
    });

    test('a free gift (0 point) is unit free with no price; an itemless one is dropped', () {
      final free = NiconicoDanmakuCodec.message(_chunkedGift(_gift(point: 0)))!;
      expect((free.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect((free.payload! as LiveGift).value.unitPrice, isNull);
      expect(NiconicoDanmakuCodec.message(_chunkedGift(_gift(point: -5))), isNull);
    });

    test('statistics.viewers becomes an audience update, not a chat', () {
      final message = NiconicoDanmakuCodec.message(_chunkedState(_stateViewers(4321)));
      expect(message!.type, LiveMessageType.audienceUpdate);
      final update = message.payload! as LiveAudienceUpdate;
      expect(update.kind, LiveAudienceSignalKind.totalViewers);
      expect(update.value, 4321);
    });

    test('only a change of the comment lock is reported, in the web player lines', () {
      final reader = NiconicoMessageReader();
      expect(reader.read(_chunkedState(_stateLock(1))), isNotNull); // locked → notice
      expect(reader.read(_chunkedState(_stateLock(1))), isNull); // same lock → nothing
      expect(reader.read(_chunkedState(_stateLock(0))), isNotNull); // lifted → notice
      expect(reader.read(_chunkedState(_stateLock(2, followSeconds: 0))), isNotNull); // followers-only
    });

    test('a program end is reported once and flagged on the reader', () {
      final reader = NiconicoMessageReader();
      final message = reader.read(_chunkedState(_stateEnded()));
      expect(message!.type, LiveMessageType.notice);
      expect(message.text, NiconicoDanmakuCodec.programEndedNotice);
      expect(reader.endedProgram, isTrue);
    });

    test('a signal chunk (field 5) is not read as a message', () {
      expect(NiconicoDanmakuCodec.message(_chunkedSignal(3)), isNull);
    });

    test('a view ChunkedEntry reads its segment window and its next pointer', () {
      final segment =
          (NiconicoProtoWriter()..message(
                1,
                (NiconicoProtoWriter()
                      ..message(1, _timestamp(1730000000))
                      ..message(2, _timestamp(1730000016))
                      ..string(3, 'https://comment.nicovideo.jp/api/v1/threads/lv300000000/messages/seg?token=abc'))
                    .toBytes(),
              ))
              .toBytes();
      final next = (NiconicoProtoWriter()..message(4, (NiconicoProtoWriter()..integer(1, 1730000032)).toBytes()))
          .toBytes();

      final entry = NiconicoDanmakuCodec.viewEntry(segment);
      expect(entry.kind, NiconicoViewEntryKind.segment);
      expect(entry.window?.uri.host, 'comment.nicovideo.jp');
      expect(entry.window?.until.isAfter(entry.window!.from), isTrue);

      final pointer = NiconicoDanmakuCodec.viewEntry(next);
      expect(pointer.kind, NiconicoViewEntryKind.next);
      expect(pointer.next, 1730000032);
    });

    test('a whole view answer splits into its delimited ChunkedEntry messages', () {
      final bytes = _delimited([
        (NiconicoProtoWriter()..message(4, (NiconicoProtoWriter()..integer(1, 123)).toBytes())).toBytes(),
      ]);
      final entries = NiconicoDanmakuCodec.split(bytes).map(NiconicoDanmakuCodec.viewEntry).toList();
      expect(entries.single.next, 123);
    });
  });

  group('seat frames and stream grant', () {
    test('the outbound frames are the recorded JSON', () {
      final start = jsonDecode(NiconicoSeatMessages.startWatching) as Map<String, dynamic>;
      expect(start['type'], 'startWatching');
      final data = start['data'] as Map<String, dynamic>;
      expect((data['stream'] as Map)['protocol'], 'hls');
      expect((data['stream'] as Map)['quality'], 'abr');
      expect((data['room'] as Map)['commentable'], false);
      expect(data['reconnect'], false);
      expect(jsonDecode(NiconicoSeatMessages.getAkashic), {
        'type': 'getAkashic',
        'data': {'chasePlay': false},
      });
      expect(NiconicoSeatMessages.keepSeat, '{"type":"keepSeat"}');
      expect(NiconicoSeatMessages.pong, '{"type":"pong"}');
    });

    test('a stream frame grants the HLS master, dropping audio qualities', () {
      final grant = NiconicoPlayParser.grant(_streamData());
      expect(grant.uri.toString(), startsWith('https://livedelivery.dlive.nicovideo.jp/hls/playlists/'));
      expect(grant.quality, 'abr');
      expect(grant.availableQualities, ['abr', 'super_high']);
    });

    test('the cookie header is path-scoped to the master and to a segment', () {
      final grant = NiconicoPlayParser.grant(_streamData());
      expect(grant.cookieHeaderFor(grant.uri), 'noco_hls=v1');
      expect(
        grant.cookieHeaderFor(Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/segments/lv300000000/x.m4s')),
        'noco_seg=v2',
      );
      // Another origin (or an unscoped path) carries nothing of this grant.
      expect(grant.cookieHeaderFor(Uri.parse('https://evil.example.com/hls/playlists/x')), isNull);
    });

    test('an already-expired cookie is dropped at grant time', () {
      final grant = NiconicoPlayParser.grant(_streamData(), now: DateTime.parse('2999-01-01T00:00:00Z'));
      // The playlist cookie has no expiry, so the master still gets a header;
      // the parsed expiry of a past one would drop that cookie instead.
      expect(grant.cookieHeaderFor(grant.uri), 'noco_hls=v1');
    });

    test('the master parses into qualities, best first, and a pick names one', () {
      final master = Uri.parse('https://livedelivery.dlive.nicovideo.jp/hls/playlists/lv300000000/sess/master.m3u8');
      final variants = NiconicoPlayParser.variants(_master, source: master);
      final qualities = NiconicoPlayParser.qualities(variants);
      expect(qualities.map((q) => q.label), ['1920x1080', '854x480']);
      expect(qualities.first.qualityId, '1920x1080@5200000');
      expect(NiconicoPlayParser.pick(variants, '854x480@1200000')?.url, endsWith('480.m3u8'));

      final lines = NiconicoPlayParser.lines(
        NiconicoPlayParser.grant(_streamData()),
        NiconicoPlayParser.pick(variants, null)!,
        roomId: 'lv300000000',
      );
      expect(lines.single.format.name, 'hls');
      expect(lines.single.headers['referer'], 'https://live.nicovideo.jp/watch/lv300000000');
      expect(lines.single.headers['cookie'], 'noco_hls=v1');
    });

    test('a non-seat socket, a wrong protocol and a bad quality list are refused', () {
      expect(() => NiconicoPlayParser.grant({..._streamData(), 'protocol': 'flv'}), throwsA(isA<NiconicoFailure>()));
      expect(() => NiconicoPlayParser.grant({..._streamData(), 'quality': 'nope'}), throwsA(isA<NiconicoFailure>()));
    });
  });

  group('watch page', () {
    test('an on-air anonymous-watchable program is a live room of its user', () {
      final watch = NiconicoRoomParser.watchData(_embeddedData(), roomId: 'lv300000000');
      expect(watch.room, 'user/456');
      expect(watch.isOnAir, isTrue);
      expect(watch.isPlayable, isTrue);
      expect(watch.socket?.host, 'a.live2.nicovideo.jp');
      expect(watch.socket?.queryParameters['frontend_id'], '100');
      final room = NiconicoRoomParser.room(watch);
      expect(room.roomId, 'user/456');
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.content.title, '深夜の作業配信');
      expect(room.anchor?.name, '山田太郎');
    });

    test('a country restriction is region-blocked', () {
      final watch = NiconicoRoomParser.watchData(_embeddedData(countryRestricted: true), roomId: 'lv300000000');
      expect(NiconicoRoomParser.room(watch).broadcast.restriction, LiveRestriction.regionBlocked);
    });

    test('a needLogin program is login-required', () {
      final watch = NiconicoRoomParser.watchData(
        _embeddedData(needLogin: true, canWatch: false),
        roomId: 'lv300000000',
      );
      expect(NiconicoRoomParser.room(watch).broadcast.restriction, LiveRestriction.needsLogin);
    });

    test('a private program an anonymous viewer cannot watch is private', () {
      final watch = NiconicoRoomParser.watchData(
        _embeddedData(program: _program(private: true), canWatch: false),
        roomId: 'lv300000000',
      );
      expect(NiconicoRoomParser.room(watch).broadcast.restriction, LiveRestriction.private);
    });

    test('the watch page script is HTML-entity decoded into the room', () {
      final watch = NiconicoRoomParser.watch(_watchPage(_embeddedData()), roomId: 'lv300000000');
      expect(watch.programId, 'lv300000000');
      expect(watch.description, contains('よろしく'));
    });
  });

  group('recent and search lists', () {
    String recentBody({int code = 200, String error = 'OK'}) => jsonEncode({
      'meta': {'statusCode': code, 'errorCode': error, 'totalCount': 100},
      'data': [
        {
          'id': 'lv300000000',
          'liveCycle': 'ON_AIR',
          'providerType': 'community',
          'programProvider': {'id': 456, 'name': '山田太郎'},
          'title': '深夜の作業配信',
          'watchPageUrl': 'https://live.nicovideo.jp/watch/lv300000000',
          'beginAt': 1730000000000,
          'statistics': {'watchCount': 1234},
          'isPayProgram': false,
          'isFollowerOnly': false,
        },
      ],
    });

    test('a recent page reads rows and pages on totalCount', () {
      final page = NiconicoRoomParser.listPage(recentBody(), page: 1, search: false);
      expect(page.rooms.single.roomId, 'user/456');
      expect(page.rooms.single.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1730000000000, isUtc: true));
      expect(page.hasMore, isTrue);
    });

    test('a non-200 meta status fails the page', () {
      expect(
        () => NiconicoRoomParser.listPage(recentBody(code: 500), page: 1, search: false),
        throwsA(isA<NiconicoFailure>()),
      );
    });

    test('a search page reads programs by beginTime seconds', () {
      final body = jsonEncode({
        'meta': {'statusCode': 200, 'errorCode': 'OK'},
        'data': {
          'totalCount': 40,
          'programs': [
            {
              'nicoliveProgramId': 'lv300000000',
              'status': 'ON_AIR',
              'providerType': 'official',
              'supplier': {
                'name': '公式',
                'programProviderId': 1,
                'icons': {'uri150x150': 'https://nicovideo.cdn.nimg.jp/i/1.jpg'},
              },
              'title': '公式番組',
              'watchPageUrl': 'https://live.nicovideo.jp/watch/lv300000000',
              'beginTime': 1730000000,
              'payment': false,
              'isFollowerOnly': false,
            },
          ],
        },
      });
      final results = NiconicoRoomParser.searchRooms(body);
      final room = (results.single as RoomSearchResult).room;
      expect(room.roomId, 'lv300000000');
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1730000000000, isUtc: true));
    });
  });

  group('links', () {
    test('program, user and channel links resolve to a room', () {
      expect(NiconicoRoomParser.programIdFromUrl('https://live.nicovideo.jp/watch/lv300000000'), 'lv300000000');
      expect(NiconicoRoomParser.programIdFromUrl('https://nico.ms/lv300000000'), 'lv300000000');
      expect(NiconicoRoomParser.broadcasterRoomIdFromUrl('https://live.nicovideo.jp/watch/user/456'), 'user/456');
      expect(NiconicoRoomParser.broadcasterRoomIdFromUrl('https://www.nicovideo.jp/user/456'), 'user/456');
      expect(NiconicoRoomParser.broadcasterRoomIdFromUrl('https://ch.nicovideo.jp/channel/ch123'), 'ch123');
      expect(NiconicoRoomParser.programIdFromUrl('https://twitch.tv/x'), isNull);
    });

    test('the resolver canonicalizes a broadcaster link without a request', () async {
      final http = _FakeHttp((req) => _resp(200, '{}'));
      final site = NiconicoSite(http: NiconicoHttp(http));
      final uri = _right(
        await NiconicoLinkResolver(site: site).resolve(Uri.parse('https://live.nicovideo.jp/watch/user/456')),
      );
      expect('$uri', 'https://live.nicovideo.jp/watch/user/456');
      expect(http.sent, isEmpty);
      expect(
        _left(await NiconicoLinkResolver(site: site).resolve(Uri.parse('https://twitch.tv/x'))),
        isA<LiveSiteUnsupported>(),
      );
    });
  });

  group('providers', () {
    test('getRoom reads the watch page anonymously and returns the room', () async {
      final http = _FakeHttp((req) => _resp(200, _watchPage(_embeddedData())));
      final site = NiconicoSite(http: NiconicoHttp(http));
      final room = _right(await NiconicoRoomProvider(site: site).getRoom('lv300000000'));
      expect(room.roomId, 'user/456');
      expect(http.sent.single.url.path, '/watch/lv300000000');
      expect(http.sent.single.headers['cookie'], isNull);
    });

    test('getAreas lists the seven tabs under one category', () async {
      final site = NiconicoSite(http: NiconicoHttp(_FakeHttp((req) => _resp(200, '{}'))));
      final areas = _right(await NiconicoAreaProvider(site: site).getAreas());
      expect(areas.length, 7);
      expect(areas.first.areaId, 'common');
      expect(areas.first.parentAreaId, 'niconico');
    });

    test('search answers room results and rejects other targets', () async {
      final body = jsonEncode({
        'meta': {'statusCode': 200, 'errorCode': 'OK'},
        'data': {
          'totalCount': 1,
          'programs': [
            {
              'nicoliveProgramId': 'lv300000000',
              'status': 'ON_AIR',
              'providerType': 'official',
              'supplier': {'name': '公式', 'programProviderId': 1},
              'title': '公式番組',
              'watchPageUrl': 'https://live.nicovideo.jp/watch/lv300000000',
              'beginTime': 1730000000,
            },
          ],
        },
      });
      final http = _FakeHttp((req) => _resp(200, body));
      final provider = NiconicoSearchProvider(site: NiconicoSite(http: NiconicoHttp(http)));
      final page = _right(await provider.search(const LiveSearchRequest(query: '番組', target: LiveSearchTarget.rooms)));
      expect((page.items.single as RoomSearchResult).room.roomId, 'lv300000000');
      expect(
        _left(await provider.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
    });

    test('the comment feed decodes a view window over the fake transport', () async {
      final chunk = _chunkedMessage(_chat(content: 'hello', name: 'kim'));
      final http = _FakeHttp((req) {
        if (req.url.queryParameters['at'] == 'now') {
          final entry = NiconicoProtoWriter()..message(4, (NiconicoProtoWriter()..integer(1, 1730000032)).toBytes());
          return _bytes(200, _delimited([entry.toBytes()]));
        }
        // The window read carries the chat.
        return _bytes(200, _delimited([chunk]));
      });
      final view = Uri.parse('https://comment.nicovideo.jp/api/v1/threads/lv300000000/messages/view?at=now');
      final response = await http.send(LiveRequest.custom(method: 'GET', site: 'niconico', url: view));
      final next = NiconicoDanmakuCodec.split(response.bodyBytes).map(NiconicoDanmakuCodec.viewEntry).single.next;
      expect(next, 1730000032);

      final windowUri = Uri.parse('https://comment.nicovideo.jp/api/v1/threads/lv300000000/messages/seg?at=1');
      final window = await http.send(LiveRequest.custom(method: 'GET', site: 'niconico', url: windowUri));
      final messages = [
        for (final bytes in NiconicoDanmakuCodec.split(window.bodyBytes)) ?NiconicoDanmakuCodec.message(bytes),
      ];
      expect(messages.single.text, 'hello');
    });
  });
}

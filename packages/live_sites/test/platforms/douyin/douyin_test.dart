import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

// The test doubles spell their class name in their one constructor; the
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_http.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_sign.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku_codec.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_protobuf.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_play_parser.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';
import 'package:test/test.dart';

const _webRid = '547977714661';
const _roomId = '7687741736843512602';

/// Hands out scripted values (the random draws of a signature).
final class _Scripted implements Random {
  _Scripted(this.values);

  final List<int> values;
  var _next = 0;

  @override
  int nextInt(int max) => values[_next++ % values.length];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

/// Answers every request from [onSend], recording the requests.
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final LiveResponse Function(LiveRequest request) onSend;
  final List<LiveRequest> requests = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    requests.add(request);
    return onSend(request);
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

String hex(List<int> bytes) => [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

DouyinSigner _signer({required String fingerprint, required List<int> clock, required List<int> seeds}) {
  var calls = 0;
  return DouyinSigner(
    userAgent: DouyinEndpoints.userAgent,
    fingerprint: fingerprint,
    now: () => DateTime.fromMillisecondsSinceEpoch(clock[calls++ % clock.length]),
    random: _Scripted(seeds),
  );
}

/// A `ChatMessage` payload: common (msgId, roomId, createTime), user (id,
/// nickname), content, eventTime.
Uint8List chatPayload({
  String content = '你好',
  int msgId = 123,
  int roomId = 0,
  int createTime = 0,
  int userId = 42,
  String nick = 'viewer',
  int eventTime = 0,
}) {
  final common =
      (DouyinProtoWriter()
            ..integer(2, msgId)
            ..integer(3, roomId)
            ..integer(4, createTime))
          .toBytes();
  final user =
      (DouyinProtoWriter()
            ..integer(1, userId)
            ..string(3, nick))
          .toBytes();
  return (DouyinProtoWriter()
        ..bytes(1, common)
        ..bytes(2, user)
        ..string(3, content)
        ..integer(15, eventTime))
      .toBytes();
}

/// A `RoomUserSeqMessage` payload: total online, cumulative, anchor text.
Uint8List seqPayload({int total = 0, int totalUser = 0, String onlineForAnchor = ''}) =>
    (DouyinProtoWriter()
          ..integer(3, total)
          ..integer(7, totalUser)
          ..string(10, onlineForAnchor))
        .toBytes();

/// A live room answer of `room/web/enter/` with the given stream description.
String enterBody(Map<String, dynamic> streamUrl) => jsonEncode({
  'status_code': 0,
  'data': {
    'room_status': 0,
    'user': {'nickname': '备用名'},
    'partition_road_map': {
      'partition': {'title': '网游'},
    },
    'data': [
      {
        'id_str': _roomId,
        'status': 2,
        'title': '正在直播',
        'cover': {
          'url_list': ['https://p3.douyinpic.com/cover.jpg'],
        },
        'user_count': 713,
        'stats': {'total_user': 30550},
        'room_view_stats': {'display_type': 1, 'display_value': '713在线观众'},
        'game_data': {
          'game_tag_info': {'game_tag_name': '英雄联盟手游'},
        },
        'stream_url': streamUrl,
        'owner': {
          'id_str': '998877',
          'web_rid': _webRid,
          'nickname': '主播',
          'signature': '个人简介',
          'avatar_thumb': {
            'url_list': ['//p3.douyinpic.com/avatar.jpg'],
          },
        },
      },
    ],
  },
});

/// The room's stream description: two video qualities, an alias of the first
/// (identical URLs) and an audio-only key that must never become a quality.
Map<String, dynamic> streamFixture({String flvQuery = 'expire=1790506922'}) {
  final origin = 'https://v.douyincdn.com/third/stream-$_roomId-medium.flv?$flvQuery';
  return {
    'live_core_sdk_data': {
      'pull_data': {
        'options': {
          'default_quality': {'sdk_key': 'ORIGION', 'resolution': '1280x720'},
          'qualities': [
            {
              'sdk_key': 'ORIGION',
              'name': '原画',
              'level': 2,
              'v_bit_rate': 2000000,
              'resolution': '1280x720',
              'v_codec': '264',
            },
            {'sdk_key': 'HD1', 'name': '高清', 'level': 3, 'v_bit_rate': 4000000, 'v_codec': 'bytevc1'},
            {'sdk_key': 'AO', 'name': '音频', 'level': 1},
          ],
        },
        'stream_data': {
          'data': {
            'ORIGION': {
              'main': {
                'flv': origin,
                'hls': 'https://v.douyincdn.com/third/stream-$_roomId-medium.m3u8?$flvQuery',
                'sdk_params': {'VCodec': 'h264', 'width': 1280, 'height': 720},
              },
            },
            'ORIGION_01': {
              'main': {'flv': origin, 'hls': 'https://v.douyincdn.com/third/stream-$_roomId-medium.m3u8?$flvQuery'},
            },
            'HD1': {
              'main': {'flv': 'https://v.douyincdn.com/third/stream-$_roomId-hd.flv?$flvQuery'},
            },
            'AO': {
              'main': {'flv': 'https://v.douyincdn.com/third/audio.flv?only_audio=1'},
            },
          },
        },
      },
    },
    'flv_pull_url': {'ORIGION': origin},
    'hls_pull_url_map': {'ORIGION': 'https://v.douyincdn.com/third/stream-$_roomId-medium.m3u8?$flvQuery'},
    'resolution_name': {'HD1': '高清'},
  };
}

void main() {
  group('signing (vectors from the 3.x code: abogus.dart, xbogus.dart)', () {
    test('SM3 matches the GB/T 32905-2016 examples', () {
      expect(
        hex(DouyinSigner.sm3(utf8.encode('abc'))),
        '66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0',
      );
      expect(
        hex(DouyinSigner.sm3(utf8.encode('abcd' * 16))),
        'debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732',
      );
    });

    // Computed with the reference code with the clock and the random draws
    // injected (Chrome 134 UA, the given fingerprint).
    const vectors = [
      (
        query: '',
        fingerprint: '1536|747|1560|835|0|30|0|0|1920|1040|1920|1040|1536|747|24|24|Win32',
        clock: [1790506922004, 1790506922008],
        seeds: [1104, 4190, 3186],
        aBogus:
            'DXmhBDzIk3EN6Eyu5I5LfY3q6fe3YmZy0SVkMD2fvx3ziL39HMY69exoUUJv3TujZsmfIFEjy4hbT3ohrQ2y8qwf9W4x/25gsfSkKl12so0j'
            '53intL6mE0hN5kb3SFlm5XNAEOk0y75CFRJ0l2CymhK4bfebY7Y6i6trHD==',
      ),
      (
        query: 'a=1',
        fingerprint: '1920|1080|1944|1165|0|0|0|0|1024|768|1280|800|1920|1080|24|24|Win32',
        clock: [1790506922020, 1790506922021],
        seeds: [2655, 8703, 7770],
        aBogus:
            'd7WMQQz1sVLB6ESS5I5LfY3q6fB3YmZy0SVkMD2fYd3ziL39HMYL9exoUUJv3ORjZsmfIFEjy4hbO3xprQAjM36UHWwoWdQ2m66gKl5Q5xSS'
            's1feeLWQnsJL5iR3SFrd5XN1EOfkqwcGFuRDA9/rmhK4bfebY7Y6i6tr/E==',
      ),
      (
        query:
            'app_name=douyin_web&enter_from=web_live&live_id=1&web_rid=547977714661&is_need_double_stream=false'
            '&aid=6383&compress=gzip&device_platform=web&browser_language=zh-CN&browser_platform=Win32'
            '&browser_name=Edge&browser_version=125.0.0.0&msToken=AAAAbbbb%3D%3D',
        fingerprint: '1280|720|1308|805|0|30|0|0|1600|900|1600|860|1280|720|24|24|Win32',
        clock: [1790506922022, 1790506922023],
        seeds: [497, 9689, 1428],
        aBogus:
            'YX8hQRw3sV9khE6z5I5LfY3q6AP3YmZy0SVkMD2fRx3ziL39HMYo9exoUUJv3OfjZsmfIFYjy4hbYNQprQ2n01wfHSkO/25ZsfSkKl12so0j'
            '53inC6WmE0wN-hsAtlaQsvr4EKi8qXCaSYypAnAJ5kIlO62-zo0/9lW=',
      ),
      (
        query: 'keyword=%E5%92%8C%E5%B9%B3+x&offset=0',
        fingerprint: '1111|888|1140|970|0|0|0|0|1500|999|1700|1000|1111|888|24|24|Win32',
        clock: [1790506922024, 1790506922024],
        seeds: [2390, 6381, 5510],
        aBogus:
            'D7R0Q5wZp3xpkE6t5I5LfY3q6R-3YmZy0SVkMD2fqx3ziL39HMYY9exoUUJv3OujZsmfIFYjy4hbY3KdrQcbM1wfHWvx/2ADmDSkKl5Q5xSS'
            's1X9eyUgJUwOmktRSec25k3lEKi8qw5cSYmsWnAJ5kIlO62-zo0/9IR=',
      ),
    ];

    test('a_bogus equals the reference vectors', () {
      for (final vector in vectors) {
        final value = _signer(
          fingerprint: vector.fingerprint,
          clock: vector.clock,
          seeds: vector.seeds,
        ).aBogus(vector.query);
        expect(value, vector.aBogus, reason: vector.query);
      }
    });

    test('every signature starts from the initial cipher table (a signer is reusable)', () {
      final vector = vectors[2];
      final shared = _signer(fingerprint: vector.fingerprint, clock: vector.clock, seeds: vector.seeds);
      expect(shared.aBogus(vector.query), vector.aBogus);
      expect(shared.aBogus(vector.query), vector.aBogus);
    });

    test('signed URLs keep the base query and a given msToken, and put a_bogus last', () {
      final enter =
          _signer(
            fingerprint: '1440|810|1466|895|0|30|0|0|1440|900|1440|860|1440|810|24|24|Win32',
            clock: [1790502760100, 1790502760103],
            seeds: [7, 9999, 4321],
          ).signedUrl(Uri.parse('https://live.douyin.com/webcast/room/web/enter/'), {
            'app_name': 'douyin_web',
            'enter_from': 'web_live',
            'live_id': '1',
            'web_rid': '547977714661',
            'is_need_double_stream': 'false',
            'msToken': 'fixed+token=',
          });
      expect(
        '$enter',
        'https://live.douyin.com/webcast/room/web/enter/?app_name=douyin_web&enter_from=web_live&live_id=1'
            '&web_rid=547977714661&is_need_double_stream=false&msToken=fixed%2Btoken%3D&aid=6383&compress=gzip'
            '&device_platform=web&browser_language=zh-CN&browser_platform=Win32&browser_name=Edge'
            '&browser_version=125.0.0.0&a_bogus=DjWhQDuZsn9ifj6b5I5LfY3q6AH3Ymgy0SVkMD2fpn3z2g39HMOL9exoUvJvydfjZsmfIFYjy'
            '4hbTpcprQcJ01wf984L/25/sfSkKl12so0j53inCy8mE0wN-hsAtePQsvr4EKi8o7/aSYmDAnAJ5kIlO62-zo0/94S=',
      );
      final partition =
          _signer(
            fingerprint: '1024|768|1050|850|0|0|0|0|1024|768|1280|800|1024|768|24|24|Win32',
            clock: [1790502760000],
            seeds: [0, 1, 2],
          ).signedUrl(Uri.parse('https://live.douyin.com/webcast/web/partition/detail/room/v2/?existing=1'), {
            'aid': '6383',
            'count': '15',
            'offset': '15',
            'partition': '1',
            'partition_type': '1',
            'msToken': 'M',
          });
      expect(
        '$partition',
        'https://live.douyin.com/webcast/web/partition/detail/room/v2/?existing=1&aid=6383&count=15&offset=15'
            '&partition=1&partition_type=1&msToken=M&compress=gzip&device_platform=web&browser_language=zh-CN'
            '&browser_platform=Win32&browser_name=Edge&browser_version=125.0.0.0&a_bogus=DfmhQDgpkVEpDE6Y5I5LfY3q6We3Ymgy'
            '0SVkMD2ffd3z2g39HMTD9exoUvJvy88jZsmfIFujy4hbYpxZrQ29M1wfH8Xx/25dmDSkKl5Q5xSSs1Xre60gnt4PmktUCec2Rv3lrOX0qXMH'
            'KRjs09oHmhK4bIOwu3GM4j==',
      );
    });

    test('signedUrl copies the caller map, forces the browser fields, puts a_bogus last', () {
      final params = Map<String, String>.unmodifiable({'web_rid': '1', 'aid': '1'});
      final signer = DouyinSigner(userAgent: DouyinEndpoints.userAgent, random: Random(3));
      final base = Uri.parse('https://live.douyin.com/webcast/room/web/enter/?live_id=1');
      final first = signer.signedUrl(base, params);
      final second = signer.signedUrl(base, params);
      expect(params, {'web_rid': '1', 'aid': '1'});
      expect(first.queryParameters.keys, [
        'live_id',
        'web_rid',
        'aid',
        'compress',
        'device_platform',
        'browser_language',
        'browser_platform',
        'browser_name',
        'browser_version',
        'msToken',
        'a_bogus',
      ]);
      expect(first.queryParameters['aid'], '6383');
      expect(first.queryParameters['msToken'], matches(RegExp(r'^[A-Za-z0-9=]{184}$')));
      expect(first.queryParameters['msToken'], isNot(second.queryParameters['msToken']));
      expect(first.query, matches(RegExp(r'&a_bogus=[A-Za-z0-9/=-]+$')));
    });

    test('the danmaku signature is the X-Bogus of the fixed stub (r1, r2 injected)', () {
      for (final (roomId, user, r1, r2, expected) in [
        (_roomId, '7312345678901234567', 0, 0, 'fDpl4KiMGENF3YOy'),
        (_roomId, '7312345678901234567', 255, 254, '1eVnhJc1lIUrcoJk'),
        ('7382735338101328680', '7273033021933946427', 31, 100, '19wv2GETf0Rijd7D'),
        ('1', '7300000000000000000', 200, 17, 'wk407jV2/WLa1rdA'),
      ]) {
        final signer = DouyinSigner(
          userAgent: DouyinEndpoints.userAgent,
          fingerprint: 'x',
          random: _Scripted([r1, r2]),
        );
        expect(
          signer.danmakuSignature(roomId: roomId, userUniqueId: user),
          expected,
          reason: '$r1 $r2',
        );
      }
      final signer = DouyinSigner(userAgent: DouyinEndpoints.userAgent, fingerprint: 'x', random: _Scripted([5, 77]));
      expect(signer.xBogus('d41d8cd98f00b204e9800998ecf8427e', counter: 2), 'v6ytTiUdP8gEsplH');
      expect(() => signer.xBogus('not md5'), throwsArgumentError);
    });

    test('msToken lengths are checked and the visitor id is 19 digits like the client', () {
      final signer = DouyinSigner(userAgent: DouyinEndpoints.userAgent, random: Random(5));
      expect(signer.msToken(), hasLength(184));
      expect(signer.msToken(length: 256), matches(RegExp(r'^[A-Za-z0-9=]{256}$')));
      expect(() => signer.msToken(length: -1), throwsArgumentError);
      for (var seed = 0; seed < 20; seed++) {
        expect(DouyinSigner.visitorId(Random(seed)), matches(RegExp(r'^7[3-9]\d{17}$')));
        final parts = DouyinSigner.browserFingerprint(Random(seed)).split('|');
        expect(parts, hasLength(17));
        expect(parts.last, 'Win32');
      }
      final visitor = DouyinSite(
        http: DouyinHttp(_FakeHttp((_) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: Uint8List(0)))),
        random: Random(9),
      );
      expect(visitor.visitorId, DouyinSigner.visitorId(Random(9)));
    });
  });

  group('protobuf codec', () {
    test('fields written are read back by number, last one winning', () {
      final bytes =
          (DouyinProtoWriter()
                ..integer(1, 7)
                ..string(3, '抖音')
                ..bytes(8, [1, 2, 3])
                ..integer(1, 9))
              .toBytes();
      final message = DouyinProtoMessage.decode(bytes);
      expect(message.integer(1), 9);
      expect(message.string(3), '抖音');
      expect(message.bytes(8), [1, 2, 3]);
      expect(message.integer(2), isNull);
      expect(message.flag(1), isTrue);
    });

    test('a negative varint reads as unsigned decimal (a uint64 above 2^63)', () {
      expect(DouyinProtoMessage.unsigned(-1), '18446744073709551615');
      expect(DouyinProtoMessage.unsigned(7687741736843512), '7687741736843512');
    });

    test('a repeated message has one entry per occurrence, a singular one merges', () {
      final inner = (DouyinProtoWriter()..integer(1, 5)).toBytes();
      final bytes =
          (DouyinProtoWriter()
                ..bytes(1, inner)
                ..bytes(1, inner))
              .toBytes();
      final message = DouyinProtoMessage.decode(bytes);
      expect(message.messages(1), hasLength(2));
      expect(message.message(1)?.integer(1), 5);
    });

    test('a bool is true when the low 32 bits of its varint are not zero', () {
      final bytes = (DouyinProtoWriter()..integer(9, 4294967296)).toBytes();
      expect(DouyinProtoMessage.decode(bytes).flag(9), isFalse);
    });

    test('malformed input is a FormatException', () {
      expect(() => DouyinProtoMessage.decode(const [0x80]), throwsFormatException);
      expect(() => DouyinProtoMessage.decode(const [0x00]), throwsFormatException);
      expect(() => DouyinProtoMessage.decode(const [0x0E, 0x05]), throwsFormatException);
    });
  });

  group('danmaku protocol', () {
    test('a PushFrame decodes to chat and audience messages', () {
      final frame = DouyinDanmakuProtocol.responseBytes([
        DouyinDanmakuProtocol.envelopeBytes(
          'WebcastChatMessage',
          chatPayload(roomId: 1, createTime: 1790506922),
          msgId: 77,
        ),
        DouyinDanmakuProtocol.envelopeBytes('WebcastRoomUserSeqMessage', seqPayload(total: 305)),
        DouyinDanmakuProtocol.envelopeBytes('WebcastMemberMessage', Uint8List(0)),
      ]);
      final decoded = DouyinDanmakuProtocol.decode(frame, roomId: '1');
      expect(decoded.errors, isEmpty);
      expect(decoded.envelopes, 3);
      expect(decoded.ack, isNull);
      final chat = decoded.messages.singleWhere((message) => message.type == LiveMessageType.chat);
      expect(chat.text, '你好');
      expect(chat.effectiveSender.userName, 'viewer');
      expect(chat.effectiveSender.userId, '42');
      expect(chat.messageId, 'douyin:123');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      final audience = decoded.messages.singleWhere((message) => message.type == LiveMessageType.audienceUpdate);
      expect((audience.payload! as LiveAudienceUpdate).value, 305);
      expect((audience.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.onlineViewers);
    });

    test('a gunzipped payload and the fallback times and texts read alike', () {
      final frame = DouyinDanmakuProtocol.responseBytes([
        DouyinDanmakuProtocol.envelopeBytes(
          'WebcastChatMessage',
          chatPayload(content: 'event', msgId: 0, eventTime: 1790506922),
          msgId: 51,
        ),
        DouyinDanmakuProtocol.envelopeBytes('WebcastRoomUserSeqMessage', seqPayload(onlineForAnchor: '30.6万')),
      ], gzipPayload: true);
      final decoded = DouyinDanmakuProtocol.decode(frame, roomId: '');
      final chat = decoded.messages.first;
      expect(chat.messageId, 'douyin:51');
      expect(chat.sentAt, DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      expect((decoded.messages.last.payload! as LiveAudienceUpdate).value, 306000);
    });

    test("another broadcast's chat is dropped, a sequence message without a figure is not read", () {
      final frame = DouyinDanmakuProtocol.responseBytes([
        DouyinDanmakuProtocol.envelopeBytes('WebcastChatMessage', chatPayload(roomId: 2)),
        DouyinDanmakuProtocol.envelopeBytes('WebcastRoomUserSeqMessage', seqPayload(onlineForAnchor: '在线')),
      ]);
      final decoded = DouyinDanmakuProtocol.decode(frame, roomId: '1');
      expect(decoded.messages, isEmpty);
      expect(decoded.envelopes, 2);
    });

    test('needAck asks for the acknowledgement of the frame, with its internal ext', () {
      final frame = DouyinDanmakuProtocol.responseBytes(const [], needAck: true, internalExt: 'ext', logId: 4242);
      final decoded = DouyinDanmakuProtocol.decode(frame, roomId: '1');
      expect(decoded.ack, isNotNull);
      final push = DouyinProtoMessage.decode(decoded.ack!);
      expect(push.integer(2), 4242);
      expect(push.string(7), 'ack');
      expect(push.string(8), 'ext');
    });

    test('an unreadable frame yields neither messages nor an ack', () {
      final decoded = DouyinDanmakuProtocol.decode([0xFF, 0xFF], roomId: '1');
      expect(decoded.errors, hasLength(1));
      expect(decoded.messages, isEmpty);
      expect(decoded.ack, isNull);
    });

    test('the heartbeat join and the endpoints carry the room, the visitor and the signature', () {
      expect(DouyinProtoMessage.decode(DouyinDanmakuProtocol.heartbeat()).string(7), 'hb');
      final endpoints = DouyinDanmakuProtocol.endpoints(
        roomId: _roomId,
        userId: '7312345678901234567',
        signature: 'abc+def/',
        now: DateTime.fromMillisecondsSinceEpoch(1790506922000),
      );
      expect(endpoints.map((uri) => uri.host), DouyinDanmakuProtocol.hosts);
      final query = endpoints.first.queryParameters;
      expect(query['room_id'], _roomId);
      expect(query['user_unique_id'], '7312345678901234567');
      expect(query['signature'], 'abc+def/');
      expect(endpoints.first.query, contains('signature=abc%2Bdef%2F'));
      expect(query['cursor'], 'h-1_t-1790506922000_r-1_d-1_u-1');
      expect(query['compress'], 'gzip');
      expect(query['heartbeatDuration'], '0');
      expect(DouyinDanmakuProtocol.handshakeHeaders('ttwid=x', _webRid).keys, [
        'user-agent',
        'cookie',
        'origin',
        'referer',
      ]);
    });
  });

  group('room parsing', () {
    test('enter gives the room by web_rid with the broadcast id and streams', () {
      final parsed = DouyinRoomParser.enter(enterBody(streamFixture()), webRid: _webRid);
      expect(parsed.room.roomId, _webRid);
      expect(parsed.roomId, _roomId);
      expect(parsed.room.content.title, '正在直播');
      expect(parsed.room.anchor?.name, '主播');
      expect(parsed.room.anchor?.avatarUrl, 'https://p3.douyinpic.com/avatar.jpg');
      expect(parsed.room.content.coverUrl, 'https://p3.douyinpic.com/cover.jpg');
      expect(parsed.room.area?.areaName, '英雄联盟手游');
      expect(parsed.room.audience.onlineViewers, 713);
      // display_type 1 shows the online count: the room has no cumulative one.
      expect(parsed.room.audience.totalViewers, isNull);
      expect(parsed.room.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(parsed.room.broadcast.effectiveRestriction, LiveRestriction.none);
      expect(parsed.room.links.webUrl, 'https://live.douyin.com/$_webRid');
      expect(parsed.streamUrl, isNotNull);
      expect(parsed.sessionEnded, isFalse);
    });

    test('an offline room has no streams, no audience and no start time', () {
      final body = jsonEncode({
        'status_code': 0,
        'data': {
          'room_status': 2,
          'user': {
            'nickname': '备用名',
            'avatar_thumb': {
              'url_list': ['https://p3/a.jpg'],
            },
          },
          'data': [
            {'id_str': _roomId, 'title': '未开播', 'status': 4},
          ],
        },
      });
      final parsed = DouyinRoomParser.enter(body, webRid: _webRid);
      expect(parsed.room.broadcast.effectiveLiveStatus, LiveStatus.offline);
      expect(parsed.room.anchor?.name, '备用名');
      expect(parsed.room.audience.onlineViewers, isNull);
      expect(parsed.streamUrl, isNull);
    });

    test('a live room without any video for this client is unplayable', () {
      final parsed = DouyinRoomParser.enter(enterBody(const <String, dynamic>{}), webRid: _webRid);
      expect(parsed.room.broadcast.effectiveRestriction, LiveRestriction.unplayable);
    });

    test('reflow carries the start time and says when the broadcast ended', () {
      final body = jsonEncode({
        'status_code': 0,
        'data': {
          'room': {
            'id_str': _roomId,
            'status': 4,
            'title': '已结束',
            'start_time': 1790500000,
            'owner': {'web_rid': _webRid, 'nickname': '主播'},
          },
        },
      });
      final parsed = DouyinRoomParser.reflow(body);
      expect(parsed.sessionEnded, isTrue);
      expect(parsed.room.roomId, _webRid);
      expect(parsed.room.broadcast.startedAt, isNull);
      expect(DouyinRoomParser.reflowWebRid(body), _webRid);
      // A broadcast still on air carries its start (the only answer that does).
      final live = DouyinRoomParser.reflow(
        jsonEncode({
          'status_code': 0,
          'data': {
            'room': {
              'id_str': _roomId,
              'status': 2,
              'title': '正在直播',
              'start_time': 1790500000,
              'create_time': 1790499000,
              'owner': {'web_rid': _webRid},
            },
          },
        }),
      );
      expect(live.sessionEnded, isFalse);
      expect(live.room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1790500000000, isUtc: true));
    });

    test('status codes decide the failure: 4001038, 2483, an empty 200, a captcha', () {
      expect(
        () => DouyinRoomParser.enter(jsonEncode({'status_code': 4001038}), webRid: _webRid),
        throwsA(isA<DouyinFailure>().having((failure) => failure.kind, 'kind', DouyinFailureKind.notFound)),
      );
      expect(
        () => DouyinRoomParser.searchRooms(jsonEncode({'status_code': 2483, 'data': <Object>[]})),
        throwsA(isA<DouyinFailure>().having((failure) => failure.kind, 'kind', DouyinFailureKind.needsLogin)),
      );
      expect(
        () => DouyinRoomParser.enter('', webRid: _webRid),
        throwsA(isA<DouyinFailure>().having((failure) => failure.kind, 'kind', DouyinFailureKind.riskControl)),
      );
      expect(
        () => DouyinRoomParser.enter('{"status_code":0}', webRid: _webRid, headers: const {'bdturing-verify': '1'}),
        throwsA(isA<DouyinFailure>().having((failure) => failure.kind, 'kind', DouyinFailureKind.riskControl)),
      );
      expect(
        () => DouyinRoomParser.feed('{}', status: 429),
        throwsA(isA<DouyinFailure>().having((failure) => failure.kind, 'kind', DouyinFailureKind.rateLimited)),
      );
      expect(
        () => DouyinRoomParser.feed('<html>challenge</html>'),
        throwsA(isA<DouyinFailure>().having((failure) => failure.kind, 'kind', DouyinFailureKind.riskControl)),
      );
    });

    test('a failure maps onto the contract error', () {
      expect(
        const DouyinFailure(DouyinFailureKind.apiChanged, 'shape').toLiveSiteError('douyin'),
        isA<LiveSiteParseError>(),
      );
      expect(
        const DouyinFailure(DouyinFailureKind.notFound, 'gone').toLiveSiteError('douyin'),
        isA<LiveSiteNotFound>(),
      );
      expect(
        const DouyinFailure(DouyinFailureKind.streamUnavailable, 'no stream').toLiveSiteError('douyin'),
        isA<LiveSiteContentUnavailable>(),
      );
    });

    test('the anonymous cookie keeps ttwid and UIFID_TEMP only', () {
      expect(
        DouyinRoomParser.anonymousCookie({
          'set-cookie':
              'ttwid=abc123; Max-Age=5184000; Path=/; __ac_nonce=deadbeef; UIFID_TEMP=xyz; Domain=.douyin.com',
        }),
        'ttwid=abc123; UIFID_TEMP=xyz',
      );
      expect(DouyinRoomParser.anonymousCookie({'set-cookie': '__ac_nonce=deadbeef'}), isNull);
    });

    test('the feed reads both generations and drops duplicates', () {
      final body = jsonEncode({
        'status_code': 0,
        'data': [
          {
            'web_rid': '111',
            'data': jsonEncode({
              'title': '字符串信封',
              'owner': {'nickname': '甲', 'id_str': '1'},
              'category': '7',
              'stats': {'user_count': 12},
            }),
          },
          {
            'room': {
              'id_str': '222',
              'title': '对象信封',
              'owner': {'nickname': '乙', 'web_rid': '222'},
              'partition_road_map': [
                {'title': '热门'},
              ],
            },
          },
          {
            'web_rid': '111',
            'data': {'title': '重复'},
          },
        ],
      });
      final rooms = DouyinRoomParser.feed(body);
      expect(rooms.map((room) => room.roomId), ['111', '222']);
      expect(rooms.first.content.title, '字符串信封');
      expect(rooms.first.area?.areaId, '7');
      expect(rooms.first.area?.areaName, DouyinRoomParser.recommendArea);
      expect(rooms.last.area?.areaName, '热门');
      expect(rooms.last.audience.onlineViewers, isNull);
      expect(rooms.first.broadcast.effectiveLiveStatus, LiveStatus.live);
    });

    test('partition rooms page by offset and keep their area name', () {
      final body = jsonEncode({
        'status_code': 0,
        'data': {
          'count': 15,
          'offset': 15,
          'data': [
            {
              'web_rid': '333',
              'tag_name': '和平精英',
              'room': {
                'id_str': '999',
                'title': '刺激',
                'owner': {'nickname': '丙', 'web_rid': '333'},
              },
            },
          ],
        },
      });
      final result = DouyinRoomParser.partitionRooms(body, offset: 0);
      expect(result.hasMore, isTrue);
      expect(result.rooms.single.roomId, '333');
      expect(result.rooms.single.area?.areaName, '和平精英');
      expect(DouyinRoomParser.partition('1010014,1'), (partition: '1010014', type: '1'));
      expect(() => DouyinRoomParser.partition('1010014'), throwsA(isA<DouyinFailure>()));
    });

    test('search cards reach through JSON-string nesting', () {
      final card = jsonEncode({
        'id_str': _roomId,
        'status': 2,
        'title': '搜索结果',
        'owner': {
          'web_rid': _webRid,
          'nickname': '主播',
          'avatar_large': {
            'url_list': ['https://p3/large.jpg'],
          },
        },
      });
      final body = jsonEncode({
        'status_code': 0,
        'data': [
          {
            'aweme_info': {
              'live_info': {'rawdata': card},
            },
          },
          {
            'aweme_info': {
              'live_info': {'rawdata': card},
            },
          },
        ],
      });
      final items = DouyinRoomParser.searchRooms(body);
      expect(items, hasLength(1));
      expect(items.first.room.roomId, _webRid);
      expect(items.first.roomId, _roomId);
      expect(items.first.room.content.coverUrl, 'https://p3/large.jpg');
      expect(items.first.room.broadcast.effectiveLiveStatus, LiveStatus.live);
    });

    test('a room page reads its React Server Component state', () {
      final state = {
        'roomStore': {
          'roomInfo': {
            'room': {
              'id_str': _roomId,
              'status': 2,
              'title': '页面里的房间',
              'user_count': 88,
              'owner': {'nickname': '主播', 'web_rid': _webRid},
            },
            'anchor': {'nickname': '主播'},
          },
        },
        'userStore': {
          'odin': {'user_unique_id': '7312345678901234567'},
        },
      };
      final html = '<html><script>self.__pace_f.push([1,${jsonEncode('3:${jsonEncode(state)}\n')}]);</script></html>';
      final parsed = DouyinRoomParser.roomPage(html, webRid: _webRid);
      expect(parsed.room.content.title, '页面里的房间');
      expect(parsed.room.audience.onlineViewers, 88);
      expect(parsed.userUniqueId, '7312345678901234567');
      expect(DouyinRoomParser.roomIdInPage(html), _webRid);
      expect(
        () => DouyinRoomParser.roomPage('<html></html>', webRid: _webRid),
        throwsA(isA<DouyinFailure>().having((failure) => failure.kind, 'kind', DouyinFailureKind.apiChanged)),
      );
    });

    test('the home page categories nest games under their sub-partition', () {
      final data = {
        'categoryData': [
          {
            'partition': {'id_str': '1', 'type': '1', 'title': '游戏'},
            'sub_partition': [
              {
                'partition': {'id_str': '11', 'type': '1', 'title': '竞技游戏'},
                'sub_partition': [
                  {
                    'partition': {'id_str': '1010014', 'type': '1', 'title': '英雄联盟'},
                  },
                  {
                    'partition': {'id_str': '1010014', 'type': '1', 'title': '重复'},
                  },
                ],
              },
            ],
          },
        ],
      };
      final html = '<html><script>self.__pace_f.push([1,${jsonEncode('0:${jsonEncode(data)}\n')}]);</script></html>';
      final areas = DouyinRoomParser.areas(html);
      expect(areas.map((area) => area.areaId), ['1,1', '11,1', '1010014,1']);
      expect(areas[2].parentAreaId, '11,1');
      expect(areas[2].areaName, '英雄联盟');
    });
  });

  group('play parsing', () {
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(1790500000000, isUtc: true);

    test('qualities rank by tier, drop audio-only and fold identical keys', () {
      final qualities = DouyinPlayParser.qualities(streamFixture());
      expect(qualities.map((quality) => quality.qualityId), ['origion', 'hd1']);
      expect(qualities.first.label, '原画');
      expect(qualities.first.codec, LiveStreamCodec.avc);
      expect(qualities.last.codec, LiveStreamCodec.hevc);
      expect(qualities.first.platformOrder, 2);
      expect(qualities.last.platformOrder, 1);
    });

    test('lines are FLV then HLS with headers, geometry and a lease', () {
      final lines = DouyinPlayParser.lines(streamFixture(), webRid: _webRid, issuedAt: issuedAt, cookie: 'ttwid=x');
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.first.lineLabel, 'flv');
      expect(lines.last.lineLabel, 'hls');
      expect(lines.first.codec, LiveStreamCodec.avc);
      expect(lines.first.formatSource, LivePlayFormatSource.declared);
      expect(lines.first.geometry.width, 1280);
      expect(lines.first.geometry.height, 720);
      expect(lines.first.headers['referer'], 'https://live.douyin.com/$_webRid');
      expect(lines.first.headers['cookie'], 'ttwid=x');
      // expire is 1790506922 s: a little under two hours after issue.
      expect(lines.first.lease?.expiresAt, DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      expect(lines.first.lease?.expiresAt, DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      final lease = lines.first.lease!;
      expect(lease.expiresAt!.difference(lease.refreshAt), DouyinPlayParser.leaseLead);
    });

    test('an alias id plays the quality its URLs were folded into', () {
      final lines = DouyinPlayParser.lines(
        streamFixture(),
        webRid: _webRid,
        issuedAt: issuedAt,
        qualityId: 'ORIGION_01',
      );
      expect(lines.first.format, LiveStreamFormat.flv);
      expect(DouyinPlayParser.qualityFor(streamFixture(), 'origion_01')?.qualityId, 'origion');
      expect(DouyinPlayParser.lines(null, webRid: _webRid, issuedAt: issuedAt), isEmpty);
    });

    test('a legacy flv_pull_url-only room still yields a line', () {
      final streamUrl = {
        'flv_pull_url': {'SD1': 'https://v.douyincdn.com/legacy.flv'},
        'default_resolution': 'SD1',
      };
      final qualities = DouyinPlayParser.qualities(streamUrl);
      expect(qualities.single.qualityId, 'sd1');
      expect(qualities.single.label, 'SD1');
      expect(DouyinPlayParser.lines(streamUrl, webRid: '', issuedAt: issuedAt).single.url, endsWith('.flv'));
    });

    test('the lease reads expire, volcTime, wsTime + keeptime and t with k', () {
      DateTime? expiry(String query) =>
          DouyinPlayParser.lease(Uri.parse('https://v.douyincdn.com/a.flv?$query'), issuedAt)?.expiresAt;
      expect(expiry('expire=1790506922'), DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      expect(expiry('expire=6ab8f7aa'), DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      expect(expiry('volcTime=1790506922'), DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      expect(expiry('wsTime=6ab8db8a&keeptime=1c20'), DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      expect(expiry('t=1790506922&k=abc'), DateTime.fromMillisecondsSinceEpoch(1790506922000, isUtc: true));
      expect(expiry('t=1790506922'), isNull);
      // Outside a day before to 31 days after issue is not an expiry.
      expect(expiry('expire=1000000000'), isNull);
      expect(expiry('nothing=1'), isNull);
    });

    test('a lifetime shorter than the lead renews at a quarter of it', () {
      final lease = DouyinPlayParser.lease(
        Uri.parse(
          'https://v.douyincdn.com/a.flv?expire=${issuedAt.add(const Duration(minutes: 8)).millisecondsSinceEpoch ~/ 1000}',
        ),
        issuedAt,
      )!;
      expect(lease.expiresAt!.difference(lease.refreshAt), const Duration(minutes: 2));
    });
  });

  group('adapter wiring', () {
    DouyinSite site(Map<String, dynamic Function()> bodies, {String? login}) {
      final http = _FakeHttp((request) {
        final path = request.url.path;
        final body = bodies[path];
        if (body == null) return LiveResponse(statusCode: 404, headers: const {}, bodyBytes: utf8.encode('{}'));
        return LiveResponse(
          statusCode: 200,
          headers: const {'set-cookie': 'ttwid=visitor; UIFID_TEMP=1'},
          bodyBytes: utf8.encode(jsonEncode(body())),
        );
      });
      return DouyinSite(http: DouyinHttp(http), loginCookie: login == null ? null : () => login, random: Random(1));
    }

    test('the manifest and the capability switch', () async {
      final douyin = site(const {});
      expect(douyin.manifest.id, 'douyin');
      expect(douyin.runtimeInfo.status, LiveSiteStatus.ready);
      expect(douyin.capability<LiveRoomProvider>(), same(douyin.capability<LiveRoomProvider>()));
      expect(douyin.capability<LivePlaybackProvider>(), isNotNull);
      expect(douyin.capability<LiveAnchorProvider>(), isNull);
      expect(douyin.capability<LiveHotProvider>(), isNull);
      await douyin.initialize(
        const LiveSiteContext(platform: LiveTargetPlatform.windows, locale: 'zh-CN', defaultLocale: 'en-US'),
      );
      final built = createBuiltInLiveSites(
        http: _FakeHttp((_) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: Uint8List(0))),
      );
      expect(built.map((entry) => entry.manifest.id), ['douyu', 'huya', 'douyin', 'bilibili', 'kuaishou']);
    });

    test('a guest bootstrap runs once and the detail carries the handles', () async {
      final douyin = site({
        DouyinEndpoints.enterPath: () => jsonDecode(enterBody(streamFixture())),
        '/': () => '<html></html>',
      });
      final room = unwrapRight(await douyin.capability<LiveRoomProvider>()!.getRoom(_webRid));
      expect(room.ref.platform, 'douyin');
      expect(room.runtime.streamHandle, isA<DouyinRoomData>());
      final handle = room.runtime.streamHandle! as DouyinRoomData;
      expect(handle.webRid, _webRid);
      expect(handle.roomId, _roomId);
      final danmaku = room.runtime.danmakuHandle! as DouyinDanmakuArgs;
      expect(danmaku.roomId, _roomId);
      expect(danmaku.userId, matches(RegExp(r'^7[3-9]\d{17}$')));
      expect(danmaku.cookie, contains('ttwid=visitor'));
      final paths = (douyin.http.http as _FakeHttp).requests.map((request) => request.url.path).toList();
      expect(paths.where((path) => path == '/'), hasLength(1));
    });

    test('qualities and lines come from the fresh detail', () async {
      final douyin = site({
        DouyinEndpoints.enterPath: () => jsonDecode(enterBody(streamFixture())),
        '/': () => '<html></html>',
      });
      final qualities = unwrapRight(await douyin.capability<LivePlaybackProvider>()!.getQualities(roomId: _webRid));
      expect(qualities, hasLength(2));
      final lines = unwrapRight(
        await douyin.capability<LivePlaybackProvider>()!.getLines(roomId: _webRid, quality: qualities.first),
      );
      expect(lines, hasLength(2));
      expect(lines.first.headers['user-agent'], DouyinEndpoints.userAgent);
    });

    test('an offline room is content-unavailable for playback, not an empty list', () async {
      final douyin = site({
        DouyinEndpoints.enterPath: () => {
          'status_code': 0,
          'data': {
            'room_status': 2,
            'data': [
              {'id_str': _roomId, 'status': 4, 'title': '未开播'},
            ],
          },
        },
        '/': () => '<html></html>',
      });
      final error = unwrapLeft(await douyin.capability<LivePlaybackProvider>()!.getQualities(roomId: _webRid));
      expect(error, isA<LiveSiteContentUnavailable>());
    });

    test('a search target the site does not search is unsupported', () async {
      final douyin = site(const {});
      final provider = douyin.capability<LiveSearchProvider>()!;
      expect(
        unwrapLeft(await provider.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.anchors))),
        isA<LiveSiteUnsupported>(),
      );
      final blank = unwrapRight(
        await provider.search(const LiveSearchRequest(query: '  ', target: LiveSearchTarget.rooms)),
      );
      expect(blank.items, isEmpty);
    });

    test('a link is canonicalized, an alien host is unsupported', () async {
      final resolver = site(const {}).capability<LiveLinkResolver>()!;
      expect(
        unwrapRight(await resolver.resolve(Uri.https('live.douyin.com', '/$_webRid'))),
        Uri.https('live.douyin.com', '/$_webRid'),
      );
      expect(
        unwrapRight(await resolver.resolve(Uri.https('www.douyin.com', '/$_webRid'))),
        Uri.https('live.douyin.com', '/$_webRid'),
      );
      final shared = await resolver.resolve(Uri.parse('https://live.douyin.com/$_webRid?enter_from=link_share'));
      expect(unwrapRight(shared).path, '/$_webRid');
      expect(unwrapLeft(await resolver.resolve(Uri.https('v.douyin.com', 'x1y2z3'))), isA<LiveSiteNotFound>());
      expect(unwrapLeft(await resolver.resolve(Uri.https('www.huya.com', '/660000'))), isA<LiveSiteUnsupported>());
    });

    test('a reflow link resolves through the share app id', () async {
      final douyin = site({
        DouyinEndpoints.reflowPath: () => {
          'status_code': 0,
          'data': {
            'room': {
              'id_str': _roomId,
              'status': 2,
              'owner': {'web_rid': _webRid},
            },
          },
        },
      });
      final resolved = await douyin.capability<LiveLinkResolver>()!.resolve(
        Uri.https('webcast.amemv.com', '/webcast/reflow/$_roomId'),
      );
      expect(unwrapRight(resolved), Uri.https('live.douyin.com', '/$_webRid'));
      final request = (douyin.http.http as _FakeHttp).requests.single;
      expect(request.url.queryParameters['app_id'], DouyinEndpoints.shareAppId);
      expect(request.url.queryParameters.containsKey('verifyFp'), isTrue);
    });
  });
}

/// The right value of an Either, failing the test when it is a left.
T unwrapRight<T>(Either<LiveSiteError, T> either) =>
    either.match<T>((error) => throw StateError('$error'), (value) => value);

/// The left error of an Either, failing the test when it is a right.
LiveSiteError unwrapLeft<T>(Either<LiveSiteError, T> either) =>
    either.match<LiveSiteError>((error) => error, (value) => throw StateError('right: $value'));

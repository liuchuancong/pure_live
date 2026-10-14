import 'dart:convert';
import 'dart:io' show ZLibEncoder;
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_protobuf.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_wbi.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_area_provider.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_room_provider.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_play_parser.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';
import 'package:test/test.dart';

// The test doubles spell their class name in their one constructor; the
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The nav answer the WBI golden vector is signed with.
const _imgKey = '7cd084941338484aae1ad9425b84077c';
const _subKey = '4932caff0ff746eab6f01bf08b70ac45';

/// The room detail every site test answers with.
const Map<String, Object?> _detailBody = {
  'code': 0,
  'data': {
    'room_info': {'room_id': 10501, 'title': 'A', 'live_status': 1, 'online': 12},
    'anchor_info': {
      'base_info': {'uname': 'host'},
    },
  },
};

/// The danmaku credentials every site test answers with.
const Map<String, Object?> _danmuBody = {
  'code': 0,
  'data': {'token': 'T', 'host_list': <Object?>[]},
};

/// The nav answer with the golden keys.
const Map<String, Object?> _navBody = {
  'code': -101,
  'data': {
    'wbi_img': {
      'img_url': 'https://i0.hdslb.com/bfs/wli/7cd084941338484aae1ad9425b84077c.png',
      'sub_url': 'https://i0.hdslb.com/bfs/wli/4932caff0ff746eab6f01bf08b70ac45.png',
    },
  },
};

/// The guest buvid pair.
const Map<String, Object?> _spiBody = {
  'code': 0,
  'data': {'b_3': 'B3', 'b_4': 'B4'},
};

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

LiveResponse _json(Object? body, {int status = 200}) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(jsonEncode(body)));

/// A site whose endpoints answer from [routes] (matched by path suffix).
BilibiliSite _site(Map<String, Object?> routes, {String cookie = '', DateTime? now}) {
  final http = _FakeHttp((request) {
    if (request.url.path.endsWith('/lol')) {
      return LiveResponse(
        statusCode: 200,
        headers: const {},
        bodyBytes: utf8.encode('<html>"access_id":"WEB1D"</html>'),
      );
    }
    for (final entry in routes.entries) {
      if (request.url.path.endsWith(entry.key)) return _json(entry.value);
    }
    return _json({'code': -404}, status: 404);
  });
  return BilibiliSite(
    http: BilibiliHttp(http),
    loginCookie: () => cookie,
    now: now == null ? DateTime.now : () => now,
    sleep: (_) async {},
  );
}

/// The fake transport of the site under test.
_FakeHttp _transportOf(BilibiliSite site) => site.http.http as _FakeHttp;

/// One protocol buffer message written by tag, for the `SEND_GIFT_V2` fixture
/// (the codec under test only reads protobuf).
final class _Pb {
  final BytesBuilder out = BytesBuilder(copy: false);

  void _varint(int value) {
    var rest = value;
    while (true) {
      final byte = rest & 0x7F;
      rest >>>= 7;
      if (rest == 0) {
        out.addByte(byte);
        return;
      }
      out.addByte(byte | 0x80);
    }
  }

  void integer(int number, int value) {
    _varint(number << 3);
    _varint(value);
  }

  void string(int number, String value) {
    final bytes = utf8.encode(value);
    _varint(number << 3 | 2);
    _varint(bytes.length);
    out.add(bytes);
  }

  void message(int number, _Pb inner) {
    _varint(number << 3 | 2);
    _varint(inner.out.length);
    out.add(inner.toBytes());
  }

  Uint8List toBytes() => out.toBytes();
}

/// One packet of the wire format: the 16-byte big-endian header plus [body].
Uint8List packet(int operation, List<int> body, {int version = 0}) {
  final buffer = Uint8List(16 + body.length);
  ByteData.sublistView(buffer)
    ..setUint32(0, buffer.length)
    ..setUint16(4, 16)
    ..setUint16(6, version)
    ..setUint32(8, operation)
    ..setUint32(12, 1);
  buffer.setRange(16, buffer.length, body);
  return buffer;
}

/// An op-5 notice packet (version 0 JSON, version 2 a compressed stream).
Uint8List notice(Object? body, {int version = 0}) => packet(
  BilibiliDanmakuProtocol.opNotice,
  version == 0 ? utf8.encode(jsonEncode(body)) : body! as List<int>,
  version: version,
);

/// [notices] as the packets of one WebSocket message.
List<int> message(List<Uint8List> notices) => [for (final part in notices) ...part];

/// The right value of an Either, failing the test when it is a left.
T unwrapRight<T>(Either<LiveSiteError, T> either) =>
    either.match((error) => throw StateError('left: ${error.message}'), (value) => value);

/// The left error of an Either, failing the test when it is a right.
LiveSiteError unwrapLeft<T>(Either<LiveSiteError, T> either) =>
    either.match<LiveSiteError>((error) => error, (_) => throw StateError('not a left'));

/// A `getRoomPlayInfo` body: an HLS and an FLV stream (avc and hevc, one of
/// the avc candidates on an `mcdn` edge) and an fmp4 tier at 400.
Map<String, Object?> playBody({required int qn, required int expires}) {
  final extra = '?expires=$expires';
  return {
    'code': 0,
    'data': {
      'room_id': 10501,
      'live_status': 1,
      'playurl_info': {
        'playurl': {
          'g_qn_desc': const [
            {'qn': 10000, 'desc': '源'},
            {'qn': 400, 'desc': '蓝光'},
            {'qn': 250, 'desc': '超清'},
          ],
          'stream': [
            {
              'protocol_name': 'http_hls',
              'format': [
                {
                  'format_name': 'ts',
                  'codec': [
                    {
                      'codec_name': 'avc',
                      'current_qn': qn,
                      'accept_qn': [250],
                      'base_url': '/live-bvc/hls.m3u8',
                      'url_info': [
                        {'host': 'https://d3.bilivideo.com', 'extra': extra},
                      ],
                    },
                  ],
                },
              ],
            },
            {
              'protocol_name': 'http_stream',
              'format': [
                {
                  'format_name': 'flv',
                  'codec': [
                    {
                      'codec_name': 'hevc',
                      'current_qn': qn,
                      'accept_qn': [250, 400],
                      'base_url': '/live-bvc/flv-hevc.flv',
                      'url_info': [
                        {'host': 'https://d2.bilivideo.com', 'extra': extra},
                      ],
                    },
                    {
                      'codec_name': 'avc',
                      'current_qn': qn,
                      'accept_qn': [250, 400, 10000],
                      'base_url': '/live-bvc/flv-avc.flv',
                      'url_info': [
                        {'host': 'https://d1.bilivideo.com', 'extra': extra},
                        {'host': 'https://mcdn.d1.bilivideo.com', 'extra': extra},
                      ],
                    },
                  ],
                },
                {
                  'format_name': 'fmp4',
                  'codec': [
                    {
                      'codec_name': 'avc',
                      'current_qn': 400,
                      'accept_qn': [400],
                      'base_url': '/live-bvc/f.mp4',
                      'url_info': [
                        {'host': 'https://d4.bilivideo.com', 'extra': extra},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    },
  };
}

void main() {
  group('WBI sign', () {
    test("the permutation table is the web client's 64 entries", () {
      expect(BilibiliWbi.mixinTable.length, 64);
      expect(BilibiliWbi.mixinTable.toSet().length, 64);
      expect(BilibiliWbi.mixinTable.every((index) => index >= 0 && index < 64), isTrue);
    });

    test('the golden vector signs to the reference w_rid', () {
      final signed = BilibiliWbi.sign(
        {'foo': '114', 'bar': '514', 'zab': '1919810'},
        imgKey: _imgKey,
        subKey: _subKey,
        wts: 1702204169,
      );
      expect(signed, 'bar=514&foo=114&wts=1702204169&zab=1919810&w_rid=8f6f2b5b3d485fe1886cec6a0be8c5d4');
    });

    test('the sorted query drops the unsafe characters and encodes the rest', () {
      expect(
        BilibiliWbi.query({'room_id': '42062', 'z': "a b!'()*"}, wts: 1700000000),
        'room_id=42062&wts=1700000000&z=a%20b',
      );
    });

    test('the keys are the wbi_img file names of a nav answer', () {
      expect(BilibiliWbi.tryNavKeys(jsonEncode(_navBody)), (imgKey: _imgKey, subKey: _subKey));
      expect(BilibiliWbi.tryNavKeys('{"code":0,"data":{}}'), isNull);
    });

    test('w_webid is the access id of the lol page', () {
      expect(BilibiliWbi.accessId(r'<html>"access_id":"abc\\123"</html>'), 'abc123');
      expect(() => BilibiliWbi.accessId('no id here'), throwsA(isA<BilibiliFailure>()));
    });
  });

  group('danmaku wire format', () {
    test('a packet header is big-endian length, header, version, op, sequence', () {
      final bytes = BilibiliDanmakuProtocol.packet(BilibiliDanmakuProtocol.opHeartbeat, '');
      expect(bytes.length, 16);
      expect(
        [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join(),
        '00000010001000000000000200000001',
      );
      expect(BilibiliDanmakuProtocol.heartbeat(), bytes);
    });

    test("the auth packet carries the credential in the web client's key order", () {
      final body = utf8.decode(
        BilibiliDanmakuProtocol.auth(uid: 7, roomId: 42062, buvid: 'X', token: 't', queueUuid: 'deadbeef').sublist(16),
      );
      expect(
        body,
        '{"uid":7,"roomid":42062,"protover":3,"buvid":"X","support_ack":true,'
        '"queue_uuid":"deadbeef","scene":"room","platform":"web","type":2,"key":"t"}',
      );
      expect(jsonDecode(body), {
        'uid': 7,
        'roomid': 42062,
        'protover': 3,
        'buvid': 'X',
        'support_ack': true,
        'queue_uuid': 'deadbeef',
        'scene': 'room',
        'platform': 'web',
        'type': 2,
        'key': 't',
      });
      // The key order is what the gateway expects; the auth asks for brotli.
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded.keys.toList(), [
        'uid',
        'roomid',
        'protover',
        'buvid',
        'support_ack',
        'queue_uuid',
        'scene',
        'platform',
        'type',
        'key',
      ]);
      expect(BilibiliDanmakuProtocol.protocolVersion, 3);
      expect(BilibiliDanmakuProtocol.queueUuid(Random(1)), matches(RegExp(r'^[0-9a-f]{8}$')));
    });

    test('a JSON notice round-trips into a chat message', () {
      final frame = BilibiliDanmakuProtocol.decode(
        notice({
          'cmd': 'DANMU_MSG',
          'info': [
            [0, 1, 15, 16777215, 1700000000, 99],
            '你好',
            [42, 'viewer', 0, 0, 0, 0],
            [12, '舰长'],
          ],
        }),
      );
      expect(frame.error, isNull);
      final message = frame.messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '你好');
      expect(message.sender?.userId, '42');
      expect(message.sender?.userName, 'viewer');
      expect(message.sender?.fanBadgeName, '舰长');
      expect(message.sender?.fanBadgeLevel, '12');
      expect(message.effectiveColor, LiveMessageColor.white);
      expect(message.messageId, 'bilibili:99');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true));
    });

    test('several packets in one message, a zlib stream and a heartbeat reply', () {
      final inner = message([
        notice({
          'cmd': 'ONLINE_RANK_COUNT',
          'data': {'online_count': 5},
        }),
        packet(BilibiliDanmakuProtocol.opHeartbeatReply, [0, 0, 0, 7]),
      ]);
      final compressed = Uint8List.fromList(ZLibEncoder().convert(inner));
      final frame = BilibiliDanmakuProtocol.decode(
        message([
          notice({
            'cmd': 'WATCHED_CHANGE',
            'data': {'num': 1234},
          }),
          notice(compressed, version: 2),
        ]),
      );
      expect(frame.error, isNull);
      expect(
        [for (final item in frame.messages) (item.type, item.payload)],
        [
          (
            LiveMessageType.audienceUpdate,
            const LiveAudienceUpdate(kind: LiveAudienceSignalKind.totalViewers, value: 1234),
          ),
          (
            LiveMessageType.audienceUpdate,
            const LiveAudienceUpdate(kind: LiveAudienceSignalKind.onlineViewers, value: 5),
          ),
          (LiveMessageType.audienceUpdate, const LiveAudienceUpdate(kind: LiveAudienceSignalKind.popularity, value: 7)),
        ],
      );
    });

    test('the auth reply code comes back, an empty body is code 0', () {
      expect(
        BilibiliDanmakuProtocol.decode(packet(BilibiliDanmakuProtocol.opAuthReply, utf8.encode('{"code":0}'))).authCode,
        0,
      );
      expect(BilibiliDanmakuProtocol.decode(packet(BilibiliDanmakuProtocol.opAuthReply, const [])).authCode, 0);
      expect(
        BilibiliDanmakuProtocol.decode(packet(BilibiliDanmakuProtocol.opAuthReply, utf8.encode('{"code":-101}')))
            .authCode,
        -101,
      );
    });

    test('a notice asking for an acknowledgement sends op 24 back', () {
      final frame = BilibiliDanmakuProtocol.decode(
        notice({
          'cmd': 'SOMETHING_ELSE',
          'p_is_ack': true,
          'msg_id': 'm1',
          'p_msg_type': 1,
          'data': const <String, Object?>{},
        }),
      );
      expect(frame.sends, hasLength(1));
      expect(ByteData.sublistView(frame.sends.single).getUint32(8), BilibiliDanmakuProtocol.opAck);
      expect(utf8.decode(frame.sends.single.sublist(16)), '{"msg_id":"m1","cmd":"SOMETHING_ELSE","p_msg_type":1}');
    });

    test('SEND_GIFT reads the json gift, gold as value', () {
      final frame = BilibiliDanmakuProtocol.decode(
        notice({
          'cmd': 'SEND_GIFT',
          'data': {
            'giftName': '小心心',
            'giftId': 23,
            'num': 2,
            'price': 100,
            'total_coin': 200,
            'coin_type': 'gold',
            'uid': 42,
            'uname': 'viewer',
            'tid': 't1',
            'timestamp': 1700000000,
            'receive_user_info': {'uname': 'host'},
            'gift_info': {'img_basic': '//i0.hdslb.com/bfs/gift/a.png'},
          },
        }),
      );
      final message = frame.messages.single;
      final gift = message.payload! as LiveGift;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '小心心 ×2');
      expect(gift.giftId, '23');
      expect(gift.count, 2);
      expect(gift.value.unit, LiveGiftUnit.gold);
      expect(gift.value.unitPrice, 100);
      expect(gift.value.totalValue, 200);
      expect(gift.iconUrl, startsWith('https://'));
      expect(gift.recipientName, 'host');
      expect(message.messageId, 'bilibili:gift:t1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true));
    });

    test('COMBO_SEND counts the combo so far and the gift table fills a price', () {
      final frame = BilibiliDanmakuProtocol.decode(
        notice({
          'cmd': 'COMBO_SEND',
          'data': {
            'gift_name': '小心心',
            'gift_id': 23,
            'total_num': 4,
            'combo_total_coin': 400,
            'batch_combo_id': 'bc1',
            'uname': 'viewer',
            'uid': 42,
          },
        }),
        gifts: const BilibiliGiftCatalog(
          gifts: {'23': BilibiliGiftInfo(id: '23', name: '小心心', price: 100)},
        ),
      );
      final gift = frame.messages.single.payload! as LiveGift;
      expect(gift.count, 4);
      expect(gift.combo.comboKey, 'bc1');
      expect(gift.combo.comboTotal, 4);
      expect(gift.value.totalValue, 400);
      expect(gift.value.unitPrice, 100);
    });

    test('SEND_GIFT_V2 reads the protobuf gift a guest gets', () {
      final inner = _Pb()
        ..integer(1, 23)
        ..string(2, '辣条')
        ..integer(3, 3)
        ..integer(5, 100)
        ..integer(7, 300)
        ..string(8, 'silver')
        ..string(9, 'tid-9')
        ..string(12, 'combo-1')
        ..message(29, _Pb()..string(1, 'host'))
        ..message(35, _Pb()..string(1, 'https://i0.hdslb.com/bfs/gift/b.png'));
      final root = _Pb()
        ..integer(1, 42)
        ..string(2, 'guest')
        ..message(10, inner);
      final frame = BilibiliDanmakuProtocol.decode(
        notice({
          'cmd': 'SEND_GIFT_V2',
          'data': {'pb': base64.encode(root.toBytes())},
        }),
      );
      final message = frame.messages.single;
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, '23');
      expect(gift.name, '辣条');
      expect(gift.count, 3);
      expect(gift.value.unit, LiveGiftUnit.silver);
      expect(gift.value.totalValue, 300);
      expect(gift.combo.comboKey, 'combo-1');
      expect(gift.recipientName, 'host');
      expect(gift.iconUrl, 'https://i0.hdslb.com/bfs/gift/b.png');
      expect(message.sender?.userId, '42');
      expect(message.sender?.userName, 'guest');
      expect(message.sentAt, isNull);
    });

    test('guard, super chat, retraction and notices dispatch by cmd', () {
      final frame = BilibiliDanmakuProtocol.decode(
        message([
          notice({
            'cmd': 'GUARD_BUY',
            'data': {'username': 'p', 'uid': 1, 'guard_level': 3, 'num': 1, 'price': 198000, 'gift_name': '舰长'},
          }),
          notice({
            'cmd': 'SUPER_CHAT_MESSAGE',
            'data': {
              'id': '9',
              'start_time': 1700000000,
              'end_time': 1700003600,
              'message': 'hi',
              'price': 30,
              'user_info': {'uname': 'p', 'face': '//i0.hdslb.com/f.png'},
            },
          }),
          notice({
            'cmd': 'SUPER_CHAT_MESSAGE_DELETE',
            'data': {
              'ids': ['9', 10],
            },
          }),
          notice({
            'cmd': 'RECALL_DANMU_MSG',
            'data': {
              'recall_type': 2,
              'uinfo': {'uid': 5},
            },
          }),
          notice({'cmd': 'CUT_OFF', 'msg': '违规'}),
          notice({'cmd': 'NOT_A_COMMAND_WE_READ', 'data': const <String, Object?>{}}),
        ]),
      );
      expect(frame.messages.map((item) => item.type).toList(), [
        LiveMessageType.gift,
        LiveMessageType.superChat,
        LiveMessageType.retraction,
        LiveMessageType.retraction,
        LiveMessageType.retraction,
        LiveMessageType.notice,
      ]);
      final guard = frame.messages.first.payload! as LiveGift;
      expect(guard.kind, LiveGiftKind.subscription);
      expect(guard.value.totalValue, 198000);
      expect(frame.messages[1].messageId, '9');
      expect((frame.messages[1].payload! as LiveSuperChatMessage).price.amount, 30);
      expect((frame.messages[2].payload! as LiveRetraction).messageId, '9');
      expect((frame.messages[4].payload! as LiveRetraction).userId, '5');
      expect(frame.messages.last.text, '直播被切断：违规');
      expect(frame.messages.last.payload, LiveNoticeKind.system);
    });

    test('brotli protocol version is set to 3 (brotli support enabled)', () {
      // The auth packet should request protover 3 for brotli support
      expect(BilibiliDanmakuProtocol.protocolVersion, 3);
      
      // Verify the auth packet includes protover: 3
      final body = utf8.decode(
        BilibiliDanmakuProtocol.auth(uid: 7, roomId: 42062, buvid: 'X', token: 't', queueUuid: 'deadbeef').sublist(16),
      );
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded['protover'], 3);
    });

    test('a bad header is an error regardless of version', () {
      final broken = BilibiliDanmakuProtocol.decode(Uint8List.fromList([0, 0, 0, 8, 0, 16, 0, 0, 0, 5, 0, 0, 0, 1]));
      expect(broken.error, isA<FormatException>());
      final truncated = BilibiliDanmakuProtocol.decode(
        Uint8List.fromList([0, 0, 0, 64, 0, 16, 0, 0, 0, 5, 0, 0, 0, 1, 0, 0]),
      );
      expect(truncated.error, isA<FormatException>());
    });

    test('a masked guest name falls back to the first candidate', () {
      expect(BilibiliDanmakuProtocol.isMaskedName('观***'), isTrue);
      expect(BilibiliDanmakuProtocol.isMaskedName('viewer'), isFalse);
    });
  });

  group('parsers', () {
    test('the room detail keeps the asked id and names the canonical long id', () {
      final parsed = BilibiliRoomParser.roomDetail(
        jsonEncode({
          'code': 0,
          'data': {
            'room_info': {
              'room_id': 10501,
              'title': 'A &amp; B',
              'cover': '//i0.hdslb.com/cover.jpg',
              'area_name': '英雄联盟',
              'online': '1234',
              'live_status': 1,
              'live_start_time': 1700000000,
              'special_type': 1,
              'description': '<p>第一条<br>第二条</p>',
            },
            'anchor_info': {
              'base_info': {'uname': 'host', 'face': '//i0.hdslb.com/face.jpg', 'uid': 7},
            },
            'watched_show': {'switch': true, 'num': 99},
            'news_info': {'content': '公告&amp;测试'},
          },
        }),
        requestedId: '42062',
      );
      expect(parsed.longId, '10501');
      final room = parsed.room;
      expect(room.roomId, '42062');
      expect(room.platform, 'bilibili');
      expect(room.content.title, 'A & B');
      expect(room.content.introduction, '第一条\n第二条');
      expect(room.content.notice, '公告&测试');
      expect(room.anchor?.name, 'host');
      expect(room.anchor?.anchorId, '7');
      expect(room.anchor?.avatarUrl, 'https://i0.hdslb.com/face.jpg@100w.jpg');
      expect(room.area?.areaName, '英雄联盟');
      expect(room.audience.popularity, 1234);
      expect(room.audience.totalViewers, 99);
      expect(room.broadcast.effectiveLiveStatus, LiveStatus.live);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true));
      expect(room.broadcast.effectiveRestriction, LiveRestriction.paid);
      expect(room.links.webUrl, 'https://live.bilibili.com/42062');
    });

    test('live_status 1 live, 2 carousel, anything else offline, strings too', () {
      LiveStatus state(Object? value) => BilibiliRoomParser.roomDetail(
        jsonEncode({
          'code': 0,
          'data': {
            'room_info': {'room_id': 1, 'live_status': value},
            'anchor_info': {'base_info': <String, Object?>{}},
          },
        }),
        requestedId: '1',
      ).room.broadcast.effectiveLiveStatus;
      expect(state('1'), LiveStatus.live);
      expect(state(2), LiveStatus.carousel);
      expect(state(3), LiveStatus.offline);
      expect(state(null), LiveStatus.offline);
      expect(
        BilibiliRoomParser.liveStatus(
          jsonEncode({
            'code': 0,
            'data': {'live_status': 2},
          }),
        ),
        isFalse,
      );
      expect(
        BilibiliRoomParser.liveStatus(
          jsonEncode({
            'code': 0,
            'data': {'live_status': '1'},
          }),
        ),
        isTrue,
      );
    });

    test('the area board is flat with its category as parent', () {
      final areas = BilibiliRoomParser.areas(
        jsonEncode({
          'code': 0,
          'data': [
            {
              'id': 1,
              'name': '娱乐',
              'list': [
                {'id': 6, 'name': '星海', 'parent_id': 1, 'pic': '//i0.hdslb.com/a.png'},
              ],
            },
          ],
        }),
      );
      expect(areas.single.areaId, '1,6');
      expect(areas.single.parentAreaId, '1');
      expect(areas.single.parentAreaName, '娱乐');
      expect(areas.single.iconUrl, 'https://i0.hdslb.com/a.png@100w.png');
      expect(BilibiliRoomParser.splitAreaId('1,6'), (parentAreaId: '1', areaId: '6'));
      expect(BilibiliRoomParser.splitAreaId('6'), (parentAreaId: '', areaId: '6'));
    });

    test('a room list parses its cards and sorts by audience', () {
      final list = BilibiliRoomParser.roomList(
        jsonEncode({
          'code': 0,
          'data': {
            'list': [
              {'roomid': 2, 'title': 'b', 'uname': 'B', 'online': 10, 'area_v2_name': 'A'},
              {
                'roomid': 3,
                'title': 'c',
                'uname': 'C',
                'online': 90,
                'watched_show': {'switch': true, 'num': 5},
              },
            ],
            'has_more': 1,
          },
        }),
      );
      expect(list.hasMore, isTrue);
      expect([for (final room in list.rooms) room.roomId], ['3', '2']);
      expect(list.rooms.first.audience.totalViewers, 5);
      expect(list.rooms.first.links.webUrl, 'https://live.bilibili.com/3');
      expect(list.rooms.last.area?.areaName, 'A');
      expect(list.rooms.last.anchor?.name, 'B');
    });

    test('search reads rooms, strips highlights and folds streamers in on page 1', () {
      final body = jsonEncode({
        'code': 0,
        'data': {
          'result': {
            'live_room': [
              {
                'roomid': 10501,
                'live_status': 1,
                'title': '<em class="keyword">host</em> 的直播间',
                'uname': 'host',
                'cate_name': '<em>英雄联盟</em>',
                'uface': '//i0.hdslb.com/f.png',
                'user_cover': '//i0.hdslb.com/c.png',
                'online': 30,
                'watched_show': {'switch': true, 'num': 300},
                'attentions': 9000,
                'live_time': '2024-01-01 08:00:00',
              },
            ],
            'live_user': [
              {'roomid': 20001, 'uname': 'other', 'live_status': 0, 'uface': '//i0.hdslb.com/o.png'},
            ],
          },
        },
      });
      final rooms = BilibiliRoomParser.searchRooms(body, page: 1);
      expect(rooms, hasLength(2));
      expect(rooms.first.content.title, 'host 的直播间');
      expect(rooms.first.area?.areaName, '英雄联盟');
      expect(rooms.first.anchor?.followerCount, 9000);
      expect(rooms.first.broadcast.startedAt, DateTime.utc(2024));
      expect(rooms.last.roomId, '20001');
      expect(BilibiliRoomParser.searchRooms(body, page: 2), hasLength(1));
      final anchors = BilibiliRoomParser.searchAnchors(
        jsonEncode({
          'code': 0,
          'data': {
            'result': [
              {'roomid': 5, 'mid': 9, 'uname': 'x', 'is_live': 1},
            ],
          },
        }),
      );
      expect(anchors.single.anchorId, '9');
      expect(anchors.single.liveStatus, LiveStatus.live);
    });

    test('the envelope maps its codes onto failures', () {
      BilibiliFailure failure(String body, {int status = 200}) {
        try {
          BilibiliRoomParser.checked(body, what: 'x', status: status);
        } on BilibiliFailure catch (error) {
          return error;
        }
        throw StateError('no failure');
      }

      expect(failure('{"code":-352}').kind, BilibiliFailureKind.riskControl);
      expect(failure('{"code":-412}').kind, BilibiliFailureKind.rateLimited);
      expect(failure('{}', status: 412).kind, BilibiliFailureKind.rateLimited);
      expect(failure('{}', status: 503).kind, BilibiliFailureKind.network);
      expect(failure('{"code":-101}').kind, BilibiliFailureKind.needsLogin);
      expect(failure('{"code":-404}').kind, BilibiliFailureKind.notFound);
      expect(failure('{"code":19002000}').kind, BilibiliFailureKind.notFound);
      expect(failure('{"code":60004}').kind, BilibiliFailureKind.notFound);
      expect(failure('{"code":-799,"message":"no"}').kind, BilibiliFailureKind.apiChanged);
      expect(failure('not json').kind, BilibiliFailureKind.apiChanged);
      expect(failure('{"code":0}', status: 404).kind, BilibiliFailureKind.apiChanged);
      expect(failure('{"code":-352}').toLiveSiteError('bilibili'), isA<LiveSiteRateLimitError>());
      expect(failure('{"code":-404}').toLiveSiteError('bilibili'), isA<LiveSiteNotFound>());
      expect(failure('{"code":-101}').toLiveSiteError('bilibili'), isA<LiveSiteAuthenticationError>());
    });

    test('the session answers: buvid pair, cookie append, danmaku endpoints', () {
      expect(BilibiliRoomParser.buvid(jsonEncode(_spiBody)), (buvid3: 'B3', buvid4: 'B4'));
      expect(BilibiliRoomParser.cookie(buvid3: 'B3', buvid4: 'B4'), 'buvid3=B3;buvid4=B4;');
      expect(
        BilibiliRoomParser.cookie(buvid3: 'B3', buvid4: 'B4', loginCookie: 'SESS=1'),
        'SESS=1;buvid3=B3;buvid4=B4;',
      );
      expect(BilibiliRoomParser.cookie(buvid3: 'B3', buvid4: 'B4', loginCookie: 'buvid3=OWN;'), 'buvid3=OWN;');
      expect(BilibiliRoomParser.danmakuUid(cookie: 'DedeUserID=8;', storedUid: 3), 8);
      expect(BilibiliRoomParser.danmakuUid(cookie: 'x=1;', storedUid: 3), 3);
      expect(BilibiliRoomParser.danmakuUid(cookie: '', storedUid: 3), 0);
      final info = BilibiliRoomParser.danmakuInfo(
        jsonEncode({
          'code': 0,
          'data': {
            'token': 'T',
            'host_list': [
              {'host': 'cn-hbgzabjt-dy-33.chat.bilibili.com', 'wss_port': 443},
              {'host': 'other.chat.bilibili.com', 'wss_port': 2243},
            ],
          },
        }),
      );
      expect(info.token, 'T');
      expect(
        [for (final uri in info.servers) uri.toString()],
        [
          BilibiliEndpoints.danmakuGateway,
          'wss://cn-hbgzabjt-dy-33.chat.bilibili.com/sub',
          'wss://other.chat.bilibili.com:2243/sub',
        ],
      );
      expect(() => BilibiliRoomParser.danmakuInfo('{"code":0,"data":{}}'), throwsA(isA<BilibiliFailure>()));
    });

    test('the gift table indexes gifts and guards', () {
      const catalog = BilibiliGiftCatalog(
        gifts: {'23': BilibiliGiftInfo(id: '23', name: 'x')},
      );
      expect(catalog['23']?.name, 'x');
      expect(BilibiliGiftCatalog.empty.isEmpty, isTrue);
      final parsed = BilibiliRoomParser.giftCatalog(
        jsonEncode({
          'code': 0,
          'data': {
            'list': [
              {'id': 23, 'name': '小心心', 'price': 100, 'coin_type': 'silver', 'img_basic': '//i0.hdslb.com/g.png'},
              {'id': 0, 'name': 'skip'},
            ],
            'guard_resources': [
              {'level': 3, 'name': '舰长', 'img': '//i0.hdslb.com/guard.png'},
            ],
          },
        }),
      );
      expect(parsed.gifts.length, 1);
      expect(parsed.gifts['23']?.silver, isTrue);
      expect(parsed.gifts['23']?.price, 100);
      expect(parsed.guards[3]?.name, '舰长');
      expect(parsed.guards[3]?.icon.toString(), 'https://i0.hdslb.com/guard.png');
      expect(BilibiliEndpoints.guardName(1), '总督');
    });

    test('play qualities are the union of the codecs, best first, labelled', () {
      final data = BilibiliPlayParser.playData(jsonEncode(playBody(qn: 250, expires: 1)));
      final qualities = BilibiliPlayParser.qualities(data);
      expect([for (final item in qualities) item.qualityId], ['10000', '400', '250']);
      expect(qualities.first.label, '源');
      expect(qualities[1].label, '蓝光');
      BilibiliFailure play(String body) {
        try {
          BilibiliPlayParser.playData(body);
        } on BilibiliFailure catch (error) {
          return error;
        }
        throw StateError('no failure');
      }

      expect(
        play(
          jsonEncode({
            'code': 0,
            'data': {'live_status': 0},
          }),
        ).kind,
        BilibiliFailureKind.streamUnavailable,
      );
      expect(
        BilibiliPlayParser.carouselWithoutStream(
          jsonEncode({
            'code': 0,
            'data': {'live_status': 2, 'playurl_info': null},
          }),
        ),
        isTrue,
      );
      expect(BilibiliPlayParser.carouselQuality.qualityId, BilibiliPlayParser.carouselQualityId);
    });

    test('lines order by request, protocol, format and codec, with the lease', () {
      final issuedAt = DateTime.utc(2026, 10);
      final expires = issuedAt.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      final data = BilibiliPlayParser.playData(jsonEncode(playBody(qn: 250, expires: expires)));
      final lines = BilibiliPlayParser.lines(
        data,
        requestedQn: 250,
        roomId: '10501',
        issuedAt: issuedAt,
        cookie: 'SESS=1',
      );
      expect(
        [for (final line in lines) line.url],
        [
          'https://d1.bilivideo.com/live-bvc/flv-avc.flv?expires=$expires',
          'https://mcdn.d1.bilivideo.com/live-bvc/flv-avc.flv?expires=$expires',
          'https://d3.bilivideo.com/live-bvc/hls.m3u8?expires=$expires',
        ],
      );
      expect(lines.first.format, LiveStreamFormat.flv);
      expect(lines.first.formatSource, LivePlayFormatSource.declared);
      expect(lines.first.codec, LiveStreamCodec.avc);
      expect(lines[2].format, LiveStreamFormat.hls);
      expect(lines.first.headers['referer'], 'https://live.bilibili.com/10501');
      expect(lines.first.headers['cookie'], 'SESS=1');
      expect(lines.first.headers['user-agent'], BilibiliEndpoints.userAgent);
      expect(lines.first.lease?.expiresAt, issuedAt.add(const Duration(hours: 2)));
      expect(
        lines.first.lease?.refreshAt,
        issuedAt.add(const Duration(hours: 2)).subtract(const Duration(seconds: 60)),
      );
      // The delivered tier is 250: asking 400 keeps only the fmp4 codec line.
      final other = BilibiliPlayParser.lines(data, requestedQn: 400, roomId: '10501', issuedAt: issuedAt);
      expect([for (final line in other) line.url], ['https://d4.bilivideo.com/live-bvc/f.mp4?expires=$expires']);
      expect(other.single.format, LiveStreamFormat.other);
    });

    test('the carousel plays its video, getRoundPlayVideo then playurl', () {
      final video = BilibiliPlayParser.roundPlayVideoData(
        jsonEncode({
          'code': 0,
          'data': {'bvid': 'BV1xx411c7mD', 'cid': 12, 'play_time': 45},
        }),
      );
      expect(video, (bvid: 'BV1xx411c7mD', cid: 12, start: const Duration(seconds: 45)));
      expect(
        () => BilibiliPlayParser.roundPlayVideoData(
          jsonEncode({
            'code': 0,
            'data': {'bvid': '', 'cid': 0},
          }),
        ),
        throwsA(isA<BilibiliFailure>()),
      );
      final lines = BilibiliPlayParser.videoLines(
        jsonEncode({
          'code': 0,
          'data': {
            'durl': [
              {
                'url': 'https://d1.bilivideo.com/v.mp4',
                'backup_url': ['https://d2.bilivideo.com/v.mp4'],
              },
            ],
          },
        }),
        bvid: 'BV1xx411c7mD',
      );
      expect(lines, hasLength(2));
      expect(lines.first.format, LiveStreamFormat.mp4);
      expect(lines.first.headers['referer'], 'https://www.bilibili.com/video/BV1xx411c7mD/');
      expect(BilibiliEndpoints.videoPlayUrl('BV1xx411c7mD', 12).queryParameters['platform'], 'html5');
    });

    test('super chats read their display window and colours', () {
      final chats = BilibiliRoomParser.superChats(
        jsonEncode({
          'code': 0,
          'data': {
            'list': [
              {
                'id': 3,
                'start_time': 1700000000,
                'end_time': 1700001000,
                'message': 'hi',
                'price': 50,
                'background_color': '#123456',
                'user_info': {'uname': 'p', 'face': '//i0.hdslb.com/f.jpg'},
              },
              {'id': 4, 'message': 'no window'},
            ],
          },
        }),
      );
      expect(chats, hasLength(1));
      expect(chats.single.messageId, '3');
      expect(chats.single.text, 'hi');
      expect(chats.single.price.amount, 50);
      expect(chats.single.faceUrl, 'https://i0.hdslb.com/f.jpg@200w.jpg');
      expect(chats.single.display.backgroundColor, '#123456');
    });
  });

  group('link resolve', () {
    test('room ids come out of the live and www page addresses', () {
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/42062'), '42062');
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/42062?spm_id=1'), '42062');
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/h5/10501'), '10501');
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/blanc/00010501'), '10501');
      expect(BilibiliSite.roomIdFromUrl('https://www.bilibili.com/42062'), '42062');
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/0'), isNull);
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/not-a-room'), isNull);
      expect(BilibiliSite.roomIdFromUrl('https://space.bilibili.com/12345'), isNull);
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/'), isNull);
      expect(BilibiliSite.roomIdFromUrl('https://live.bilibili.com/123456789012345678901'), isNull);
      expect(BilibiliSite.isShortLink('https://b23.tv/abc'), isTrue);
    });

    test('the resolver canonicalises a room link and refuses a foreign host', () async {
      final site = _site({
        '/whatever': const {'code': 0},
      });
      final resolver = site.capability<LiveLinkResolver>()!;
      expect(
        unwrapRight(await resolver.resolve(Uri.parse('https://live.bilibili.com/h5/42062'))),
        Uri.parse('https://live.bilibili.com/42062'),
      );
      expect(unwrapLeft(await resolver.resolve(Uri.parse('https://example.com/42062'))), isA<LiveSiteUnsupported>());
    });

    test('a short link is followed to its room', () async {
      final http = _FakeHttp(
        (_) => LiveResponse(
          statusCode: 302,
          headers: const {'location': 'https://live.bilibili.com/10501/'},
          bodyBytes: utf8.encode('redirecting'),
        ),
      );
      final site = BilibiliSite(http: BilibiliHttp(http));
      final resolved = unwrapRight(await site.capability<LiveLinkResolver>()!.resolve(Uri.parse('https://b23.tv/abc')));
      expect(resolved, Uri.parse('https://live.bilibili.com/10501'));
      expect(http.requests.single.headers['user-agent'], BilibiliEndpoints.userAgent);
    });

    test('a short link the transport already followed names its room in the page', () async {
      final http = _FakeHttp(
        (_) => LiveResponse(
          statusCode: 200,
          headers: const {},
          bodyBytes: utf8.encode('<script>window.__INITIAL_STATE__={"room_id": 42062}</script>'),
        ),
      );
      final site = BilibiliSite(http: BilibiliHttp(http));
      final resolved = unwrapRight(await site.capability<LiveLinkResolver>()!.resolve(Uri.parse('https://b23.tv/xyz')));
      expect(resolved, Uri.parse('https://live.bilibili.com/42062'));
    });

    test('a short link that names no room is not-found', () async {
      final http = _FakeHttp((_) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode('hi')));
      final site = BilibiliSite(http: BilibiliHttp(http));
      expect(
        unwrapLeft(await site.capability<LiveLinkResolver>()!.resolve(Uri.parse('https://b23.tv/xyz'))),
        isA<LiveSiteNotFound>(),
      );
    });
  });

  group('site', () {
    test('the manifest and the capability switch', () async {
      final site = _site({
        '/any': const {'code': 0},
      });
      expect(site.manifest.id, 'bilibili');
      expect(site.manifest.localizedName('zh-CN', 'en-US'), '哔哩哔哩直播');
      expect(site.runtimeInfo.status, LiveSiteStatus.ready);
      expect(site.capability<LiveRoomProvider>(), isA<BilibiliRoomProvider>());
      expect(site.capability<LiveAreaProvider>(), isA<BilibiliAreaProvider>());
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
      await site.dispose();
    });

    test('a detail signs its request and remembers the long id', () async {
      final site = _site({
        '/x/frontend/finger/spi': _spiBody,
        '/x/web-interface/nav': _navBody,
        '/xlive/web-room/v1/index/getInfoByRoom': _detailBody,
        '/xlive/web-room/v1/index/getDanmuInfo': _danmuBody,
      }, cookie: 'DedeUserID=42;');
      final room = unwrapRight(await site.capability<LiveRoomProvider>()!.getRoom('42062'));
      expect(room.roomId, '42062');
      expect((room.runtime.streamHandle! as BilibiliRoomData).longId, '10501');
      final args = room.runtime.danmakuHandle! as BilibiliDanmakuArgs;
      expect(args.token, 'T');
      expect(args.roomId, 10501);
      expect(args.uid, 42);
      expect(site.longId('42062'), '10501');
      final detail = _transportOf(site).requests.lastWhere((request) => request.url.path.endsWith('getInfoByRoom'));
      expect(detail.url.query, contains('w_rid='));
      expect(detail.url.query, contains('room_id=42062'));
      expect(detail.headers['cookie'], contains('buvid3=B3'));
    });

    test('a signed request renews its keys once after -352', () async {
      var details = 0;
      final http = _FakeHttp((request) {
        switch (request.url.path) {
          case '/x/frontend/finger/spi':
            return _json(_spiBody);
          case '/x/web-interface/nav':
            return _json(_navBody);
          case '/xlive/web-room/v1/index/getInfoByRoom':
            details++;
            return details == 1 ? _json({'code': -352, 'message': 'risk'}) : _json(_detailBody);
          case '/xlive/web-room/v1/index/getDanmuInfo':
            return _json(_danmuBody);
        }
        return _json({'code': -404}, status: 404);
      });
      final site = BilibiliSite(http: BilibiliHttp(http), now: () => DateTime.utc(2026, 10), sleep: (_) async {});
      expect(unwrapRight(await site.capability<LiveRoomProvider>()!.getRoom('10501')).roomId, '10501');
      expect(details, 2);
      final signed = http.requests.where((request) => request.url.path.endsWith('getInfoByRoom'));
      expect(signed, hasLength(2));
      expect(signed.last.url.query, contains('w_rid='));
      expect(signed.last.url.query, contains('wts=1790812800'));
    });

    test('a non-numeric room id is not-found without a request', () async {
      final site = _site({
        '/any': const {'code': 0},
      });
      expect(unwrapLeft(await site.capability<LiveRoomProvider>()!.getRoom('abc')), isA<LiveSiteNotFound>());
    });

    test('the area page falls back to the signed list', () async {
      final site = _site({
        '/room/v1/area/getRoomList': const {'code': -352, 'message': 'risk'},
        '/x/web-interface/nav': _navBody,
        '/x/frontend/finger/spi': _spiBody,
        'second/getList': {
          'code': 0,
          'data': {
            'list': [
              {'roomid': 3, 'title': 'c', 'online': 9},
            ],
          },
        },
      });
      final page = unwrapRight(await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '1,6'));
      expect(page.items.single.roomId, '3');
      final signed = _transportOf(site).requests.last;
      expect(signed.url.query, contains('w_webid=WEB1D'));
      expect(signed.url.query, contains('area_id=6'));
      expect(signed.url.query, contains('parent_area_id=1'));
    });

    test('a throttle is never retried or answered by the fallback', () async {
      final http = _FakeHttp((request) => _json(const {'code': 0}, status: 412));
      final site = BilibiliSite(http: BilibiliHttp(http), sleep: (_) async {});
      final result = await site.capability<LiveAreaProvider>()!.getAreaRooms(areaId: '1,6');
      expect(unwrapLeft(result), isA<LiveSiteRateLimitError>());
      expect(http.requests.where((request) => request.url.path.endsWith('getRoomList')), hasLength(1));
      expect(http.requests.any((request) => request.url.path.endsWith('nav')), isFalse);
    });

    test('the search page refuses an unsupported target and answers a blank query', () async {
      final site = _site({
        '/x/web-interface/search/type': const {
          'code': 0,
          'data': {'result': <String, Object?>{}},
        },
      });
      final search = site.capability<LiveSearchProvider>()!;
      expect(search.supportedTargets, {LiveSearchTarget.rooms, LiveSearchTarget.anchors});
      final blank = await search.search(const LiveSearchRequest(query: ' ', target: LiveSearchTarget.rooms));
      expect(unwrapRight(blank).items, isEmpty);
      expect(
        unwrapLeft(await search.search(const LiveSearchRequest(query: 'x', target: LiveSearchTarget.areas))),
        isA<LiveSiteUnsupported>(),
      );
      final rooms = await search.search(const LiveSearchRequest(query: 'host', target: LiveSearchTarget.rooms));
      expect(unwrapRight(rooms).items, isEmpty);
      final anchors = await search.search(const LiveSearchRequest(query: 'host', target: LiveSearchTarget.anchors));
      expect(unwrapRight(anchors).items, isEmpty);
    });

    test('the discovery feed falls back to the recommendation list', () async {
      final site = _site({
        '/room/v1/Area/getListByAreaID': const {'code': -799, 'message': 'no'},
        '/webMain/getMoreRecList': {
          'code': 0,
          'data': {
            'recommend_room_list': [
              {'roomid': 8, 'title': 'r', 'online': 4},
            ],
          },
        },
      });
      final page = unwrapRight(await site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(page.items.single.roomId, '8');
      expect(_transportOf(site).requests.where((r) => r.url.path.endsWith('getListByAreaID')), hasLength(2));
    });

    test('playback reads qualities and lines from getRoomPlayInfo', () async {
      final issuedAt = DateTime.utc(2026, 10);
      final expires = issuedAt.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      final site = _site({
        '/x/frontend/finger/spi': _spiBody,
        '/xlive/web-room/v2/index/getRoomPlayInfo': playBody(qn: 250, expires: expires),
      }, now: issuedAt);
      final playback = site.capability<LivePlaybackProvider>()!;
      final qualities = unwrapRight(await playback.getQualities(roomId: '10501'));
      expect(qualities.first.qualityId, '10000');
      final lines = unwrapRight(
        await playback.getLines(
          roomId: '10501',
          quality: const LivePlayQuality(label: 'x', qualityId: '250'),
        ),
      );
      expect(lines.first.url, 'https://d1.bilivideo.com/live-bvc/flv-avc.flv?expires=$expires');
      expect(lines.first.headers['referer'], 'https://live.bilibili.com/10501');
      expect(lines.first.lease, isNotNull);
    });

    test('a carousel without a stream plays its video', () async {
      final site = _site({
        '/x/frontend/finger/spi': _spiBody,
        '/xlive/web-room/v2/index/getRoomPlayInfo': const {
          'code': 0,
          'data': {'live_status': 2, 'playurl_info': null},
        },
        '/live/getRoundPlayVideo': const {
          'code': 0,
          'data': {'bvid': 'BV1xx411c7mD', 'cid': 12, 'play_time': 0},
        },
        '/x/player/playurl': const {
          'code': 0,
          'data': {
            'durl': [
              {'url': 'https://d1.bilivideo.com/v.mp4'},
            ],
          },
        },
      });
      final playback = site.capability<LivePlaybackProvider>()!;
      expect(unwrapRight(await playback.getQualities(roomId: '10501')).single.qualityId, 'carousel');
      final lines = unwrapRight(await playback.getLines(roomId: '10501', quality: BilibiliPlayParser.carouselQuality));
      expect(lines.single.format, LiveStreamFormat.mp4);
    });

    test('the danmaku provider reports a room without a token', () async {
      final site = _site({
        '/x/frontend/finger/spi': _spiBody,
        '/xlive/web-room/v1/index/getDanmuInfo': const {'code': -799, 'message': 'no'},
      });
      final result = await site.capability<LiveDanmakuProvider>()!.createSession(roomId: '10501');
      expect(unwrapLeft(result), isA<LiveSiteContentUnavailable>());
    });

    test('the gift table is cached across rooms and never blocks a failure', () async {
      var calls = 0;
      final http = _FakeHttp((request) {
        if (!request.url.path.endsWith('giftConfig')) return _json({'code': -404}, status: 404);
        calls++;
        return _json({
          'code': 0,
          'data': {
            'list': [
              {'id': 23, 'name': '小心心', 'price': 100, 'coin_type': 'gold'},
            ],
          },
        });
      });
      final site = BilibiliSite(http: BilibiliHttp(http), now: () => DateTime.utc(2026, 10));
      expect((await site.giftCatalog()).gifts.length, 1);
      expect((await site.giftCatalog()).gifts.length, 1);
      expect(calls, 1);
    });

    test('a broken gift table answer still gives an empty catalogue', () async {
      final site = _site({
        '/giftPanel/giftConfig': const {'code': 0, 'data': null},
      });
      expect((await site.giftCatalog()).isEmpty, isTrue);
    });

    test('the registered built-in sites include bilibili', () {
      final ids = [
        for (final site in createBuiltInLiveSites(http: _FakeHttp((_) => _json({'code': 0})))) site.manifest.id,
      ];
      expect(ids, contains('bilibili'));
    });

    test('the protobuf reader reads the gift fields by tag and ignores the rest', () {
      final inner = _Pb()
        ..integer(1, 23)
        ..string(2, '辣条')
        ..integer(5, 100);
      final root = _Pb()
        ..integer(1, 42)
        ..string(2, 'guest')
        ..integer(99, 7)
        ..message(10, inner);
      final decoded = BilibiliProtoMessage.decode(root.toBytes());
      expect(decoded.integer(1), 42);
      expect(decoded.string(2), 'guest');
      expect(decoded.message(10)?.string(2), '辣条');
      expect(decoded.message(10)?.integer(5), 100);
      expect(decoded.message(11), isNull);
      expect(BilibiliProtoMessage.unsigned(-1), '18446744073709551615');
    });
  });
}

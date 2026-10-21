import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show md5;
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/huya/api/huya_endpoints.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku_codec.dart';
import 'package:live_sites/src/platforms/huya/huya_tars.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';
import 'package:test/test.dart';

/// Builds a server push frame: an outer struct {tag0 command, tag1 payload}
/// around a single-push payload {tag1 uri, tag2 body, tag5 message id}.
Uint8List pushFrame(int uri, Uint8List body, {int id = 0}) {
  final payload =
      (TarsWriter()
            ..writeInt(1, uri)
            ..writeBytes(2, body)
            ..writeInt(5, id))
          .toBytes();
  return (TarsWriter()
        ..writeInt(0, HuyaDanmakuProtocol.pushCommand)
        ..writeBytes(1, payload))
      .toBytes();
}

void main() {
  group('Tars', () {
    test('rotateUid moves the low-32-bit byte and round-trips', () {
      expect(HuyaPlayParser.rotateUid(0x00000001), 0x00000100);
      // An anonymous uid above 2^32 keeps its high half, only the low turns.
      const uid = (3 << 32) + 0x12345678;
      expect(HuyaPlayParser.unrotateUid(HuyaPlayParser.rotateUid(uid)), uid);
    });

    test('a client register frame decodes to command 16 with its groups', () {
      final frame = HuyaDanmakuProtocol.register(777);
      final outer = TarsStruct.decode(frame);
      expect(outer.integer(0), HuyaDanmakuProtocol.registerCommand);
      final payload = TarsStruct.decode(outer.bytes(1) ?? const <int>[]);
      expect(payload.list(0), containsAll(<Object>['live:777', 'chat:777']));
      expect(payload.string(1), '');
    });

    test('a heartbeat frame decodes to command 20', () {
      expect(TarsStruct.decode(HuyaDanmakuProtocol.heartbeat()).integer(0), HuyaDanmakuProtocol.heartbeatCommand);
    });
  });

  group('HuyaDanmakuProtocol decoding', () {
    test('uri 1400 becomes a chat message', () {
      final body =
          (TarsWriter()
                ..writeStruct(
                  0,
                  (s) => s
                    ..writeInt(0, 42)
                    ..writeString(2, 'Bob'),
                )
                ..writeString(3, 'hello')
                ..writeStruct(6, (f) => f.writeInt(0, 0)))
              .toBytes();
      final r = HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.chatUri, body, id: 9));
      expect(r.ended, isEmpty);
      final message = r.messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.effectiveSender.userName, 'Bob');
      expect(message.effectiveSender.userId, '42');
      expect(message.messageId, 'huya:9');
    });

    test('uri 8006 becomes a popularity audience update', () {
      final body = (TarsWriter()..writeInt(0, 12345)).toBytes();
      final r = HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.popularityUri, body));
      final update = r.messages.single.payload! as LiveAudienceUpdate;
      expect(update.kind, LiveAudienceSignalKind.popularity);
      expect(update.value, 12345);
    });

    test('uri 6501 becomes a gift priced from the packet, with a combo key', () {
      final body =
          (TarsWriter()
                ..writeInt(0, 500) // iItemType
                ..writeInt(2, 3) // iItemCount
                ..writeInt(4, 88) // lSenderUid
                ..writeString(6, 'Giver') // sSenderNick
                ..writeInt(9, 4) // iItemGroup combo counter
                ..writeString(20, '虎粮') // sPropsName
                ..writeInt(39, 999) // lComboSeqId
                ..writeInt(41, 1500)) // lPayTotal
              .toBytes();
      final r = HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.giftUri, body, id: 7));
      final gift = r.messages.single.payload! as LiveGift;
      expect(gift.name, '虎粮');
      expect(gift.count, 3);
      expect(gift.value.totalValue, 1500.0);
      expect(gift.combo.comboKey, '88:999');
      expect(gift.combo.comboTotal, 4);
      expect(r.messages.single.effectiveSender.userName, 'Giver');
    });

    test('a gift without a name is dropped', () {
      final body = (TarsWriter()..writeInt(2, 1)).toBytes();
      expect(HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.giftUri, body)).messages, isEmpty);
    });
  });

  test('a frame that is not Tars gives nothing, not a throw', () {
    expect(HuyaDanmakuProtocol.decode(const [0, 1, 2, 3]).messages, isEmpty);
  });

  group('signAntiCode', () {
    test('signs an fm template with the rotated uid and drops the template', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final wsSeconds = now.millisecondsSinceEpoch ~/ 1000;
      const stream = 'stream123';
      const uid = 123;
      const template = r'$0|$1|$2|$3';
      final antiCode =
          'fm=${Uri.encodeComponent(base64.encode(utf8.encode(template)))}'
          '&wsTime=${wsSeconds.toRadixString(16)}&ctype=huya_webh5&t=100&fs=bgct';

      final signed = HuyaPlayParser.signAntiCode(
        antiCode,
        streamName: stream,
        uid: uid,
        clock: HuyaSignClock(),
        now: now,
      );

      final millis = now.millisecondsSinceEpoch;
      final seqId = uid + millis;
      final hash = md5.convert(utf8.encode('$seqId|huya_webh5|100')).toString();
      final rotated = HuyaPlayParser.rotateUid(uid);
      final wsHex = wsSeconds.toRadixString(16);
      final expectedSecret = md5.convert(utf8.encode('$rotated|$stream|$hash|$wsHex')).toString();

      expect(signed, contains('wsSecret=$expectedSecret'));
      expect(signed, contains('u=$rotated'));
      expect(signed, contains('seqid=$seqId'));
      expect(signed, contains('ver=1'));
      expect(signed, isNot(contains('fm=')));
    });

    test('a query without fm is returned unchanged (a static token)', () {
      const antiCode = 'wsTime=abc&t=100';
      expect(
        HuyaPlayParser.signAntiCode(
          antiCode,
          streamName: 'x',
          uid: 1,
          clock: HuyaSignClock(),
          now: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        antiCode,
      );
    });

    test('a template that does not decode throws apiChanged', () {
      final antiCode = 'fm=${Uri.encodeComponent('not-base64-template-without-placeholders')}&wsTime=deadbeef';
      expect(
        () => HuyaPlayParser.signAntiCode(
          antiCode,
          streamName: 'x',
          uid: 1,
          clock: HuyaSignClock(),
          now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ),
        throwsA(isA<HuyaFailure>()),
      );
    });
  });

  group('HuyaRoomParser link helpers', () {
    test('numeric vs alias', () {
      expect(HuyaRoomParser.isNumericId('12345'), isTrue);
      expect(HuyaRoomParser.isNumericId('lpl'), isFalse);
      expect(HuyaRoomParser.isRoomKey('lpl-1_A'), isTrue);
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://www.huya.com/12345')), '12345');
      expect(HuyaRoomParser.aliasAt(Uri.parse('https://www.huya.com/someone')), 'someone');
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://example.com/12345')), isNull);
    });

    test('roomIdFromPage reads TT_ROOM_DATA', () {
      expect(HuyaRoomParser.roomIdFromPage('var TT_ROOM_DATA = { "profileRoom": 999888 };'), '999888');
    });
  });

  group('HuyaPlayParser.lines', () {
    // The `multiLine` list is what a live room's play lines are built from; a
    // read that walks into it one level too deep yields nothing, and huya then
    // reports every live room as unplayable.
    Map<String, dynamic> profileStream() => {
      'baseSteamInfoList': [
        {
          'sCdnType': 'AL',
          'sStreamName': 'stream-A',
          'sFlvUrl': 'http://al.flv.huya.com/src',
          'sFlvAntiCode': 'wsSecret=1',
          'sHlsUrl': 'http://al.hls.huya.com/src',
          'sHlsAntiCode': 'wsSecret=2',
        },
      ],
      'flv': {
        'multiLine': [
          {'cdnType': 'AL', 'url': 'al'},
        ],
      },
      'hls': {
        'multiLine': [
          {'cdnType': 'AL', 'url': 'al'},
          {'cdnType': 'TX', 'url': 'tx'},
        ],
      },
    };

    test('reads every multiLine entry whose cdn has a base stream', () {
      final lines = HuyaPlayParser.lines(profileStream(), [
        for (final raw in (profileStream()['baseSteamInfoList'] as List).cast<Map<String, dynamic>>()) raw,
      ], null);
      expect(lines.map((line) => '${line.format.name}:${line.cdnType}'), ['flv:AL', 'hls:AL']);
      expect(lines.first.base, 'https://al.flv.huya.com/src');
      expect(lines.first.streamName, 'stream-A');
    });

    test('a line whose cdn no base lists is left out', () {
      final lines = HuyaPlayParser.lines({'flv': {'multiLine': [
        {'cdnType': 'HS', 'url': 'hs'},
      ]}}, [], null);
      expect(lines, isEmpty);
    });
  });

  group('HuyaDanmakuProtocol push/batch framing', () {
    test('uri 8001 end notice reports the streamer uid', () {
      final body = (TarsWriter()..writeInt(0, 4242)).toBytes();
      expect(HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.endUri, body)).ended, [4242]);
    });

    test('command 22 batch decodes every item', () {
      final chat = (TarsWriter()..writeString(3, 'one')).toBytes();
      final gift =
          (TarsWriter()
                ..writeString(20, 'flower')
                ..writeInt(2, 2))
              .toBytes();
      final items = <({int uri, Uint8List body})>[
        (uri: HuyaDanmakuProtocol.chatUri, body: chat),
        (uri: HuyaDanmakuProtocol.giftUri, body: gift),
      ];
      final batch =
          (TarsWriter()..writeList<({int uri, Uint8List body})>(
                1,
                items,
                (writer, item) => writer.writeStruct(
                  0,
                  (s) => s
                    ..writeInt(0, item.uri)
                    ..writeBytes(1, item.body),
                ),
              ))
              .toBytes();
      final frame =
          (TarsWriter()
                ..writeInt(0, HuyaDanmakuProtocol.batchCommand)
                ..writeBytes(1, batch))
              .toBytes();
      final r = HuyaDanmakuProtocol.decode(frame);
      expect(r.messages.map((m) => m.text), containsAll(<String>['one', 'flower ×2']));
    });

    test('a headline push (2001314) decodes its panel entries as super chats', () {
      final now = DateTime.utc(2026, 10, 1, 12);
      final entries = <({
        String content,
        int total,
        int countdown,
        int cost,
        int paid,
        int id,
        String nick,
        String avatar,
      })>[
        (content: 'hello', total: 120, countdown: 60, cost: 50, paid: 0, id: 9, nick: 'Fan', avatar: '//img/a.png'),
        (content: 'by cents', total: 60, countdown: 0, cost: 0, paid: 500, id: 10, nick: '', avatar: ''),
        (content: '   ', total: 60, countdown: 60, cost: 1, paid: 0, id: 11, nick: '', avatar: ''),
      ];
      final panel =
          (TarsWriter()..writeList<({String content, int total, int countdown, int cost, int paid, int id, String nick, String avatar})>(
                1,
                entries,
                (writer, item) => writer.writeStruct(
                  0,
                  (s) => s
                    ..writeStruct(0, (u) => u
                          ..writeString(1, item.nick)
                          ..writeString(2, item.avatar))
                    ..writeString(1, item.content)
                    ..writeInt(2, item.cost)
                    ..writeInt(4, item.total)
                    ..writeInt(5, item.countdown)
                    ..writeInt(9, item.id)
                    ..writeInt(12, item.paid),
                ),
              ))
              .toBytes();
      final r = HuyaDanmakuProtocol.decode(
        pushFrame(HuyaDanmakuProtocol.superChatUri, panel),
        now: now,
      );
      // The whitespace-only entry is dropped; two super chats remain, in order.
      expect(r.messages, hasLength(2));
      expect(r.messages.every((m) => m.type == LiveMessageType.superChat), isTrue);
      final first = r.messages.first.payload! as LiveSuperChatMessage;
      expect(first.messageId, 'huya:9');
      expect(first.text, 'hello');
      expect(first.userName, 'Fan');
      expect(first.faceUrl, 'https://img/a.png');
      expect(first.price.amount, 50);
      expect(first.endTime, now.add(const Duration(seconds: 60)));
      expect(first.startTime, now.subtract(const Duration(seconds: 60)));
      expect(first.display.backgroundBottomColor, HuyaDanmakuProtocol.superChatBottom);
      // iCostPay in cents reads as at least ¥1 when iCost is absent.
      final second = r.messages[1].payload! as LiveSuperChatMessage;
      expect(second.price.amount, 5);
      expect(second.messageId, 'huya:10');
    });

    test('a notice-only headline push (no panel list) decodes to nothing', () {
      final body = (TarsWriter()..writeString(7, 'just a pointer')).toBytes();
      expect(HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.superChatUri, body)).messages, isEmpty);
    });
  });

  group('WUP packet', () {
    test('the message-board request round-trips through encode/decode', () {
      final bytes = HuyaDanmakuProtocol.messageBoardRequest(123456);
      // A 4-byte big-endian length prefix that counts itself in.
      expect(ByteData.sublistView(bytes, 0, 4).getInt32(0), bytes.length);
      final packet = WupPacket.decode(bytes);
      expect(packet.servant, 'wupui');
      expect(packet.function, 'getHeadLineMessageBoard');
      expect(packet.params.keys, contains('tReq'));
    });

    test('a board answer with a zero code and no result is an empty board', () {
      final bytes =
          WupPacket(
            servant: 'wupui',
            function: 'getHeadLineMessageBoard',
            params: {'': WupPacket.intParam(0)},
          ).encode();
      expect(HuyaDanmakuProtocol.superChatBoard(bytes, now: DateTime.utc(2026)), isEmpty);
    });

    test('a non-zero return code is api-changed', () {
      final bytes =
          WupPacket(
            servant: 'wupui',
            function: 'getHeadLineMessageBoard',
            params: {'': WupPacket.intParam(3)},
          ).encode();
      expect(
        () => HuyaDanmakuProtocol.superChatBoard(bytes, now: DateTime.utc(2026)),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
      );
    });

    test('an HTTP 5xx answer is network', () {
      expect(
        () => HuyaDanmakuProtocol.superChatBoard(const [0, 0, 0, 4, 0, 0, 0, 0], now: DateTime.utc(2026), status: 503),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.network)),
      );
    });
  });

  group('play token', () {
    test('the native getCdnTokenInfoEx request round-trips with the pc_exe identity', () {
      final bytes =
          HuyaPlayParser.cdnTokenRequest(
            flvUrl: '',
            streamName: 'stream1',
            userId: const HuyaUserId(huyaUa: HuyaEndpoints.nativeTarsUserAgent),
          );
      final packet = WupPacket.decode(bytes);
      expect(packet.servant, 'liveui');
      expect(packet.function, 'getCdnTokenInfoEx');
      // tId (the user identity) sits at tReq tag 3; its sHuYaUA (tag 3) is the pc_exe UA.
      final tReq = packet.struct('tReq')!;
      expect(tReq.struct(3)!.string(3), HuyaEndpoints.nativeTarsUserAgent);
      expect(tReq.string(1), 'stream1');
    });

    test('a token answer returns the sFlvToken and iExpireTime; a non-zero code is returned', () {
      final answer =
          WupPacket(
            servant: 'liveui',
            function: 'getCdnTokenInfoEx',
            params: {
              '': WupPacket.intParam(0),
              'tRsp': WupPacket.structParam((w) => w
                    ..writeString(0, 'wsTime=6aba3701&t=100')
                    ..writeInt(1, 300)),
            },
          ).encode();
      final result = HuyaPlayParser.cdnTokenResponse(answer);
      expect(result.code, 0);
      expect(result.token, 'wsTime=6aba3701&t=100');
      expect(result.expireTime, 300);

      final refused = WupPacket(
        servant: 'liveui',
        function: 'getCdnTokenInfoEx',
        params: {'': WupPacket.intParam(3)},
      ).encode();
      expect(HuyaPlayParser.cdnTokenResponse(refused).code, 3);
    });

    test('tokenWindow bounds the token by wsTime+300 s and the earlier iExpireTime', () {
      final receivedAt = DateTime.utc(2026, 10, 1, 12);
      final wsSeconds = receivedAt.millisecondsSinceEpoch ~/ 1000 + 400;
      final ws = wsSeconds.toRadixString(16);
      // iExpireTime 90 s after receipt is earlier than wsTime+300 s.
      final window = HuyaPlayParser.tokenWindow('wsTime=$ws', expireTime: 90, receivedAt: receivedAt);
      expect(window.invalidAt, receivedAt.add(const Duration(seconds: 90)));
      expect(window.refreshAt, receivedAt.add(const Duration(seconds: 60)));
      // An absolute second expiry above 10^9 is read as a unix second.
      final absolute = receivedAt.add(const Duration(seconds: 200)).millisecondsSinceEpoch ~/ 1000;
      expect(
        HuyaPlayParser.tokenWindow('wsTime=$ws', expireTime: absolute, receivedAt: receivedAt).invalidAt,
        DateTime.fromMillisecondsSinceEpoch(absolute * 1000, isUtc: true),
      );
    });

    test('an empty token or one without a hexadecimal wsTime is api-changed', () {
      final now = DateTime.utc(2026);
      expect(
        () => HuyaPlayParser.tokenWindow(' ', expireTime: 0, receivedAt: now),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
      );
      expect(
        () => HuyaPlayParser.tokenWindow('wsSecret=x', expireTime: 0, receivedAt: now),
        throwsA(isA<HuyaFailure>().having((f) => f.kind, 'kind', HuyaFailureKind.apiChanged)),
      );
    });
  });

  group('replay recording', () {
    test('a replay room with a recording is playable at its one quality', () {
      final body = jsonEncode({
        'status': 200,
        'data': {
          'liveStatus': 'REPLAY',
          'liveData': {
            'roomName': '回放房间',
            'hls': 'https://v.huya.com/play/back/888.m3u8?vid=888&definition=yuanhua&srckey=abc',
          },
          'profileInfo': {'uid': 123, 'nick': 'Chan'},
        },
      });
      final profile = HuyaRoomParser.profile(body, requestedId: '123');
      expect(profile.replay?.videoId, 888);
      expect(profile.room.broadcast.effectiveRestriction, LiveRestriction.none);
      expect(profile.qualities.single.label, '原画');
      expect(profile.qualities.single.qualityId, contains('.m3u8'));
      expect(profile.hasStream, isFalse);
    });

    test('getMomentContent lists every replay definition, source first', () {
      final body = jsonEncode({
        'status': 200,
        'data': {
          'moment': {
            'videoInfo': {
              'definitions': [
                {
                  'defName': '360P',
                  'height': 360,
                  'm3u8': 'https://v.huya.com/play/350.m3u8?vid=888&definition=350',
                },
                {
                  'defName': '原画',
                  'height': 1080,
                  'url': 'https://v.huya.com/play/yuanhua.m3u8?vid=888&definition=yuanhua',
                },
                {
                  'defName': '720P',
                  'height': 720,
                  'm3u8': 'https://v.huya.com/play/1300.m3u8?vid=888&definition=1300',
                },
              ],
            },
          },
        },
      });
      final qualities = HuyaRoomParser.replayQualities(body);
      expect(qualities.map((quality) => quality.label), ['原画', '720P', '360P']);
      expect(qualities.first.qualityId, contains('definition=yuanhua'));
      expect(qualities.first.platformOrder, HuyaPlayParser.sourceRank);
    });

    test('a replay room with no recording stays unplayable', () {
      final body = jsonEncode({
        'status': 200,
        'data': {
          'liveStatus': 'REPLAY',
          'liveData': {'roomName': '回放', 'hls': 'https://v.huya.com/live/x.flv'},
          'profileInfo': {'uid': 1},
        },
      });
      final profile = HuyaRoomParser.profile(body, requestedId: '1');
      expect(profile.replay, isNull);
      expect(profile.room.broadcast.effectiveRestriction, LiveRestriction.unplayable);
    });
  });
}

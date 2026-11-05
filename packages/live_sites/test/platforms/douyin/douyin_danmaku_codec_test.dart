import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku_codec.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_protobuf.dart';
import 'package:test/test.dart';

/// The broadcast the socket is joined to, as the platform writes it.
const String _room = '7300000000000000000';
const int _otherRoom = 7300000000000001;

/// The largest time the protocol can mean, spelled out because it keeps the
/// out-of-range cases honest.
const int _maxTime = 8640000000000000;

/// `Common{msgId 2, roomId 3, createTime 4}`.
Uint8List _common({int msgId = 0, int roomId = 0, int createTime = 0}) =>
    (DouyinProtoWriter()
          ..integer(2, msgId)
          ..integer(3, roomId)
          ..integer(4, createTime))
        .toBytes();

/// `User{id 1, nickName 3}`.
Uint8List _user({int id = 42, String name = 'Ann'}) =>
    (DouyinProtoWriter()
          ..integer(1, id)
          ..string(3, name))
        .toBytes();

/// A `WebcastChatMessage`.
Uint8List _chat({String text = 'hello', Uint8List? common, Uint8List? user, int eventTime = 0}) =>
    (DouyinProtoWriter()
          ..bytes(1, common ?? _common())
          ..bytes(2, user ?? _user())
          ..string(3, text)
          ..integer(15, eventTime))
        .toBytes();

/// A `RoomUserSeqMessage{total 3, totalUser 7, onlineUserForAnchor 10}`.
Uint8List _seq({int? total, String? anchorText, int totalUser = 0}) {
  final writer = DouyinProtoWriter();
  if (total != null) writer.integer(3, total);
  writer.integer(7, totalUser);
  if (anchorText != null) writer.string(10, anchorText);
  return writer.toBytes();
}

/// An envelope of [method].
Uint8List _envelope(String method, Uint8List payload, {int msgId = 0}) =>
    DouyinDanmakuProtocol.envelopeBytes(method, payload, msgId: msgId);

/// A `Response{messagesList 1, internalExt 5, needAck 9}`.
Uint8List _response(List<Uint8List> envelopes, {bool needAck = false, String internalExt = ''}) {
  final writer = DouyinProtoWriter();
  for (final envelope in envelopes) {
    writer.bytes(1, envelope);
  }
  if (internalExt.isNotEmpty) writer.string(5, internalExt);
  if (needAck) writer.integer(9, 1);
  return writer.toBytes();
}

/// A `PushFrame` carrying [payload] as its body.
Uint8List _frame(List<int> payload, {String encoding = '', int logId = 7, List<int>? headers}) =>
    (DouyinProtoWriter()
          ..integer(2, logId)
          ..bytes(5, headers ?? const [])
          ..string(6, encoding)
          ..bytes(8, payload))
        .toBytes();

/// The messages of one frame holding [envelopes].
DouyinDanmakuFrame _read(List<Uint8List> envelopes, {String encoding = '', int logId = 7}) =>
    DouyinDanmakuProtocol.decode(
      _frame(_response(envelopes), encoding: encoding, logId: logId),
      roomId: _room,
    );

/// The one chat line of a frame holding [payload] as a `WebcastChatMessage`, or
/// null when the protocol dropped it.
LiveMessage? _chatLine(Uint8List payload, {String roomId = _room}) {
  final messages = DouyinDanmakuProtocol.decode(
    _frame(_response([_envelope('WebcastChatMessage', payload)])),
    roomId: roomId,
  ).messages;
  return messages.isEmpty ? null : messages.single;
}

void main() {
  group('where the socket is opened', () {
    test('the two IM edges are tried in order with one query, and the signature stays a query value', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true);
      final uris = DouyinDanmakuProtocol.endpoints(roomId: _room, userId: '1001', signature: 'ab+cd/ef', now: now);
      expect(uris.map((uri) => uri.host), DouyinEndpoints.danmakuHosts);
      expect(uris.map((uri) => uri.scheme), ['wss', 'wss']);
      expect(uris.map((uri) => uri.path), [DouyinEndpoints.danmakuPath, DouyinEndpoints.danmakuPath]);
      expect(uris.first.queryParameters['room_id'], _room);
      expect(uris.first.queryParameters['user_unique_id'], '1001');
      expect(uris.first.queryParameters['cursor'], 'h-1_t-1790733600000_r-1_d-1_u-1');
      expect(uris.first.queryParameters['signature'], 'ab+cd/ef', reason: 'the query value reads back as written');
      expect(uris.first.toString(), contains('signature=ab%2Bcd%2Fef'), reason: 'a + or / is percent-encoded');
      expect(uris.first.queryParameters['compress'], 'gzip');
      expect(uris.last.queryParameters['room_id'], _room, reason: 'both edges ask for the same broadcast');
    });

    test('the handshake names the browser and only sends a cookie there is one of', () {
      final bare = DouyinDanmakuProtocol.handshakeHeaders('   ', '7300-web-rid');
      expect(bare.containsKey('cookie'), isFalse);
      expect(bare['user-agent'], DouyinEndpoints.userAgent);
      expect(bare['origin'], DouyinEndpoints.origin);
      expect(bare['referer'], '${DouyinEndpoints.origin}/7300-web-rid');

      final withCookie = DouyinDanmakuProtocol.handshakeHeaders(' ttwid=a; ', 'a b');
      expect(withCookie['cookie'], 'ttwid=a;', reason: 'a header cannot carry the padding');
      expect(withCookie['referer'], '${DouyinEndpoints.origin}/a%20b');
    });
  });

  group('what the client writes', () {
    test('the heartbeat frame says only hb, and reading one asks for nothing', () {
      final frame = DouyinDanmakuProtocol.heartbeat();
      final message = DouyinProtoMessage.decode(frame);
      expect(message.string(7), 'hb');
      expect(message.fields, hasLength(1));

      final read = DouyinDanmakuProtocol.decode(frame, roomId: _room);
      expect(read.errors, isEmpty);
      expect(read.ack, isNull);
      expect(read.messages, isEmpty);
      expect(read.envelopes, 0);
    });

    test('the acknowledgement writes every field, even the empty ones', () {
      final empty = DouyinProtoMessage.decode(DouyinDanmakuProtocol.ack(0, ''));
      expect(empty.fields.map((field) => field.number), [2, 7, 8]);
      expect(empty.integer(2), 0);
      expect(empty.string(7), 'ack');
      expect(empty.string(8), isEmpty);

      final full = DouyinProtoMessage.decode(DouyinDanmakuProtocol.ack(1234, 'ext-1'));
      expect(full.integer(2), 1234);
      expect(full.string(8), 'ext-1');
    });
  });

  group('one received frame', () {
    test('a readable frame reports its messages in order and asks for nothing', () {
      final read = _read([
        _envelope('WebcastChatMessage', _chat(text: 'first')),
        _envelope('WebcastGiftMessage', Uint8List.fromList([0x08, 0x01])),
        _envelope('WebcastRoomUserSeqMessage', _seq(total: 400)),
        _envelope('WebcastControlMessage', Uint8List.fromList([0x08, 0x02])),
      ]);
      expect(read.errors, isEmpty);
      expect(read.envelopes, 4, reason: 'the count is what the frame carried, read or not');
      expect(read.ack, isNull);
      expect(read.messages.map((message) => message.type), [LiveMessageType.chat, LiveMessageType.audienceUpdate]);
      expect(read.messages.first.text, 'first');
      expect(DouyinDanmakuProtocol.handledMethods, ['WebcastChatMessage', 'WebcastRoomUserSeqMessage']);
    });

    test('needAck brings back the frame log id and the response internal ext', () {
      final frame = DouyinDanmakuProtocol.responseBytes(
        [_envelope('WebcastChatMessage', _chat())],
        needAck: true,
        internalExt: 'internal-1',
        logId: 555,
      );
      final ack = DouyinProtoMessage.decode(DouyinDanmakuProtocol.decode(frame, roomId: _room).ack!);
      expect(ack.integer(2), 555);
      expect(ack.string(7), 'ack');
      expect(ack.string(8), 'internal-1');

      final notAsked = DouyinDanmakuProtocol.decode(
        _frame(_response([_envelope('WebcastChatMessage', _chat())], internalExt: 'e')),
        roomId: _room,
      );
      expect(notAsked.ack, isNull, reason: 'no needAck, no acknowledgement, ext or not');
    });

    test('the payload is expanded when the encoding says gzip, and when it only starts with the magic', () {
      final response = _response([_envelope('WebcastChatMessage', _chat(text: 'by magic'))]);
      final byMagic = DouyinDanmakuProtocol.decode(_frame(Uint8List.fromList(gzip.encode(response))), roomId: _room);
      expect(byMagic.messages.single.text, 'by magic', reason: 'no payloadEncoding field, only the 1f 8b start');

      final saidSo = DouyinDanmakuProtocol.decode(
        _frame(Uint8List.fromList(gzip.encode(response)), encoding: 'GZIP'),
        roomId: _room,
      );
      expect(saidSo.messages.single.text, 'by magic', reason: 'the encoding name is matched case-insensitively');

      // A frame that claims gzip and is not one loses the frame, not the socket.
      final lying = DouyinDanmakuProtocol.decode(_frame(response, encoding: 'gzip'), roomId: _room);
      expect(lying.messages, isEmpty);
      expect(lying.errors, hasLength(1));
    });

    test("the protocol's own frame builder is the shape the reader wants", () {
      final built = DouyinDanmakuProtocol.responseBytes(
        [_envelope('WebcastChatMessage', _chat(text: 'built'))],
        gzipPayload: true,
        logId: 3,
        internalExt: 'e',
        needAck: true,
      );
      final read = DouyinDanmakuProtocol.decode(built, roomId: _room);
      expect(read.messages.single.text, 'built');
      expect(DouyinProtoMessage.decode(read.ack!).integer(2), 3, reason: 'the builder writes the frame log id');

      // The empty frame is not an error: it simply says nothing.
      final nothing = DouyinDanmakuProtocol.decode(DouyinDanmakuProtocol.responseBytes(const []), roomId: _room);
      expect(nothing.messages, isEmpty);
      expect(nothing.errors, isEmpty);
      expect(nothing.envelopes, 0);
      expect(nothing.ack, isNull);
    });

    test('a part that does not add up loses the whole frame, acknowledgement included', () {
      final askedForAnAck = _response([_envelope('WebcastChatMessage', _chat())], needAck: true);
      for (final frame in <List<int>>[
        [0xFF, 0xFF],
        _frame(Uint8List.fromList([0xFF, 0xFF])),
        // A readable frame whose body is not readable.
        (DouyinProtoWriter()
              ..integer(2, 7)
              ..string(7, 'ack')
              ..bytes(8, Uint8List.fromList([0xFF, 0xFF])))
            .toBytes(),
        // The header list is read here and then ignored, and a corrupt entry is
        // still a corrupt frame: no messages and no acknowledgement.
        (DouyinProtoWriter()
              ..integer(2, 7)
              ..bytes(5, Uint8List.fromList([0xFF, 0xFF]))
              ..bytes(8, askedForAnAck))
            .toBytes(),
      ]) {
        final read = DouyinDanmakuProtocol.decode(frame, roomId: _room);
        expect(read.messages, isEmpty, reason: '$frame is not a frame this room can read');
        expect(read.ack, isNull, reason: 'a frame that lost its messages lost its acknowledgement too');
        expect(read.envelopes, 0);
        expect(read.errors, hasLength(1));
      }
      // A readable but empty frame is not one of those.
      expect(DouyinDanmakuProtocol.decode(const <int>[], roomId: _room).errors, isEmpty);
    });

    test('one unreadable message loses only itself, and an unread method loses nothing', () {
      final read = _read([
        _envelope('WebcastChatMessage', Uint8List.fromList([0xFF, 0xFF])),
        _envelope('WebcastEmojiChatMessage', _chat(text: 'not read')),
        _envelope('WebcastChatMessage', _chat(text: 'kept')),
      ]);
      expect(read.messages.map((message) => message.text), ['kept']);
      expect(read.errors, hasLength(1), reason: 'a method this protocol does not read is not an error');
      expect(read.envelopes, 3);
    });
  });

  group('a chat message', () {
    test('who, what and when come from the fields the platform fills', () {
      final line = _chatLine(
        _chat(
          text: '你好',
          common: _common(msgId: 99, createTime: 1790733600123),
          user: _user(id: 7200000000000001, name: '  Ann '),
        ),
      )!;
      expect(line.type, LiveMessageType.chat);
      expect(line.text, '你好');
      expect(line.effectiveSender.userName, 'Ann', reason: 'the model trims what the platform padded');
      expect(line.effectiveSender.userId, '7200000000000001');
      expect(line.messageId, 'douyin:99');
      expect(line.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600123, isUtc: true));
      expect(line.color, LiveMessageColor.white);
    });

    test('another broadcast is dropped, and one that names no room is kept', () {
      expect(_chatLine(_chat(common: _common(roomId: _otherRoom))), isNull);
      expect(_chatLine(_chat(common: _common())), isNotNull, reason: 'a chat that names no room is kept');
      // A chat with no Common at all still arrives, and without a time.
      final bare = _chatLine((DouyinProtoWriter()..string(3, 'bare')).toBytes())!;
      expect(bare.text, 'bare');
      expect(bare.sentAt, isNull);
      expect(bare.messageId, isEmpty);
      expect(bare.effectiveSender.userId, isEmpty, reason: 'an account of 0 is nobody, not one shared account');
      expect(_chatLine(_chat(user: (DouyinProtoWriter()..integer(1, 0)).toBytes()))!.effectiveSender.userId, isEmpty);
    });

    test('the id is the common msg id, else the envelope id, both unsigned', () {
      expect(_chatLine(_chat())!.messageId, isEmpty, reason: 'a chat that names no id anywhere gets none');
      final byEnvelope = DouyinDanmakuProtocol.decode(
        _frame(_response([_envelope('WebcastChatMessage', _chat(), msgId: 4242)])),
        roomId: _room,
      ).messages.single;
      expect(byEnvelope.messageId, 'douyin:4242');
      // A uint64 above 2^63 is spelled out, not reported negative.
      expect(_chatLine(_chat(common: _common(msgId: -5)))!.messageId, 'douyin:18446744073709551611');
    });

    test('a time above 1e11 is milliseconds, below it seconds, and 0 is none', () {
      expect(
        _chatLine(_chat(common: _common(createTime: 1790733600)))!.sentAt,
        DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true),
      );
      expect(
        _chatLine(_chat(common: _common(createTime: 1790733600123)))!.sentAt,
        DateTime.fromMillisecondsSinceEpoch(1790733600123, isUtc: true),
      );
      expect(_chatLine(_chat())!.sentAt, isNull);
      // `eventTime` only answers when `createTime` says nothing, and an
      // impossible fallback leaves the chat standing without a time.
      expect(
        _chatLine(_chat(eventTime: 1790733600))!.sentAt,
        DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true),
      );
      expect(_chatLine(_chat(eventTime: _maxTime + 1))!.sentAt, isNull);
      // An impossible `createTime` is not a time at all: that message is lost.
      final read = _read([
        _envelope(
          'WebcastChatMessage',
          _chat(
            text: 'lost',
            common: _common(createTime: _maxTime + 1),
          ),
        ),
        _envelope('WebcastChatMessage', _chat(text: 'kept')),
      ]);
      expect(read.messages.map((message) => message.text), ['kept']);
      expect(read.errors, hasLength(1));
    });
  });

  group('the audience figure', () {
    test('the exact total wins, the anchor text is the fallback, and neither is invented', () {
      LiveAudienceUpdate figure(Uint8List payload) =>
          DouyinDanmakuProtocol.online(payload)!.payload! as LiveAudienceUpdate;

      final both = figure(_seq(total: 40000, anchorText: '30.6万'));
      expect(both.kind, LiveAudienceSignalKind.onlineViewers);
      expect(both.value, 40000, reason: 'the display text rounds what this field gives exactly');
      expect(figure(_seq(total: 0, anchorText: '30.6万')).value, 306000);
      expect(figure(_seq(total: -1, anchorText: '1,200')).value, 1200);
      // `totalUser` is the cumulative figure, not the concurrent one.
      expect(DouyinDanmakuProtocol.online(_seq(totalUser: 999999)), isNull);
      expect(DouyinDanmakuProtocol.online(_seq()), isNull);
      expect(DouyinDanmakuProtocol.online(_seq(anchorText: '暂无')), isNull, reason: 'no digit, no figure');
      expect(DouyinDanmakuProtocol.online(_seq(total: 0, anchorText: '0')), isNotNull);
    });

    test('the audience envelope reaches the room through decode', () {
      final read = _read([_envelope('WebcastRoomUserSeqMessage', _seq(total: 12))]);
      expect(read.messages.single.type, LiveMessageType.audienceUpdate);
      expect((read.messages.single.payload! as LiveAudienceUpdate).value, 12);
      expect(read.ack, isNull);
    });
  });

  // What this reader does with varints, wire types, merged and repeated
  // messages, fixed widths and truncated bytes is proved for all five
  // hand-written platform readers in `test/platforms/protobuf_readers_test.dart`.
  group('the text under the protobuf', () {
    test('a chat text with a broken byte still reads', () {
      expect(DouyinDanmakuProtocol.decodeText([0xFF, ...utf8.encode('ok')]), '\uFFFDok');
    });
  });
}

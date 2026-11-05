import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/huya/api/huya_endpoints.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku_codec.dart';
import 'package:live_sites/src/platforms/huya/huya_tars.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:test/test.dart';

// The private helper spells its own name in its constructor, as the package's
// value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One board entry, written with the tags the panel is read by.
class _Entry {
  _Entry({this.nick, this.avatar, this.content, this.cost, this.total, this.countdown, this.id, this.paid});

  final String? nick;
  final String? avatar;
  final String? content;
  final int? cost;
  final int? total;
  final int? countdown;
  final int? id;
  final int? paid;

  void writeTo(TarsWriter writer) {
    if (nick != null || avatar != null) {
      writer.writeStruct(0, (user) {
        if (nick != null) user.writeString(1, nick!);
        if (avatar != null) user.writeString(2, avatar!);
      });
    }
    if (content != null) writer.writeString(1, content!);
    if (cost != null) writer.writeInt(2, cost!);
    if (total != null) writer.writeInt(4, total!);
    if (countdown != null) writer.writeInt(5, countdown!);
    if (id != null) writer.writeInt(9, id!);
    if (paid != null) writer.writeInt(12, paid!);
  }
}

/// A server frame: the command at tag 0 and its payload at tag 1.
Uint8List _frame(int command, List<int> payload) =>
    (TarsWriter()
          ..writeInt(0, command)
          ..writeBytes(1, payload))
        .toBytes();

/// A single push (`WSPushMessage`): uri 1, body 2, message id 5.
Uint8List _push(int uri, List<int> body, {int id = 9001}) =>
    (TarsWriter()
          ..writeInt(1, uri)
          ..writeBytes(2, body)
          ..writeInt(5, id))
        .toBytes();

/// A batch (`WSPushMessage_V2`): items at tag 1, each with uri 0, body 1, id 2.
Uint8List _batch(List<(int, List<int>, int)> items) =>
    (TarsWriter()..writeList<(int, List<int>, int)>(
          1,
          items,
          (writer, item) => writer.writeStruct(
            0,
            (inner) => inner
              ..writeInt(0, item.$1)
              ..writeBytes(1, item.$2)
              ..writeInt(2, item.$3),
          ),
        ))
        .toBytes();

/// `MessageNotice`: sender 0 (uid 0, nick 2), text 3, bullet format 6 (colour 0).
Uint8List _chatBody({int uid = 123, String nick = 'Ann', String text = 'hi', int? fontColor}) =>
    (TarsWriter()
          ..writeStruct(
            0,
            (sender) => sender
              ..writeInt(0, uid)
              ..writeString(2, nick),
          )
          ..writeString(3, text)
          ..writeStruct(6, (format) => format.writeInt(0, fontColor ?? 0)))
        .toBytes();

/// `SendItemSubBroadcastPacket` (0 item, 2 count, 4 sender, 6 nick, 9 combo,
/// 20 name, 39 combo sequence, 41 pay total).
Uint8List _giftBody({
  int item = 71,
  int count = 3,
  int uid = 123,
  String nick = 'Ann',
  int combo = 2,
  String name = '虎粮',
  int sequence = 0,
  int payTotal = 0,
}) =>
    (TarsWriter()
          ..writeInt(0, item)
          ..writeInt(2, count)
          ..writeInt(4, uid)
          ..writeString(6, nick)
          ..writeInt(9, combo)
          ..writeString(20, name)
          ..writeInt(39, sequence)
          ..writeInt(41, payTotal))
        .toBytes();

/// `AttendeeCountNotice` (0 the heat figure).
Uint8List _popularityBody(int count) => (TarsWriter()..writeInt(0, count)).toBytes();

/// `EndLiveNotice` (0 the streamer uid).
Uint8List _endBody(int uid) => (TarsWriter()..writeInt(0, uid)).toBytes();

/// A `GameEventMessageBoardPanel` holding these entries at tag 1.
Uint8List _panel(List<_Entry> entries) =>
    (TarsWriter()..writeList<_Entry>(1, entries, (writer, entry) => writer.writeStruct(0, entry.writeTo))).toBytes();

/// The answer of `getHeadLineMessageBoard`: the return code in `""` and the
/// panel under `tRsp` tag 1; [raw] replaces the `tRsp` parameter.
Uint8List _boardAnswer(List<_Entry> entries, {int code = 0, List<int>? raw}) {
  final tRsp =
      raw ??
      WupPacket.structParam(
        (writer) => writer.writeStruct(
          1,
          (panel) => panel.writeList<_Entry>(1, entries, (writer, entry) => writer.writeStruct(0, entry.writeTo)),
        ),
      );
  return WupPacket(
    servant: 'wupui',
    function: 'getHeadLineMessageBoard',
    params: {'': WupPacket.intParam(code), 'tRsp': tRsp},
  ).encode();
}

/// The push of a headline super chat; no body when it carries no board.
Uint8List _superChatPush(List<_Entry>? entries, {int id = 5001}) =>
    _push(HuyaDanmakuProtocol.superChatUri, entries == null ? const <int>[] : _panel(entries), id: id);

HuyaDanmakuFrame _decode(List<int> frame, {DateTime? now}) => HuyaDanmakuProtocol.decode(frame, now: now);

void main() {
  group('the client side of the socket', () {
    test('registration asks for the two groups of the streamer', () {
      final outer = TarsStruct.decode(HuyaDanmakuProtocol.register(4242));
      expect(outer.integer(0), HuyaDanmakuProtocol.registerCommand);
      final payload = TarsStruct.decode(outer.bytes(1)!);
      expect(payload.list(0), ['live:4242', 'chat:4242'], reason: 'a list of strings is their values');
      expect(payload.string(1), isEmpty);
      expect(HuyaDanmakuProtocol.groups(0), ['live:0', 'chat:0']);
    });

    test('the heartbeat is command 20 with an empty payload', () {
      final outer = TarsStruct.decode(HuyaDanmakuProtocol.heartbeat());
      expect(outer.integer(0), HuyaDanmakuProtocol.heartbeatCommand);
      expect(outer.bytes(1), isEmpty);
    });

    test('the numbers the protocol is written around', () {
      expect(HuyaDanmakuProtocol.heartbeatInterval, const Duration(seconds: 60));
      expect(HuyaDanmakuProtocol.registerCommand, 16);
      expect(HuyaDanmakuProtocol.heartbeatCommand, 20);
      expect(HuyaDanmakuProtocol.pushCommand, 7);
      expect(HuyaDanmakuProtocol.batchCommand, 22);
      expect(HuyaDanmakuProtocol.chatUri, 1400);
      expect(HuyaDanmakuProtocol.popularityUri, 8006);
      expect(HuyaDanmakuProtocol.giftUri, 6501);
      expect(HuyaDanmakuProtocol.endUri, 8001);
      expect(HuyaDanmakuProtocol.superChatUri, 2001314);
      expect(HuyaDanmakuProtocol.superChatRetryDelays, const [
        Duration.zero,
        Duration(milliseconds: 600),
        Duration(milliseconds: 1800),
        Duration(seconds: 4),
      ]);
      expect(HuyaDanmakuProtocol.superChatTimeout, const Duration(seconds: 3));
      expect(HuyaDanmakuProtocol.maxRememberedSuperChats, 512);
      expect(HuyaDanmakuProtocol.superChatTop, '#ffffff');
      expect(HuyaDanmakuProtocol.superChatBottom, '#246488');
    });
  });

  group('the envelope of a server frame', () {
    test('a single push is read as its uri, body and message id', () {
      final frame = _decode(_frame(HuyaDanmakuProtocol.pushCommand, _push(HuyaDanmakuProtocol.chatUri, _chatBody())));
      expect(frame.messages.single.text, 'hi');
      expect(frame.messages.single.messageId, 'huya:9001');
      expect(frame.ended, isEmpty);
      expect(frame.superChatNotices, 0);
    });

    test('a batch is read in order, and its items keep their own ids', () {
      final frame = _decode(
        _frame(
          HuyaDanmakuProtocol.batchCommand,
          _batch([
            (HuyaDanmakuProtocol.chatUri, _chatBody(text: 'one'), 11),
            (HuyaDanmakuProtocol.popularityUri, _popularityBody(40), 12),
            (HuyaDanmakuProtocol.chatUri, _chatBody(text: 'two'), 13),
          ]),
        ),
      );
      expect(frame.messages.map((message) => message.text), ['one', '', 'two']);
      expect(frame.messages.map((message) => message.messageId), ['huya:11', 'huya:12', 'huya:13']);
      expect(frame.messages[1].type, LiveMessageType.audienceUpdate);
    });

    test('a command this protocol does not know gives nothing', () {
      for (final command in [0, 3, 16, 20, 21]) {
        expect(
          _decode(_frame(command, _push(HuyaDanmakuProtocol.chatUri, _chatBody()))).messages,
          isEmpty,
          reason: 'command $command',
        );
      }
    });

    test('an uri this protocol does not report is ignored', () {
      final frame = _decode(_frame(HuyaDanmakuProtocol.pushCommand, _push(9999, _chatBody())));
      expect(frame.messages, isEmpty);
      expect(frame.ended, isEmpty);
      expect(frame.superChatNotices, 0);
    });

    test('a frame that is not Tars is dropped whole', () {
      expect(_decode([0xFF, 0xFE, 0xFD]).messages, isEmpty);
      expect(_decode(const <int>[]).messages, isEmpty);
    });

    test('a body that fails to decode loses only its own item', () {
      final frame = _decode(
        _frame(
          HuyaDanmakuProtocol.batchCommand,
          _batch([
            (HuyaDanmakuProtocol.chatUri, [0xFF], 11),
            (HuyaDanmakuProtocol.chatUri, _chatBody(text: 'kept'), 12),
          ]),
        ),
      );
      expect(frame.messages.map((message) => message.text), ['kept']);
    });

    test('a stream-end notice names its streamer, and 0 when it names none', () {
      List<int> ended(List<int> body) =>
          _decode(_frame(HuyaDanmakuProtocol.pushCommand, _push(HuyaDanmakuProtocol.endUri, body))).ended;
      expect(ended(_endBody(777)), [777]);
      expect(ended(const <int>[]), [0]);
      expect(ended(<int>[]), [0], reason: 'a body without tag 0 names nobody');
      expect(
        _decode(
          _frame(
            HuyaDanmakuProtocol.batchCommand,
            _batch([(HuyaDanmakuProtocol.endUri, _endBody(1), 3), (HuyaDanmakuProtocol.endUri, _endBody(2), 4)]),
          ),
        ).ended,
        [1, 2],
      );
      expect(
        _decode(_frame(HuyaDanmakuProtocol.pushCommand, _push(HuyaDanmakuProtocol.endUri, _endBody(7)))).messages,
        isEmpty,
      );
    });
  });

  group('chat, heat and gifts', () {
    test('a chat line carries its sender, colour and id', () {
      final message = HuyaDanmakuProtocol.chat(_chatBody(fontColor: 0xFF0000), 5)!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hi');
      expect(message.sender?.userId, '123');
      expect(message.sender?.userName, 'Ann');
      expect(message.color, LiveMessageColor.numberToColor(0xFF0000));
      expect(message.messageId, 'huya:5');

      final plain = HuyaDanmakuProtocol.chat(_chatBody(), 0)!;
      expect(plain.color, LiveMessageColor.white, reason: 'the default colour is -1 and 0 reads as white');
      expect(plain.messageId, isEmpty);
    });

    test('a chat without text is not reported, and missing fields read as defaults', () {
      expect(HuyaDanmakuProtocol.chat(_chatBody(text: ''), 1), isNull);
      expect(HuyaDanmakuProtocol.chat(null, 1), isNull, reason: 'an empty body has no text');
      final bare = HuyaDanmakuProtocol.chat((TarsWriter()..writeString(3, 'x')).toBytes(), 1)!;
      expect(bare.sender?.userId, '0');
      expect(bare.sender?.userName, isEmpty);
      expect(bare.color, LiveMessageColor.white);
    });

    test('the colour and id spellings of a push', () {
      expect(HuyaDanmakuProtocol.color(0), LiveMessageColor.white);
      expect(HuyaDanmakuProtocol.color(-1), LiveMessageColor.white);
      expect(HuyaDanmakuProtocol.color(1), LiveMessageColor.numberToColor(1));
      expect(HuyaDanmakuProtocol.messageId(1), 'huya:1');
      expect(HuyaDanmakuProtocol.messageId(0), isEmpty);
      expect(HuyaDanmakuProtocol.messageId(-3), isEmpty);
      expect(HuyaDanmakuProtocol.comboKey(9, 3), '9:3');
      expect(HuyaDanmakuProtocol.comboKey(9, 0), isEmpty);
    });

    test('popularity is heat, never concurrent viewers', () {
      final message = HuyaDanmakuProtocol.popularity(_popularityBody(4321), 7)!;
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.kind, LiveAudienceSignalKind.popularity);
      expect(audience.value, 4321);
      expect(message.messageId, 'huya:7');

      final empty = HuyaDanmakuProtocol.popularity(null, 0)!;
      expect((empty.payload! as LiveAudienceUpdate).value, 0, reason: 'a missing figure is zero, not unknown');
    });

    test('a gift carries its count, combo and the price in the packet', () {
      final message = HuyaDanmakuProtocol.gift(_giftBody(sequence: 555, payTotal: 900), 8)!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '虎粮 ×3');
      expect(message.sender?.userId, '123');
      expect(message.sender?.userName, 'Ann');
      expect(message.messageId, 'huya:8');
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, '71');
      expect(gift.count, 3);
      expect(gift.value.totalValue, 900);
      expect(gift.combo.comboTotal, 2);
      expect(gift.combo.comboKey, '123:555');
    });

    test('a gift without a name is not reported, and its defaults are gentle', () {
      expect(HuyaDanmakuProtocol.gift(_giftBody(name: '  '), 1), isNull);
      final bare = HuyaDanmakuProtocol.gift((TarsWriter()..writeString(20, '花')).toBytes(), 0)!;
      final gift = bare.payload! as LiveGift;
      expect(bare.text, '花 ×1', reason: 'a count of zero still shows one');
      expect(gift.giftId, isEmpty);
      expect(gift.count, 1);
      expect(gift.value.totalValue, isNull);
      expect(gift.combo.comboTotal, isNull);
      expect(gift.combo.comboKey, isEmpty);
    });
  });

  group('the headline message board', () {
    final now = DateTime.utc(2026, 11, 5, 12);
    List<LiveSuperChatMessage> board(List<_Entry> entries) =>
        HuyaDanmakuProtocol.superChatEntries(_panel(entries), now)!;

    test('a panel entry becomes a super chat timed from the frame', () {
      final chat = board([
        _Entry(nick: 'Ann', avatar: '//img.huya.com/a.png', content: '你好', cost: 20, total: 120, countdown: 40, id: 99),
      ]).single;
      expect(chat.messageId, 'huya:99');
      expect(chat.userName, 'Ann');
      expect(chat.faceUrl, 'https://img.huya.com/a.png');
      expect(chat.text, '你好');
      expect(chat.price.amount, 20);
      expect(chat.endTime, now.add(const Duration(seconds: 40)), reason: 'the countdown is what is left');
      expect(chat.startTime, now.subtract(const Duration(seconds: 80)), reason: 'the total is how long it has run');
      expect(chat.display.backgroundColor, HuyaDanmakuProtocol.superChatTop);
      expect(chat.display.backgroundBottomColor, HuyaDanmakuProtocol.superChatBottom);
    });

    test('without a countdown the total is what is left, and the window is the whole total', () {
      final chat = board([_Entry(content: 'x', total: 60, countdown: 0)]).single;
      expect(chat.endTime, now.add(const Duration(seconds: 60)));
      expect(chat.startTime, now);
    });

    test('an entry without text or time left is dropped', () {
      expect(
        board([
          _Entry(content: '  ', total: 60),
          _Entry(content: 'kept', total: 60, countdown: 0),
          _Entry(content: 'no time left', total: 0, countdown: 0),
          _Entry(total: 30),
          _Entry(content: 'also kept', countdown: 5),
        ]).map((chat) => chat.text),
        ['kept', 'also kept'],
      );
    });

    test('the price is iCost, else a hundredth of iCostPay, and never below one', () {
      int? priced(int? cost, int? paid) =>
          board([_Entry(content: 'x', total: 60, cost: cost, paid: paid)]).single.price.amount;
      expect(priced(30, 5000), 30);
      expect(priced(0, 5000), 50);
      expect(priced(0, 149), 1, reason: 'the hundredth is rounded down, not up');
      expect(priced(0, 101), 1);
      expect(priced(0, 50), 1, reason: 'a fraction of a unit still shows one');
      expect(priced(0, 0), 0);
      expect(priced(null, null), 0);
    });

    test('an id of zero claims no message id', () {
      expect(board([_Entry(content: 'x', total: 60)]).single.messageId, isEmpty);
    });

    test('a body that is not a panel is a notice-only push', () {
      expect(HuyaDanmakuProtocol.superChatEntries(null, now), isNull);
      expect(HuyaDanmakuProtocol.superChatEntries(const <int>[], now), isNull);
      expect(HuyaDanmakuProtocol.superChatEntries([0xFF], now), isNull, reason: 'not Tars at all');
      expect(
        HuyaDanmakuProtocol.superChatEntries(_popularityBody(5), now),
        isNull,
        reason: 'tag 1 is not the entry list',
      );
      expect(HuyaDanmakuProtocol.superChatEntries(_panel(const []), now), isEmpty, reason: 'an empty board is a board');
    });

    test('a headline push with its board becomes super chats, and one without counts as a notice', () {
      final withBoard = _decode(
        _frame(HuyaDanmakuProtocol.pushCommand, _superChatPush([_Entry(content: 'x', total: 60, id: 3)])),
        now: now,
      );
      expect(withBoard.messages.single.type, LiveMessageType.superChat);
      expect(withBoard.messages.single.messageId, 'huya:3');
      expect(withBoard.messages.single.sentAt, now, reason: 'no countdown means the board is fresh');
      expect(withBoard.superChatNotices, 0);

      final noticeOnly = _decode(_frame(HuyaDanmakuProtocol.pushCommand, _superChatPush(null)), now: now);
      expect(noticeOnly.messages, isEmpty);
      expect(noticeOnly.superChatNotices, 1);

      final emptyBoard = _decode(
        _frame(HuyaDanmakuProtocol.pushCommand, _superChatPush([_Entry(content: 'x', total: 0)])),
        now: now,
      );
      expect(emptyBoard.messages, isEmpty);
      expect(emptyBoard.superChatNotices, 0, reason: 'a board that is there but yields nothing is not a missing board');
    });

    test('a super-chat message carries its board entry', () {
      final chat = board([_Entry(nick: 'Ann', content: 'x', cost: 5, total: 60)]).single;
      final message = HuyaDanmakuProtocol.superChatMessage(chat);
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, 'x');
      expect(message.sender?.userName, 'Ann');
      expect(message.messageId, chat.messageId);
      expect(message.sentAt, chat.startTime);
      expect(message.payload, same(chat));
      expect(HuyaDanmakuProtocol.superChatMessage(chat.rebuild((b) => b.faceUrl = '')).sender?.avatarUrl, isNull);
    });

    test('the board request names its servant, function and fields', () {
      final packet = WupPacket.decode(HuyaDanmakuProtocol.messageBoardRequest(12345));
      expect(packet.servant, 'wupui');
      expect(packet.function, 'getHeadLineMessageBoard');
      final request = packet.struct('tReq')!;
      expect(request.integer(0), 12345);
      expect(request.string(1), isEmpty);
      expect(request.struct(2)?.string(3), HuyaEndpoints.hysdkUserAgent, reason: 'the identity rides in the request');
      expect(request.integer(3), 0);
      expect(request.integer(4), 10);
    });

    test('the board answer is read through its packet', () {
      final chats = HuyaDanmakuProtocol.superChatBoard(
        _boardAnswer([_Entry(content: 'from the board', total: 60, id: 8)]),
        now: now,
      );
      expect(chats.single.text, 'from the board');
      expect(chats.single.messageId, 'huya:8');
      expect(HuyaDanmakuProtocol.superChatBoard(_boardAnswer(const []), now: now), isEmpty);
      expect(
        HuyaDanmakuProtocol.superChatBoard(_boardAnswer(const [], raw: WupPacket.intParam(0)), now: now),
        isEmpty,
        reason: 'no panel under tRsp is an empty board',
      );
    });

    test('a board answer that cannot be used says why', () {
      HuyaFailureKind? failure(List<int> bytes, {int status = 200}) {
        try {
          HuyaDanmakuProtocol.superChatBoard(bytes, now: now, status: status);
          return null;
        } on HuyaFailure catch (failure) {
          return failure.kind;
        }
      }

      final good = _boardAnswer([_Entry(content: 'x', total: 1)]);
      expect(failure(good), isNull);
      expect(failure(good, status: 503), HuyaFailureKind.network);
      expect(failure(good, status: 404), HuyaFailureKind.apiChanged);
      expect(failure(good, status: 302), HuyaFailureKind.apiChanged);
      expect(failure([1, 2, 3, 4]), HuyaFailureKind.apiChanged, reason: 'not a WUP packet');
      expect(failure(_boardAnswer(const [], code: -1)), HuyaFailureKind.apiChanged, reason: 'a non-zero return code');
      expect(
        failure(_boardAnswer(const [], raw: const [0xFF, 0xFE, 0xFD])),
        HuyaFailureKind.apiChanged,
        reason: 'a tRsp that is not Tars at all',
      );
    });
  });

  group('the Tars wire itself', () {
    test('the scalars round-trip, and a singular field keeps its last value', () {
      final bytes =
          (TarsWriter()
                ..writeInt(0, -5)
                ..writeBool(1, value: true)
                ..writeString(2, '中文')
                ..writeDouble(3, 1.5)
                ..writeBytes(4, const [1, 2, 3])
                ..writeString(2, 'second'))
              .toBytes();
      final struct = TarsStruct.decode(bytes);
      expect(struct.integer(0), -5);
      expect(struct.fields[1], 1, reason: 'a bool is a one-byte integer on this wire');
      expect(struct.fields[3], 1.5);
      expect(struct.string(2), 'second');
      expect(struct.bytes(4), [1, 2, 3]);
      expect(struct.fields.containsKey(99), isFalse);
      expect(struct.integer(2), isNull, reason: 'a string is not read as a number');
    });

    test('a nested struct, a list and a map keep their shapes', () {
      final bytes =
          (TarsWriter()
                ..writeStruct(
                  0,
                  (inner) => inner
                    ..writeInt(1, 7)
                    ..writeString(2, 'x'),
                )
                ..writeList<int>(1, [1, 2], (writer, value) => writer.writeInt(0, value))
                ..writeMap<String, int>(
                  2,
                  {'a': 1},
                  key: (writer, key) => writer.writeString(0, key),
                  value: (writer, value) => writer.writeInt(1, value),
                ))
              .toBytes();
      final struct = TarsStruct.decode(bytes);
      expect(struct.struct(0)?.integer(1), 7);
      expect(struct.struct(0)?.string(2), 'x');
      expect(struct.list(1), [1, 2]);
      expect(struct.map(2), {'a': 1});
      expect(struct.struct(1), isNull, reason: 'a list is not a struct');
    });

    test('a truncated field is a format failure, not a partial read', () {
      final bytes = (TarsWriter()..writeString(0, 'hello')).toBytes();
      expect(() => TarsStruct.decode(bytes.sublist(0, bytes.length - 2)), throwsA(isA<FormatException>()));
      expect(() => TarsStruct.decode(const [0x00]), throwsA(isA<FormatException>()));
      expect(
        () => TarsStruct.decode((TarsWriter()..writeStruct(0, (w) => w.writeInt(1, 2))).toBytes().sublist(0, 2)),
        throwsA(isA<FormatException>()),
        reason: 'a structure that never ends',
      );
    });

    test('a WUP packet keeps its parameters and its code', () {
      final packet = WupPacket(
        servant: 'wupui',
        function: 'getHeadLineMessageBoard',
        params: {'': WupPacket.intParam(0), 'tReq': WupPacket.structParam((w) => w.writeInt(0, 5))},
        requestId: 12,
      );
      final decoded = WupPacket.decode(packet.encode());
      expect(decoded.servant, 'wupui');
      expect(decoded.function, 'getHeadLineMessageBoard');
      expect(decoded.requestId, 12);
      expect(decoded.code, 0);
      expect(decoded.struct('tReq')?.integer(0), 5);
      expect(decoded.struct('missing'), isNull);
      expect(
        WupPacket.decode(WupPacket(servant: 's', function: 'f', params: {'': WupPacket.intParam(2)}).encode()).code,
        2,
        reason: "the empty parameter name is huya's return code",
      );
      expect(() => WupPacket.decode(const [0, 0, 0, 4, 0xFF]), throwsA(isA<FormatException>()));
    });
  });
}

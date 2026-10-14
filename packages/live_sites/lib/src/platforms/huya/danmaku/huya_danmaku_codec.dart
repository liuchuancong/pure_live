import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/huya/huya_tars.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_json.dart';

/// What one Huya server frame held: its messages in receive order, and the
/// streamer uids of its stream-end notices (uri 8001; `0` when a notice names
/// none, which still ends this room's run).
typedef HuyaDanmakuFrame = ({List<LiveMessage> messages, List<int> ended});

/// Huya's danmaku protocol (the Tars codec of the web client), without I/O.
///
/// Every frame is a bare Tars structure (no length prefix): tag 0 the command,
/// tag 1 its payload bytes. The client registers the streamer's groups
/// (command 16) and sends heartbeats (command 20); the server pushes single
/// messages (command 7: tag 1 uri, tag 2 body, tag 5 message id) and batches
/// for one group (command 22: tag 1 items of tag 0 uri, tag 1 body, tag 2
/// message id). Chat is uri 1400, popularity uri 8006, a gift uri 6501, a stream
/// end uri 8001 and a headline super chat uri 2001314. A headline push carries
/// the board's panel (`GameEventMessageBoardPanel`); its entries become super
/// chats, timed from the moment the frame is read.
abstract final class HuyaDanmakuProtocol {
  /// Heartbeat period (60 000 ms); a socket silent for three periods (180 s)
  /// is replaced.
  static const Duration heartbeatInterval = Duration(seconds: 60);

  /// `EWSCmdC2S_RegisterGroupReq`.
  static const int registerCommand = 16;

  /// `EWSCmdC2S_HeartBeatReq`.
  static const int heartbeatCommand = 20;

  /// A single push (`WSPushMessage`).
  static const int pushCommand = 7;

  /// A batch of pushes for one group (`WSPushMessage_V2`).
  static const int batchCommand = 22;

  /// Chat (`MessageNotice`).
  static const int chatUri = 1400;

  /// Popularity (`AttendeeCountNotice`): a heat figure, not concurrent
  /// viewers.
  static const int popularityUri = 8006;

  /// A gift sent in this room (`SendItemSubBroadcastPacket`).
  static const int giftUri = 6501;

  /// The stream ended (`EndLiveNotice`: tag 0 lPresenterUid).
  static const int endUri = 8001;

  /// A headline super chat (`GameEventMessageBoardPanel`): the board's entries,
  /// each a paid message pinned for its remaining seconds.
  static const int superChatUri = 2001314;

  /// The top colour of a Huya super chat's card (the web client's fixed banner).
  static const String superChatTop = '#ffffff';

  /// The bottom colour of a Huya super chat's card.
  static const String superChatBottom = '#246488';

  /// The groups a connection registers for streamer [uid].
  static List<String> groups(int uid) => ['live:$uid', 'chat:$uid'];

  /// Command 16 registering [groups] of streamer [uid]: the payload is tag 0
  /// the group list, tag 1 an empty token.
  static Uint8List register(int uid) {
    final payload = TarsWriter()
      ..writeList<String>(0, groups(uid), (writer, group) => writer.writeString(0, group))
      ..writeString(1, '');
    return (TarsWriter()
          ..writeInt(0, registerCommand)
          ..writeBytes(1, payload.toBytes()))
        .toBytes();
  }

  /// Command 20 with an empty payload.
  static Uint8List heartbeat() =>
      (TarsWriter()
            ..writeInt(0, heartbeatCommand)
            ..writeBytes(1, const []))
          .toBytes();

  /// The messages of one server [frame]: chat, popularity, gifts and headline
  /// super chats from commands 7 and 22, plus the streamer uids of stream-end
  /// notices. A super chat's window is timed from [now] (default the clock).
  /// Other commands and uris are ignored; a frame that is not Tars gives
  /// nothing, and an item whose body fails to decode is skipped without losing
  /// the others.
  static HuyaDanmakuFrame decode(List<int> frame, {DateTime? now}) {
    final messages = <LiveMessage>[];
    final ended = <int>[];
    void item(int uri, Uint8List? body, int eventId) {
      try {
        switch (uri) {
          case endUri:
            ended.add(TarsStruct.decode(body ?? const <int>[]).integer(0) ?? 0);
          case superChatUri:
            messages.addAll(superChatPush(body, now ?? DateTime.now()));
          case chatUri:
            final message = chat(body, eventId);
            if (message != null) messages.add(message);
          case popularityUri:
            final message = popularity(body, eventId);
            if (message != null) messages.add(message);
          case giftUri:
            final message = gift(body, eventId);
            if (message != null) messages.add(message);
        }
      } on FormatException {
        // A malformed item is skipped; the rest of the frame survives.
      }
    }

    try {
      final outer = TarsStruct.decode(frame);
      final payload = outer.bytes(1);
      switch (outer.integer(0)) {
        case pushCommand:
          final push = TarsStruct.decode(payload ?? const <int>[]);
          item(push.integer(1) ?? 0, push.bytes(2), push.integer(5) ?? 0);
        case batchCommand:
          final batch = TarsStruct.decode(payload ?? const <int>[]);
          for (final entry in batch.list(1)) {
            if (entry is! TarsStruct) continue;
            item(entry.integer(0) ?? 0, entry.bytes(1), entry.integer(2) ?? 0);
          }
      }
    } on FormatException {
      // A frame that is not Tars: drop it whole.
    }
    return (messages: messages, ended: ended);
  }

  /// The colour of a chat's `iFontColor`: 0 or less (-1 is the default) is
  /// white, anything else goes through [LiveMessageColor.numberToColor].
  static LiveMessageColor color(int fontColor) =>
      fontColor <= 0 ? LiveMessageColor.white : LiveMessageColor.numberToColor(fontColor);

  /// The message id of a push (`huya:{id}`): its `lMsgId` (tag 5 of a single
  /// push, tag 2 of a batch item); empty for 0 or less.
  static String messageId(int eventId) => eventId > 0 ? 'huya:$eventId' : '';

  /// The combo key of a gift from sender [uid] with `lComboSeqId` [sequence]:
  /// every packet of one combo carries the same sequence id (the time the
  /// combo began, in ms), so the sender is part of the key. Empty without a
  /// sequence id.
  static String comboKey(int uid, int sequence) => sequence > 0 ? '$uid:$sequence' : '';

  /// uri 1400 (`MessageNotice`): tag 0 the sender (tag 0 uid, tag 2 nick), tag
  /// 3 the text, tag 6 the bullet format (tag 0 colour). A chat with empty
  /// text is dropped; missing fields read as defaults.
  static LiveMessage? chat(Uint8List? body, int eventId) {
    final notice = TarsStruct.decode(body ?? const <int>[]);
    final text = notice.string(3) ?? '';
    if (text.isEmpty) return null;
    final sender = notice.struct(0);
    return LiveMessage.normalized(
      text: text,
      sender: MessageSender.normalized(userId: '${sender?.integer(0) ?? 0}', userName: sender?.string(2) ?? ''),
      color: color(notice.struct(6)?.integer(0) ?? 0),
      messageId: messageId(eventId),
    );
  }

  /// uri 8006 (`AttendeeCountNotice`): tag 0 `iAttendeeCount`, an audience
  /// update of popularity (a heat figure, never concurrent viewers).
  static LiveMessage? popularity(Uint8List? body, int eventId) => LiveMessage.normalized(
    type: LiveMessageType.audienceUpdate,
    color: LiveMessageColor.white,
    messageId: messageId(eventId),
    payload: LiveAudienceUpdate(
      kind: LiveAudienceSignalKind.popularity,
      value: TarsStruct.decode(body ?? const <int>[]).integer(0) ?? 0,
    ),
  );

  /// uri 6501 (`SendItemSubBroadcastPacket`): tag 0 `iItemType`, 2
  /// `iItemCount`, 4 `lSenderUid`, 6 `sSenderNick`, 9 `iItemGroup` (the combo
  /// counter), 20 `sPropsName`, 39 `lComboSeqId`, 41 `lPayTotal`. A gift
  /// without a name is not reported (the price rides in the packet, so no
  /// external catalogue is needed). The text is `虎粮 ×1`.
  static LiveMessage? gift(Uint8List? body, int eventId) {
    final packet = TarsStruct.decode(body ?? const <int>[]);
    final name = (packet.string(20) ?? '').trim();
    if (name.isEmpty) return null;
    final count = packet.integer(2) ?? 0;
    final combo = packet.integer(9) ?? 0;
    final payTotal = packet.integer(41) ?? 0;
    final id = packet.integer(0) ?? 0;
    final uid = packet.integer(4) ?? 0;
    final gift = LiveGift(
      giftId: id == 0 ? '' : '$id',
      name: name,
      count: count > 0 ? count : 1,
      value: LiveGiftValue(totalValue: payTotal > 0 ? payTotal.toDouble() : null),
      combo: LiveGiftCombo(comboKey: comboKey(uid, packet.integer(39) ?? 0), comboTotal: combo > 0 ? combo : null),
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: '${gift.name} ×${gift.count}',
      sender: MessageSender.normalized(userId: '$uid', userName: packet.string(6) ?? ''),
      color: LiveMessageColor.white,
      messageId: messageId(eventId),
      payload: gift,
    );
  }

  /// A headline push (uri 2001314): the board panel's entries as super chats,
  /// timed from [now]. Empty when [body] is missing, not a panel, or without the
  /// entry list at tag 1 (a notice-only push, whose board a later fetch reads).
  static List<LiveMessage> superChatPush(List<int>? body, DateTime now) {
    if (body == null || body.isEmpty) return const [];
    final TarsStruct panel;
    try {
      panel = TarsStruct.decode(body);
    } on FormatException {
      return const [];
    }
    if (panel.fields[1] is! List) return const [];
    return [for (final entry in _panel(panel, now)) superChatMessage(entry)];
  }

  /// The board panel's entries (tag 1): 0 user (1 nick, 2 avatar), 1 content,
  /// 2 iCost, 4 iTotalSec, 5 iCountDown, 9 lMessageId, 12 iCostPay. An entry
  /// without text or time left is dropped; the window ends the countdown (or the
  /// total) seconds after [now] and starts the total before. The price is iCost,
  /// else iCostPay / 100 (at least 1). The id is `huya:{lMessageId}`, so an event
  /// rebuilt on every poll stays one message.
  static List<LiveSuperChatMessage> _panel(TarsStruct panel, DateTime now) {
    final entries = <LiveSuperChatMessage>[];
    for (final raw in panel.list(1)) {
      if (raw is! TarsStruct) continue;
      final content = (raw.string(1) ?? '').trim();
      final total = raw.integer(4) ?? 0;
      final countdown = raw.integer(5) ?? 0;
      final remaining = countdown > 0 ? countdown : total;
      if (content.isEmpty || remaining <= 0) continue;
      final cost = raw.integer(2) ?? 0;
      final paid = raw.integer(12) ?? 0;
      final id = raw.integer(9) ?? 0;
      final user = raw.struct(0);
      final end = now.add(Duration(seconds: remaining));
      entries.add(
        LiveSuperChatMessage(
          messageId: id > 0 ? 'huya:$id' : '',
          userName: (user?.string(1) ?? '').trim(),
          faceUrl: normalizeImageUrl(user?.string(2)),
          text: content,
          price: SuperChatPrice(amount: cost > 0 ? cost : (paid > 0 ? max(1, (paid / 100).round()) : cost)),
          startTime: end.subtract(Duration(seconds: total > 0 ? total : remaining)),
          endTime: end,
          display: const SuperChatDisplay(backgroundColor: superChatTop, backgroundBottomColor: superChatBottom),
        ),
      );
    }
    return entries;
  }

  /// One board entry as a super-chat message (the payload rides along for the
  /// board's own view).
  static LiveMessage superChatMessage(LiveSuperChatMessage data) => LiveMessage.normalized(
    type: LiveMessageType.superChat,
    text: data.text,
    sender: MessageSender.normalized(userName: data.userName, avatarUrl: data.faceUrl.isEmpty ? null : data.faceUrl),
    color: LiveMessageColor.white,
    messageId: data.messageId,
    sentAt: data.startTime,
    payload: data,
  );
}

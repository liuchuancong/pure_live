import 'dart:typed_data';

import 'package:live_sites/src/common/tars/tars.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';

/// What one Huya server frame held: its messages in order, and the streamer
/// uids of its stream-end notices (0 when a notice names none).
typedef HuyaDanmakuFrame = ({List<LiveMessage> messages, List<int> ended});

/// Huya's danmaku protocol, without I/O.
///
/// Every frame is a Tars structure: tag 0 the command, tag 1 its payload
/// bytes. The client registers the streamer's groups (command 16) and sends
/// heartbeats (command 20); the server pushes single messages (command 7: tag 1
/// uri, tag 2 body, tag 5 message id) and batches (command 22: tag 1 items of
/// tag 0 uri, tag 1 body, tag 2 message id). Chat is uri 1400, popularity uri
/// 8006, a gift uri 6501 and the stream end uri 8001.
///
/// Mapped onto this tree's models: a gift is a [LiveGift] of its name, count,
/// paid total and combo key (the combo counter and gift id have no field); a
/// chat colour is an int (white for none); the audience is a
/// [LiveAudienceUpdate]; a message id is `id`. The headline (super chat) board
/// (uri 2001314) is **not read yet**: its board panel and the background board
/// fetch are a separate follow-up, so those notices are ignored here.
abstract final class HuyaDanmakuProtocol {
  /// The only endpoint.
  static final Uri endpoint = Uri.parse('wss://wsapi.huya.com');

  /// Heartbeat period.
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

  /// The stream ended (`EndLiveNotice`: 0 lPresenterUid, …).
  static const int endUri = 8001;

  /// The headline (super chat) board notice — recognised and skipped until its
  /// board reader lands.
  static const int superChatUri = 2001314;

  /// The detail of the run's end at the stream end.
  static const String broadcastEnded = 'Broadcast ended';

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

  /// The messages of one server [frame]: chat, popularity and gifts from
  /// commands 7 and 22, and the streamer uid of each stream-end notice. A
  /// headline (super chat) notice is skipped; other commands and uris give
  /// nothing; a frame that is not Tars gives nothing, and an item whose body
  /// fails to decode is skipped without losing the others.
  static HuyaDanmakuFrame decode(List<int> frame) {
    final messages = <LiveMessage>[];
    final ended = <int>[];
    void item(int uri, Uint8List? body, int eventId) {
      if (uri == endUri) {
        try {
          ended.add(TarsStruct.decode(body ?? const []).integer(0) ?? 0);
        } on FormatException {
          // Not an end notice.
        }
        return;
      }
      if (uri == superChatUri) return; // board reader not migrated yet.
      try {
        final message = switch (uri) {
          chatUri => _chat(body, eventId),
          popularityUri => _popularity(body, eventId),
          giftUri => gift(body, eventId),
          _ => null,
        };
        if (message != null) messages.add(message);
      } on FormatException {
        // A malformed item loses only itself.
      }
    }

    try {
      final outer = TarsStruct.decode(frame);
      final payload = outer.bytes(1);
      switch (outer.integer(0)) {
        case pushCommand:
          final push = TarsStruct.decode(payload ?? const []);
          item(push.integer(1) ?? 0, push.bytes(2), push.integer(5) ?? 0);
        case batchCommand:
          final batch = TarsStruct.decode(payload ?? const []);
          for (final entry in batch.list(1)) {
            if (entry is! TarsStruct) continue;
            item(entry.integer(0) ?? 0, entry.bytes(1), entry.integer(2) ?? 0);
          }
      }
    } on FormatException {
      // A frame that is not Tars.
    }
    return (messages: messages, ended: ended);
  }

  /// The colour of a chat's `iFontColor`: 0 or less (-1 is the default) is
  /// white, anything else the value itself.
  static int color(int fontColor) => fontColor <= 0 ? 0xFFFFFF : fontColor & 0xFFFFFF;

  /// The message id of a push (`huya:{id}`): its `lMsgId`, the same on every
  /// connection to the room; 0 or less means none.
  static String _messageId(int eventId) => eventId > 0 ? 'huya:$eventId' : '';

  /// uri 1400 (`MessageNotice`): tag 0 the sender (tag 0 uid, tag 2 nick), tag
  /// 3 the text, tag 6 the bullet format (tag 0 colour).
  static LiveMessage? _chat(Uint8List? body, int eventId) {
    final notice = TarsStruct.decode(body ?? const []);
    final sender = notice.struct(0);
    final id = _messageId(eventId);
    return LiveMessage(
      type: LiveMessageType.chat,
      color: color(notice.struct(6)?.integer(0) ?? 0),
      message: notice.string(3) ?? '',
      userName: sender?.string(2) ?? '',
      userId: '${sender?.integer(0) ?? 0}',
      id: id.isEmpty ? null : id,
    );
  }

  /// The combo key of a gift from sender [uid] with `lComboSeqId` [sequence]:
  /// every packet of one combo carries the same sequence id, so the sender is
  /// part of the key. Empty without a sequence id.
  static String comboKey(int uid, int sequence) => sequence > 0 ? '$uid:$sequence' : '';

  /// uri 6501 (`SendItemSubBroadcastPacket`): tag 0 `iItemType`, 2
  /// `iItemCount`, 4 `lSenderUid`, 6 `sSenderNick`, 9 `iItemGroup` (the combo
  /// counter), 20 `sPropsName`, 39 `lComboSeqId`, 41 `lPayTotal`. A gift without
  /// a name is not reported (the gift table is not loaded). The combo counter
  /// and the gift id have no field here; the paid total and combo key do.
  static LiveMessage? gift(Uint8List? body, int eventId) {
    final packet = TarsStruct.decode(body ?? const []);
    final name = (packet.string(20) ?? '').trim();
    if (name.isEmpty) return null;
    final count = packet.integer(2) ?? 0;
    final payTotal = packet.integer(41) ?? 0;
    final uid = packet.integer(4) ?? 0;
    final key = comboKey(uid, packet.integer(39) ?? 0);
    final id = _messageId(eventId);
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: packet.string(6) ?? '',
      userId: '$uid',
      message: '$name ×${count > 0 ? count : 1}',
      color: 0xFFFFFF,
      id: id.isEmpty ? null : id,
      data: LiveGift(
        name: name,
        count: count > 0 ? count : 1,
        totalValue: payTotal > 0 ? payTotal : null,
        combo: key.isEmpty ? null : key,
      ),
    );
  }

  /// uri 8006 (`AttendeeCountNotice`): tag 0 `iAttendeeCount`, a heat figure.
  /// This tree has no popularity metric, so the heat rides in `watching`.
  static LiveMessage? _popularity(Uint8List? body, int eventId) {
    final heat = TarsStruct.decode(body ?? const []).integer(0) ?? 0;
    final id = _messageId(eventId);
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      userName: '',
      message: '',
      id: id.isEmpty ? null : id,
      data: LiveAudienceUpdate(watching: heat),
    );
  }
}

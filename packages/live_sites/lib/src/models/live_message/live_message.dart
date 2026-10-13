// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_badge/live_badge.dart';
import 'package:live_sites/src/models/live_emote/live_emote.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/live_message_style/live_message_style.dart';
import 'package:live_sites/src/models/live_message_type/live_message_type.dart';
import 'package:meta/meta.dart';

/// One danmaku message.
@immutable
final class LiveMessage {
  /// Creates a message.
  const LiveMessage({
    required this.type,
    required this.userName,
    required this.message,
    required this.color,
    this.userId = '',
    this.data,
    this.userLevel = '',
    this.fansLevel = '',
    this.fansName = '',
    this.isLocal = false,
    this.messageId = '',
    this.sentAt,
    this.style,
    this.replayed = false,
    this.emotes = const [],
    this.sourceRoomId = '',
    this.nameColor,
    this.badges = const [],
  });

  /// Kind.
  final LiveMessageType type;

  /// Sender name.
  final String userName;

  /// Sender id.
  final String userId;

  /// Text.
  final String message;

  /// For [LiveMessageType.online] a `LiveAudienceUpdate` (older engines may send
  /// a number); for [LiveMessageType.gift] a [LiveGift].
  final Object? data;

  /// Colour.
  final LiveMessageColor color;

  /// Sender level.
  final String userLevel;

  /// Fan badge level.
  final String fansLevel;

  /// Fan badge name.
  final String fansName;

  /// Composed on this device.
  final bool isLocal;

  /// The platform's id for the message, when it has one: suppresses packets
  /// replayed after a reconnect without merging two genuine identical texts.
  final String messageId;

  /// The platform's timestamp; null when it has none (reception order then).
  final DateTime? sentAt;

  /// Presentation of a local message.
  final LiveMessageStyle? style;

  /// Not something that just happened: sent again after a reconnect resumed the
  /// chat, or a backlog the platform gives on joining.
  final bool replayed;

  /// The pictures the platform names for codes in [message], each code once;
  /// empty when it names none.
  final List<LiveEmote> emotes;

  /// The room the message was said in when it is not the room joined, as the
  /// platform names it (Kugou's PK partner); empty for this room.
  final String sourceRoomId;

  /// The colour the platform gives the sender's name (17LIVE's `name.textColor`);
  /// null for the chat's default.
  final LiveMessageColor? nameColor;

  /// The badges the platform shows next to the sender's name, in its order; empty
  /// when it shows none.
  final List<LiveBadge> badges;

  /// [data] when it is a [LiveGift]; null for other kinds and for local gifts.
  LiveGift? get gift => switch (data) {
    final LiveGift gift => gift,
    _ => null,
  };

  /// Whether [sourceRoomId] names another room.
  bool get isFromOtherRoom => sourceRoomId.isNotEmpty;
}

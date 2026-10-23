// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_message_style/live_message_style.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_message.g.dart';

/// One danmaku message.
///
/// [payload]'s concrete type follows [type] — the contract is MODELS.md §5
/// (gift → LiveGift, audienceUpdate → LiveAudienceUpdate, retraction →
/// LiveRetraction, notice → LiveNoticeKind, everything else null);
/// [payload] and [style] are runtime-only and never serialized.
/// [messageId] suppresses packets a platform replays after a reconnect
/// without merging two genuine identical texts; [replayed] marks a backlog
/// or replay as not-live-happening; [sourceRoomId] names the real room of a
/// cross-room message (a PK partner room), `''` for the joined room.
abstract class LiveMessage implements Built<LiveMessage, LiveMessageBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveMessage([void Function(LiveMessageBuilder)? updates]) = _$LiveMessage;

  /// The normalized-fields constructor; construct through
  /// [LiveMessage.normalized] unless the caller normalized upstream.
  factory LiveMessage.of({
    required LiveMessageType type,
    String text = '',
    MessageSender? sender,
    LiveMessageColor? color,
    LiveMessageStyle? style,
    Object? payload,
    List<LiveEmote> emotes = const [],
    String messageId = '',
    DateTime? sentAt,
    DateTime? createdAt,
    bool isLocal = false,
    bool replayed = false,
    String sourceRoomId = '',
  }) => LiveMessage(
    (b) => b
      ..type = type
      ..text = text
      ..sender = sender?.toBuilder()
      ..color = color
      ..style = style
      ..payload = payload
      ..emotes.replace(emotes)
      ..messageId = messageId
      ..sentAt = sentAt
      ..createdAt = createdAt
      ..isLocal = isLocal
      ..replayed = replayed
      ..sourceRoomId = sourceRoomId,
  );

  LiveMessage._();

  /// Deserializes a stored JSON record.
  factory LiveMessage.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveMessage.serializer, json)!;

  /// Adapter entry point: normalizes text once and delegates.
  factory LiveMessage.normalized({
    LiveMessageType type = LiveMessageType.chat,
    String text = '',
    MessageSender? sender,
    LiveMessageColor? color,
    LiveMessageStyle? style,
    Object? payload,
    List<LiveEmote> emotes = const [],
    String messageId = '',
    DateTime? sentAt,
    DateTime? createdAt,
    bool isLocal = false,
    bool replayed = false,
    String sourceRoomId = '',
  }) => LiveMessage.of(
    type: type,
    text: text.trim(),
    sender: sender,
    color: color,
    style: style,
    payload: payload,
    emotes: emotes,
    messageId: messageId,
    sentAt: sentAt,
    createdAt: createdAt,
    isLocal: isLocal,
    replayed: replayed,
    sourceRoomId: sourceRoomId,
  );

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveMessage> get serializer => _$liveMessageSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveMessageBuilder b) => b
    ..text = ''
    ..messageId = ''
    ..sourceRoomId = ''
    ..isLocal = false
    ..replayed = false;

  /// What kind of message this is.
  LiveMessageType get type;

  /// The message's text.
  String get text;

  /// Who sent it, when the platform says so.
  @BuiltValueField(serialize: false)
  MessageSender? get sender;

  /// The text color the platform gave.
  LiveMessageColor? get color;

  /// The locally composed presentation; runtime-only.
  @BuiltValueField(serialize: false)
  LiveMessageStyle? get style;

  /// The typed payload [type] names; runtime-only.
  @BuiltValueField(serialize: false)
  Object? get payload;

  /// The picture emotes named in [text].
  BuiltList<LiveEmote> get emotes;

  /// The platform's dedup id, `''` when it sends none.
  String get messageId;

  /// When the platform sent the message.
  DateTime? get sentAt;

  /// When this record was created locally.
  DateTime? get createdAt;

  /// Whether the message was composed on this device.
  bool get isLocal;

  /// Whether the message is a replay, not live-happening.
  bool get replayed;

  /// The real room of a cross-room message, `''` for the joined room.
  String get sourceRoomId;

  /// Query helpers for [LiveMessage].
}

/// Query helpers for [LiveMessage].
extension LiveMessageQuery on LiveMessage {
  /// The message color; white when the platform gave none.
  LiveMessageColor get effectiveColor => color ?? LiveMessageColor.white;

  /// The sender; an empty system sender when none was given.
  MessageSender get effectiveSender => sender ?? MessageSender();

  /// Whether [sourceRoomId] names a room other than the joined one.
  bool get isFromOtherRoom => sourceRoomId.isNotEmpty;

  /// [payload] when this is a gift message; null otherwise.
  Object? get giftOrNull => switch (payload) {
    final p when type == LiveMessageType.gift => p,
    _ => null,
  };
}

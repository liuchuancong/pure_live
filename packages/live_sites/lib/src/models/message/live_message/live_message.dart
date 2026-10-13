import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_message_style/live_message_style.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_message.freezed.dart';
part 'live_message.g.dart';

/// One danmaku message.
///
/// [payload]'s concrete type follows [type] — the contract is MODELS.md §5
/// (gift → LiveGift, audienceUpdate → LiveAudienceUpdate, retraction →
/// LiveRetraction, notice → LiveNoticeKind, everything else null).
/// [messageId] suppresses packets a platform replays after a reconnect
/// without merging two genuine identical texts; [replayed] marks a backlog
/// or replay as not-live-happening; [sourceRoomId] names the real room of a
/// cross-room message (a PK partner room), `''` for the joined room.
@freezed
abstract class LiveMessage with _$LiveMessage {
  /// The normalized-fields constructor (code generation and copyWith
  /// target); construct through [LiveMessage.normalized] unless the caller
  /// normalized upstream.
  const factory LiveMessage({
    required LiveMessageType type,
    @Default('') String text,
    MessageSender? sender,
    LiveMessageColor? color,
    @JsonKey(includeFromJson: false, includeToJson: false) LiveMessageStyle? style,
    Object? payload,
    @Default([]) List<LiveEmote> emotes,
    @Default('') String messageId,
    DateTime? sentAt,
    DateTime? createdAt,
    @Default(false) bool isLocal,
    @Default(false) bool replayed,
    @Default('') String sourceRoomId,
  }) = _LiveMessage;

  /// Deserializes a stored JSON record.
  factory LiveMessage.fromJson(Map<String, Object?> json) => _$LiveMessageFromJson(json);

  /// Adapter entry point: normalizes text once and delegates.
  factory LiveMessage.normalized({
    LiveMessageType type = LiveMessageType.chat,
    String text = '',
    MessageSender? sender,
    LiveMessageColor? color,
    @JsonKey(includeFromJson: false, includeToJson: false) LiveMessageStyle? style,
    Object? payload,
    List<LiveEmote> emotes = const [],
    String messageId = '',
    DateTime? sentAt,
    DateTime? createdAt,
    bool isLocal = false,
    bool replayed = false,
    String sourceRoomId = '',
  }) => LiveMessage(
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
}

/// Query helpers for [LiveMessage].
///
/// A separate extension because freezed cannot implement a private
/// generative constructor next to the required `type` parameter.
extension LiveMessageQuery on LiveMessage {
  /// The message color; white when the platform gave none.
  LiveMessageColor get effectiveColor => color ?? LiveMessageColor.white;

  /// The sender; an empty system sender when none was given.
  MessageSender get effectiveSender => sender ?? const MessageSender();

  /// Whether [sourceRoomId] names a room other than the joined one.
  bool get isFromOtherRoom => sourceRoomId.isNotEmpty;

  /// [payload] when this is a gift message; null otherwise.
  Object? get giftOrNull => switch (payload) {
    final p when type == LiveMessageType.gift => p,
    _ => null,
  };
}

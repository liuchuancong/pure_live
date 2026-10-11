import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_message.freezed.dart';
part 'live_message.g.dart';

/// The kind of a danmaku stream message.
enum LiveMessageType {
  /// A normal chat bullet.
  chat,

  /// A gift event.
  gift,

  /// A super chat (paid highlight).
  superChat,

  /// A viewer-count or watcher-list update.
  audienceUpdate,

  /// A message recall (single message).
  recall,

  /// A room-level notice (title change, stream start…).
  notice,

  /// A subscription or gifted-subscription event.
  subscription,
}

/// A danmaku stream message, already normalized to the common model.
///
/// Platform decoders map their wire format into this; UI never sees
/// platform packets. [data] is a runtime payload (a `LiveGift` for gift
/// messages, a `LiveAudienceUpdate` for audience updates) and never
/// enters JSON.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveMessage with _$LiveMessage {
  /// A stream message; [id] dedupes repeats when the platform provides
  /// one.
  const factory LiveMessage({
    required LiveMessageType type,
    required String userName,
    required String message,
    String? userId,
    String? id,
    int? color,
    @Default(<LiveEmote>[]) List<LiveEmote> emotes,
    DateTime? sentAt,
    @JsonKey(includeToJson: false, includeFromJson: false) Object? data,
  }) = _LiveMessage;

  /// Restores a message from JSON (the runtime `data` is not restored).
  factory LiveMessage.fromJson(Map<String, Object?> json) => _$LiveMessageFromJson(json);
}

/// An inline emote: text placeholder plus the image that replaces it.
@freezed
abstract class LiveEmote with _$LiveEmote {
  /// An emote shown where [code] appears inside the message text.
  const factory LiveEmote({required String code, required String url}) = _LiveEmote;

  /// Restores an emote from JSON.
  factory LiveEmote.fromJson(Map<String, Object?> json) => _$LiveEmoteFromJson(json);
}

/// A badge shown before the sender name (fan club, guard, title).
@freezed
abstract class LiveBadge with _$LiveBadge {
  /// A badge with [name] and its display [color].
  const factory LiveBadge({required String name, int? color}) = _LiveBadge;

  /// Restores a badge from JSON.
  factory LiveBadge.fromJson(Map<String, Object?> json) => _$LiveBadgeFromJson(json);
}

import 'package:meta/meta.dart';

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
/// platform packets.
@immutable
final class LiveMessage {
  /// A stream message; [id] dedupes repeats when the platform provides
  /// one.
  const new({
    required this.type,
    required this.userName,
    required this.message,
    this.userId,
    this.id,
    this.color,
    this.emotes = const [],
    this.sentAt,
    this.data,
  });

  /// Which kind of message this is.
  final LiveMessageType type;

  /// Sender display name.
  final String userName;

  /// Sender platform id, when the platform exposes one.
  final String? userId;

  /// Message text (chat), gift name (gift), notice text (notice)…
  final String message;

  /// Stable message id for dedupe, when the platform provides one.
  final String? id;

  /// Danmaku color as an ARGB int, when the platform allows colors.
  final int? color;

  /// Inline emotes referenced by this message.
  final List<LiveEmote> emotes;

  /// When the platform timestamped the message.
  final DateTime? sentAt;

  /// The typed payload for structured kinds: `LiveGift` for
  /// [LiveMessageType.gift], `LiveAudienceUpdate` for audience updates.
  final Object? data;

  @override
  String toString() => 'LiveMessage(${type.name}, $userName: $message)';
}

/// An inline emote: text placeholder plus the image that replaces it.
@immutable
final class LiveEmote {
  /// An emote shown where [code] appears inside the message text.
  const new({required this.code, required this.url});

  /// The literal placeholder, e.g. `[dog]`.
  final String code;

  /// The image URL.
  final String url;
}

/// A badge shown before the sender name (fan club, guard, title).
@immutable
final class LiveBadge {
  /// A badge with [name] and its display [color].
  const new({required this.name, this.color});

  /// Badge text.
  final String name;

  /// Badge background as an ARGB int.
  final int? color;
}

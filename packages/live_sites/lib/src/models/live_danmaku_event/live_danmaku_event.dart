import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_danmaku_event.freezed.dart';

/// The kind of a normalized danmaku event.
enum LiveDanmakuEventType {
  /// A chat message.
  message,

  /// A gift.
  gift,

  /// A like or reaction.
  like,

  /// A membership or join event.
  member,

  /// A room-status change (live, offline).
  roomStatus,

  /// Anything else the protocol adaptation did not map.
  unknown,
}

/// A platform-independent danmaku event produced by a protocol adaptation.
/// Unmapped platform fields live in [metadata] rather than being dropped.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveDanmakuEvent with _$LiveDanmakuEvent {
  /// Creates an event for [siteId]'s [roomId] of [type], received at
  /// [receivedAt], with the optional fields the platform supplied.
  const factory LiveDanmakuEvent({
    required String siteId,
    required String roomId,
    required LiveDanmakuEventType type,
    required DateTime receivedAt,
    String? userId,
    String? userName,
    String? text,
    num? value,
    @Default({}) Map<String, Object?> metadata,
  }) = _LiveDanmakuEvent;
}

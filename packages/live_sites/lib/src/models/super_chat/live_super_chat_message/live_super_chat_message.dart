import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_super_chat_message.freezed.dart';
part 'live_super_chat_message.g.dart';

/// One super chat (highlighted paid message) on the room's message board.
///
/// [messageId] is the dedup key: some board APIs rebuild `startTime` from a
/// countdown on every poll, so time-based equality would make the same paid
/// message look new. Empty on platforms without an event id — snapshots then
/// compare by user, text and price.
@freezed
abstract class LiveSuperChatMessage with _$LiveSuperChatMessage {
  /// Creates a LiveSuperChatMessage with already-normalized fields.
  const factory LiveSuperChatMessage({
    @Default('') String messageId,
    @Default('') String userName,
    @Default('') String faceUrl,
    @Default('') String text,
    @Default(SuperChatPrice()) SuperChatPrice price,
    DateTime? startTime,
    DateTime? endTime,
    @Default(SuperChatDisplay()) SuperChatDisplay display,
  }) = _LiveSuperChatMessage;

  /// Deserializes a stored JSON record.
  factory LiveSuperChatMessage.fromJson(Map<String, Object?> json) => _$LiveSuperChatMessageFromJson(json);
}

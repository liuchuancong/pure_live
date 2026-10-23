// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';

part 'live_super_chat_message.g.dart';

/// One super chat (highlighted paid message) on the room's message board.
///
/// [messageId] is the dedup key: some board APIs rebuild `startTime` from a
/// countdown on every poll, so time-based equality would make the same paid
/// message look new. Empty on platforms without an event id — snapshots then
/// compare by user, text and price.
abstract class LiveSuperChatMessage implements Built<LiveSuperChatMessage, LiveSuperChatMessageBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveSuperChatMessage([void Function(LiveSuperChatMessageBuilder)? updates]) = _$LiveSuperChatMessage;

  /// Creates a LiveSuperChatMessage with already-normalized fields.
  factory LiveSuperChatMessage.of({
    String messageId = '',
    String userName = '',
    String faceUrl = '',
    String text = '',
    SuperChatPrice? price,
    DateTime? startTime,
    DateTime? endTime,
    SuperChatDisplay? display,
  }) => LiveSuperChatMessage(
    (b) => b
      ..messageId = messageId
      ..userName = userName
      ..faceUrl = faceUrl
      ..text = text
      ..price.replace(price ?? SuperChatPrice())
      ..startTime = startTime
      ..endTime = endTime
      ..display.replace(display ?? SuperChatDisplay()),
  );

  LiveSuperChatMessage._();

  /// Deserializes a stored JSON record.
  factory LiveSuperChatMessage.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(LiveSuperChatMessage.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveSuperChatMessage> get serializer => _$liveSuperChatMessageSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveSuperChatMessageBuilder b) => b
    ..messageId = ''
    ..userName = ''
    ..faceUrl = ''
    ..text = ''
    ..price.replace(SuperChatPrice())
    ..display.replace(SuperChatDisplay());

  /// The dedup key, `''` on platforms without an event id.
  String get messageId;

  /// Who paid.
  String get userName;

  /// The payer's avatar.
  String get faceUrl;

  /// What was said.
  String get text;

  /// What was paid.
  SuperChatPrice get price;

  /// When the super chat started showing.
  DateTime? get startTime;

  /// When the super chat stops showing.
  DateTime? get endTime;

  /// The platform's presentation colors.
  SuperChatDisplay get display;
}

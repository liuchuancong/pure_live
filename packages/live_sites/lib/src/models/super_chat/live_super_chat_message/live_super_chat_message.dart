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
/// Two snapshots of one paid event can differ: some board APIs rebuild
/// `startTime` from a countdown on every poll, and the stream and the board
/// may both tell it. [isSameEventAs] says which messages are one event —
/// [messageId] when there is one, else the sender, text and price with the
/// start (or, for an estimated start, the display window). `==` stays the
/// value equality of every field.
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
    bool hasEstimatedStartTime = false,
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
      ..hasEstimatedStartTime = hasEstimatedStartTime
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
    ..hasEstimatedStartTime = false
    ..display.replace(SuperChatDisplay());

  /// The platform's event id, `''` on platforms without one.
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

  /// Whether [startTime] was rebuilt from a countdown when the board was
  /// read rather than taken from the event (Huya's board: each read puts the
  /// start at its own clock less the time shown), so it drifts from read to
  /// read; false for a platform's event time.
  bool get hasEstimatedStartTime;

  /// The platform's presentation colors.
  SuperChatDisplay get display;

  /// Whether [other] is the same paid event, for folding the board's reads
  /// and the stream into one card each.
  ///
  /// An id is authoritative: when either has one, only equal ids match.
  /// Without ids the sender, text and price must agree, and the start too;
  /// when either start is estimated ([hasEstimatedStartTime]), display
  /// windows that overlap are enough, since a drifting start is the same
  /// purchase while a later window is a new one. Overlap is not transitive,
  /// so this is deliberately not `==`: fold a list with it, not a set.
  bool isSameEventAs(LiveSuperChatMessage other) {
    if (messageId.isNotEmpty || other.messageId.isNotEmpty) return messageId == other.messageId;
    if (userName != other.userName || text != other.text || price != other.price) return false;
    final start = startTime;
    final otherStart = other.startTime;
    if (start == null || otherStart == null) return start == otherStart;
    if (start.isAtSameMomentAs(otherStart)) return true;
    if (!hasEstimatedStartTime && !other.hasEstimatedStartTime) return false;
    final end = endTime;
    final otherEnd = other.endTime;
    return end != null && otherEnd != null && start.isBefore(otherEnd) && otherStart.isBefore(end);
  }
}

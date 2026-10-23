// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_gift.g.dart';

/// One gift event.
///
/// [count] is how many were sent in this hit; the run's accumulated total
/// lives in [combo]. [recipientName] names the receiving streamer of a
/// cross-room gift (a PK partner); `''` means the current streamer.
abstract class LiveGift implements Built<LiveGift, LiveGiftBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveGift([void Function(LiveGiftBuilder)? updates]) = _$LiveGift;

  /// Creates a LiveGift with already-normalized fields.
  factory LiveGift.of({
    String giftId = '',
    String name = '',
    String? iconUrl,
    LiveGiftKind kind = LiveGiftKind.normal,
    int count = 1,
    LiveGiftValue? value,
    LiveGiftCombo? combo,
    String recipientName = '',
  }) => LiveGift(
    (b) => b
      ..giftId = giftId
      ..name = name
      ..iconUrl = iconUrl
      ..kind = kind
      ..count = count
      ..value.replace(value ?? LiveGiftValue())
      ..combo.replace(combo ?? LiveGiftCombo())
      ..recipientName = recipientName,
  );

  LiveGift._();

  /// Deserializes a stored JSON record.
  factory LiveGift.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveGift.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveGift> get serializer => _$liveGiftSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveGiftBuilder b) => b
    ..giftId = ''
    ..name = ''
    ..kind = LiveGiftKind.normal
    ..count = 1
    ..value.replace(LiveGiftValue())
    ..combo.replace(LiveGiftCombo())
    ..recipientName = '';

  /// The platform's gift identifier.
  String get giftId;

  /// The gift's display name.
  String get name;

  /// The gift's icon.
  String? get iconUrl;

  /// What kind of gift this is.
  LiveGiftKind get kind;

  /// How many were sent in this hit.
  int get count;

  /// What the gift is worth.
  LiveGiftValue get value;

  /// The combo run this hit belongs to.
  LiveGiftCombo get combo;

  /// The receiving streamer of a cross-room gift, `''` for the current one.
  String get recipientName;
}

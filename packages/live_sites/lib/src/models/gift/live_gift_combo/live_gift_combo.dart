// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_gift_combo.g.dart';

/// The combo (rapid repeat) state of a gift event.
///
/// [comboKey] groups hits of one combo run (`''` = the platform has no combo
/// concept); [comboTotal] is the accumulated hit count of the run
/// (bilibili `combo_total`), null when the platform does not report it.
abstract class LiveGiftCombo implements Built<LiveGiftCombo, LiveGiftComboBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveGiftCombo([void Function(LiveGiftComboBuilder)? updates]) = _$LiveGiftCombo;

  /// Creates a LiveGiftCombo with already-normalized fields.
  factory LiveGiftCombo.of({String comboKey = '', int? comboTotal}) => LiveGiftCombo(
    (b) => b
      ..comboKey = comboKey
      ..comboTotal = comboTotal,
  );

  LiveGiftCombo._();

  /// Deserializes a stored JSON record.
  factory LiveGiftCombo.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(LiveGiftCombo.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveGiftCombo> get serializer => _$liveGiftComboSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveGiftComboBuilder b) => b..comboKey = '';

  /// The key that groups one combo run, `''` when the platform has none.
  String get comboKey;

  /// The run's accumulated hit count, when the platform reports it.
  int? get comboTotal;
}

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_gift_value.freezed.dart';
part 'live_gift_value.g.dart';

/// What a gift is worth, in the platform's own denomination.
///
/// [LiveGiftUnit.free] implies both prices are meaningless; otherwise a null
/// price means the platform did not say (never a fabricated zero).
@freezed
abstract class LiveGiftValue with _$LiveGiftValue {
  /// Creates a LiveGiftValue with already-normalized fields.
  const factory LiveGiftValue({@Default(LiveGiftUnit.other) LiveGiftUnit unit, double? unitPrice, double? totalValue}) =
      _LiveGiftValue;

  /// Deserializes a stored JSON record.
  factory LiveGiftValue.fromJson(Map<String, Object?> json) => _$LiveGiftValueFromJson(json);
}

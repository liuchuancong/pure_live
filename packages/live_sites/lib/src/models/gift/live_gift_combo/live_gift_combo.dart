import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_gift_combo.freezed.dart';
part 'live_gift_combo.g.dart';

/// The combo (rapid repeat) state of a gift event.
///
/// [comboKey] groups hits of one combo run (`''` = the platform has no combo
/// concept); [comboTotal] is the accumulated hit count of the run
/// (bilibili `combo_total`), null when the platform does not report it.
@freezed
abstract class LiveGiftCombo with _$LiveGiftCombo {
  /// Creates a LiveGiftCombo with already-normalized fields.
  const factory LiveGiftCombo({@Default('') String comboKey, int? comboTotal}) = _LiveGiftCombo;

  /// Deserializes a stored JSON record.
  factory LiveGiftCombo.fromJson(Map<String, Object?> json) => _$LiveGiftComboFromJson(json);
}

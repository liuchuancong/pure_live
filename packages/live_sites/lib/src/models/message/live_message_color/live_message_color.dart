import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
// `white`/`numberToColor` read as factories but cannot be constructors:
// `white` is a shared constant instance, `numberToColor` normalizes
// platform-packed int colors before constructing.
// ignore_for_file: prefer_constructors_over_static_methods

part 'live_message_color.freezed.dart';
part 'live_message_color.g.dart';

/// An RGB color a platform attaches to a danmaku text or a sender name.
@freezed
abstract class LiveMessageColor with _$LiveMessageColor {
  /// Creates a LiveMessageColor with already-normalized fields.
  const factory LiveMessageColor(int r, int g, int b) = _LiveMessageColor;

  /// Deserializes a stored JSON record.
  factory LiveMessageColor.fromJson(Map<String, Object?> json) => _$LiveMessageColorFromJson(json);

  /// The plain white most platforms use as the default text color.
  static LiveMessageColor get white => const LiveMessageColor(255, 255, 255);

  /// Parses a platform's packed int color (`0xBBGGRR`/`0xAABBGGRR` layouts).
  ///
  /// 6-digit input is RGB; 8-digit input carries a leading alpha byte that
  /// is dropped — platforms send it, but danmaku text is opaque.
  static LiveMessageColor numberToColor(int intColor) {
    var digits = intColor.toRadixString(16);
    if (digits.length == 4) digits = '00$digits';
    if (digits.length == 6) {
      return LiveMessageColor(
        int.parse(digits.substring(0, 2), radix: 16),
        int.parse(digits.substring(2, 4), radix: 16),
        int.parse(digits.substring(4, 6), radix: 16),
      );
    }
    if (digits.length == 8) {
      return LiveMessageColor(
        int.parse(digits.substring(2, 4), radix: 16),
        int.parse(digits.substring(4, 6), radix: 16),
        int.parse(digits.substring(6, 8), radix: 16),
      );
    }
    return white;
  }
}

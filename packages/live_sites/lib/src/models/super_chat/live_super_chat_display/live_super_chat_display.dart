import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_super_chat_display.freezed.dart';
part 'live_super_chat_display.g.dart';

/// The presentation colors a platform prescribes for one super chat
/// (bilibili's red-gold banner family), as `#RRGGBB` strings.
@freezed
abstract class SuperChatDisplay with _$SuperChatDisplay {
  /// Creates a SuperChatDisplay with already-normalized fields.
  const factory SuperChatDisplay({@Default('') String backgroundColor, @Default('') String backgroundBottomColor}) =
      _SuperChatDisplay;

  /// Deserializes a stored JSON record.
  factory SuperChatDisplay.fromJson(Map<String, Object?> json) => _$SuperChatDisplayFromJson(json);
}

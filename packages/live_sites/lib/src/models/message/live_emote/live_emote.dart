import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_emote.freezed.dart';
part 'live_emote.g.dart';

/// One picture emote a platform names for a code inside a message text.
@freezed
abstract class LiveEmote with _$LiveEmote {
  /// Creates a LiveEmote with already-normalized fields.
  const factory LiveEmote({required String code, required String url}) = _LiveEmote;

  /// Deserializes a stored JSON record.
  factory LiveEmote.fromJson(Map<String, Object?> json) => _$LiveEmoteFromJson(json);
}

import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_badge.freezed.dart';
part 'live_badge.g.dart';

/// One badge image worn next to a sender's name, or attached to a room.
///
/// [id] is the platform's own badge identifier (17live `styleID`), `''` when
/// it has none — the URL is what rendering needs, the id is what equality
/// and caching want.
@freezed
abstract class LiveBadge with _$LiveBadge {
  /// Creates a LiveBadge with already-normalized fields.
  const factory LiveBadge({required String url, @Default('') String id}) = _LiveBadge;

  /// Deserializes a stored JSON record.
  factory LiveBadge.fromJson(Map<String, Object?> json) => _$LiveBadgeFromJson(json);
}

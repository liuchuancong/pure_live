import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/converters/epoch_millis_converter.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'room_local.freezed.dart';
part 'room_local.g.dart';

/// The per-user, this-device-only state of a followed room.
///
/// Never written by platform adapters: [tagIds] are the local follow groups
/// (not platform tags), [lastWatchedAt] feeds the viewing history, and
/// [watchDurationMs] accumulates watched time. IPTV library state (favorite,
/// pinned, hidden) maps here too (MODELS.md §6).
@freezed
abstract class RoomLocal with _$RoomLocal {
  /// Creates a RoomLocal with already-normalized fields.
  const factory RoomLocal({
    @EpochMillisConverter() DateTime? lastWatchedAt,
    @Default([]) List<String> tagIds,
    int? watchDurationMs,
  }) = _RoomLocal;

  /// Deserializes a stored JSON record.
  factory RoomLocal.fromJson(Map<String, Object?> json) => _$RoomLocalFromJson(json);
}

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'room_local.g.dart';

/// The per-user, this-device-only state of a followed room.
///
/// Never written by platform adapters: [tagIds] are the local follow groups
/// (not platform tags), [lastWatchedAt] feeds the viewing history, and
/// [watchDurationMs] accumulates watched time. IPTV library state (favorite,
/// pinned, hidden) maps here too (MODELS.md §6).
abstract class RoomLocal implements Built<RoomLocal, RoomLocalBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory RoomLocal([void Function(RoomLocalBuilder)? updates]) = _$RoomLocal;

  /// Creates a RoomLocal with already-normalized fields.
  /// Creates a RoomLocal with already-normalized fields.
  factory RoomLocal.of({DateTime? lastWatchedAt, List<String> tagIds = const [], int? watchDurationMs}) => RoomLocal(
    (b) => b
      ..lastWatchedAt = lastWatchedAt
      ..tagIds.replace(tagIds)
      ..watchDurationMs = watchDurationMs,
  );

  RoomLocal._();

  /// Deserializes a stored JSON record.
  factory RoomLocal.fromJson(Map<String, Object?> json) => serializers.deserializeWith(RoomLocal.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<RoomLocal> get serializer => _$roomLocalSerializer;

  /// When the room was last watched on this device.
  DateTime? get lastWatchedAt;

  /// The local follow groups this room sits in.
  BuiltList<String> get tagIds;

  /// Watched time accumulated on this device, in milliseconds.
  int? get watchDurationMs;
}

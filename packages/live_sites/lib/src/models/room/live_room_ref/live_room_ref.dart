// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_room_ref.g.dart';

/// The `(platform, roomId)` identity pair of a room.
///
/// The generated all-field equality IS identity equality here — this is the
/// type all identity comparison, dedup and merging go through; `LiveRoom`
/// itself compares by value (MODELS.md §1.5.1). Case normalization for
/// platforms whose room ids are user names happens in that platform's
/// parser (ARCHITECTURE.md §7.4); identity keys join already-normalized
/// ids.
abstract class LiveRoomRef implements Built<LiveRoomRef, LiveRoomRefBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveRoomRef([void Function(LiveRoomRefBuilder)? updates]) = _$LiveRoomRef;

  /// Creates a LiveRoomRef with already-normalized fields.
  /// Creates a LiveRoomRef with already-normalized fields.
  factory LiveRoomRef.of({required String platform, required String roomId}) => LiveRoomRef(
    (b) => b
      ..platform = platform
      ..roomId = roomId,
  );

  LiveRoomRef._();

  /// Deserializes a stored JSON record.
  factory LiveRoomRef.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveRoomRef.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveRoomRef> get serializer => _$liveRoomRefSerializer;

  /// The platform the room belongs to, normalized lowercase.
  String get platform;

  /// The room's platform id.
  String get roomId;

  /// Joins an identity pair into its storage key.
  static String identityKeyOf({required String platform, required String roomId}) => '$platform:$roomId';
}

/// Identity accessors for [LiveRoomRef].
extension LiveRoomRefIdentity on LiveRoomRef {
  /// `platform:roomId` — the key used by follows, tags, merges and storage.
  String get identityKey => LiveRoomRef.identityKeyOf(platform: platform, roomId: roomId);
}

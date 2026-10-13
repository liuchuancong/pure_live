import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_room_ref.freezed.dart';
part 'live_room_ref.g.dart';

/// The `(platform, roomId)` identity pair of a room.
///
/// freezed's all-field equality IS identity equality here — this is the type
/// all identity comparison, dedup and merging go through; `LiveRoom` itself
/// compares by value (MODELS.md §1.5.1). Case normalization for platforms
/// whose room ids are user names happens in that platform's parser
/// (ARCHITECTURE.md §7.4); identity keys join already-normalized ids.
@freezed
abstract class LiveRoomRef with _$LiveRoomRef {
  /// Creates a LiveRoomRef with already-normalized fields.
  const factory LiveRoomRef({required String platform, required String roomId}) = _LiveRoomRef;

  /// Deserializes a stored JSON record.
  factory LiveRoomRef.fromJson(Map<String, Object?> json) => _$LiveRoomRefFromJson(json);

  /// Joins an identity pair into its storage key.
  static String identityKeyOf({required String platform, required String roomId}) => '$platform:$roomId';
}

/// Identity accessors for [LiveRoomRef].
///
/// A separate extension because freezed cannot implement a private
/// generative constructor next to required factory parameters.
extension LiveRoomRefIdentity on LiveRoomRef {
  /// `platform:roomId` — the key used by follows, tags, merges and storage.
  String get identityKey => LiveRoomRef.identityKeyOf(platform: platform, roomId: roomId);
}

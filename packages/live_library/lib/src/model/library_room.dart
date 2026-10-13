import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/live_sites.dart';

part 'library_room.freezed.dart';
part 'library_room.g.dart';

/// A followed room: the network snapshot plus the user's own metadata.
///
/// The split is the point of this model: [room] is what the site
/// returned (refreshed freely), everything else belongs to the user and
/// is never touched by a refresh. [note] is the user's remark, [groupIds]
/// the follow groups the room belongs to and [position] the user's
/// ordering inside the follow list.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LibraryRoom with _$LibraryRoom {
  /// A followed room record.
  const factory LibraryRoom({
    required LiveRoom room,
    required DateTime followedAt,
    @Default(0) int position,
    String? note,
    @Default(<String>[]) List<String> groupIds,
  }) = _LibraryRoom;

  /// Restores a record from JSON.
  factory LibraryRoom.fromJson(Map<String, Object?> json) => _$LibraryRoomFromJson(json);
}

/// A follow group (a user-made bucket of followed rooms).
@freezed
abstract class FollowGroup with _$FollowGroup {
  /// A group record.
  const factory FollowGroup({required String id, required String name, @Default(0) int position}) = _FollowGroup;

  /// Restores a group from JSON.
  factory FollowGroup.fromJson(Map<String, Object?> json) => _$FollowGroupFromJson(json);
}

/// One watch-history entry: the room as it was watched.
@freezed
abstract class WatchRecord with _$WatchRecord {
  /// A history record; [seq] orders the list (newest first).
  const factory WatchRecord({required LiveRoom room, required DateTime watchedAt, @Default(0) int seq}) = _WatchRecord;

  /// Restores a record from JSON.
  factory WatchRecord.fromJson(Map<String, Object?> json) => _$WatchRecordFromJson(json);
}

/// The identity helper shared by the library lists.
extension LibraryRoomIdentity on LibraryRoom {
  /// The room's stable identity, e.g. `bilibili:23058`.
  String get identity => room.identityKey;
}

/// The identity helper shared by the history entries.
extension WatchRecordIdentity on WatchRecord {
  /// The room's stable identity.
  String get identity => room.identityKey;
}

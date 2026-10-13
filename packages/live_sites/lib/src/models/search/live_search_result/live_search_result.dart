import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_search_result.freezed.dart';

/// One typed search hit: exactly one of a room, an anchor, or an area.
///
/// A room hit never requires an anchor object and an anchor hit never
/// requires a room object — the union makes the wrong shape unrepresentable.
@freezed
sealed class LiveSearchResult with _$LiveSearchResult {
  /// Creates a LiveSearchResult with already-normalized fields.
  const factory LiveSearchResult.room(LiveRoom room) = RoomSearchResult;

  /// Creates a LiveSearchResult with already-normalized fields.
  const factory LiveSearchResult.anchor(LiveAnchor anchor) = AnchorSearchResult;

  /// Creates a LiveSearchResult with already-normalized fields.
  const factory LiveSearchResult.area(LiveArea area) = AreaSearchResult;
}

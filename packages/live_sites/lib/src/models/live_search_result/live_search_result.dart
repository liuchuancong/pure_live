import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_sites/src/models/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/live_area/live_area.dart';
import 'package:live_sites/src/models/live_room/live_room.dart';

part 'live_search_result.freezed.dart';

// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed factories
// cannot use the `new` shorthand.

/// One search hit, tagged by which content type it is. A result never forces an
/// anchor onto a room-only hit or a room onto an anchor-only hit: each variant
/// carries exactly the entity its `LiveSearchTarget` names, and callers match on
/// the variant type to read it.
@freezed
abstract class LiveSearchResult with _$LiveSearchResult {
  /// A room hit.
  const factory LiveSearchResult.room(LiveRoom room) = RoomSearchResult;

  /// An anchor hit.
  const factory LiveSearchResult.anchor(LiveAnchor anchor) = AnchorSearchResult;

  /// An area (category) hit.
  const factory LiveSearchResult.area(LiveArea area) = AreaSearchResult;
}

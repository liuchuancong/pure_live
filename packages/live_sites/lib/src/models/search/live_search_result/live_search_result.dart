import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:meta/meta.dart';

/// One typed search hit: exactly one of a room, an anchor, or an area.
///
/// A room hit never requires an anchor object and an anchor hit never
/// requires a room object — the union makes the wrong shape unrepresentable.
/// Hand-written sealed, not built_value: a three-case union is what pattern
/// matching wants, and it never persists on its own.
@immutable
sealed class LiveSearchResult {
  /// Creates a LiveSearchResult with already-normalized fields.
  const factory LiveSearchResult.room(LiveRoom room) = RoomSearchResult;

  /// Creates a LiveSearchResult with already-normalized fields.
  const factory LiveSearchResult.anchor(LiveAnchor anchor) = AnchorSearchResult;

  /// Creates a LiveSearchResult with already-normalized fields.
  const factory LiveSearchResult.area(LiveArea area) = AreaSearchResult;
}

/// A room hit.
@immutable
final class RoomSearchResult implements LiveSearchResult {
  /// The room that was found.
  const RoomSearchResult(this.room);

  /// The room that was found.
  final LiveRoom room;

  @override
  bool operator ==(Object other) => other is RoomSearchResult && other.room == room;

  @override
  int get hashCode => room.hashCode;

  @override
  String toString() => 'LiveSearchResult.room($room)';
}

/// An anchor hit.
@immutable
final class AnchorSearchResult implements LiveSearchResult {
  /// The anchor that was found.
  const AnchorSearchResult(this.anchor);

  /// The anchor that was found.
  final LiveAnchor anchor;

  @override
  bool operator ==(Object other) => other is AnchorSearchResult && other.anchor == anchor;

  @override
  int get hashCode => anchor.hashCode;

  @override
  String toString() => 'LiveSearchResult.anchor($anchor)';
}

/// An area hit.
@immutable
final class AreaSearchResult implements LiveSearchResult {
  /// The area that was found.
  const AreaSearchResult(this.area);

  /// The area that was found.
  final LiveArea area;

  @override
  bool operator ==(Object other) => other is AreaSearchResult && other.area == area;

  @override
  int get hashCode => area.hashCode;

  @override
  String toString() => 'LiveSearchResult.area($area)';
}

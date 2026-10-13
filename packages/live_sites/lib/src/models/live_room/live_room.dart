import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_sites/src/models/live_anchor/live_anchor.dart';

part 'live_room.freezed.dart';

/// A live room as the shared contract represents it.
///
/// Identity is the pair (siteId, id): two snapshots of the same room are equal
/// regardless of a changed title, viewer count or live flag, which keeps
/// Set/Map semantics stable across refreshes. Freezed's generated equality is
/// therefore disabled and identity is expressed through [Equatable] instead.
///
/// The broadcasting streamer is a [LiveAnchor], not loose id/name strings: a
/// room and an anchor are different entities (a room is somewhere to watch, an
/// anchor is somebody to follow) and the anchor's facts — display name, avatar,
/// whether they are on air — belong to that type rather than being duplicated
/// here. The anchor is null when the source names none.
///
/// [cover] and [uri] are parsed URIs, never UI widgets. Fields the source does
/// not provide stay null rather than being filled with a fake zero, so a
/// viewer count of `0` is distinguishable from an unknown count. [metadata]
/// carries source-specific fields that have no shared representation.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@Freezed(equal: false)
abstract class LiveRoom with _$LiveRoom, Equatable {
  /// A room snapshot for [siteId] with the platform-specific [id].
  const factory LiveRoom({
    required String siteId,
    required String id,
    required String title,
    LiveAnchor? anchor,
    Uri? cover,
    Uri? uri,
    bool? isLive,
    int? viewerCount,
    String? categoryId,
    String? categoryName,
    @Default({}) Map<String, Object?> metadata,
  }) = _LiveRoom;

  const LiveRoom._();

  /// The stable identity key, e.g. `bilibili:23058`.
  String get identity => '$siteId:$id';

  @override
  List<Object?> get props => [siteId, id];
}

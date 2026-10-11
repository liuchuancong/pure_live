import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/live_status.dart';

part 'live_room.freezed.dart';
part 'live_room.g.dart';

/// 3.x compatibility: the lifecycle state is stored by index. Unknown
/// indexes fall back to [LiveStatus.unknown] instead of throwing, so old
/// data never breaks the reader.
class LiveStatusConverter implements JsonConverter<LiveStatus, int> {
  /// A converter reading and writing the enum index.
  const LiveStatusConverter();

  @override
  LiveStatus fromJson(int json) =>
      json >= 0 && json < LiveStatus.values.length ? LiveStatus.values[json] : LiveStatus.unknown;

  @override
  int toJson(LiveStatus object) => object.index;
}

/// 3.x compatibility: timestamps are stored as Unix milliseconds (the 3.x
/// wire and storage format), not ISO strings.
class EpochMillisConverter implements JsonConverter<DateTime?, int?> {
  /// A converter reading and writing Unix milliseconds.
  const EpochMillisConverter();

  @override
  DateTime? fromJson(int? json) => json == null ? null : DateTime.fromMillisecondsSinceEpoch(json);

  @override
  int? toJson(DateTime? object) => object?.millisecondsSinceEpoch;
}

/// 3.x compatibility: the restriction is stored by name; unknown names are
/// dropped rather than breaking the reader.
class LiveRestrictionConverter implements JsonConverter<LiveRestriction?, String?> {
  /// A converter reading and writing the JSON name.
  const LiveRestrictionConverter();

  @override
  LiveRestriction? fromJson(String? json) => json == null ? null : LiveRestriction.tryParse(json);

  @override
  String? toJson(LiveRestriction? object) => object?.name;
}

/// A live room — the identity object every site operation revolves
/// around.
///
/// Identity is (platform, roomId): two snapshots of the same room are
/// `==` regardless of title, viewer counts or status changes, which
/// keeps Set/Map semantics and UI update checks stable across refreshes —
/// hence Freezed equality is off and the identity is expressed through
/// `Equatable` instead.
///
/// [data] and [danmakuData] are runtime caches owned by the platform
/// adapter (session handles, signed init payloads). They never enter
/// JSON, never survive a database round trip, and are never carried
/// across by [mergeFrom] — an adapter must be able to re-derive them
/// from the stable fields after a restore.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@immutable
@Freezed(equal: false)
abstract class LiveRoom with _$LiveRoom, Equatable {
  /// A room snapshot; [status] defaults to [LiveStatus.unknown].
  const factory LiveRoom({
    required String platform,
    required String roomId,
    @Default('') String title,
    @Default('') String nick,
    String? avatar,
    String? cover,
    String? areaId,
    String? areaName,
    @Default(LiveStatus.unknown) @LiveStatusConverter() LiveStatus status,
    @LiveRestrictionConverter() LiveRestriction? restriction,
    int? watching,
    int? onlineViewers,
    @EpochMillisConverter() DateTime? startedAt,
    @Default(<String, String>{}) Map<String, String> httpHeaders,
    @Default(<String>[]) List<String> tagIds,
    @JsonKey(includeToJson: false, includeFromJson: false) Object? data,
    @JsonKey(includeToJson: false, includeFromJson: false) Object? danmakuData,
  }) = _LiveRoom;

  /// Restores a room from 3.x-compatible JSON (the runtime caches are not
  /// restored).
  factory LiveRoom.fromJson(Map<String, Object?> json) => _$LiveRoomFromJson(json);

  const LiveRoom._();

  /// The stable identity key, e.g. `bilibili:23058`.
  String get identity => '$platform:$roomId';

  /// Merges [fresh] (a newer snapshot of this same room) over this one.
  ///
  /// Sparse detail rule: empty strings and nulls in [fresh] never erase
  /// known good values here. Runtime caches never travel with the merge.
  /// Throws [ArgumentError] when [fresh] has a different identity.
  LiveRoom mergeFrom(LiveRoom fresh) {
    if (fresh.identity != identity) {
      throw ArgumentError('cannot merge ${fresh.identity} into $identity');
    }
    // Freezed's copyWith clears nullable fields when passed null, so every
    // field is copied only when the fresh snapshot actually carries it.
    var merged = this;
    if (fresh.title.isNotEmpty) merged = merged.copyWith(title: fresh.title);
    if (fresh.nick.isNotEmpty) merged = merged.copyWith(nick: fresh.nick);
    if (fresh.avatar != null) merged = merged.copyWith(avatar: fresh.avatar);
    if (fresh.cover != null) merged = merged.copyWith(cover: fresh.cover);
    if (fresh.areaId != null && fresh.areaId!.isNotEmpty) merged = merged.copyWith(areaId: fresh.areaId);
    if (fresh.areaName != null && fresh.areaName!.isNotEmpty) merged = merged.copyWith(areaName: fresh.areaName);
    if (fresh.status != LiveStatus.unknown) merged = merged.copyWith(status: fresh.status);
    if (fresh.restriction != null) merged = merged.copyWith(restriction: fresh.restriction);
    if (fresh.watching != null) merged = merged.copyWith(watching: fresh.watching);
    if (fresh.onlineViewers != null) merged = merged.copyWith(onlineViewers: fresh.onlineViewers);
    if (fresh.startedAt != null) merged = merged.copyWith(startedAt: fresh.startedAt);
    if (fresh.httpHeaders.isNotEmpty) merged = merged.copyWith(httpHeaders: fresh.httpHeaders);
    if (fresh.tagIds.isNotEmpty) merged = merged.copyWith(tagIds: fresh.tagIds);
    return merged;
  }

  /// Identity equality: platform and room id decide, snapshot fields do
  /// not — `Equatable` is what expresses that here, because Freezed's own
  /// equality is off.
  @override
  List<Object?> get props => [platform, roomId];
}

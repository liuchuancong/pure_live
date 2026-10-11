import 'package:live_sites/src/models/live_status.dart';
import 'package:meta/meta.dart';

/// A live room — the identity object every site operation revolves
/// around.
///
/// Identity is (platform, roomId): two snapshots of the same room are
/// `==` regardless of title, viewer counts or status changes, which
/// keeps Set/Map semantics and UI update checks stable across refreshes.
///
/// [data] and [danmakuData] are runtime caches owned by the platform
/// adapter (session handles, signed init payloads). They never enter
/// JSON, never survive a database round trip, and are never carried
/// across by [mergeFrom] — an adapter must be able to re-derive them
/// from the stable fields after a restore.
@immutable
final class LiveRoom {
  /// A room snapshot; [status] defaults to [LiveStatus.unknown].
  const new({
    required this.platform,
    required this.roomId,
    this.title = '',
    this.nick = '',
    this.avatar,
    this.cover,
    this.areaId,
    this.areaName,
    this.status = LiveStatus.unknown,
    this.restriction,
    this.watching,
    this.onlineViewers,
    this.startedAt,
    this.httpHeaders = const {},
    this.tagIds = const [],
    this.data,
    this.danmakuData,
  });

  /// Restores a room from 3.x-compatible JSON; unknown status indexes
  /// fall back to [LiveStatus.unknown], unknown restriction names are
  /// dropped.
  // ignore: unnecessary_type_name_in_constructor
  factory LiveRoom.fromJson(Map<String, Object?> json) {
    final statusIndex = (json['status'] as num?)?.toInt() ?? LiveStatus.unknown.index;
    final status = statusIndex >= 0 && statusIndex < LiveStatus.values.length
        ? LiveStatus.values[statusIndex]
        : LiveStatus.unknown;
    final restrictionName = json['restriction'] as String?;
    final startedMs = (json['startedAt'] as num?)?.toInt();
    return LiveRoom(
      platform: json['platform'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      nick: json['nick'] as String? ?? '',
      avatar: json['avatar'] as String?,
      cover: json['cover'] as String?,
      areaId: json['areaId'] as String?,
      areaName: json['areaName'] as String?,
      status: status,
      restriction: restrictionName == null ? null : LiveRestriction.tryParse(restrictionName),
      watching: (json['watching'] as num?)?.toInt(),
      onlineViewers: (json['onlineViewers'] as num?)?.toInt(),
      startedAt: startedMs == null ? null : DateTime.fromMillisecondsSinceEpoch(startedMs),
      httpHeaders: (json['httpHeaders'] as Map?)?.cast<String, String>() ?? const {},
      tagIds: (json['tagIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  /// The owning site id, e.g. `bilibili`.
  final String platform;

  /// The room's platform id (short id where a platform has both).
  final String roomId;

  /// Current stream title.
  final String title;

  /// Streamer display name.
  final String nick;

  /// Streamer avatar URL.
  final String? avatar;

  /// Room cover URL.
  final String? cover;

  /// Area id the room currently streams in.
  final String? areaId;

  /// Area display name.
  final String? areaName;

  /// Lifecycle state.
  final LiveStatus status;

  /// Platform viewing restriction, if any.
  final LiveRestriction? restriction;

  /// Current audience reading (watching口径 preferred).
  final int? watching;

  /// Cumulative unique viewers, when the platform reports it.
  final int? onlineViewers;

  /// When the current streaming session started.
  final DateTime? startedAt;

  /// HTTP headers required to fetch the cover/avatar of this room.
  final Map<String, String> httpHeaders;

  /// Tags the room carries.
  final List<String> tagIds;

  /// Platform-owned runtime cache (opaque to every other layer).
  final Object? data;

  /// Platform-owned danmaku session cache.
  final Object? danmakuData;

  /// The stable identity key, e.g. `bilibili:23058`.
  String get identity => '$platform:$roomId';

  /// Returns a copy; [data] and [danmakuData] use the `Function()`
  /// clearing convention — pass `() => null` to drop the runtime cache.
  LiveRoom copyWith({
    String? title,
    String? nick,
    String? Function()? avatar,
    String? Function()? cover,
    String? Function()? areaId,
    String? Function()? areaName,
    LiveStatus? status,
    LiveRestriction? Function()? restriction,
    int? Function()? watching,
    int? Function()? onlineViewers,
    DateTime? Function()? startedAt,
    Map<String, String>? httpHeaders,
    List<String>? tagIds,
    Object? Function()? data,
    Object? Function()? danmakuData,
  }) => LiveRoom(
    platform: platform,
    roomId: roomId,
    title: title ?? this.title,
    nick: nick ?? this.nick,
    avatar: avatar == null ? this.avatar : avatar(),
    cover: cover == null ? this.cover : cover(),
    areaId: areaId == null ? this.areaId : areaId(),
    areaName: areaName == null ? this.areaName : areaName(),
    status: status ?? this.status,
    restriction: restriction == null ? this.restriction : restriction(),
    watching: watching == null ? this.watching : watching(),
    onlineViewers: onlineViewers == null ? this.onlineViewers : onlineViewers(),
    startedAt: startedAt == null ? this.startedAt : startedAt(),
    httpHeaders: httpHeaders ?? this.httpHeaders,
    tagIds: tagIds ?? this.tagIds,
    data: data == null ? this.data : data(),
    danmakuData: danmakuData == null ? this.danmakuData : danmakuData(),
  );

  /// Merges [fresh] (a newer snapshot of this same room) over this one.
  ///
  /// Sparse detail rule: empty strings and nulls in [fresh] never erase
  /// known good values here. Runtime caches never travel with the merge.
  /// Throws [ArgumentError] when [fresh] has a different identity.
  LiveRoom mergeFrom(LiveRoom fresh) {
    if (fresh.identity != identity) {
      throw ArgumentError('cannot merge ${fresh.identity} into $identity');
    }
    return copyWith(
      title: fresh.title.isEmpty ? null : fresh.title,
      nick: fresh.nick.isEmpty ? null : fresh.nick,
      avatar: fresh.avatar == null ? null : () => fresh.avatar,
      cover: fresh.cover == null ? null : () => fresh.cover,
      areaId: fresh.areaId == null || fresh.areaId!.isEmpty ? null : () => fresh.areaId,
      areaName: fresh.areaName == null || fresh.areaName!.isEmpty ? null : () => fresh.areaName,
      status: fresh.status == LiveStatus.unknown ? null : fresh.status,
      restriction: fresh.restriction == null ? null : () => fresh.restriction,
      watching: fresh.watching == null ? null : () => fresh.watching,
      onlineViewers: fresh.onlineViewers == null ? null : () => fresh.onlineViewers,
      startedAt: fresh.startedAt == null ? null : () => fresh.startedAt,
      httpHeaders: fresh.httpHeaders.isEmpty ? null : fresh.httpHeaders,
      tagIds: fresh.tagIds.isEmpty ? null : fresh.tagIds,
    );
  }

  /// Serializes the stable fields; runtime caches are excluded by design
  /// so a persisted room restores as a clean snapshot.
  Map<String, Object?> toJson() => {
    'platform': platform,
    'roomId': roomId,
    if (title.isNotEmpty) 'title': title,
    if (nick.isNotEmpty) 'nick': nick,
    if (avatar != null) 'avatar': avatar,
    if (cover != null) 'cover': cover,
    if (areaId != null) 'areaId': areaId,
    if (areaName != null) 'areaName': areaName,
    'status': status.index,
    if (restriction != null) 'restriction': restriction!.jsonName,
    if (watching != null) 'watching': watching,
    if (onlineViewers != null) 'onlineViewers': onlineViewers,
    if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
    if (httpHeaders.isNotEmpty) 'httpHeaders': httpHeaders,
    if (tagIds.isNotEmpty) 'tagIds': tagIds,
  };

  @override
  bool operator ==(Object other) => other is LiveRoom && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;

  @override
  String toString() => 'LiveRoom($identity, ${status.name}, $title)';
}

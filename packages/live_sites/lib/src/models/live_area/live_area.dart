// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:convert';

import 'package:meta/meta.dart';

/// An area (category) of a platform: what the area pages list and what is
/// stored for followed areas.
@immutable
final class LiveArea {
  /// Creates an area.
  const LiveArea({
    this.platform = '',
    this.areaType = '',
    this.typeName = '',
    this.areaId = '',
    this.areaName = '',
    this.areaPic = '',
    this.shortName = '',
  });

  /// Reads stored JSON; missing fields become empty text whatever their JSON
  /// type (a platform may return a numeric id).
  factory LiveArea.fromJson(Map<String, Object?> json) {
    String text(String key) => json[key]?.toString() ?? '';
    return LiveArea(
      platform: text('platform'),
      areaType: text('areaType'),
      typeName: text('typeName'),
      areaId: text('areaId'),
      areaName: text('areaName'),
      areaPic: text('areaPic'),
      shortName: text('shortName'),
    );
  }

  /// Platform id.
  final String platform;

  /// Id of the parent category.
  final String areaType;

  /// Name of the parent category.
  final String typeName;

  /// Area id.
  final String areaId;

  /// Area name.
  final String areaName;

  /// Area picture URL.
  final String areaPic;

  /// Short name (some platforms route by it).
  final String shortName;

  /// The identity used by followed areas, or null without platform or id.
  String? get identityKey => identityKeyFor(platform: platform, areaId: areaId, areaType: areaType);

  /// Whether [other] is the same area.
  bool hasSameIdentity(LiveArea other) {
    final key = identityKey;
    return key != null && key == other.identityKey;
  }

  /// Platforms identify areas by platform and id, whatever the parent; IPTV ids
  /// are global too. Missevan's catalog ids and tag ids are separate namespaces,
  /// so its parent type is part of the identity.
  static String? identityKeyFor({String? platform, String? areaId, String? areaType}) {
    final site = platform?.trim().toLowerCase() ?? '';
    final id = areaId?.trim() ?? '';
    if (site.isEmpty || id.isEmpty) return null;
    final namespace = site == 'missevan' ? areaType?.trim().toLowerCase() ?? '' : '';
    return jsonEncode([site, namespace, id]);
  }

  /// The stored JSON.
  Map<String, Object?> toJson() => {
    'platform': platform,
    'areaType': areaType,
    'typeName': typeName,
    'areaId': areaId,
    'areaName': areaName,
    'areaPic': areaPic,
    'shortName': shortName,
  };

  @override
  bool operator ==(Object other) => other is LiveArea && other.identityKey == identityKey;

  @override
  int get hashCode => identityKey.hashCode;

  @override
  String toString() => 'LiveArea($platform, $areaId, $areaName)';
}

/// One quality a room offers.
@immutable
final class LivePlayQuality {
  /// Creates a quality.
  const LivePlayQuality({
    required this.quality,
    this.data,
    this.id,
    this.sort = 0,
    this.isPlaybackUnconfirmed = false,
    this.codec,
  });

  /// Label shown to the user.
  final String quality;

  /// Platform data needed to request this quality.
  final Object? data;

  /// Stable platform identifier used to confirm that a requested quality was
  /// applied; kept apart from [data], whose URL lists and request maps are
  /// implementation details.
  final Object? id;

  /// Order among the room's qualities.
  final int sort;

  /// The stream is playing but the platform did not confirm this quality; the
  /// label is shown as unconfirmed rather than renamed.
  final bool isPlaybackUnconfirmed;

  /// The video codec of this quality (`avc`, `hevc`), filled only by platforms
  /// that know it before any URL is resolved. A hint, not part of the identity
  /// ([selectionId]); the codec actually played is the line's. "优先 H.264" uses
  /// it to pass over an HEVC quality when choosing where a room starts.
  final String? codec;

  /// A copy with [isPlaybackUnconfirmed] set to [unconfirmed].
  LivePlayQuality withPlaybackUnconfirmed({required bool unconfirmed}) => unconfirmed == isPlaybackUnconfirmed
      ? this
      : LivePlayQuality(
          quality: quality,
          data: data,
          id: id,
          sort: sort,
          isPlaybackUnconfirmed: unconfirmed,
          codec: codec,
        );

  /// The identity of this option: [id], or the label for adapters without one.
  /// Never derived from [data].
  Object get selectionId => id ?? quality;

  @override
  String toString() => 'LivePlayQuality($quality, $id)';
}

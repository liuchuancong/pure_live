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
    this.createdAt,
    this.updatedAt,
    this.rawData = const {},
  });

  /// Reads stored JSON; missing fields become empty text whatever their JSON
  /// type (a platform may return a numeric id).
  factory LiveArea.fromJson(Map<String, Object?> json) {
    String text(String key) => json[key]?.toString() ?? '';
    final raw = json['rawData'];
    return LiveArea(
      platform: text('platform'),
      areaType: text('areaType'),
      typeName: text('typeName'),
      areaId: text('areaId'),
      areaName: text('areaName'),
      areaPic: text('areaPic'),
      shortName: text('shortName'),
      createdAt: DateTime.tryParse(text('createdAt')),
      updatedAt: DateTime.tryParse(text('updatedAt')),
      rawData: raw is Map ? raw.cast<String, Object?>() : const {},
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

  /// When this area was first stored, UTC; null for a transient parse.
  final DateTime? createdAt;

  /// When this area was last refreshed from the platform, UTC.
  final DateTime? updatedAt;

  /// The untouched platform payload this area was parsed from, for debugging and
  /// re-parsing after a schema change; empty when not kept.
  final Map<String, Object?> rawData;

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
    if (createdAt case final at?) 'createdAt': at.toIso8601String(),
    if (updatedAt case final at?) 'updatedAt': at.toIso8601String(),
    if (rawData.isNotEmpty) 'rawData': rawData,
  };

  @override
  bool operator ==(Object other) => other is LiveArea && other.identityKey == identityKey;

  @override
  int get hashCode => identityKey.hashCode;

  @override
  String toString() => 'LiveArea($platform, $areaId, $areaName)';
}

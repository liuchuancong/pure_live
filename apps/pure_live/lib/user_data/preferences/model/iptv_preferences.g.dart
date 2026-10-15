// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IptvPreferences _$IptvPreferencesFromJson(
  Map<String, dynamic> json,
) => _IptvPreferences(
  autoSyncPlaylists: json['autoSyncPlaylists'] as bool? ?? true,
  playlistSyncInterval: json['playlistSyncInterval'] == null
      ? const Duration(hours: 24)
      : Duration(microseconds: (json['playlistSyncInterval'] as num).toInt()),
  autoSyncGuides: json['autoSyncGuides'] as bool? ?? true,
  guideSyncInterval: json['guideSyncInterval'] == null
      ? const Duration(hours: 6)
      : Duration(microseconds: (json['guideSyncInterval'] as num).toInt()),
  lineHealthFreshness: json['lineHealthFreshness'] == null
      ? const Duration(hours: 12)
      : Duration(microseconds: (json['lineHealthFreshness'] as num).toInt()),
);

Map<String, dynamic> _$IptvPreferencesToJson(_IptvPreferences instance) =>
    <String, dynamic>{
      'autoSyncPlaylists': instance.autoSyncPlaylists,
      'playlistSyncInterval': instance.playlistSyncInterval.inMicroseconds,
      'autoSyncGuides': instance.autoSyncGuides,
      'guideSyncInterval': instance.guideSyncInterval.inMicroseconds,
      'lineHealthFreshness': instance.lineHealthFreshness.inMicroseconds,
    };

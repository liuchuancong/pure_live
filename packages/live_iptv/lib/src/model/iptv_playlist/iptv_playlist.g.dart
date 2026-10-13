// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IptvPlaylist _$IptvPlaylistFromJson(Map<String, dynamic> json) => _IptvPlaylist(
  id: json['id'] as String,
  name: json['name'] as String,
  importedAt: DateTime.parse(json['importedAt'] as String),
  url: json['url'] as String?,
  channelCount: (json['channelCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$IptvPlaylistToJson(_IptvPlaylist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'importedAt': instance.importedAt.toIso8601String(),
  'url': instance.url,
  'channelCount': instance.channelCount,
};

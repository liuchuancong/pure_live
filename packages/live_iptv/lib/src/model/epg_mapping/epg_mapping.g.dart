// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_mapping.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EpgMapping _$EpgMappingFromJson(Map<String, dynamic> json) => _EpgMapping(
  channelId: json['channelId'] as String,
  epgChannelKey: json['epgChannelKey'] as String,
  playlistId: json['playlistId'] as String? ?? '',
  epgSourceId: json['epgSourceId'] as String? ?? '',
  locked: json['locked'] as bool? ?? false,
  origin: json['origin'] as String? ?? epgAutoMappingOrigin,
);

Map<String, dynamic> _$EpgMappingToJson(_EpgMapping instance) => <String, dynamic>{
  'channelId': instance.channelId,
  'epgChannelKey': instance.epgChannelKey,
  'playlistId': instance.playlistId,
  'epgSourceId': instance.epgSourceId,
  'locked': instance.locked,
  'origin': instance.origin,
};

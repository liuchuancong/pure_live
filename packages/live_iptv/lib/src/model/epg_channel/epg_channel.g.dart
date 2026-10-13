// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EpgChannel _$EpgChannelFromJson(Map<String, dynamic> json) => _EpgChannel(
  sourceId: json['sourceId'] as String,
  channelId: json['channelId'] as String,
  displayName: json['displayName'] as String? ?? '',
  iconUrl: json['iconUrl'] as String?,
);

Map<String, dynamic> _$EpgChannelToJson(_EpgChannel instance) => <String, dynamic>{
  'sourceId': instance.sourceId,
  'channelId': instance.channelId,
  'displayName': instance.displayName,
  'iconUrl': instance.iconUrl,
};

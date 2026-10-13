// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IptvChannel _$IptvChannelFromJson(Map<String, dynamic> json) => _IptvChannel(
  id: json['id'] as String,
  entry: IptvEntry.fromJson(json['entry'] as Map<String, dynamic>),
  favorite: json['favorite'] as bool? ?? false,
  hidden: json['hidden'] as bool? ?? false,
  pinned: json['pinned'] as bool? ?? false,
  position: (json['position'] as num?)?.toInt() ?? 0,
  number: (json['number'] as num?)?.toInt(),
);

Map<String, dynamic> _$IptvChannelToJson(_IptvChannel instance) => <String, dynamic>{
  'id': instance.id,
  'entry': instance.entry,
  'favorite': instance.favorite,
  'hidden': instance.hidden,
  'pinned': instance.pinned,
  'position': instance.position,
  'number': instance.number,
};

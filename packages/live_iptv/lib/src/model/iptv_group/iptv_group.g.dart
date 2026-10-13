// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IptvGroup _$IptvGroupFromJson(Map<String, dynamic> json) => _IptvGroup(
  name: json['name'] as String,
  order: (json['order'] as num?)?.toInt() ?? 0,
  pinned: json['pinned'] as bool? ?? false,
  hidden: json['hidden'] as bool? ?? false,
);

Map<String, dynamic> _$IptvGroupToJson(_IptvGroup instance) => <String, dynamic>{
  'name': instance.name,
  'order': instance.order,
  'pinned': instance.pinned,
  'hidden': instance.hidden,
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_anchor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveAnchor _$LiveAnchorFromJson(Map<String, dynamic> json) => _LiveAnchor(
  platform: json['platform'] as String? ?? '',
  anchorId: json['anchorId'] as String? ?? '',
  name: json['name'] as String? ?? '',
  avatarUrl: json['avatarUrl'] as String?,
  profileUrl: json['profileUrl'] as String?,
  followerCount: (json['followerCount'] as num?)?.toInt(),
  introduction: json['introduction'] as String?,
  isVerified: json['isVerified'] as bool?,
  anchorLevel: (json['anchorLevel'] as num?)?.toInt(),
  liveStatus: $enumDecodeNullable(_$LiveStatusEnumMap, json['liveStatus']),
);

Map<String, dynamic> _$LiveAnchorToJson(_LiveAnchor instance) => <String, dynamic>{
  'platform': instance.platform,
  'anchorId': instance.anchorId,
  'name': instance.name,
  'avatarUrl': instance.avatarUrl,
  'profileUrl': instance.profileUrl,
  'followerCount': instance.followerCount,
  'introduction': instance.introduction,
  'isVerified': instance.isVerified,
  'anchorLevel': instance.anchorLevel,
  'liveStatus': _$LiveStatusEnumMap[instance.liveStatus],
};

const _$LiveStatusEnumMap = {
  LiveStatus.live: 'live',
  LiveStatus.replay: 'replay',
  LiveStatus.carousel: 'carousel',
  LiveStatus.offline: 'offline',
  LiveStatus.banned: 'banned',
  LiveStatus.unknown: 'unknown',
};

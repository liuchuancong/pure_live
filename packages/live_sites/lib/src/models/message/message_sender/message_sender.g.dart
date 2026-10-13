// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_sender.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageSender _$MessageSenderFromJson(Map<String, dynamic> json) => _MessageSender(
  userId: json['userId'] as String? ?? '',
  userName: json['userName'] as String? ?? '',
  avatarUrl: json['avatarUrl'] as String?,
  userLevel: json['userLevel'] as String?,
  fanBadgeLevel: json['fanBadgeLevel'] as String? ?? '',
  fanBadgeName: json['fanBadgeName'] as String? ?? '',
  nameColor: json['nameColor'] == null ? null : LiveMessageColor.fromJson(json['nameColor'] as Map<String, dynamic>),
  badges:
      (json['badges'] as List<dynamic>?)?.map((e) => LiveBadge.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  role: $enumDecodeNullable(_$LiveAnchorRoleEnumMap, json['role']) ?? LiveAnchorRole.viewer,
  membershipTier: (json['membershipTier'] as num?)?.toInt(),
);

Map<String, dynamic> _$MessageSenderToJson(_MessageSender instance) => <String, dynamic>{
  'userId': instance.userId,
  'userName': instance.userName,
  'avatarUrl': instance.avatarUrl,
  'userLevel': instance.userLevel,
  'fanBadgeLevel': instance.fanBadgeLevel,
  'fanBadgeName': instance.fanBadgeName,
  'nameColor': instance.nameColor?.toJson(),
  'badges': instance.badges.map((e) => e.toJson()).toList(),
  'role': _$LiveAnchorRoleEnumMap[instance.role]!,
  'membershipTier': instance.membershipTier,
};

const _$LiveAnchorRoleEnumMap = {
  LiveAnchorRole.anchor: 'anchor',
  LiveAnchorRole.moderator: 'moderator',
  LiveAnchorRole.viewer: 'viewer',
  LiveAnchorRole.platform: 'platform',
  LiveAnchorRole.system: 'system',
};

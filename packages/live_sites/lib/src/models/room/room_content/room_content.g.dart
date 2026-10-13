// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomContent _$RoomContentFromJson(Map<String, dynamic> json) => _RoomContent(
  title: json['title'] as String? ?? '',
  coverUrl: json['coverUrl'] as String? ?? '',
  introduction: json['introduction'] as String?,
  notice: json['notice'] as String?,
  badges:
      (json['badges'] as List<dynamic>?)?.map((e) => LiveBadge.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  platformTags: (json['platformTags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
);

Map<String, dynamic> _$RoomContentToJson(_RoomContent instance) => <String, dynamic>{
  'title': instance.title,
  'coverUrl': instance.coverUrl,
  'introduction': instance.introduction,
  'notice': instance.notice,
  'badges': instance.badges.map((e) => e.toJson()).toList(),
  'platformTags': instance.platformTags,
};

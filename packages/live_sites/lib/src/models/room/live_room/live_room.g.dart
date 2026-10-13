// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveRoom _$LiveRoomFromJson(Map<String, dynamic> json) => _LiveRoom(
  ref: LiveRoomRef.fromJson(json['ref'] as Map<String, dynamic>),
  content: json['content'] == null
      ? const RoomContent()
      : RoomContent.fromJson(json['content'] as Map<String, dynamic>),
  audience: json['audience'] == null
      ? const RoomAudience()
      : RoomAudience.fromJson(json['audience'] as Map<String, dynamic>),
  broadcast: json['broadcast'] == null
      ? const RoomBroadcast()
      : RoomBroadcast.fromJson(json['broadcast'] as Map<String, dynamic>),
  links: json['links'] == null ? const RoomLinks() : RoomLinks.fromJson(json['links'] as Map<String, dynamic>),
  guide: json['guide'] == null ? const RoomGuide() : RoomGuide.fromJson(json['guide'] as Map<String, dynamic>),
  local: json['local'] == null ? const RoomLocal() : RoomLocal.fromJson(json['local'] as Map<String, dynamic>),
  anchor: json['anchor'] == null ? null : LiveAnchor.fromJson(json['anchor'] as Map<String, dynamic>),
  area: json['area'] == null ? null : LiveArea.fromJson(json['area'] as Map<String, dynamic>),
  createdAt: json['createdAt'] == null ? null : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LiveRoomToJson(_LiveRoom instance) => <String, dynamic>{
  'ref': instance.ref.toJson(),
  'content': instance.content.toJson(),
  'audience': instance.audience.toJson(),
  'broadcast': instance.broadcast.toJson(),
  'links': instance.links.toJson(),
  'guide': instance.guide.toJson(),
  'local': instance.local.toJson(),
  'anchor': instance.anchor?.toJson(),
  'area': instance.area?.toJson(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

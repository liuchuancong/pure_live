// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveRoom _$LiveRoomFromJson(Map<String, dynamic> json) => _LiveRoom(
  ref: refFromJson(json['ref']),
  state: _state(json['state']),
  title: json['title'] as String,
  anchorName: _text(json['anchorName']),
  anchorId: _text(json['anchorId']),
  avatar: _text(json['avatar']),
  cover: _text(json['cover']),
  area: _text(json['area']),
  introduction: _text(json['introduction']),
  viewers: _intOrNull(json['viewers']),
  followers: _intOrNull(json['followers']),
  startedAt: _at(json['startedAt']),
  requiresAuth: json['requiresAuth'] as bool? ?? false,
  isScheduled: json['isScheduled'] as bool? ?? false,
  streamId: _text(json['streamId']),
  tags: json['tags'] == null ? const <String>[] : _stringList(json['tags']),
  extra: json['extra'] == null ? const <String, Object?>{} : _map(json['extra']),
);

Map<String, dynamic> _$LiveRoomToJson(_LiveRoom instance) => <String, dynamic>{
  'ref': refToJson(instance.ref),
  'state': _$LiveRoomStateEnumMap[instance.state]!,
  'title': instance.title,
  'anchorName': instance.anchorName,
  'anchorId': instance.anchorId,
  'avatar': instance.avatar,
  'cover': instance.cover,
  'area': instance.area,
  'introduction': instance.introduction,
  'viewers': _intOrNull(instance.viewers),
  'followers': _intOrNull(instance.followers),
  'startedAt': formatUtc(instance.startedAt),
  'requiresAuth': instance.requiresAuth,
  'isScheduled': instance.isScheduled,
  'streamId': instance.streamId,
  'tags': _stringListOut(instance.tags),
  'extra': _mapOut(instance.extra),
};

const _$LiveRoomStateEnumMap = {
  LiveRoomState.live: 'live',
  LiveRoomState.ended: 'ended',
  LiveRoomState.notStarted: 'notStarted',
  LiveRoomState.unknown: 'unknown',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_room_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveRoomStatus _$LiveRoomStatusFromJson(Map<String, dynamic> json) => _LiveRoomStatus(
  ref: refFromJson(json['ref']),
  state: $enumDecode(_$LiveRoomStateEnumMap, json['state']),
  viewers: _intOrNull(json['viewers']),
  title: json['title'] as String?,
  cover: json['cover'] as String?,
  anchorName: json['anchorName'] as String?,
  startedAt: json['startedAt'] == null ? null : DateTime.parse(json['startedAt'] as String),
);

Map<String, dynamic> _$LiveRoomStatusToJson(_LiveRoomStatus instance) => <String, dynamic>{
  'ref': refToJson(instance.ref),
  'state': _$LiveRoomStateEnumMap[instance.state]!,
  'viewers': _intOrNull(instance.viewers),
  'title': instance.title,
  'cover': instance.cover,
  'anchorName': instance.anchorName,
  'startedAt': instance.startedAt?.toIso8601String(),
};

const _$LiveRoomStateEnumMap = {
  LiveRoomState.live: 'live',
  LiveRoomState.ended: 'ended',
  LiveRoomState.notStarted: 'notStarted',
  LiveRoomState.unknown: 'unknown',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_local.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomLocal _$RoomLocalFromJson(Map<String, dynamic> json) => _RoomLocal(
  lastWatchedAt: const EpochMillisConverter().fromJson(json['lastWatchedAt']),
  tagIds: (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  watchDurationMs: (json['watchDurationMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$RoomLocalToJson(_RoomLocal instance) => <String, dynamic>{
  'lastWatchedAt': const EpochMillisConverter().toJson(instance.lastWatchedAt),
  'tagIds': instance.tagIds,
  'watchDurationMs': instance.watchDurationMs,
};

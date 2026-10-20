// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LibraryRoom _$LibraryRoomFromJson(Map<String, dynamic> json) => _LibraryRoom(
  room: LiveRoom.fromJson(json['room'] as Map<String, dynamic>),
  followedAt: DateTime.parse(json['followedAt'] as String),
  position: (json['position'] as num?)?.toInt() ?? 0,
  note: json['note'] as String?,
  groupIds: (json['groupIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
);

Map<String, dynamic> _$LibraryRoomToJson(_LibraryRoom instance) => <String, dynamic>{
  'room': instance.room.toJson(),
  'followedAt': instance.followedAt.toIso8601String(),
  'position': instance.position,
  'note': instance.note,
  'groupIds': instance.groupIds,
};

_FollowGroup _$FollowGroupFromJson(Map<String, dynamic> json) => _FollowGroup(
  id: json['id'] as String,
  name: json['name'] as String,
  position: (json['position'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$FollowGroupToJson(_FollowGroup instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'position': instance.position,
};

_WatchRecord _$WatchRecordFromJson(Map<String, dynamic> json) => _WatchRecord(
  room: LiveRoom.fromJson(json['room'] as Map<String, dynamic>),
  watchedAt: DateTime.parse(json['watchedAt'] as String),
  seq: (json['seq'] as num?)?.toInt() ?? 0,
  progress: (json['progress'] as num?)?.toDouble(),
  position: const DurationMillisConverter().fromJson(json['position']),
);

Map<String, dynamic> _$WatchRecordToJson(_WatchRecord instance) => <String, dynamic>{
  'room': instance.room.toJson(),
  'watchedAt': instance.watchedAt.toIso8601String(),
  'seq': instance.seq,
  'progress': instance.progress,
  'position': const DurationMillisConverter().toJson(instance.position),
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_broadcast.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomBroadcast _$RoomBroadcastFromJson(Map<String, dynamic> json) => _RoomBroadcast(
  liveStatus: const LiveStatusByNameConverter().fromJson(json['liveStatus']),
  startedAt: const EpochMillisConverter().fromJson(json['startedAt']),
  restriction: $enumDecodeNullable(_$LiveRestrictionEnumMap, json['restriction']),
  activity: $enumDecodeNullable(_$LiveRoomActivityEnumMap, json['activity']) ?? LiveRoomActivity.none,
);

Map<String, dynamic> _$RoomBroadcastToJson(_RoomBroadcast instance) => <String, dynamic>{
  'liveStatus': const LiveStatusByNameConverter().toJson(instance.liveStatus),
  'startedAt': const EpochMillisConverter().toJson(instance.startedAt),
  'restriction': _$LiveRestrictionEnumMap[instance.restriction],
  'activity': _$LiveRoomActivityEnumMap[instance.activity]!,
};

const _$LiveRestrictionEnumMap = {
  LiveRestriction.none: 'none',
  LiveRestriction.needsLogin: 'needsLogin',
  LiveRestriction.paid: 'paid',
  LiveRestriction.subscribersOnly: 'subscribersOnly',
  LiveRestriction.private: 'private',
  LiveRestriction.appOnly: 'appOnly',
  LiveRestriction.regionBlocked: 'regionBlocked',
  LiveRestriction.password: 'password',
  LiveRestriction.adult: 'adult',
  LiveRestriction.unplayable: 'unplayable',
};

const _$LiveRoomActivityEnumMap = {
  LiveRoomActivity.none: 'none',
  LiveRoomActivity.pk: 'pk',
  LiveRoomActivity.coStream: 'coStream',
  LiveRoomActivity.radio: 'radio',
  LiveRoomActivity.carousel: 'carousel',
};

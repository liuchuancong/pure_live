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
  areaId: _text(json['areaId']),
  link: _text(json['link']),
  notice: _text(json['notice']),
  audience: _audience(json['audience']),
  introduction: _text(json['introduction']),
  viewers: _intOrNull(json['viewers']),
  viewersMetric: json['viewersMetric'] == null ? LiveAudienceMetric.unknown : _metric(json['viewersMetric']),
  followers: _intOrNull(json['followers']),
  startedAt: _at(json['startedAt']),
  restriction: _restriction(json['restriction']),
  reportedStateCode: _intOrNull(json['reportedStateCode']),
  catchUp: _catchUp(json['catchUp']),
  epgId: _text(json['epgId']),
  currentProgramme: _text(json['currentProgramme']),
  currentProgrammeDescription: _text(json['currentProgrammeDescription']),
  isScheduled: json['isScheduled'] as bool? ?? false,
  streamId: _text(json['streamId']),
  tags: json['tags'] == null ? const <String>[] : _stringList(json['tags']),
  headers: json['headers'] == null ? const <String, String>{} : _stringMap(json['headers']),
  sitePayload: json['sitePayload'] == null ? const <String, Object?>{} : _map(json['sitePayload']),
  danmakuPayload: json['danmakuPayload'] == null ? const <String, Object?>{} : _map(json['danmakuPayload']),
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
  'areaId': instance.areaId,
  'link': instance.link,
  'notice': instance.notice,
  'audience': _audienceOut(instance.audience),
  'introduction': instance.introduction,
  'viewers': _intOrNull(instance.viewers),
  'viewersMetric': _$LiveAudienceMetricEnumMap[instance.viewersMetric]!,
  'followers': _intOrNull(instance.followers),
  'startedAt': formatUtc(instance.startedAt),
  'restriction': _restrictionName(instance.restriction),
  'reportedStateCode': _intOrNull(instance.reportedStateCode),
  'catchUp': _catchUpOut(instance.catchUp),
  'epgId': instance.epgId,
  'currentProgramme': instance.currentProgramme,
  'currentProgrammeDescription': instance.currentProgrammeDescription,
  'isScheduled': instance.isScheduled,
  'streamId': instance.streamId,
  'tags': _stringListOut(instance.tags),
  'headers': _stringMapOut(instance.headers),
  'sitePayload': _mapOut(instance.sitePayload),
  'danmakuPayload': _mapOut(instance.danmakuPayload),
  'extra': _mapOut(instance.extra),
};

const _$LiveRoomStateEnumMap = {
  LiveRoomState.live: 'live',
  LiveRoomState.ended: 'ended',
  LiveRoomState.notStarted: 'notStarted',
  LiveRoomState.unknown: 'unknown',
};

const _$LiveAudienceMetricEnumMap = {
  LiveAudienceMetric.onlineViewers: 'onlineViewers',
  LiveAudienceMetric.totalViewers: 'totalViewers',
  LiveAudienceMetric.popularity: 'popularity',
  LiveAudienceMetric.unknown: 'unknown',
};

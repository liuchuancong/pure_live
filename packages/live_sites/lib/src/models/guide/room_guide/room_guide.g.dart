// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_guide.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomGuide _$RoomGuideFromJson(Map<String, dynamic> json) => _RoomGuide(
  epgId: json['epgId'] as String?,
  currentProgramme: json['currentProgramme'] as String? ?? '',
  currentProgrammeDescription: json['currentProgrammeDescription'] as String?,
  catchUp: json['catchUp'] == null
      ? const GuideCatchUp()
      : GuideCatchUp.fromJson(json['catchUp'] as Map<String, dynamic>),
  httpHeaders: (json['httpHeaders'] as Map<String, dynamic>?)?.map((k, e) => MapEntry(k, e as String)) ?? const {},
);

Map<String, dynamic> _$RoomGuideToJson(_RoomGuide instance) => <String, dynamic>{
  'epgId': instance.epgId,
  'currentProgramme': instance.currentProgramme,
  'currentProgrammeDescription': instance.currentProgrammeDescription,
  'catchUp': instance.catchUp.toJson(),
  'httpHeaders': instance.httpHeaders,
};

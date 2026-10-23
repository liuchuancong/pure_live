// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_retraction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveRetraction _$LiveRetractionFromJson(Map<String, dynamic> json) =>
    _LiveRetraction(
      userId: json['userId'] as String?,
      messageId: json['messageId'] as String?,
      all: json['all'] as bool? ?? false,
    );

Map<String, dynamic> _$LiveRetractionToJson(_LiveRetraction instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'messageId': instance.messageId,
      'all': instance.all,
    };

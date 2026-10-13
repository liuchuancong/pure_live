// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TvPreferences _$TvPreferencesFromJson(Map<String, dynamic> json) =>
    _TvPreferences(
      focusMemory: json['focusMemory'] as bool? ?? true,
      focusScale: (json['focusScale'] as num?)?.toDouble() ?? 1.08,
      longPressSeek: json['longPressSeek'] as bool? ?? false,
      channelReversal: json['channelReversal'] as bool? ?? false,
    );

Map<String, dynamic> _$TvPreferencesToJson(_TvPreferences instance) =>
    <String, dynamic>{
      'focusMemory': instance.focusMemory,
      'focusScale': instance.focusScale,
      'longPressSeek': instance.longPressSeek,
      'channelReversal': instance.channelReversal,
    };

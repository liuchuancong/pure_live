// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'danmaku_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DanmakuPreferences _$DanmakuPreferencesFromJson(Map<String, dynamic> json) =>
    _DanmakuPreferences(
      enabled: json['enabled'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1,
      area: (json['area'] as num?)?.toDouble() ?? 1,
    );

Map<String, dynamic> _$DanmakuPreferencesToJson(_DanmakuPreferences instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'opacity': instance.opacity,
      'fontScale': instance.fontScale,
      'area': instance.area,
    };

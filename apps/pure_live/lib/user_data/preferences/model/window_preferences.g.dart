// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WindowPreferences _$WindowPreferencesFromJson(Map<String, dynamic> json) =>
    _WindowPreferences(
      floatOnLeave: json['floatOnLeave'] as bool? ?? false,
      pauseOnClose: json['pauseOnClose'] as bool? ?? false,
      alwaysOnTop: json['alwaysOnTop'] as bool? ?? false,
      scale: (json['scale'] as num?)?.toDouble() ?? 0.4,
    );

Map<String, dynamic> _$WindowPreferencesToJson(_WindowPreferences instance) =>
    <String, dynamic>{
      'floatOnLeave': instance.floatOnLeave,
      'pauseOnClose': instance.pauseOnClose,
      'alwaysOnTop': instance.alwaysOnTop,
      'scale': instance.scale,
    };

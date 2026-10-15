// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppearancePreferences _$AppearancePreferencesFromJson(Map<String, dynamic> json) => _AppearancePreferences(
  designLanguageId: json['designLanguageId'] as String? ?? '',
  themeMode: $enumDecodeNullable(_$AppThemeModeEnumMap, json['themeMode']) ?? AppThemeMode.system,
  accentColor: (json['accentColor'] as num?)?.toInt(),
  pureBlack: json['pureBlack'] as bool? ?? false,
  densityId: json['densityId'] as String? ?? '',
  fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
  fontFamily: json['fontFamily'] as String?,
  transparency: (json['transparency'] as num?)?.toDouble() ?? 1.0,
  reduceTransparency: json['reduceTransparency'] as bool? ?? false,
  animations: json['animations'] as bool? ?? true,
  focusOutline: json['focusOutline'] as bool? ?? true,
);

Map<String, dynamic> _$AppearancePreferencesToJson(_AppearancePreferences instance) => <String, dynamic>{
  'designLanguageId': instance.designLanguageId,
  'themeMode': _$AppThemeModeEnumMap[instance.themeMode]!,
  'accentColor': instance.accentColor,
  'pureBlack': instance.pureBlack,
  'densityId': instance.densityId,
  'fontScale': instance.fontScale,
  'fontFamily': instance.fontFamily,
  'transparency': instance.transparency,
  'reduceTransparency': instance.reduceTransparency,
  'animations': instance.animations,
  'focusOutline': instance.focusOutline,
};

const _$AppThemeModeEnumMap = {AppThemeMode.system: 'system', AppThemeMode.light: 'light', AppThemeMode.dark: 'dark'};

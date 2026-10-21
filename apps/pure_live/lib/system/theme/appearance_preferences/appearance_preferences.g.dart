// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppearancePreferences _$AppearancePreferencesFromJson(
  Map<String, dynamic> json,
) => _AppearancePreferences(
  designLanguageId: json['designLanguageId'] as String? ?? '',
  themeMode:
      $enumDecodeNullable(_$AppThemeModeEnumMap, json['themeMode']) ??
      AppThemeMode.system,
  accentColor: (json['accentColor'] as num?)?.toInt(),
  pureBlack: json['pureBlack'] as bool? ?? false,
  dynamicColor: json['dynamicColor'] as bool? ?? false,
  densityId: json['densityId'] as String? ?? '',
  fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
  fontFamily: json['fontFamily'] as String?,
  transparency: (json['transparency'] as num?)?.toDouble() ?? 1.0,
  reduceTransparency: json['reduceTransparency'] as bool? ?? false,
  animations: json['animations'] as bool? ?? true,
  focusOutline: json['focusOutline'] as bool? ?? true,
  wallpaperKind:
      $enumDecodeNullable(_$WallpaperKindEnumMap, json['wallpaperKind']) ??
      WallpaperKind.none,
  wallpaperColor: (json['wallpaperColor'] as num?)?.toInt(),
  wallpaperGradientColors:
      (json['wallpaperGradientColors'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  wallpaperGradientAngle:
      (json['wallpaperGradientAngle'] as num?)?.toInt() ?? 0,
  wallpaperGradientStops:
      (json['wallpaperGradientStops'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ??
      const <double>[],
  wallpaperImagePath: json['wallpaperImagePath'] as String? ?? '',
  wallpaperFit: json['wallpaperFit'] as String? ?? 'cover',
  wallpaperBlur: (json['wallpaperBlur'] as num?)?.toDouble() ?? 0.0,
  wallpaperScrim: (json['wallpaperScrim'] as num?)?.toDouble() ?? 0.35,
);

Map<String, dynamic> _$AppearancePreferencesToJson(
  _AppearancePreferences instance,
) => <String, dynamic>{
  'designLanguageId': instance.designLanguageId,
  'themeMode': _$AppThemeModeEnumMap[instance.themeMode]!,
  'accentColor': instance.accentColor,
  'pureBlack': instance.pureBlack,
  'dynamicColor': instance.dynamicColor,
  'densityId': instance.densityId,
  'fontScale': instance.fontScale,
  'fontFamily': instance.fontFamily,
  'transparency': instance.transparency,
  'reduceTransparency': instance.reduceTransparency,
  'animations': instance.animations,
  'focusOutline': instance.focusOutline,
  'wallpaperKind': _$WallpaperKindEnumMap[instance.wallpaperKind]!,
  'wallpaperColor': instance.wallpaperColor,
  'wallpaperGradientColors': instance.wallpaperGradientColors,
  'wallpaperGradientAngle': instance.wallpaperGradientAngle,
  'wallpaperGradientStops': instance.wallpaperGradientStops,
  'wallpaperImagePath': instance.wallpaperImagePath,
  'wallpaperFit': instance.wallpaperFit,
  'wallpaperBlur': instance.wallpaperBlur,
  'wallpaperScrim': instance.wallpaperScrim,
};

const _$AppThemeModeEnumMap = {
  AppThemeMode.system: 'system',
  AppThemeMode.light: 'light',
  AppThemeMode.dark: 'dark',
};

const _$WallpaperKindEnumMap = {
  WallpaperKind.none: 'none',
  WallpaperKind.solid: 'solid',
  WallpaperKind.gradient: 'gradient',
  WallpaperKind.image: 'image',
};

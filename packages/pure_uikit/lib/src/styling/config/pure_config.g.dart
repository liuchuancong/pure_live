// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pure_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UiConfig _$UiConfigFromJson(Map<String, dynamic> json) => _UiConfig(
  language: $enumDecode(_$PureDesignLanguageEnumMap, json['language']),
  brightness: $enumDecodeNullable(_$UiBrightnessModeEnumMap, json['brightness']) ?? UiBrightnessMode.system,
  accent: const ColorConverter().fromJson((json['accent'] as num?)?.toInt()),
  pureBlack: json['pureBlack'] as bool? ?? false,
  density: $enumDecodeNullable(_$UiDensityEnumMap, json['density']) ?? UiDensity.comfortable,
  fontFamily: json['fontFamily'] as String?,
  fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
  bodySmallSize: (json['bodySmallSize'] as num?)?.toDouble(),
  bodySize: (json['bodySize'] as num?)?.toDouble(),
  subtitleSize: (json['subtitleSize'] as num?)?.toDouble(),
  titleSize: (json['titleSize'] as num?)?.toDouble(),
  headlineSize: (json['headlineSize'] as num?)?.toDouble(),
  transparency: (json['transparency'] as num?)?.toDouble() ?? 1.0,
  reduceTransparency: json['reduceTransparency'] as bool? ?? false,
  animations: json['animations'] as bool? ?? true,
  focusOutline: json['focusOutline'] as bool? ?? true,
);

Map<String, dynamic> _$UiConfigToJson(_UiConfig instance) => <String, dynamic>{
  'language': _$PureDesignLanguageEnumMap[instance.language]!,
  'brightness': _$UiBrightnessModeEnumMap[instance.brightness]!,
  'accent': const ColorConverter().toJson(instance.accent),
  'pureBlack': instance.pureBlack,
  'density': _$UiDensityEnumMap[instance.density]!,
  'fontFamily': instance.fontFamily,
  'fontScale': instance.fontScale,
  'bodySmallSize': instance.bodySmallSize,
  'bodySize': instance.bodySize,
  'subtitleSize': instance.subtitleSize,
  'titleSize': instance.titleSize,
  'headlineSize': instance.headlineSize,
  'transparency': instance.transparency,
  'reduceTransparency': instance.reduceTransparency,
  'animations': instance.animations,
  'focusOutline': instance.focusOutline,
};

const _$PureDesignLanguageEnumMap = {PureDesignLanguage.fluent: 'fluent'};

const _$UiBrightnessModeEnumMap = {
  UiBrightnessMode.system: 'system',
  UiBrightnessMode.light: 'light',
  UiBrightnessMode.dark: 'dark',
};

const _$UiDensityEnumMap = {
  UiDensity.compact: 'compact',
  UiDensity.comfortable: 'comfortable',
  UiDensity.spacious: 'spacious',
};

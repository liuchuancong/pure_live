// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UiConfig _$UiConfigFromJson(Map<String, dynamic> json) => _UiConfig(
  language: $enumDecodeNullable(_$LiveDesignLanguageEnumMap, json['language']) ?? LiveDesignLanguage.token,
  brightness: $enumDecodeNullable(_$UiBrightnessModeEnumMap, json['brightness']) ?? UiBrightnessMode.system,
  accent: const ColorConverter().fromJson((json['accent'] as num?)?.toInt()),
  pureBlack: json['pureBlack'] as bool? ?? false,
  density: $enumDecodeNullable(_$UiDensityEnumMap, json['density']) ?? UiDensity.comfortable,
  fontFamily: json['fontFamily'] as String?,
  fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
  transparency: (json['transparency'] as num?)?.toDouble() ?? 1.0,
  reduceTransparency: json['reduceTransparency'] as bool? ?? false,
  animations: json['animations'] as bool? ?? true,
  focusOutline: json['focusOutline'] as bool? ?? true,
);

Map<String, dynamic> _$UiConfigToJson(_UiConfig instance) => <String, dynamic>{
  'language': _$LiveDesignLanguageEnumMap[instance.language]!,
  'brightness': _$UiBrightnessModeEnumMap[instance.brightness]!,
  'accent': const ColorConverter().toJson(instance.accent),
  'pureBlack': instance.pureBlack,
  'density': _$UiDensityEnumMap[instance.density]!,
  'fontFamily': instance.fontFamily,
  'fontScale': instance.fontScale,
  'transparency': instance.transparency,
  'reduceTransparency': instance.reduceTransparency,
  'animations': instance.animations,
  'focusOutline': instance.focusOutline,
};

const _$LiveDesignLanguageEnumMap = {
  LiveDesignLanguage.token: 'token',
  LiveDesignLanguage.fluent: 'fluent',
  LiveDesignLanguage.macos: 'macos',
  LiveDesignLanguage.neumorphic: 'neumorphic',
  LiveDesignLanguage.glass: 'glass',
  LiveDesignLanguage.wind: 'wind',
  LiveDesignLanguage.forui: 'forui',
  LiveDesignLanguage.material: 'material',
  LiveDesignLanguage.cupertino: 'cupertino',
};

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

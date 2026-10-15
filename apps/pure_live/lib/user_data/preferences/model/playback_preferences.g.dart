// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlaybackPreferences _$PlaybackPreferencesFromJson(Map<String, dynamic> json) =>
    _PlaybackPreferences(
      quality: json['quality'] as String? ?? '',
      engineId: json['engineId'] as String? ?? '',
      linePreference:
          $enumDecodeNullable(
            _$LinePreferenceEnumMap,
            json['linePreference'],
          ) ??
          LinePreference.automatic,
      preferredLineId: json['preferredLineId'] as String? ?? '',
      autoRecover: json['autoRecover'] as bool? ?? true,
      maxRecoveryAttempts: (json['maxRecoveryAttempts'] as num?)?.toInt() ?? 3,
    );

Map<String, dynamic> _$PlaybackPreferencesToJson(
  _PlaybackPreferences instance,
) => <String, dynamic>{
  'quality': instance.quality,
  'engineId': instance.engineId,
  'linePreference': _$LinePreferenceEnumMap[instance.linePreference]!,
  'preferredLineId': instance.preferredLineId,
  'autoRecover': instance.autoRecover,
  'maxRecoveryAttempts': instance.maxRecoveryAttempts,
};

const _$LinePreferenceEnumMap = {
  LinePreference.automatic: 'automatic',
  LinePreference.preferred: 'preferred',
};

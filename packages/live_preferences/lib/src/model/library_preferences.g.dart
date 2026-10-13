// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LibraryPreferences _$LibraryPreferencesFromJson(Map<String, dynamic> json) =>
    _LibraryPreferences(
      listLayout:
          $enumDecodeNullable(_$LiveListLayoutEnumMap, json['listLayout']) ??
          LiveListLayout.grid,
      gridColumns: (json['gridColumns'] as num?)?.toInt() ?? 2,
      historyLimit: (json['historyLimit'] as num?)?.toInt() ?? 300,
    );

Map<String, dynamic> _$LibraryPreferencesToJson(_LibraryPreferences instance) =>
    <String, dynamic>{
      'listLayout': _$LiveListLayoutEnumMap[instance.listLayout]!,
      'gridColumns': instance.gridColumns,
      'historyLimit': instance.historyLimit,
    };

const _$LiveListLayoutEnumMap = {
  LiveListLayout.grid: 'grid',
  LiveListLayout.list: 'list',
};

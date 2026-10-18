// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_path_choices.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserPathChoices _$UserPathChoicesFromJson(Map<String, dynamic> json) =>
    _UserPathChoices(
      customByArea:
          (json['customByArea'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$UserPathChoicesToJson(_UserPathChoices instance) =>
    <String, dynamic>{'customByArea': instance.customByArea};

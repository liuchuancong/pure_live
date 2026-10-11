// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anchor_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnchorSummary _$AnchorSummaryFromJson(Map<String, dynamic> json) =>
    _AnchorSummary(
      ref: refFromJson(json['ref']),
      name: _name(json['name']),
      avatar: _text(json['avatar']),
      fans: _intOrNull(json['fans']),
      currentRoom: refFromJsonOrNull(json['currentRoom']),
      description: _text(json['description']),
      extra: json['extra'] == null
          ? const <String, Object?>{}
          : _map(json['extra']),
    );

Map<String, dynamic> _$AnchorSummaryToJson(_AnchorSummary instance) =>
    <String, dynamic>{
      'ref': refToJson(instance.ref),
      'name': instance.name,
      'avatar': ?instance.avatar,
      'fans': ?_intOrNull(instance.fans),
      'currentRoom': ?refToJsonOrNull(instance.currentRoom),
      'description': ?instance.description,
      'extra': _mapOut(instance.extra),
    };

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class UserFullModel {
  final String email;
  final DateTime? createdAt;
  final String? updateAt;
  final String? version;
  final UserConfigModel? config;
  final Map<String, dynamic> backupMap;

  UserFullModel({
    required this.email,
    required this.createdAt,
    this.updateAt,
    this.version,
    this.config,
    this.backupMap = const {},
  });

  factory UserFullModel.fromFirestore(Map<String, dynamic> data) {
    final configMap = _configMap(data['config']);

    return UserFullModel(
      email: _stringOrNull(data['email']) ?? '',
      createdAt: _dateTimeOrNull(data['created_at']) ?? _dateTimeOrNull(data['createdAt']),
      updateAt: _stringOrNull(data['update_at']),
      version: _stringOrNull(data['version']),
      config: configMap == null ? null : UserConfigModel.fromBackupMap(configMap),
      backupMap: configMap ?? const {},
    );
  }
}

class UserConfigModel {
  final int backupVersion;
  final Map<String, dynamic> app;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> font;
  final Map<String, dynamic> player;
  final Map<String, dynamic> danmaku;
  final Map<String, dynamic> volume;
  final Map<String, dynamic> favorite;
  final Map<String, dynamic> history;
  final Map<String, dynamic> webdav;
  final Map<String, dynamic> iptv;
  final Map<String, dynamic> cookie;
  final Map<String, dynamic> proxy;
  final Map<String, dynamic> windowSize;
  final Map<String, dynamic> exit;
  final Map<String, dynamic> startup;
  final Map<String, dynamic> tags;
  final Map<String, dynamic> refresh;
  final Map<String, dynamic> page;

  UserConfigModel({
    required this.backupVersion,
    required this.app,
    required this.theme,
    required this.font,
    required this.player,
    required this.danmaku,
    required this.volume,
    required this.favorite,
    required this.history,
    required this.webdav,
    required this.iptv,
    required this.cookie,
    required this.proxy,
    required this.windowSize,
    required this.exit,
    required this.startup,
    required this.tags,
    required this.refresh,
    required this.page,
  });

  factory UserConfigModel.fromBackupMap(Map<String, dynamic> map) {
    return UserConfigModel(
      backupVersion: _backupVersion(map['backupVersion']),
      app: _mapSection(map['app']),
      theme: _mapSection(map['theme']),
      font: _mapSection(map['font']),
      player: _mapSection(map['player']),
      danmaku: _mapSection(map['danmaku']),
      volume: _mapSection(map['volume']),
      favorite: _mapSection(map['favorite']),
      history: _mapSection(map['history']),
      webdav: _mapSection(map['webdav']),
      iptv: _mapSection(map['iptv']),
      cookie: _mapSection(map['cookie']),
      proxy: _mapSection(map['proxy']),
      windowSize: _mapSection(map['windowSize']),
      exit: _mapSection(map['exit']),
      startup: _mapSection(map['startup']),
      tags: _mapSection(map['tags']),
      refresh: _mapSection(map['refresh']),
      page: _mapSection(map['page']),
    );
  }

  Map<String, dynamic> toBackupMap() {
    return {
      'backupVersion': backupVersion,
      'app': app,
      'theme': theme,
      'font': font,
      'player': player,
      'danmaku': danmaku,
      'volume': volume,
      'favorite': favorite,
      'history': history,
      'webdav': webdav,
      'iptv': iptv,
      'cookie': cookie,
      'proxy': proxy,
      'windowSize': windowSize,
      'exit': exit,
      'startup': startup,
      'tags': tags,
      'refresh': refresh,
      'page': page,
    };
  }

  static UserConfigModel fromRawJsonString(String rawStr) {
    final configMap = _configMap(rawStr);
    if (configMap == null) {
      throw const FormatException('Backup configuration must be a JSON object.');
    }
    return UserConfigModel.fromBackupMap(configMap);
  }
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } on RangeError {
      return null;
    }
  }
  if (value is String) return DateTime.tryParse(value.trim());
  return null;
}

Map<String, dynamic>? _configMap(Object? value) {
  Object? decoded = value;
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    try {
      decoded = jsonDecode(normalized);
    } on FormatException {
      return null;
    }
  }
  if (decoded is! Map) return null;

  final result = <String, dynamic>{};
  for (final entry in decoded.entries) {
    if (entry.key is String) result[entry.key as String] = entry.value;
  }
  return result;
}

Map<String, dynamic> _mapSection(Object? value) {
  if (value is! Map) return {};
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is String) result[entry.key as String] = entry.value;
  }
  return result;
}

int _backupVersion(Object? value) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };
  return parsed == null || parsed < 1 ? 1 : parsed;
}

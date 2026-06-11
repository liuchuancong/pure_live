import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserFullModel {
  final String email;
  final Timestamp createdAt;
  final String? updateAt;
  final String? version;
  final UserConfigModel? config;

  UserFullModel({required this.email, required this.createdAt, this.updateAt, this.version, this.config});

  factory UserFullModel.fromFirestore(Map<String, dynamic> data) {
    UserConfigModel? parsedConfig;

    if (data['config'] != null) {
      Map<String, dynamic> configMap = {};
      if (data['config'] is String) {
        configMap = json.decode(data['config']) as Map<String, dynamic>;
      } else if (data['config'] is Map) {
        configMap = Map<String, dynamic>.from(data['config']);
      }
      parsedConfig = UserConfigModel.fromBackupMap(configMap);
    }

    return UserFullModel(
      email: data['email'] ?? '',
      createdAt: data['created_at'] ?? Timestamp.now(),
      updateAt: data['update_at'],
      version: data['version'],
      config: parsedConfig,
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
      backupVersion: map['backupVersion'] ?? 1,
      app: Map<String, dynamic>.from(map['app'] ?? {}),
      theme: Map<String, dynamic>.from(map['theme'] ?? {}),
      font: Map<String, dynamic>.from(map['font'] ?? {}),
      player: Map<String, dynamic>.from(map['player'] ?? {}),
      danmaku: Map<String, dynamic>.from(map['danmaku'] ?? {}),
      volume: Map<String, dynamic>.from(map['volume'] ?? {}),
      favorite: Map<String, dynamic>.from(map['favorite'] ?? {}),
      history: Map<String, dynamic>.from(map['history'] ?? {}),
      webdav: Map<String, dynamic>.from(map['webdav'] ?? {}),
      iptv: Map<String, dynamic>.from(map['iptv'] ?? {}),
      cookie: Map<String, dynamic>.from(map['cookie'] ?? {}),
      proxy: Map<String, dynamic>.from(map['proxy'] ?? {}),
      windowSize: Map<String, dynamic>.from(map['windowSize'] ?? {}),
      exit: Map<String, dynamic>.from(map['exit'] ?? {}),
      startup: Map<String, dynamic>.from(map['startup'] ?? {}),
      tags: Map<String, dynamic>.from(map['tags'] ?? {}),
      refresh: Map<String, dynamic>.from(map['refresh'] ?? {}),
      page: Map<String, dynamic>.from(map['page'] ?? {}),
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
    final decode = json.decode(rawStr) as Map<String, dynamic>;
    return UserConfigModel.fromBackupMap(decode);
  }
}

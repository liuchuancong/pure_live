import 'dart:async' show unawaited;
import 'dart:io';

import 'package:live_storage/live_storage.dart';

// A demo prints; that is its whole job.
// ignore_for_file: avoid_print

/// A favorite live room, stored as a JSON document.
final class FavoriteRoom {
  /// Creates a favorite room.
  new(this.platform, this.roomId, this.nick);

  /// Restores a room from its stored JSON document.
  factory fromJson(Map<String, Object?> json) {
    return FavoriteRoom(json['platform']! as String, json['roomId']! as String, json['nick']! as String);
  }

  /// The site the room lives on.
  final String platform;

  /// The room id on that site.
  final String roomId;

  /// The streamer's display name.
  final String nick;

  /// Serializes the room to its JSON document.
  Map<String, Object?> toJson() => {'platform': platform, 'roomId': roomId, 'nick': nick};

  @override
  String toString() => '$platform/$roomId ($nick)';
}

/// A player setting pair, stored through `prefObject` as JSON.
final class PlayerSettings {
  /// Creates settings.
  new(this.rate, this.volume);

  /// Restores settings from its stored JSON document.
  factory fromJson(Map<String, Object?> json) {
    return PlayerSettings(json['rate']! as double, json['volume']! as double);
  }

  /// The playback rate.
  final double rate;

  /// The output volume.
  final double volume;

  /// Serializes the settings to their JSON document.
  Map<String, Object?> toJson() => {'rate': rate, 'volume': volume};

  @override
  String toString() => 'PlayerSettings(rate: $rate, volume: $volume)';
}

/// Walks the live_storage story: bootstrap, a namespaced JSON store, the
/// settings facade and write-through pref values.
Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp('live_storage_demo');
  print('Storage directory: ${directory.path}');

  _section('1. Bootstrap');
  final bootstrap = StorageBootstrap(pathProvider: StoragePathProvider(resolver: () async => directory.path));
  await bootstrap.initialize();
  print('SQLite opened at ${StorageStores.instance.databasePath}');

  _section('2. Namespaced JSON store');
  final rooms = await StorageStores.instance.openStore('demo.rooms');
  final changes = rooms.watchKeys().listen((key) => print('  [watch] $key changed'));
  await rooms.put('222', FavoriteRoom('huya', '222', 'synk').toJson());
  await rooms.put('999', FavoriteRoom('douyu', '999', 'otto').toJson());
  print('get(222)     -> ${FavoriteRoom.fromJson(rooms.get('222')! as Map<String, Object?>)}');
  await rooms.put('222', FavoriteRoom('huya', '222', 'synk2').toJson());
  print('after update -> ${FavoriteRoom.fromJson(rooms.get('222')! as Map<String, Object?>)}');
  print('count/keys   -> ${rooms.length} ${rooms.keys}');
  await rooms.delete('999');
  print('after delete -> count ${rooms.length}');
  await changes.cancel();

  _section('3. StoragePrefs');
  await StoragePrefs.init();
  await StoragePrefs.setString('lastPlatform', 'huya');
  print('lastPlatform -> ${StoragePrefs.getString('lastPlatform')}');
  await StoragePrefs.persistBatch(() {
    unawaited(StoragePrefs.setBool('danmakuOn', true));
    unawaited(StoragePrefs.setInt('danmakuSize', 18));
  });
  print(
    'batch        -> danmakuOn=${StoragePrefs.getBool('danmakuOn')} '
    'danmakuSize=${StoragePrefs.getInt('danmakuSize')}',
  );
  await StoragePrefs.remove('danmakuSize');

  _section('4. PrefValue');
  prefBool('danmakuOn', false)
    ..listen((value) => print('  [pref] danmakuOn -> $value'))
    ..v = false;
  final player = prefObject(
    'demo.player',
    PlayerSettings(1, 1),
    fromJson: PlayerSettings.fromJson,
    toJson: (settings) => settings.toJson(),
  )..v = PlayerSettings(1.5, 0.4);
  print('player       -> $player');

  _section('5. Shutdown');
  await StoragePrefs.flush();
  await bootstrap.shutdown();
  await directory.delete(recursive: true);
  print('Flushed, closed and removed the temp directory.');
}

void _section(String title) {
  print('');
  print('== $title');
}

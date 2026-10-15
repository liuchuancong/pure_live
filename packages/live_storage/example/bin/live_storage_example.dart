import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:live_storage/live_storage.dart';

// A demo prints; that is its whole job.
// ignore_for_file: avoid_print

/// A favorite live room, stored as a typed value behind a [JsonBoxAdapter].
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

/// A player setting pair, stored through `prefObject` as JSON — no adapter
/// needed.
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

/// Walks the live_storage story: bootstrap, typed repository, the simple
/// settings facade and write-through pref values.
Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp('live_storage_demo');
  print('Storage directory: ${directory.path}');

  _section('1. Bootstrap');
  final adapters = StorageAdapterRegistry()
    ..add('demo', () {
      // Type ids are a workspace-wide registry: assign once, never renumber.
      Hive.registerAdapter(
        JsonBoxAdapter<FavoriteRoom>(42, fromJson: FavoriteRoom.fromJson, toJson: (room) => room.toJson()),
      );
    });
  final bootstrap = StorageBootstrap(
    pathProvider: StoragePathProvider(resolver: () async => directory.path),
    adapterRegistry: adapters,
  );
  await bootstrap.initialize();
  print('Hive initialized at the app-provided path; demo adapter registered.');

  _section('2. Typed repository');
  final rooms = HiveStorageRepository<FavoriteRoom>(box: await StorageBoxManager().keyed<FavoriteRoom>('demo.rooms'));
  final changes = rooms.watch(key: '222').listen((_) => print('  [watch] 222 changed'));
  await rooms.save('222', FavoriteRoom('huya', '222', 'synk'));
  await rooms.save('999', FavoriteRoom('douyu', '999', 'otto'));
  print('get(222)     -> ${rooms.get('222')}');
  await rooms.update('222', (room) => FavoriteRoom(room.platform, room.roomId, 'synk2'));
  print('after update -> ${rooms.get('222')}');
  print('count/keys   -> ${rooms.count} ${rooms.getAllKeys()}');
  await rooms.delete('999');
  print('after delete -> count ${rooms.count}');
  await changes.cancel();

  _section('3. StoragePrefs');
  await StoragePrefs.init();
  await StoragePrefs.setString('lastPlatform', 'huya');
  print('lastPlatform -> ${StoragePrefs.getString('lastPlatform')}');
  await StoragePrefs.persistBatch(() async {
    await StoragePrefs.setBool('danmakuOn', true);
    await StoragePrefs.setInt('danmakuSize', 18);
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

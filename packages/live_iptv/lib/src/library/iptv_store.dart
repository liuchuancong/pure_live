import 'dart:async';

import 'package:live_iptv/src/model/iptv_models.dart';
import 'package:live_storage/live_storage.dart';

/// The persistence seam of the IPTV library.
abstract interface class IptvStore {
  /// Loads the channels (ordered by position).
  Future<List<IptvChannel>> loadChannels();

  /// Loads the imported playlists.
  Future<List<IptvPlaylist>> loadPlaylists();

  /// Stores the channels.
  Future<void> saveChannels(List<IptvChannel> channels);

  /// Stores the playlists.
  Future<void> savePlaylists(List<IptvPlaylist> playlists);

  /// Emits when another writer changed the library.
  Stream<void> get changes;
}

/// The preference keys the library owns.
abstract final class IptvKeys {
  /// Library channels.
  static const String channels = 'iptv.channels.v1';

  /// Imported playlists.
  static const String playlists = 'iptv.playlists.v1';
}

/// An [IptvStore] over the live_storage preferences seam.
final class PreferencesIptvStore implements IptvStore {
  /// A store over [preferences].
  new(this.preferences);

  /// The preferences store.
  final PreferencesStore preferences;

  @override
  Stream<void> get changes => preferences.changes;

  @override
  Future<List<IptvChannel>> loadChannels() => _load(IptvKeys.channels, IptvChannel.fromJson);

  @override
  Future<List<IptvPlaylist>> loadPlaylists() => _load(IptvKeys.playlists, IptvPlaylist.fromJson);

  @override
  Future<void> saveChannels(List<IptvChannel> channels) =>
      _save(IptvKeys.channels, channels, (channel) => channel.toJson());

  @override
  Future<void> savePlaylists(List<IptvPlaylist> playlists) =>
      _save(IptvKeys.playlists, playlists, (playlist) => playlist.toJson());

  Future<List<T>> _load<T>(String key, T Function(Map<String, Object?>) fromJson) async {
    final raw = await preferences.read(key);
    if (raw is! List) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is Map) fromJson(entry.cast<String, Object?>()),
    ];
  }

  Future<void> _save<T>(String key, List<T> items, Map<String, Object?> Function(T) toJson) =>
      preferences.write(key, [for (final item in items) toJson(item)]);
}

/// An in-memory [IptvStore] for tests and previews.
final class InMemoryIptvStore implements IptvStore {
  /// An empty store.
  new();

  final _changes = StreamController<void>.broadcast();
  List<IptvChannel> _channels = const [];
  List<IptvPlaylist> _playlists = const [];

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<IptvChannel>> loadChannels() async => _channels;

  @override
  Future<List<IptvPlaylist>> loadPlaylists() async => _playlists;

  @override
  Future<void> saveChannels(List<IptvChannel> channels) async {
    _channels = List.unmodifiable(channels);
    _changes.add(null);
  }

  @override
  Future<void> savePlaylists(List<IptvPlaylist> playlists) async {
    _playlists = List.unmodifiable(playlists);
    _changes.add(null);
  }
}

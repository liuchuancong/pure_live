import 'dart:async';

import 'package:live_iptv/src/model/guide_models.dart';
import 'package:live_iptv/src/model/iptv_models.dart';
import 'package:live_storage/live_storage.dart';

/// The persistence seam of the IPTV library.
abstract interface class IptvStore {
  /// Loads the channels (ordered by position).
  Future<List<IptvChannel>> loadChannels();

  /// Loads the imported playlists.
  Future<List<IptvPlaylist>> loadPlaylists();

  /// Loads the guide sources (in import order).
  Future<List<EpgSource>> loadGuideSources();

  /// Loads every stored guide channel.
  Future<List<EpgChannel>> loadGuideChannels();

  /// Loads every stored programme.
  Future<List<EpgProgramme>> loadGuideProgrammes();

  /// Loads every stored channel-to-guide mapping.
  Future<List<EpgMapping>> loadGuideMappings();

  /// Stores the channels.
  Future<void> saveChannels(List<IptvChannel> channels);

  /// Stores the playlists.
  Future<void> savePlaylists(List<IptvPlaylist> playlists);

  /// Stores the guide sources.
  Future<void> saveGuideSources(List<EpgSource> sources);

  /// Stores every guide channel (the whole set, one write).
  Future<void> saveGuideChannels(List<EpgChannel> channels);

  /// Stores every programme (the whole set, one write).
  Future<void> saveGuideProgrammes(List<EpgProgramme> programmes);

  /// Stores every channel-to-guide mapping (the whole set, one write).
  Future<void> saveGuideMappings(List<EpgMapping> mappings);

  /// Emits when another writer changed the library.
  Stream<void> get changes;
}

/// The keys the IPTV library owns in its keyed table.
abstract final class IptvKeys {
  /// The table the IPTV library owns in the shared database.
  static const String table = 'iptv';

  /// Library channels.
  static const String channels = 'iptv.channels.v1';

  /// Imported playlists.
  static const String playlists = 'iptv.playlists.v1';

  /// Guide sources.
  static const String guideSources = 'iptv.guideSources.v1';

  /// Stored guide channels.
  static const String guideChannels = 'iptv.guideChannels.v1';

  /// Stored programmes.
  static const String guideProgrammes = 'iptv.guideProgrammes.v1';

  /// Channel-to-guide mappings.
  static const String guideMappings = 'iptv.guideMappings.v1';
}

/// An [IptvStore] over a live_storage keyed store.
final class KeyedIptvStore implements IptvStore {
  /// A store writing through [store].
  new(this.store);

  /// The keyed store (drift-backed in production).
  final KeyedStore store;

  @override
  Stream<void> get changes => store.watch();

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

  @override
  Future<List<EpgSource>> loadGuideSources() => _load(IptvKeys.guideSources, EpgSource.fromJson);

  @override
  Future<List<EpgChannel>> loadGuideChannels() => _load(IptvKeys.guideChannels, EpgChannel.fromJson);

  @override
  Future<List<EpgProgramme>> loadGuideProgrammes() => _load(IptvKeys.guideProgrammes, EpgProgramme.fromJson);

  @override
  Future<List<EpgMapping>> loadGuideMappings() => _load(IptvKeys.guideMappings, EpgMapping.fromJson);

  @override
  Future<void> saveGuideSources(List<EpgSource> sources) =>
      _save(IptvKeys.guideSources, sources, (source) => source.toJson());

  @override
  Future<void> saveGuideChannels(List<EpgChannel> channels) =>
      _save(IptvKeys.guideChannels, channels, (channel) => channel.toJson());

  @override
  Future<void> saveGuideProgrammes(List<EpgProgramme> programmes) =>
      _save(IptvKeys.guideProgrammes, programmes, (programme) => programme.toJson());

  @override
  Future<void> saveGuideMappings(List<EpgMapping> mappings) =>
      _save(IptvKeys.guideMappings, mappings, (mapping) => mapping.toJson());

  Future<List<T>> _load<T>(String key, T Function(Map<String, Object?>) fromJson) async {
    final raw = store.get<Object?>(key);
    if (raw is! List) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is Map) fromJson(entry.cast<String, Object?>()),
    ];
  }

  Future<void> _save<T>(String key, List<T> items, Map<String, Object?> Function(T) toJson) =>
      store.put(key, [for (final item in items) toJson(item)]);
}

/// An in-memory [IptvStore] for tests and previews.
final class InMemoryIptvStore implements IptvStore {
  /// An empty store.
  new();

  final _changes = StreamController<void>.broadcast();
  List<IptvChannel> _channels = const [];
  List<IptvPlaylist> _playlists = const [];
  List<EpgSource> _sources = const [];
  List<EpgChannel> _guideChannels = const [];
  List<EpgProgramme> _programmes = const [];
  List<EpgMapping> _mappings = const [];

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<IptvChannel>> loadChannels() async => _channels;

  @override
  Future<List<IptvPlaylist>> loadPlaylists() async => _playlists;

  @override
  Future<List<EpgSource>> loadGuideSources() async => _sources;

  @override
  Future<List<EpgChannel>> loadGuideChannels() async => _guideChannels;

  @override
  Future<List<EpgProgramme>> loadGuideProgrammes() async => _programmes;

  @override
  Future<List<EpgMapping>> loadGuideMappings() async => _mappings;

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

  @override
  Future<void> saveGuideSources(List<EpgSource> sources) async {
    _sources = List.unmodifiable(sources);
    _changes.add(null);
  }

  @override
  Future<void> saveGuideChannels(List<EpgChannel> channels) async {
    _guideChannels = List.unmodifiable(channels);
    _changes.add(null);
  }

  @override
  Future<void> saveGuideProgrammes(List<EpgProgramme> programmes) async {
    _programmes = List.unmodifiable(programmes);
    _changes.add(null);
  }

  @override
  Future<void> saveGuideMappings(List<EpgMapping> mappings) async {
    _mappings = List.unmodifiable(mappings);
    _changes.add(null);
  }
}

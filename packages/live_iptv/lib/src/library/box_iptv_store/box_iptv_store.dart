import 'dart:async';

import 'package:live_iptv/src/library/iptv_keys/iptv_keys.dart';
import 'package:live_iptv/src/library/iptv_store/iptv_store.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_storage/live_storage.dart';

/// An [IptvStore] over a live_storage list repository.
///
/// One document per concern, each written whole; a half-written document is
/// the failure mode this avoids, at the cost of rewriting a list to change
/// one row. The library is small enough for that and the alternative is a
/// schema migration for every field.
final class BoxIptvStore implements IptvStore {
  /// A store writing through [store].
  new(this.store);

  /// The IPTV repository, one document per concern.
  ///
  /// The element type is `Object?`, not `Map`: Hive hands a stored list back as
  /// a `List<dynamic>`, so a box typed any narrower fails its own value codec
  /// on the first read after a write.
  final StorageListRepository<Object?> store;

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

  @override
  Future<List<IptvGroup>> loadGroups() => _load(IptvKeys.groups, IptvGroup.fromJson);

  @override
  Future<void> saveGroups(List<IptvGroup> groups) => _save(IptvKeys.groups, groups, (group) => group.toJson());

  @override
  Future<List<IptvLineHealth>> loadLineHealth() async {
    final raw = store.get(IptvKeys.lineHealth);
    if (raw == null) {
      return const [];
    }
    // A record whose address is gone is dropped rather than guessed at:
    // half a verdict about an unknown URL would rank a line the probe never
    // asked about.
    return [
      for (final entry in raw)
        if (entry is Map) ?IptvLineHealth.fromJson(entry.cast<String, Object?>()),
    ];
  }

  @override
  Future<void> saveLineHealth(List<IptvLineHealth> health) =>
      _save(IptvKeys.lineHealth, health, (record) => record.toJson());

  Future<List<T>> _load<T>(String key, T Function(Map<String, Object?>) fromJson) async {
    final raw = store.get(key);
    if (raw == null) {
      return const [];
    }
    // One unreadable entry drops out, not the document: a record written by
    // an older schema must not blank the whole library.
    final items = <T>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final decoded = _decode(fromJson, entry.cast<String, Object?>());
      if (decoded != null) {
        items.add(decoded);
      }
    }
    return items;
  }

  static T? _decode<T>(T Function(Map<String, Object?>) fromJson, Map<String, Object?> json) {
    try {
      return fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> _save<T>(String key, List<T> items, Map<String, Object?> Function(T) toJson) =>
      store.save(key, [for (final item in items) toJson(item)]);
}

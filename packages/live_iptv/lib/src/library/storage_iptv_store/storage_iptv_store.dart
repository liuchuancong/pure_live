import 'dart:async';

import 'package:live_iptv/src/library/iptv_keys/iptv_keys.dart';
import 'package:live_iptv/src/library/iptv_store/iptv_store.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_storage/live_storage.dart';

/// An [IptvStore] over the app's shared JSON list store.
///
/// One document per concern, each written whole; a half-written document is
/// the failure mode this avoids, at the cost of rewriting a list to change
/// one row. The library is small enough for that and the alternative is a
/// schema migration for every field.
///
/// Dates cross this boundary in UTC and live everywhere else in the
/// viewer's local clock. built_value's wire format demands UTC
/// (`DateTimeSerializer` refuses a local instant), but every clock the
/// package keeps — an import's date, a programme's start — is created from
/// `DateTime.now()` and shown as the wall clock it names, and the records
/// the retired converters wrote carry no offset at all. So the store is the
/// one place the two meet: a save converts what the wire needs, a load
/// hands records back the way the rest of the package has always held
/// them — local rows untouched, UTC rows brought back.
final class StorageIptvStore implements IptvStore {
  /// A store writing through [store].
  new(this.store);

  /// The IPTV list store, one document per concern.
  final JsonListStore store;

  @override
  Stream<void> get changes => store.watch();

  @override
  Future<List<IptvChannel>> loadChannels() => _load(IptvKeys.channels, IptvChannel.fromJson);

  @override
  Future<List<IptvPlaylist>> loadPlaylists() =>
      _load(IptvKeys.playlists, (json) => _playlistLocal(IptvPlaylist.fromJson(json)));

  @override
  Future<void> saveChannels(List<IptvChannel> channels) =>
      _save(IptvKeys.channels, channels, (channel) => channel.toJson());

  @override
  Future<void> savePlaylists(List<IptvPlaylist> playlists) =>
      _save(IptvKeys.playlists, playlists, (playlist) => _playlistUtc(playlist).toJson());

  @override
  Future<List<EpgSource>> loadGuideSources() =>
      _load(IptvKeys.guideSources, (json) => _sourceLocal(EpgSource.fromJson(json)));

  @override
  Future<List<EpgChannel>> loadGuideChannels() => _load(IptvKeys.guideChannels, EpgChannel.fromJson);

  @override
  Future<List<EpgProgramme>> loadGuideProgrammes() =>
      _load(IptvKeys.guideProgrammes, (json) => _programmeLocal(EpgProgramme.fromJson(json)));

  @override
  Future<List<EpgMapping>> loadGuideMappings() => _load(IptvKeys.guideMappings, EpgMapping.fromJson);

  @override
  Future<void> saveGuideSources(List<EpgSource> sources) =>
      _save(IptvKeys.guideSources, sources, (source) => _sourceUtc(source).toJson());

  @override
  Future<void> saveGuideChannels(List<EpgChannel> channels) =>
      _save(IptvKeys.guideChannels, channels, (channel) => channel.toJson());

  @override
  Future<void> saveGuideProgrammes(List<EpgProgramme> programmes) =>
      _save(IptvKeys.guideProgrammes, programmes, (programme) => _programmeUtc(programme).toJson());

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
    if (raw is! List) {
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
    if (raw is! List) {
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

  // Date normalization ---------------------------------------------------------

  /// [record] with `importedAt` on the wire's clock (UTC) — a copy only when
  /// the date is not already UTC, so an unchanged save copies nothing.
  static IptvPlaylist _playlistUtc(IptvPlaylist record) =>
      record.importedAt.isUtc ? record : record.rebuild((b) => b..importedAt = record.importedAt.toUtc());

  /// [record] with `importedAt` back in the viewer's clock.
  static IptvPlaylist _playlistLocal(IptvPlaylist record) =>
      record.importedAt.isUtc ? record.rebuild((b) => b..importedAt = record.importedAt.toLocal()) : record;

  /// [record] with its refresh and creation dates on the wire's clock.
  static EpgSource _sourceUtc(EpgSource record) {
    final refresh = record.lastRefresh;
    final created = record.createdAt;
    final utcRefresh = refresh == null || refresh.isUtc;
    final utcCreated = created == null || created.isUtc;
    if (utcRefresh && utcCreated) {
      return record;
    }
    return record.rebuild(
      (b) => b
        ..lastRefresh = refresh?.toUtc()
        ..createdAt = created?.toUtc(),
    );
  }

  /// [record] with its dates back in the viewer's clock.
  static EpgSource _sourceLocal(EpgSource record) {
    final refresh = record.lastRefresh;
    final created = record.createdAt;
    final utcRefresh = refresh != null && refresh.isUtc;
    final utcCreated = created != null && created.isUtc;
    if (!utcRefresh && !utcCreated) {
      return record;
    }
    return record.rebuild(
      (b) => b
        ..lastRefresh = refresh?.toLocal()
        ..createdAt = created?.toLocal(),
    );
  }

  /// [record] with its programme window on the wire's clock.
  static EpgProgramme _programmeUtc(EpgProgramme record) => record.start.isUtc
      ? record
      : record.rebuild(
          (b) => b
            ..start = record.start.toUtc()
            ..stop = record.stop.toUtc(),
        );

  /// [record] with its programme window back in the viewer's clock.
  static EpgProgramme _programmeLocal(EpgProgramme record) => record.start.isUtc
      ? record.rebuild(
          (b) => b
            ..start = record.start.toLocal()
            ..stop = record.stop.toLocal(),
        )
      : record;
}

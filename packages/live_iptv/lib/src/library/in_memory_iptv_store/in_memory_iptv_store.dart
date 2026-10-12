import 'dart:async';

import 'package:live_iptv/src/library/iptv_store/iptv_store.dart';
import 'package:live_iptv/src/model/model.dart';

/// An in-memory [IptvStore] for tests and previews.
///
/// It behaves like the box on the parts the library cares about — whole-set
/// reads and writes, a change event per save — and nothing more, so a test
/// that needs the storage layer's quirks is a test of the storage layer.
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
  List<IptvGroup> _groups = const [];
  List<IptvLineHealth> _health = const [];

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

  @override
  Future<List<IptvGroup>> loadGroups() async => _groups;

  @override
  Future<void> saveGroups(List<IptvGroup> groups) async {
    _groups = List.unmodifiable(groups);
    _changes.add(null);
  }

  @override
  Future<List<IptvLineHealth>> loadLineHealth() async => _health;

  @override
  Future<void> saveLineHealth(List<IptvLineHealth> health) async {
    _health = List.unmodifiable(health);
    _changes.add(null);
  }
}

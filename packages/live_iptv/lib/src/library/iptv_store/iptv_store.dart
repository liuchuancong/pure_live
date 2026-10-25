import 'dart:async';

import 'package:live_iptv/src/model/model.dart';

/// The persistence seam of the IPTV library.
///
/// Nine concerns, each loaded and saved as a whole list: the library is a
/// small document store rather than a query engine, and a caller that wants
/// one channel still reads the list it belongs to. The write methods are
/// whole-set on purpose — a partial save is where a list ends up holding two
/// records of one channel.
///
/// The implementations are `StorageIptvStore` (production, over the app's
/// shared JSON list store) and `InMemoryIptvStore` (tests and previews); the
/// keys they store under are `IptvKeys`.
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

  /// Loads the group records the user arranged (in no particular order).
  Future<List<IptvGroup>> loadGroups();

  /// Loads the last probe verdict of every address that has one.
  Future<List<IptvLineHealth>> loadLineHealth();

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

  /// Stores every group record (the whole set, one write).
  Future<void> saveGroups(List<IptvGroup> groups);

  /// Stores every probe verdict (the whole set, one write).
  Future<void> saveLineHealth(List<IptvLineHealth> health);

  /// Emits when another writer changed the library.
  Stream<void> get changes;
}

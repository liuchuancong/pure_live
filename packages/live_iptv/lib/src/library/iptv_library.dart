import 'dart:async';

import 'package:live_iptv/src/library/iptv_store.dart';
import 'package:live_iptv/src/model/guide_models.dart';
import 'package:live_iptv/src/model/iptv_models.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';
import 'package:live_iptv/src/playlist/playlist_parser.dart';
import 'package:live_sites/live_sites.dart' as sites;
import 'package:live_storage/live_storage.dart';

/// The user's IPTV library: imported playlists and the channels they
/// yielded, with favourites and ordering.
///
/// Importing reconciles channels by URL: channels that already exist
/// (same URL) keep their channel id and the user's favourite/hidden/
/// position flags; new URLs are appended; channels the new playlist no
/// longer carries are dropped only when `removeMissing` is true — the
/// default keeps them, because a temporarily unavailable source must not
/// delete the user's list.
final class IptvLibrary {
  /// A library over [store].
  new(this.store);

  /// The persistence seam.
  final IptvStore store;

  final _changes = StreamController<void>.broadcast();
  List<IptvChannel> _channels = const [];
  List<IptvPlaylist> _playlists = const [];
  List<EpgSource> _sources = const [];
  List<EpgChannel> _guideChannels = const [];
  List<EpgProgramme> _programmes = const [];
  List<EpgMapping> _mappings = const [];
  bool _loaded = false;
  StreamSubscription<void>? _external;

  /// Emits after every committed mutation.
  Stream<void> get changes => _changes.stream;

  /// The channels, ordered by position.
  List<IptvChannel> get channels => List.unmodifiable(_channels);

  /// The imported playlists.
  List<IptvPlaylist> get playlists => List.unmodifiable(_playlists);

  /// The guide sources, in import order.
  List<EpgSource> get guideSources => List.unmodifiable(_sources);

  /// Loads the library (idempotent).
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _channels = await store.loadChannels();
    _playlists = await store.loadPlaylists();
    _sources = await store.loadGuideSources();
    _guideChannels = await store.loadGuideChannels();
    _programmes = await store.loadGuideProgrammes();
    _mappings = await store.loadGuideMappings();
    _external ??= store.changes.listen((_) => unawaited(_reload()));
  }

  /// The guide source [id], or null.
  EpgSource? guideSource(String id) {
    for (final source in _sources) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }

  /// The channels of the guide source [sourceId].
  List<EpgChannel> guideChannels(String sourceId) => List.unmodifiable([
    for (final channel in _guideChannels)
      if (channel.sourceId == sourceId) channel,
  ]);

  /// The mappings of the playlist [playlistId].
  List<EpgMapping> mappings(String playlistId) => List.unmodifiable([
    for (final mapping in _mappings)
      if (mapping.playlistId == playlistId) mapping,
  ]);

  /// The programmes of guide channel [channelKey] that start at or after
  /// [from] and stop at or before [to], by start.
  ///
  /// The key is the one a room carries ([epgChannelKey]), so a caller that
  /// holds a room can ask without knowing how the library sorted them.
  List<EpgProgramme> programmes(String channelKey, {required DateTime from, required DateTime to}) {
    final matching = [
      for (final programme in _programmes)
        if (epgChannelKey(programme.sourceId, programme.channelId) == channelKey &&
            !programme.start.isBefore(from) &&
            !programme.stop.isAfter(to))
          programme,
    ]..sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(matching);
  }

  /// The programmes of [channelKeys] that are on air at [at]: started at or
  /// before it and not stopped yet.
  List<EpgProgramme> programmesAt(Set<String> channelKeys, DateTime at) => List.unmodifiable([
    for (final programme in _programmes)
      if (channelKeys.contains(epgChannelKey(programme.sourceId, programme.channelId)) &&
          !programme.start.isAfter(at) &&
          !programme.stop.isBefore(at))
        programme,
  ]);

  /// The playlist named [name] (case-insensitive), or null.
  ///
  /// The importer asks this before it writes anything: a name the user
  /// already has is a replacement, not a second playlist, and only the user
  /// can say whether that is what they meant.
  IptvPlaylist? playlistNamed(String name) {
    final wanted = name.trim().toLowerCase();
    for (final playlist in _playlists) {
      if (playlist.name.trim().toLowerCase() == wanted) {
        return playlist;
      }
    }
    return null;
  }

  /// Imports a parsed playlist, replacing the record named [replaceId] when
  /// given.
  ///
  /// The channels are reconciled by URL exactly as [importFromText] does —
  /// the user's favourites, hidden flags and ordering survive a re-import —
  /// and the playlist record is updated in place when it is a replacement,
  /// so a room that points at a channel id keeps working across a sync.
  Future<({String id, int channels, int added, int updated})> importResult(
    PlaylistParseResult result, {
    required String name,
    String? url,
    String? replaceId,
    bool removeMissing = false,
  }) async {
    final entries = result.entries;
    if (entries.isEmpty) {
      throw const StorageValidationException('playlist has no channels');
    }
    final byUrl = {for (final channel in _channels) channel.entry.url: channel};
    var nextPosition = _channels.isEmpty
        ? 0
        : _channels.map((channel) => channel.position).reduce((a, b) => a > b ? a : b) + 1;
    final seenUrls = <String>{};
    final reconciled = <IptvChannel>[];
    var added = 0;
    var updated = 0;
    for (final entry in entries) {
      seenUrls.add(entry.url);
      final existing = byUrl[entry.url];
      if (existing != null) {
        reconciled.add(existing.copyWith(entry: entry));
        updated++;
      } else {
        reconciled.add(
          IptvChannel(
            id: 'c${DateTime.now().microsecondsSinceEpoch}_${reconciled.length}',
            entry: entry,
            position: nextPosition++,
          ),
        );
        added++;
      }
    }
    if (!removeMissing) {
      for (final channel in _channels) {
        if (!seenUrls.contains(channel.entry.url)) {
          reconciled.add(channel);
        }
      }
    }
    _channels = reconciled;
    final existing = replaceId == null ? null : _playlistById(replaceId);
    final id = existing?.id ?? 'p${DateTime.now().microsecondsSinceEpoch}';
    final record = IptvPlaylist(
      id: id,
      name: name,
      importedAt: DateTime.now(),
      url: url ?? existing?.url,
      channelCount: entries.length,
    );
    _playlists = [
      for (final playlist in _playlists)
        if (playlist.id != id) playlist,
      record,
    ];
    await store.saveChannels(_channels);
    await store.savePlaylists(_playlists);
    _changes.add(null);
    return (id: id, channels: entries.length, added: added, updated: updated);
  }

  IptvPlaylist? _playlistById(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) {
        return playlist;
      }
    }
    return null;
  }

  /// Imports [text] as a playlist named [name], appending a record.
  ///
  /// [url] records the remote source when the text came from one. Returns
  /// the number of channels the text carried. Callers that need to replace a
  /// playlist of the same name, or to know how many channels were new, use
  /// [importResult] instead — this method keeps its original shape for the
  /// call sites that only wanted the count.
  Future<int> importFromText(String text, {required String name, String? url, bool removeMissing = false}) async {
    final entries = parsePlaylist(text);
    if (entries.isEmpty) {
      throw const StorageValidationException('playlist has no channels');
    }
    final byUrl = {for (final channel in _channels) channel.entry.url: channel};
    var nextPosition = _channels.isEmpty
        ? 0
        : _channels.map((channel) => channel.position).reduce((a, b) => a > b ? a : b) + 1;
    final seenUrls = <String>{};
    final reconciled = <IptvChannel>[];
    for (final entry in entries) {
      seenUrls.add(entry.url);
      final existing = byUrl[entry.url];
      if (existing != null) {
        // Keep the user's flags; refresh the parsed fields.
        reconciled.add(existing.copyWith(entry: entry));
      } else {
        reconciled.add(
          IptvChannel(
            id: 'c${DateTime.now().microsecondsSinceEpoch}_${reconciled.length}',
            entry: entry,
            position: nextPosition++,
          ),
        );
      }
    }
    if (!removeMissing) {
      for (final channel in _channels) {
        if (!seenUrls.contains(channel.entry.url)) {
          reconciled.add(channel);
        }
      }
    }
    _channels = reconciled;
    _playlists = [
      ..._playlists,
      IptvPlaylist(
        id: 'p${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        importedAt: DateTime.now(),
        url: url,
        channelCount: entries.length,
      ),
    ];
    await store.saveChannels(_channels);
    await store.savePlaylists(_playlists);
    _changes.add(null);
    return entries.length;
  }

  /// Removes the playlist record [id] and, when it was the last one holding
  /// them, the channels only it carried.
  ///
  /// Channels are shared between playlists by URL, so deleting a source may
  /// leave channels another source still lists: those stay, and only the
  /// ones nothing else claims go with it.
  Future<void> deletePlaylist(String id) async {
    final record = _playlistById(id);
    if (record == null) {
      return;
    }
    _playlists = [
      for (final playlist in _playlists)
        if (playlist.id != id) playlist,
    ];
    // The playlist's mappings go with it: a mapping names one of its
    // channels, and that channel no longer exists.
    _mappings = [
      for (final mapping in _mappings)
        if (mapping.playlistId != id) mapping,
    ];
    await store.savePlaylists(_playlists);
    await store.saveGuideMappings(_mappings);
    _changes.add(null);
  }

  /// The playlist held at [id], or null.
  IptvPlaylist? playlistById(String id) => _playlistById(id);

  /// Toggles the favourite flag of [id].
  Future<void> toggleFavorite(String id) => _update(id, (channel) => channel.copyWith(favorite: !channel.favorite));

  /// Toggles the hidden flag of [id].
  Future<void> toggleHidden(String id) => _update(id, (channel) => channel.copyWith(hidden: !channel.hidden));

  /// Moves [id] to [position] in the channel order.
  Future<void> reorder(String id, int position) async {
    final ordered = [..._channels]..sort((a, b) => a.position.compareTo(b.position));
    final index = ordered.indexWhere((channel) => channel.id == id);
    if (index < 0) {
      return;
    }
    final moved = ordered.removeAt(index);
    ordered.insert(position.clamp(0, ordered.length), moved);
    _channels = [for (final (index, channel) in ordered.indexed) channel.copyWith(position: index)];
    await _commit();
  }

  /// Removes one channel.
  Future<void> remove(String id) async {
    final next = [
      for (final channel in _channels)
        if (channel.id != id) channel,
    ];
    if (next.length == _channels.length) {
      return;
    }
    _channels = next;
    await _commit();
  }

  /// Releases the library.
  Future<void> dispose() async {
    await _external?.cancel();
    _external = null;
    await _changes.close();
  }

  /// Replaces guide source [source] with [channels] and [programmes], and
  /// drops the sources in [duplicates] with everything of theirs.
  ///
  /// One write per list: a source's data is only ever replaced whole, because
  /// a guide that updated its channels but not its programmes shows a week of
  /// programmes under the wrong names. [duplicates] are sources the user named
  /// the same — importing a guide again under a name they already have must
  /// not leave two sources whose programmes fight over the same channels.
  Future<void> saveGuide(
    EpgSource source,
    List<EpgChannel> channels,
    List<EpgProgramme> programmes, {
    List<EpgSource> duplicates = const [],
  }) async {
    final dropped = {for (final duplicate in duplicates) duplicate.id};
    _sources = [
      for (final saved in _sources)
        if (!dropped.contains(saved.id)) saved,
    ];
    _guideChannels = [
      for (final channel in _guideChannels)
        if (!dropped.contains(channel.sourceId)) channel,
    ];
    _programmes = [
      for (final programme in _programmes)
        if (!dropped.contains(programme.sourceId)) programme,
    ];
    _mappings = [
      for (final mapping in _mappings)
        if (!dropped.contains(mapping.epgSourceId)) mapping,
    ];
    _sources = [..._sources, source];
    _guideChannels = [..._guideChannels, ...channels];
    _programmes = [..._programmes, ...programmes];
    await _commitGuide();
  }

  /// Updates the fields of a guide source without touching its data.
  Future<void> updateGuideSource(EpgSource source) async {
    if (guideSource(source.id) == null) {
      return;
    }
    _sources = [
      for (final saved in _sources)
        if (saved.id == source.id) source else saved,
    ];
    await _commitGuide();
  }

  /// Deletes the guide source [id] with its channels, its programmes and the
  /// mappings that named it; false when there is no such source.
  ///
  /// The mappings go with it because a mapping to a deleted guide would
  /// otherwise keep a room pointing at programmes that no longer exist.
  Future<bool> deleteGuideSource(String id) async {
    if (guideSource(id) == null) {
      return false;
    }
    _sources = [
      for (final source in _sources)
        if (source.id != id) source,
    ];
    _guideChannels = [
      for (final channel in _guideChannels)
        if (channel.sourceId != id) channel,
    ];
    _programmes = [
      for (final programme in _programmes)
        if (programme.sourceId != id) programme,
    ];
    _mappings = [
      for (final mapping in _mappings)
        if (mapping.epgSourceId != id) mapping,
    ];
    await _commitGuide();
    return true;
  }

  /// Applies the mappings the matcher computed: [upserts] replace whatever is
  /// stored for their channel, [deletes] name the guide keys to drop.
  Future<void> applyMappings({required List<EpgMapping> upserts, required List<EpgMapping> deletes}) async {
    if (upserts.isEmpty && deletes.isEmpty) {
      return;
    }
    final removed = {for (final mapping in deletes) '${mapping.channelId}\u0000${mapping.epgChannelKey}'};
    final replaced = {for (final mapping in upserts) mapping.channelId};
    _mappings = [
      for (final mapping in _mappings)
        if (!removed.contains('${mapping.channelId}\u0000${mapping.epgChannelKey}') &&
            !replaced.contains(mapping.channelId))
          mapping,
      ...upserts,
    ];
    await _commitGuide();
  }

  /// Deletes the programmes that stopped before [before].
  ///
  /// A guide carries days of past programmes; keeping them would grow the
  /// store without ever being read, because a guide shows what is on now.
  Future<void> pruneProgrammes(DateTime before) async {
    final kept = [
      for (final programme in _programmes)
        if (!programme.stop.isBefore(before)) programme,
    ];
    if (kept.length == _programmes.length) {
      return;
    }
    _programmes = kept;
    await _commitGuide();
  }

  Future<void> _commitGuide() async {
    await store.saveGuideSources(_sources);
    await store.saveGuideChannels(_guideChannels);
    await store.saveGuideProgrammes(_programmes);
    await store.saveGuideMappings(_mappings);
    _changes.add(null);
  }

  Future<void> _update(String id, IptvChannel Function(IptvChannel) transform) async {
    var changed = false;
    _channels = [
      for (final channel in _channels)
        if (channel.id == id)
          () {
            changed = true;
            return transform(channel);
          }()
        else
          channel,
    ];
    if (changed) {
      await _commit();
    }
  }

  Future<void> _commit() async {
    await store.saveChannels(_channels);
    _changes.add(null);
  }

  Future<void> _reload() async {
    _channels = await store.loadChannels();
    _playlists = await store.loadPlaylists();
    _sources = await store.loadGuideSources();
    _guideChannels = await store.loadGuideChannels();
    _programmes = await store.loadGuideProgrammes();
    _mappings = await store.loadGuideMappings();
    _changes.add(null);
  }
}

/// The library as the `live_sites` IPTV site's channel source: the site
/// layer exposes these through [sites.IptvSite] so IPTV channels play
/// through the ordinary playback stack.
final class LibraryIptvChannelSource implements sites.IptvChannelSource {
  /// A source over [library]; [includeHidden] keeps hidden channels out
  /// by default.
  new(this.library, {this.includeHidden = false});

  /// The library to read.
  final IptvLibrary library;

  /// Whether hidden channels are exposed.
  final bool includeHidden;

  @override
  List<sites.IptvChannel> get channels => [
    for (final channel in library.channels)
      if (includeHidden || !channel.hidden) _toSiteChannel(channel),
  ];

  @override
  sites.IptvChannel? channelById(String id) {
    for (final channel in library.channels) {
      if (channel.id == id) {
        return _toSiteChannel(channel);
      }
    }
    return null;
  }

  static sites.IptvChannel _toSiteChannel(IptvChannel channel) => sites.IptvChannel(
    id: channel.id,
    name: channel.entry.name,
    url: channel.entry.url,
    group: channel.entry.group,
    headers: channel.entry.headers,
    epgChannelId: channel.entry.tvgId,
    favorite: channel.favorite,
  );
}

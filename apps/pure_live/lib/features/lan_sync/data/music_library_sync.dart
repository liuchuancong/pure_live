import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/providers/settings/settings_refresh.dart' show refreshSettings;
import 'package:pure_live/features/lan_sync/data/scoped_sync.dart' show ScopeSnapshotLedger, ScopeSource;
import 'package:pure_live/features/lan_sync/data/sync_scopes.dart' show LanSyncScope;
import 'package:pure_live/modules/music/controller/music_dislikes.dart' show kMusicDislikeLimit, kMusicDislikesKey;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show kMusicFavouritesKey, kMusicRecentKey, kMusicRecentLimit, musicTrackFromJson, musicTrackKey, musicTrackToJson;
import 'package:pure_live/modules/music/controller/music_lyric_overrides.dart'
    show kMusicLyricOverrideLimit, kMusicLyricOverridesKey;
import 'package:pure_live/modules/music/controller/music_playlists.dart'
    show MusicPlaylist, kMusicPlaylistLimit, kMusicPlaylistsKey;

/// The music library's entity ids. One playlist, one collected song, one
/// recently played song, one dislike rule and one linked lyric each carry
/// their own id, so two devices editing different entries never collide the
/// way whole pref strings would.
const String _playlistPrefix = 'playlist:';
const String _favouritePrefix = 'favourite:';
const String _recentPrefix = 'recent:';
const String _dislikePrefix = 'dislike:';
const String _lyricPrefix = 'lyric:';

/// One entity's write, as the adapter and the change detector both see it.
typedef MusicLibraryChange = ({String entityId, bool tombstone, Map<String, Object?> payload});

/// The library as entities: entity id → the payload a peer should receive.
///
/// The shapes are the stores' own JSON, so a payload read back here is
/// exactly what a remote apply writes and what the snapshot ledger keeps.
Future<Map<String, Map<String, Object?>>> musicLibraryEntities() async {
  final out = <String, Map<String, Object?>>{};
  for (final playlist in _readPlaylists()) {
    out['$_playlistPrefix${playlist.id}'] = playlist.toJson();
  }
  for (final track in _readTracks(kMusicFavouritesKey)) {
    out['$_favouritePrefix${musicTrackKey(track)}'] = musicTrackToJson(track);
  }
  for (final track in _readTracks(kMusicRecentKey)) {
    out['$_recentPrefix${musicTrackKey(track)}'] = musicTrackToJson(track);
  }
  for (final rule in _readDislikes()) {
    out['$_dislikePrefix$rule'] = {'rule': rule};
  }
  for (final entry in _readLyrics().entries) {
    out['$_lyricPrefix${entry.key}'] = {'text': entry.value};
  }
  return out;
}

/// The source the change detector diffs: the live library as entities.
ScopeSource musicLibraryScopeSource(Ref ref) => (
  current: musicLibraryEntities,
  upsert: (entityId, payload) async {
    await applyMusicLibraryChanges([(entityId: entityId, tombstone: false, payload: payload)]);
  },
  delete: (entityId) async {
    await applyMusicLibraryChanges([(entityId: entityId, tombstone: true, payload: const {})]);
  },
  afterBatch: () async => refreshSettings(ref),
);

/// Applies the library changes that arrived from a peer.
///
/// Collection order follows the batch: songs the peer sent in its newest-first
/// order land at the top in that same order; deletions leave both the stored
/// list and this batch's pending songs. Returns how many changes were applied.
Future<int> applyMusicLibraryChanges(List<MusicLibraryChange> changes, {ScopeSnapshotLedger? ledger}) async {
  final playlists = _readPlaylists();
  final favourites = _readTracks(kMusicFavouritesKey);
  final recent = _readTracks(kMusicRecentKey);
  final dislikes = _readDislikes();
  final lyrics = _readLyrics();

  final touched = <String>{};
  var playlistsChanged = false;
  var favouritesChanged = false;
  var recentChanged = false;
  var dislikesChanged = false;
  var lyricsChanged = false;

  final addedFavourites = <String, audio.MusicTrack>{};
  final addedRecent = <String, audio.MusicTrack>{};

  for (final change in changes) {
    final entityId = change.entityId;
    if (entityId.startsWith(_playlistPrefix)) {
      final id = entityId.substring(_playlistPrefix.length);
      if (change.tombstone) {
        playlists.removeWhere((playlist) => playlist.id == id);
      } else {
        final playlist = MusicPlaylist.fromJson(change.payload);
        if (playlist == null || playlist.id != id) continue;
        final index = playlists.indexWhere((playlist) => playlist.id == id);
        if (index >= 0) {
          playlists[index] = playlist;
        } else if (playlists.length < kMusicPlaylistLimit) {
          playlists.add(playlist);
        } else {
          continue;
        }
      }
      playlistsChanged = true;
    } else if (entityId.startsWith(_favouritePrefix) || entityId.startsWith(_recentPrefix)) {
      final isFavourite = entityId.startsWith(_favouritePrefix);
      final prefix = isFavourite ? _favouritePrefix : _recentPrefix;
      final key = entityId.substring(prefix.length);
      final list = isFavourite ? favourites : recent;
      final added = isFavourite ? addedFavourites : addedRecent;
      list.removeWhere((track) => musicTrackKey(track) == key);
      added.remove(key);
      if (!change.tombstone) {
        final track = musicTrackFromJson(change.payload);
        if (track == null) continue;
        added[key] = track;
      }
      if (isFavourite) {
        favouritesChanged = true;
      } else {
        recentChanged = true;
      }
    } else if (entityId.startsWith(_dislikePrefix)) {
      final rule = entityId.substring(_dislikePrefix.length);
      if (change.tombstone) {
        dislikes.remove(rule);
      } else {
        final value = change.payload['rule'];
        if (value is! String || value.isEmpty) continue;
        dislikes
          ..remove(value)
          ..add(value);
        while (dislikes.length > kMusicDislikeLimit) {
          dislikes.remove(dislikes.first);
        }
      }
      dislikesChanged = true;
    } else if (entityId.startsWith(_lyricPrefix)) {
      final key = entityId.substring(_lyricPrefix.length);
      if (change.tombstone) {
        lyrics.remove(key);
      } else {
        final text = change.payload['text'];
        if (text is! String) continue;
        lyrics
          ..remove(key)
          ..[key] = text;
        while (lyrics.length > kMusicLyricOverrideLimit) {
          lyrics.remove(lyrics.keys.first);
        }
      }
      lyricsChanged = true;
    } else {
      continue;
    }
    touched.add(entityId);
  }

  final nextFavourites = [...addedFavourites.values, ...favourites];
  final nextRecent = [...addedRecent.values, ...recent].take(kMusicRecentLimit).toList();

  if (playlistsChanged) {
    await _writePlaylists(playlists);
  }
  if (favouritesChanged) {
    await _writeTracks(kMusicFavouritesKey, nextFavourites);
  }
  if (recentChanged) {
    await _writeTracks(kMusicRecentKey, nextRecent);
  }
  if (dislikesChanged) {
    await _writeDislikes(dislikes);
  }
  if (lyricsChanged) {
    await _writeLyrics(lyrics);
  }

  if (ledger != null) {
    for (final entityId in touched) {
      final payload = _storedPayload(entityId, playlists, nextFavourites, nextRecent, dislikes, lyrics);
      await ledger.markApplied(LanSyncScope.musicLibrary, entityId, payload);
    }
  }

  return touched.length;
}

/// The library scope's adapter: entity-level writes plus a merge that keeps
/// both sides' songs when two devices edited the same playlist.
final class MusicLibrarySyncAdapter implements LanSyncDataAdapter {
  /// The adapter over [ledger]; [onApplied] refreshes the module's providers
  /// after a batch so the player and the LX endpoint see the new library.
  MusicLibrarySyncAdapter({required this.ledger, required this.onApplied});

  final ScopeSnapshotLedger ledger;

  /// Runs after a batch was written.
  final void Function() onApplied;

  @override
  String get scope => LanSyncScope.musicLibrary.id;

  @override
  int get schemaVersion => 1;

  @override
  ScopeSyncCapabilities get capabilities => const ScopeSyncCapabilities(
    supportsDelete: true,
    supportsBidirectional: true,
    supportsMerge: true,
    supportedPolicies: {ConflictPolicy.preferLocal, ConflictPolicy.preferRemote, ConflictPolicy.merge},
  );

  @override
  Future<SyncApplyResult> applyChanges({required List<SyncChange> changes}) async {
    final valid = <MusicLibraryChange>[];
    final failures = <SyncChangeFailure>[];
    for (final change in changes) {
      final reason = _validate(change);
      if (reason != null) {
        failures.add(SyncChangeFailure(change: change, reason: reason));
        continue;
      }
      valid.add((entityId: change.entityId, tombstone: change.isTombstone, payload: change.payload));
    }
    var applied = 0;
    if (valid.isNotEmpty) {
      applied = await applyMusicLibraryChanges(valid, ledger: ledger);
      onApplied();
    }
    return SyncApplyResult(appliedCount: applied, failures: failures);
  }

  @override
  Future<SyncConflictResolution> resolveConflict({required SyncChange local, required SyncChange remote}) async {
    final entityId = local.entityId;
    if (entityId.startsWith(_playlistPrefix)) {
      final merged = mergeMusicPlaylistPayloads(local.payload, remote.payload);
      if (merged != null) return MergedResolution(merged);
    }
    // The LX list merge unions songs and rules: an update outlives a
    // concurrent delete. The same rule keeps this side consistent with the
    // interop endpoint.
    if (entityId.startsWith(_favouritePrefix) ||
        entityId.startsWith(_recentPrefix) ||
        entityId.startsWith(_dislikePrefix)) {
      if (local.isTombstone && !remote.isTombstone) return const UseRemoteResolution();
      if (remote.isTombstone && !local.isTombstone) return const UseLocalResolution();
    }
    return const UseLocalResolution();
  }
}

/// Merges two versions of one playlist: both sides' songs, local order first;
/// the name and a link follow the side that moved the list most recently.
Map<String, Object?>? mergeMusicPlaylistPayloads(Map<String, Object?> local, Map<String, Object?> remote) {
  final id = local['id'] ?? remote['id'];
  final name = local['name'] ?? remote['name'];
  final createdAt = local['createdAt'] ?? remote['createdAt'];
  if (id is! String || name is! String || createdAt is! int) return null;

  final localTime = (local['locationUpdateTime'] as num?)?.toInt() ?? 0;
  final remoteTime = (remote['locationUpdateTime'] as num?)?.toInt() ?? 0;
  final newer = remoteTime > localTime ? remote : local;
  final source = local['source'] ?? remote['source'];
  final sourceListId = local['sourceListId'] ?? remote['sourceListId'];
  final position = local['position'] ?? remote['position'];
  final tracks = <Object?>[];
  final seen = <String>{};
  for (final entry in [..._trackPayloads(local['tracks']), ..._trackPayloads(remote['tracks'])]) {
    final track = musicTrackFromJson(entry);
    if (track == null || !seen.add(musicTrackKey(track))) continue;
    tracks.add(entry);
  }
  final merged = <String, Object?>{
    'id': id,
    'name': newer['name'] is String ? newer['name'] : name,
    'createdAt': createdAt,
    'tracks': tracks,
    if (source is String) 'source': source,
    if (sourceListId is String) 'sourceListId': sourceListId,
    if (position is int) 'position': position,
    if (localTime > 0 || remoteTime > 0) 'locationUpdateTime': localTime > remoteTime ? localTime : remoteTime,
  };
  return merged;
}

/// One side's stored track list, as the playlists' JSON keeps it.
List<Object?> _trackPayloads(Object? value) => value is List ? value : const <Object?>[];

/// Whether a change names an entity this scope knows and carries a payload
/// its store can read; null when it does.
String? _validate(SyncChange change) {
  final entityId = change.entityId;
  if (change.isTombstone) {
    return _isKnownEntity(entityId) ? null : 'unknown music library entity';
  }
  if (entityId.startsWith(_playlistPrefix)) {
    final id = entityId.substring(_playlistPrefix.length);
    final playlist = MusicPlaylist.fromJson(change.payload);
    if (playlist == null || playlist.id != id) return 'the playlist payload is not one this build reads';
    return null;
  }
  if (entityId.startsWith(_favouritePrefix) || entityId.startsWith(_recentPrefix)) {
    final prefix = entityId.startsWith(_favouritePrefix) ? _favouritePrefix : _recentPrefix;
    final key = entityId.substring(prefix.length);
    final track = musicTrackFromJson(change.payload);
    if (track == null || musicTrackKey(track) != key) return 'the song payload is not one this build reads';
    return null;
  }
  if (entityId.startsWith(_dislikePrefix)) {
    return change.payload['rule'] is String ? null : 'the dislike rule is missing';
  }
  if (entityId.startsWith(_lyricPrefix)) {
    return change.payload['text'] is String ? null : 'the lyric text is missing';
  }
  return 'unknown music library entity';
}

bool _isKnownEntity(String entityId) =>
    entityId.startsWith(_playlistPrefix) ||
    entityId.startsWith(_favouritePrefix) ||
    entityId.startsWith(_recentPrefix) ||
    entityId.startsWith(_dislikePrefix) ||
    entityId.startsWith(_lyricPrefix);

/// The stored payload one entity now has, or null when it is gone — what
/// the snapshot ledger records after a remote batch.
Map<String, Object?>? _storedPayload(
  String entityId,
  List<MusicPlaylist> playlists,
  List<audio.MusicTrack> favourites,
  List<audio.MusicTrack> recent,
  Set<String> dislikes,
  Map<String, String> lyrics,
) {
  if (entityId.startsWith(_playlistPrefix)) {
    final id = entityId.substring(_playlistPrefix.length);
    for (final playlist in playlists) {
      if (playlist.id == id) return playlist.toJson();
    }
    return null;
  }
  if (entityId.startsWith(_favouritePrefix) || entityId.startsWith(_recentPrefix)) {
    final prefix = entityId.startsWith(_favouritePrefix) ? _favouritePrefix : _recentPrefix;
    final key = entityId.substring(prefix.length);
    for (final track in entityId.startsWith(_favouritePrefix) ? favourites : recent) {
      if (musicTrackKey(track) == key) return musicTrackToJson(track);
    }
    return null;
  }
  if (entityId.startsWith(_dislikePrefix)) {
    final rule = entityId.substring(_dislikePrefix.length);
    return dislikes.contains(rule) ? {'rule': rule} : null;
  }
  if (entityId.startsWith(_lyricPrefix)) {
    final key = entityId.substring(_lyricPrefix.length);
    final text = lyrics[key];
    return text == null ? null : {'text': text};
  }
  return null;
}

List<MusicPlaylist> _readPlaylists() {
  final raw = _readString(kMusicPlaylistsKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final json = jsonDecode(raw);
    if (json is! List) return [];
    return [for (final entry in json) ?MusicPlaylist.fromJson(entry)];
  } on Object {
    return [];
  }
}

List<audio.MusicTrack> _readTracks(String key) {
  final raw = _readString(key);
  if (raw == null || raw.isEmpty) return [];
  try {
    final json = jsonDecode(raw);
    if (json is! List) return [];
    return [for (final entry in json) ?musicTrackFromJson(entry)];
  } on Object {
    return [];
  }
}

Set<String> _readDislikes() {
  final raw = _readString(kMusicDislikesKey);
  if (raw == null || raw.isEmpty) return <String>{};
  try {
    final json = jsonDecode(raw);
    if (json is! List) return <String>{};
    return <String>{
      for (final entry in json)
        if (entry is String && entry.isNotEmpty) entry,
    };
  } on Object {
    return <String>{};
  }
}

Map<String, String> _readLyrics() {
  final raw = _readString(kMusicLyricOverridesKey);
  if (raw == null || raw.isEmpty) return <String, String>{};
  try {
    final json = jsonDecode(raw);
    if (json is! Map) return <String, String>{};
    return <String, String>{
      for (final entry in json.entries)
        if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
    };
  } on Object {
    return <String, String>{};
  }
}

String? _readString(String key) {
  try {
    return StoragePrefs.getString(key);
  } on Object {
    return null;
  }
}

Future<void> _writePlaylists(List<MusicPlaylist> playlists) =>
    _writeString(kMusicPlaylistsKey, jsonEncode([for (final playlist in playlists) playlist.toJson()]));

Future<void> _writeTracks(String key, List<audio.MusicTrack> tracks) =>
    _writeString(key, jsonEncode([for (final track in tracks) musicTrackToJson(track)]));

Future<void> _writeDislikes(Set<String> rules) => _writeString(kMusicDislikesKey, jsonEncode(rules.toList()));

Future<void> _writeLyrics(Map<String, String> overrides) =>
    _writeString(kMusicLyricOverridesKey, jsonEncode(overrides));

Future<void> _writeString(String key, String value) async {
  try {
    await StoragePrefs.setString(key, value);
  } on Object {
    // A preference; a closed store loses it.
  }
}

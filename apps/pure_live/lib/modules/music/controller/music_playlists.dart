import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart' show musicTrackFromJson, musicTrackToJson;
import 'package:pure_live/modules/music/controller/music_settings.dart' show musicSettingsProvider;

/// The preference the viewer's own playlists are kept under.
const String kMusicPlaylistsKey = 'music.playlists';

/// How many playlists the module keeps.
const int kMusicPlaylistLimit = 100;

/// One playlist the viewer made: a name and its songs, in order.
@immutable
final class MusicPlaylist {
  /// Creates a playlist.
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
    this.source,
    this.sourceListId,
    this.position = 0,
    this.locationUpdateTime,
  });

  /// Reads a stored playlist; null when the entry is damaged.
  static MusicPlaylist? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final createdAt = (json['createdAt'] as num?)?.toInt();
    if (id is! String || id.isEmpty || name is! String || createdAt == null) return null;
    final entries = json['tracks'];
    final locatedAt = (json['locationUpdateTime'] as num?)?.toInt();
    return MusicPlaylist(
      id: id,
      name: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      tracks: entries is List ? [for (final entry in entries) ?musicTrackFromJson(entry)] : const [],
      source: json['source'] is String && (json['source'] as String).isNotEmpty ? json['source'] as String : null,
      sourceListId:
          json['sourceListId'] is String && (json['sourceListId'] as String).isNotEmpty
              ? json['sourceListId'] as String
              : null,
      position: (json['position'] as num?)?.toInt() ?? 0,
      locationUpdateTime: locatedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(locatedAt),
    );
  }

  /// The playlist's id.
  final String id;

  /// The playlist's name.
  final String name;

  /// Its songs, in play order.
  final List<audio.MusicTrack> tracks;

  /// When it was made.
  final DateTime createdAt;

  /// The platform a linked online playlist came from — the reference's
  /// `my_list.source`; null for a purely local list.
  final String? source;

  /// The linked online playlist's id — the reference's `my_list.sourceListId`.
  final String? sourceListId;

  /// The playlist's place among the viewer's lists — the reference's
  /// `my_list.position`.
  final int position;

  /// When the playlist last moved — the reference's
  /// `my_list.locationUpdateTime`.
  final DateTime? locationUpdateTime;

  /// The stored shape.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'tracks': [for (final track in tracks) musicTrackToJson(track)],
    if (source != null) 'source': source,
    if (sourceListId != null) 'sourceListId': sourceListId,
    'position': position,
    if (locationUpdateTime != null) 'locationUpdateTime': locationUpdateTime!.millisecondsSinceEpoch,
  };

  /// A copy with selected fields replaced.
  MusicPlaylist copyWith({
    String? name,
    List<audio.MusicTrack>? tracks,
    String? source,
    String? sourceListId,
    int? position,
    DateTime? locationUpdateTime,
    bool clearLink = false,
  }) => MusicPlaylist(
    id: id,
    name: name ?? this.name,
    tracks: tracks ?? this.tracks,
    createdAt: createdAt,
    source: clearLink ? null : (source ?? this.source),
    sourceListId: clearLink ? null : (sourceListId ?? this.sourceListId),
    position: position ?? this.position,
    locationUpdateTime: locationUpdateTime ?? this.locationUpdateTime,
  );
}

/// How a playlist can be re-ordered — the reference's 排序.
enum MusicPlaylistSort {
  /// By song title.
  title,

  /// By artist, then title.
  artist,

  /// By album, then title.
  album,

  /// By duration, shortest first; songs with no duration go last.
  duration,

  /// Random order.
  shuffle,
}

/// The viewer's playlists — lx-music's 我的歌单.
///
/// A playlist is local: it stores enough of each song to draw its row and
/// resolve it again, so a list survives a search that found the song. A song
/// already in a list is not added twice; reordering is a move inside it.
final class MusicPlaylistsController extends Notifier<List<MusicPlaylist>> {
  @override
  List<MusicPlaylist> build() {
    final raw = _read();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [for (final entry in json) ?MusicPlaylist.fromJson(entry)];
    } on Object {
      return const [];
    }
  }

  /// The playlist with [id], or null.
  MusicPlaylist? find(String id) {
    for (final playlist in state) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  /// Makes a playlist called [name]; null when the list is full.
  Future<MusicPlaylist?> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.length >= kMusicPlaylistLimit) return null;
    final playlist = MusicPlaylist(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      tracks: const [],
      createdAt: DateTime.now(),
      position: state.isEmpty ? 0 : [for (final existing in state) existing.position].reduce(_maxOf) + 1,
    );
    state = [...state, playlist];
    await _save();
    return playlist;
  }

  static int _maxOf(int a, int b) => a > b ? a : b;

  /// Moves a playlist to another place among the viewer's lists — the
  /// reference's `updateUserListPosition`; the moved list's
  /// `locationUpdateTime` marks the rearrangement.
  Future<void> move(String id, int to) async {
    final from = state.indexWhere((playlist) => playlist.id == id);
    if (from < 0 || to < 0 || to >= state.length || from == to) return;
    final reordered = [...state]..removeAt(from);
    final movedAt = DateTime.now();
    reordered.insert(to, state[from].copyWith(position: to, locationUpdateTime: movedAt));
    state = [
      for (var i = 0; i < reordered.length; i++)
        if (i == to) reordered[i] else reordered[i].copyWith(position: i),
    ];
    await _save();
  }

  /// Links a playlist to an online playlist — the reference stores the
  /// platform and its list id on `my_list` so the link survives a restart.
  Future<void> linkSource(String id, {required String source, required String sourceListId}) async {
    state = [
      for (final playlist in state)
        if (playlist.id == id) playlist.copyWith(source: source, sourceListId: sourceListId) else playlist,
    ];
    await _save();
  }

  /// Unlinks a playlist from its online source.
  Future<void> unlinkSource(String id) async {
    state = [
      for (final playlist in state)
        if (playlist.id == id) playlist.copyWith(clearLink: true) else playlist,
    ];
    await _save();
  }

  /// Renames a playlist.
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final playlist in state)
        if (playlist.id == id) playlist.copyWith(name: trimmed) else playlist,
    ];
    await _save();
  }

  /// Deletes a playlist; its songs stay in the library and the queue.
  Future<void> delete(String id) async {
    state = [
      for (final playlist in state)
        if (playlist.id != id) playlist,
    ];
    await _save();
  }

  /// Replaces the whole shelf with [playlists] — the sync bridge's
  /// overwrite path; positions follow the input order.
  Future<void> replaceAll(List<MusicPlaylist> playlists) async {
    state = [
      for (var i = 0; i < playlists.length; i++) playlists[i].copyWith(position: i),
    ];
    await _save();
  }

  /// Adds [track] to the playlist; false when it is already there or the
  /// playlist is gone.
  Future<bool> addTrack(String id, audio.MusicTrack track) async {
    final playlist = find(id);
    if (playlist == null || playlist.tracks.contains(track)) return false;
    final tracks = ref.read(musicSettingsProvider).addToTop ? [track, ...playlist.tracks] : [...playlist.tracks, track];
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(tracks: tracks) else item,
    ];
    await _save();
    return true;
  }

  /// Adds [tracks] to the playlist in one save; returns how many were new.
  ///
  /// Order follows the input even when new songs go to the top, and songs
  /// already in the list are counted as duplicates rather than added twice.
  Future<int> addTracks(String id, Iterable<audio.MusicTrack> tracks) async {
    final playlist = find(id);
    if (playlist == null) return 0;
    final existing = playlist.tracks.toSet();
    final seen = <audio.MusicTrack>{};
    final fresh = <audio.MusicTrack>[
      for (final track in tracks)
        if (seen.add(track) && !existing.contains(track)) track,
    ];
    if (fresh.isEmpty) return 0;
    final merged = ref.read(musicSettingsProvider).addToTop
        ? [...fresh, ...playlist.tracks]
        : [...playlist.tracks, ...fresh];
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(tracks: merged) else item,
    ];
    await _save();
    return fresh.length;
  }

  /// Drops [track] from the playlist.
  Future<void> removeTrack(String id, audio.MusicTrack track) async {
    state = [
      for (final playlist in state)
        if (playlist.id == id)
          playlist.copyWith(
            tracks: [
              for (final entry in playlist.tracks)
                if (entry != track) entry,
            ],
          )
        else
          playlist,
    ];
    await _save();
  }

  /// Drops every track in [tracks] with one save — the batch form behind a
  /// multi-selection's 移除.
  Future<void> removeTracks(String id, Iterable<audio.MusicTrack> tracks) async {
    final removed = tracks.toSet();
    if (removed.isEmpty) return;
    state = [
      for (final playlist in state)
        if (playlist.id == id)
          playlist.copyWith(
            tracks: [
              for (final entry in playlist.tracks)
                if (!removed.contains(entry)) entry,
            ],
          )
        else
          playlist,
    ];
    await _save();
  }

  /// Moves a song inside the playlist.
  Future<void> moveTrack(String id, int from, int to) async {
    final playlist = find(id);
    if (playlist == null || from < 0 || from >= playlist.tracks.length) return;
    final tracks = [...playlist.tracks];
    final track = tracks.removeAt(from);
    tracks.insert(to.clamp(0, tracks.length), track);
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(tracks: tracks) else item,
    ];
    await _save();
  }

  /// Sorts a playlist in place.
  Future<void> sortTracks(String id, MusicPlaylistSort by) async {
    final playlist = find(id);
    if (playlist == null || playlist.tracks.length < 2) return;
    final tracks = [...playlist.tracks];

    switch (by) {
      case MusicPlaylistSort.title:
        tracks.sort(_titleOf);
      case MusicPlaylistSort.artist:
        tracks.sort((a, b) {
          final byArtist = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());

          return byArtist != 0 ? byArtist : _titleOf(a, b);
        });
      case MusicPlaylistSort.album:
        tracks.sort((a, b) {
          final byAlbum = a.album.toLowerCase().compareTo(b.album.toLowerCase());

          return byAlbum != 0 ? byAlbum : _titleOf(a, b);
        });
      case MusicPlaylistSort.duration:
        tracks.sort((a, b) {
          final left = a.duration;
          final right = b.duration;

          if (left == null && right == null) return _titleOf(a, b);
          if (left == null) return 1;
          if (right == null) return -1;

          return left.compareTo(right);
        });
      case MusicPlaylistSort.shuffle:
        tracks.shuffle();
    }

    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(tracks: tracks) else item,
    ];
    await _save();
  }

  static int _titleOf(audio.MusicTrack a, audio.MusicTrack b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());

  /// Empties a playlist without deleting it.
  Future<void> clear(String id) async {
    state = [
      for (final playlist in state)
        if (playlist.id == id) playlist.copyWith(tracks: const []) else playlist,
    ];
    await _save();
  }

  /// Writes [playlist] into [directory] as a JSON file; returns its path.
  ///
  /// The shape is the store's own: a name and the tracks the module can
  /// resolve again, so a list moves between installs without a platform
  /// login. The reference's 导出歌单.
  Future<String> exportToDirectory(MusicPlaylist playlist, String directory) async {
    final safe = audio.MusicDownloadRequest.sanitizeFileName(playlist.name);
    final file = File('$directory/${safe.isEmpty ? playlist.id : safe}.json');

    await file.writeAsString(
      jsonEncode({
        'name': playlist.name,
        'tracks': [for (final track in playlist.tracks) musicTrackToJson(track)],
      }),
      flush: true,
    );

    return file.path;
  }

  /// Writes every playlist to [path] as the reference's 导出歌单为文本: one
  /// `name  singer  album` line per song, lists separated by a blank line.
  /// Returns the path written.
  Future<String> exportToTextFile(String path) async {
    final body = _exportBlocks((track) => '${track.title}  ${track.artist}  ${track.album}');
    await File(path).writeAsString('\uFEFF$body', flush: true);
    return path;
  }

  /// Writes every playlist to [path] as the reference's 导出歌单为CSV: a
  /// localized header row, then `name,singer,album` rows with quotes escaped.
  /// Returns the path written.
  Future<String> exportToCsvFile(String path, {required String header}) async {
    final body = _exportBlocks(
      (track) => '${_csvEscape(track.title)},${_csvEscape(track.artist)},${_csvEscape(track.album)}',
    );
    await File(path).writeAsString('\uFEFF$header$body', flush: true);
    return path;
  }

  /// Every playlist's rows, lists separated by a blank line — the reference
  /// exports all lists into one file.
  String _exportBlocks(String Function(audio.MusicTrack track) rowOf) =>
      [for (final playlist in state) [for (final track in playlist.tracks) rowOf(track)].join('\n')].join('\n\n');

  /// Writes one file per playlist into [directory] — the reference's un-merged
  /// export, `lx_list_<name>.txt`-style names.
  Future<void> exportToTextDirectory(String directory) =>
      _exportPerList(directory, 'txt', (track) => '${track.title}  ${track.artist}  ${track.album}');

  /// Writes one CSV file per playlist into [directory], each with [header].
  Future<void> exportToCsvDirectory(String directory, {required String header}) => _exportPerList(
    directory,
    'csv',
    (track) => '${_csvEscape(track.title)},${_csvEscape(track.artist)},${_csvEscape(track.album)}',
    header: header,
  );

  Future<void> _exportPerList(
    String directory,
    String extension,
    String Function(audio.MusicTrack track) rowOf, {
    String? header,
  }) async {
    for (final playlist in state) {
      final safe = audio.MusicDownloadRequest.sanitizeFileName(playlist.name);
      final name = safe.isEmpty ? playlist.id : safe;
      final rows = [for (final track in playlist.tracks) rowOf(track)].join('\n');
      await File('$directory/lx_list_$name.$extension').writeAsString(
        '\uFEFF${header ?? ''}$rows',
        flush: true,
      );
    }
  }

  /// [value] with CSV quoting applied — a quote doubles, a comma wraps the
  /// field in quotes.
  static String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return escaped.contains(',') ? '"$escaped"' : escaped;
  }

  /// Imports a file written by [exportToDirectory]; null when it cannot be
  /// read or holds no songs. A plain array of tracks is accepted too, which is
  /// what a hand-written list looks like.
  ///
  /// The list always lands as a new playlist; an existing name gets a suffix
  /// rather than being overwritten.
  Future<MusicPlaylist?> importFromFile(String path) async {
    try {
      final json = jsonDecode(await File(path).readAsString());
      final String name;
      final Object? entries;

      if (json is Map) {
        name = (json['name'] as String?)?.trim() ?? '';
        entries = json['tracks'];
      } else if (json is List) {
        name = '';
        entries = json;
      } else {
        return null;
      }

      if (entries is! List || state.length >= kMusicPlaylistLimit) return null;

      final tracks = [for (final entry in entries) ?musicTrackFromJson(entry)];

      if (tracks.isEmpty) return null;

      final base = name.isNotEmpty ? name : _nameOf(path);
      final playlist = MusicPlaylist(
        id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
        name: _uniqueName(base.isEmpty ? '歌单' : base),
        tracks: tracks,
        createdAt: DateTime.now(),
      );

      state = [...state, playlist];
      await _save();

      return playlist;
    } on Object {
      return null;
    }
  }

  /// [base], or [base] with the first free ` (n)` suffix.
  String _uniqueName(String base) {
    final names = {for (final playlist in state) playlist.name};
    if (!names.contains(base)) return base;

    for (var index = 2; ; index++) {
      final candidate = '$base ($index)';
      if (!names.contains(candidate)) return candidate;
    }
  }

  String _nameOf(String path) {
    final separator = path.lastIndexOf(RegExp(r'[\\/]'));
    final fileName = separator >= 0 ? path.substring(separator + 1) : path;
    final dot = fileName.lastIndexOf('.');

    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  static String? _read() {
    try {
      return StoragePrefs.getString(kMusicPlaylistsKey);
    } on Object {
      return null;
    }
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(kMusicPlaylistsKey, jsonEncode([for (final playlist in state) playlist.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's playlists.
final musicPlaylistsProvider = NotifierProvider<MusicPlaylistsController, List<MusicPlaylist>>(
  MusicPlaylistsController.new,
);

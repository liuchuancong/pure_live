/// The bridge between the module's own stores and the reference sync
/// protocol's list data: LX's `{defaultList, loveList, userList}` shape, its
/// MusicInfo JSON and its dislike rules string.
library;

import 'dart:convert' show jsonEncode, utf8;

import 'package:crypto/crypto.dart' show md5;

import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_playlists.dart' show MusicPlaylist;

/// The bridge between the module's own stores and the reference sync

/// protocol's list data: LX's `{defaultList, loveList, userList}` shape, its
/// MusicInfo JSON and its dislike rules string.
/// The sync modes the reference's first-time dialog offers; the module
/// answers `list_sync_get_sync_mode` with one of these.
const List<String> kMusicSyncModes = [
  'merge_remote_local',
  'merge_local_remote',
  'overwrite_remote_local',
  'overwrite_local_remote',
  'overwrite_remote_local_full',
  'overwrite_local_remote_full',
];

/// Builds the LX list data from the module's recent, favourites and playlists.
Map<String, Object?> musicSyncListDataFromState(
  List<audio.MusicTrack> recent,
  List<audio.MusicTrack> favourites,
  List<MusicPlaylist> playlists,
) => <String, Object?>{
  'defaultList': [for (final track in recent) musicSyncMusicInfo(track)],
  'loveList': [for (final track in favourites) musicSyncMusicInfo(track)],
  'userList': [
    for (final playlist in playlists)
      <String, Object?>{
        'id': playlist.id,
        'name': playlist.name,
        if (playlist.locationUpdateTime != null)
          'locationUpdateTime': playlist.locationUpdateTime!.millisecondsSinceEpoch,
        'list': [for (final track in playlist.tracks) musicSyncMusicInfo(track)],
      },
  ],
};

/// Encodes one song in the reference's online MusicInfo shape; the source id
/// doubles as the LX `source` field.
Map<String, Object?> musicSyncMusicInfo(audio.MusicTrack track) => <String, Object?>{
  'id': track.id,
  'name': track.title,
  'singer': track.artist,
  'source': track.sourceId,
  if (track.duration != null)
    'interval': '${_two(track.duration!.inMinutes)}:${_two(track.duration!.inSeconds % 60)}',
  'meta': <String, Object?>{
    'songId': track.id,
    if (track.album.isNotEmpty) 'albumName': track.album,
    if (track.coverUri != null) 'picUrl': track.coverUri.toString(),
    if (track.albumId != null) 'albumId': track.albumId,
    'qualitys': [for (final quality in track.qualities) quality.id],
  },
};

String _two(int value) => value.toString().padLeft(2, '0');

/// Reads one song back out; null when the entry is not one we can key.
audio.MusicTrack? musicSyncTrackFromInfo(Object? json) {
  if (json is! Map) return null;
  final id = json['id'];
  final name = json['name'];
  if (id is! String || id.isEmpty || name is! String) return null;
  final meta = json['meta'];
  final interval = json['interval'];
  return audio.MusicTrack(
    id: id,
    sourceId: json['source'] is String ? json['source'] as String : '',
    title: name,
    artist: json['singer'] is String ? json['singer'] as String : '',
    album: meta is Map && meta['albumName'] is String ? meta['albumName'] as String : '',
    albumId: meta is Map && meta['albumId'] is String ? meta['albumId'] as String : null,
    coverUri: meta is Map && meta['picUrl'] is String ? Uri.tryParse(meta['picUrl'] as String) : null,
    duration: _durationOf(interval is String ? interval : null),
  );
}

Duration? _durationOf(String? interval) {
  if (interval == null) return null;
  final parts = interval.split(':');
  if (parts.length != 2) return null;
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null) return null;
  return Duration(minutes: minutes, seconds: seconds);
}

/// Decodes LX list data; the three keys tolerate partial payloads the way
/// the reference's `patchListData` does.
({List<audio.MusicTrack> recent, List<audio.MusicTrack> favourites, List<MusicPlaylist> playlists})
musicSyncApplyListData(Object? listData) {
  if (listData is! Map) return (recent: const [], favourites: const [], playlists: const []);
  final love = _tracksOf(listData['loveList']);
  final defaultList = _tracksOf(listData['defaultList']);
  final playlists = <MusicPlaylist>[
    for (final entry in listData['userList'] as List? ?? const <Object?>[])
      if (entry is Map && entry['id'] is String && entry['name'] is String)
        MusicPlaylist(
          id: entry['id'] as String,
          name: entry['name'] as String,
          tracks: _tracksOf(entry['list']),
          createdAt: DateTime.now(),
        ),
  ];
  for (var i = 0; i < playlists.length; i++) {
    playlists[i] = playlists[i].copyWith(position: i);
  }
  return (recent: defaultList, favourites: love, playlists: playlists);
}

List<audio.MusicTrack> _tracksOf(Object? json) => [
  if (json is List)
    for (final entry in json) ?musicSyncTrackFromInfo(entry),
];

/// The MD5 the reference compares snapshots with: md5 over the JSON of the
/// list data, hex — the reference's `toMD5`.
String musicSyncMd5Of(Object? data) => md5.convert(utf8.encode(jsonEncode(data))).toString();

/// The dislike rules string for a set of `singer - title` rules, one per
/// line — the reference stores rules as one plain string.
String musicSyncDislikeRulesFromLines(Iterable<String> lines) => lines.join('\n');

/// Splits a rules string back into trimmed, non-empty lines.
List<String> musicSyncDislikeLines(String rules) => [
  for (final line in rules.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

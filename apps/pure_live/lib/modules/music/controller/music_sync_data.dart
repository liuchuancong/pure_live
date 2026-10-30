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
          locationUpdateTime: entry['locationUpdateTime'] is int
              ? DateTime.fromMillisecondsSinceEpoch(entry['locationUpdateTime'] as int)
              : null,
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

/// The result of one merge pass: the merged data plus the two sides the
/// server still has to overwrite.
final class MusicSyncMergeResult {
  const MusicSyncMergeResult(this.data, {required this.updateLocal, required this.updateRemote});

  final Map<String, Object?> data;
  final bool updateLocal;
  final bool updateRemote;
}

/// Patches partial list data the reference's `patchListData` does.
Map<String, Object?> musicSyncPatchListData(Object? listData) => <String, Object?>{
  'defaultList': listData is Map && listData['defaultList'] is List ? listData['defaultList'] : <Object?>[],
  'loveList': listData is Map && listData['loveList'] is List ? listData['loveList'] : <Object?>[],
  'userList': listData is Map && listData['userList'] is List ? listData['userList'] : <Object?>[],
};

/// Runs one sync-mode merge pass over the two sides' list data, the
/// reference's `handleMergeListData` decision table; null for a mode the
/// server must reject (`cancel` and strangers).
MusicSyncMergeResult? musicSyncMergeListData(Object? local, Object? remote, String mode, {required bool addToTop}) {
  final localData = musicSyncPatchListData(local);
  final remoteData = musicSyncPatchListData(remote);
  switch (mode) {
    case 'merge_local_remote':
      return MusicSyncMergeResult(
        musicSyncMergeUserLists(localData, remoteData, addToTop: addToTop),
        updateLocal: true,
        updateRemote: true,
      );
    case 'merge_remote_local':
      return MusicSyncMergeResult(
        musicSyncMergeUserLists(remoteData, localData, addToTop: addToTop),
        updateLocal: true,
        updateRemote: true,
      );
    case 'overwrite_local_remote':
      return MusicSyncMergeResult(musicSyncOverwriteUserLists(localData, remoteData), updateLocal: false, updateRemote: true);
    case 'overwrite_remote_local':
      return MusicSyncMergeResult(musicSyncOverwriteUserLists(remoteData, localData), updateLocal: true, updateRemote: false);
    case 'overwrite_local_remote_full':
      return MusicSyncMergeResult(localData, updateLocal: false, updateRemote: true);
    case 'overwrite_remote_local_full':
      return MusicSyncMergeResult(remoteData, updateLocal: true, updateRemote: false);
    default:
      return null;
  }
}

/// Whether a list data map has any content, the reference's length checks.
bool musicSyncListDataIsEmpty(Map<String, Object?> data) =>
    _listOf(data, 'defaultList').isEmpty && _listOf(data, 'loveList').isEmpty && _listOf(data, 'userList').isEmpty;

/// The data map's list under [key]; patched maps always hold lists.
List<Object?> _listOf(Map<String, Object?> data, String key) {
  final value = data[key];
  return value is List ? value : const <Object?>[];
}

/// Merges two sides the reference's `mergeList`: songs dedupe per list (the
/// target's top entries keep their place when adding to top), user lists
/// fold by id with the later `locationUpdateTime` winning the position.
Map<String, Object?> musicSyncMergeUserLists(Map<String, Object?> source, Map<String, Object?> target, {required bool addToTop}) =>
    <String, Object?>{
      'defaultList': _mergeMusicInfos(_listOf(source, 'defaultList'), _listOf(target, 'defaultList'), addToTop),
      'loveList': _mergeMusicInfos(_listOf(source, 'loveList'), _listOf(target, 'loveList'), addToTop),
      'userList': _mergeUserLists(_listOf(source, 'userList'), _listOf(target, 'userList'), addToTop),
    };

/// The reference's `overwriteList`: the source side wins outright; target
/// user lists the source never had join at their remembered position.
Map<String, Object?> musicSyncOverwriteUserLists(Map<String, Object?> source, Map<String, Object?> target) => <String, Object?>{
  'defaultList': source['defaultList'],
  'loveList': source['loveList'],
  'userList': _overwriteUserLists(_listOf(source, 'userList'), _listOf(target, 'userList')),
};

/// The reference's `handleMergeList`: concat by add position, then dedupe
/// by song id — bottom keeps the first occurrence, top keeps the last.
List<Object?> _mergeMusicInfos(List<Object?> source, List<Object?> target, bool addToTop) {
  final combined = addToTop ? [...target, ...source] : [...source, ...target];
  final seen = <String>{};
  final merged = <Object?>[
    for (final entry in combined)
      if (entry is Map && entry['id'] is String && seen.add(entry['id'] as String)) entry,
  ];
  return addToTop ? _keepLastOccurrences(combined, merged) : merged;
}

/// The reference's top-position walk: deduped songs sit at their last
/// (topmost) occurrence's position.
List<Object?> _keepLastOccurrences(List<Object?> combined, List<Object?> merged) {
  final ids = {for (final entry in merged) if (entry is Map) entry['id'] as String};
  final lastPosition = <String, int>{};
  for (var i = combined.length - 1; i >= 0; i--) {
    final entry = combined[i];
    if (entry is Map && entry['id'] is String && ids.contains(entry['id'])) {
      lastPosition.putIfAbsent(entry['id'] as String, () => i);
    }
  }
  return [
    for (var i = 0; i < combined.length; i++)
      if (combined[i] case final Map<Object?, Object?> entry
          when entry['id'] is String && lastPosition[entry['id']] == i)
        combined[i],
  ];
}

/// The reference's `mergeList` user-list half, in place over JSON maps.
List<Object?> _mergeUserLists(List<Object?> source, List<Object?> target, bool addToTop) {
  final merged = [...source];
  Map<Object?, Object?>? find(String id) {
    for (final list in merged) {
      if (list is Map && list['id'] == id) return list;
    }
    return null;
  }

  for (var index = 0; index < target.length; index++) {
    final list = target[index];
    if (list is! Map) continue;
    final id = list['id'];
    if (id is! String) continue;
    final targetTime = _updateTimeOf(list);
    final sourceList = find(id);
    if (sourceList != null) {
      sourceList['list'] = _mergeMusicInfos(
        sourceList['list'] is List ? sourceList['list']! as List : const <Object?>[],
        list['list'] is List ? list['list']! as List : const <Object?>[],
        addToTop,
      );
      if (targetTime >= _updateTimeOf(sourceList)) continue;
      // The target moved the list more recently: take its position and time.
      merged.remove(sourceList);
      sourceList['locationUpdateTime'] = targetTime;
      merged.insert(index.clamp(0, merged.length), sourceList);
    } else if (targetTime != 0) {
      merged.insert(index.clamp(0, merged.length), list);
    } else {
      merged.add(list);
    }
  }
  return merged;
}

/// The reference's `overwriteList` user-list half.
List<Object?> _overwriteUserLists(List<Object?> source, List<Object?> target) {
  final merged = [...source];
  final ids = {for (final list in merged) if (list is Map) list['id']: true};
  for (var index = 0; index < target.length; index++) {
    final list = target[index];
    if (list is! Map || ids[list['id']] == true) continue;
    final time = _updateTimeOf(list);
    if (time != 0) {
      merged.insert(index.clamp(0, merged.length), list);
    } else {
      merged.add(list);
    }
  }
  return merged;
}

int _updateTimeOf(Map<Object?, Object?> list) {
  final time = list['locationUpdateTime'];
  return time is int ? time : 0;
}

/// The reference's `mergeList` for dislike rules: both sides' lines
/// normalized and deduped — `filterRules(source + '\n' + target)`.
String musicSyncDislikeMerge(String local, String remote) {
  final lines = <String>{};
  for (final item in '$local\n$remote'.split('\n')) {
    if (item.isEmpty) continue;
    final parts = item.split('@');
    final name = _dislikeName(parts.isNotEmpty ? parts[0] : '');
    final singer = _dislikeName(parts.length > 1 ? parts[1] : '');
    if (name.isNotEmpty) {
      lines.add(singer.isNotEmpty ? '$name@$singer' : name);
    } else if (singer.isNotEmpty) {
      lines.add('@$singer');
    }
  }
  return lines.join('\n');
}

/// One rule half: inner `@` becomes the reference's `#` alias, then
/// lowercase and trim.
String _dislikeName(String raw) => raw.replaceAll('@', '#').toLowerCase().trim();


/// The dislike rules string for a set of `singer - title` rules, one per
/// line — the reference stores rules as one plain string.
String musicSyncDislikeRulesFromLines(Iterable<String> lines) => lines.join('\n');

/// Splits a rules string back into trimmed, non-empty lines.
List<String> musicSyncDislikeLines(String rules) => [
  for (final line in rules.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

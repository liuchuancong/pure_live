import 'dart:convert' show jsonDecode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_dislikes.dart' show musicDislikesProvider;
import 'package:pure_live/modules/music/controller/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_search.dart' show musicSearchProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart' show OnlinePlaylists;

/// One `lxmusic://` action, parsed.
///
/// The sealed family mirrors the reference's three link types — music,
/// songlist, player — so `switch` over it is exhaustive and a new link
/// type cannot silently fall through.
sealed class MusicDeeplinkAction {
  const MusicDeeplinkAction();
}

/// `lxmusic://music/search/…` — fill the library's search field.
final class MusicDeeplinkSearch extends MusicDeeplinkAction {
  const MusicDeeplinkSearch({required this.keywords});

  /// The query, at most 128 characters like the reference keeps.
  final String keywords;
}

/// `lxmusic://music/play` — play one fully described track.
final class MusicDeeplinkPlay extends MusicDeeplinkAction {
  const MusicDeeplinkPlay({required this.track});

  final audio.MusicTrack track;
}

/// `lxmusic://music/searchPlay/…` — look the song up by name and play the
/// first hit; [playLater] queues it instead of cutting the current song.
final class MusicDeeplinkSearchPlay extends MusicDeeplinkAction {
  const MusicDeeplinkSearchPlay({required this.name, required this.singer, this.playLater = false});

  final String name;
  final String singer;
  final bool playLater;
}

/// `lxmusic://songlist/open/…` — open an online playlist's detail page.
final class MusicDeeplinkOpenSonglist extends MusicDeeplinkAction {
  const MusicDeeplinkOpenSonglist({required this.sourceId, required this.id});

  final String sourceId;
  final String id;
}

/// `lxmusic://songlist/play/…` — play an online playlist, optionally from
/// [index].
final class MusicDeeplinkPlaySonglist extends MusicDeeplinkAction {
  const MusicDeeplinkPlaySonglist({required this.sourceId, required this.id, this.index});

  final String sourceId;
  final String id;
  final int? index;
}

/// One of the player's remote commands.
enum MusicDeeplinkPlayerCommand { play, pause, skipNext, skipPrev, togglePlay, collect, uncollect, dislike }

/// `lxmusic://player/<command>`.
final class MusicDeeplinkPlayer extends MusicDeeplinkAction {
  const MusicDeeplinkPlayer({required this.command});

  final MusicDeeplinkPlayerCommand command;
}

/// A link the parser rejects; the message is what the UI shows.
final class MusicDeeplinkException implements Exception {
  const MusicDeeplinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The sources a play link may describe, with the id key each one's
/// payload carries — the reference's per-source verification table.
const Map<String, String> kMusicDeeplinkSourceIdKeys = <String, String>{
  'kw': 'songmid',
  'kg': 'hash',
  'tx': 'songmid',
  'wy': 'songmid',
  'mg': 'copyrightId',
};

/// Parses a `lxmusic://…` link into an action.
///
/// Throws [MusicDeeplinkException] for anything malformed — unknown type
/// or action, a play link without a usable payload, an id-less songlist.
MusicDeeplinkAction parseMusicDeeplink(String link) {
  const scheme = 'lxmusic://';
  if (!link.startsWith(scheme)) throw const MusicDeeplinkException('Not a lxmusic:// link');

  final body = link.substring(scheme.length);
  final split = body.split('?');
  final segments = split.first
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(_decode)
      .toList();
  if (segments.isEmpty) throw const MusicDeeplinkException('Empty link');

  final params = <String, String>{};
  if (split.length > 1) {
    for (final pair in split[1].split('&')) {
      if (pair.isEmpty) continue;
      final equals = pair.indexOf('=');
      final key = equals < 0 ? pair : pair.substring(0, equals);
      final value = equals < 0 ? '' : _decode(pair.substring(equals + 1));
      params[key] = value;
    }
  }
  final type = segments.first;
  final action = segments.length > 1 ? segments[1] : '';
  final paths = segments.sublist(2);

  switch (type) {
    case 'music':
      return _parseMusicLink(action, paths, params);
    case 'songlist':
      return _parseSonglistLink(action, paths, params);
    case 'player':
      final command = MusicDeeplinkPlayerCommand.values.where((value) => value.name == action).firstOrNull;
      if (command == null) throw MusicDeeplinkException('Unknown player action: $action');
      return MusicDeeplinkPlayer(command: command);
    default:
      throw MusicDeeplinkException('Unknown type: $type');
  }
}

/// Percent-decodes a link part; senders that skip encoding must still work.
String _decode(String part) {
  // decodeComponent throws on a stray '%', so only decode parts whose every
  // escape is a well-formed %XX.
  if (!part.contains(RegExp('%(?:[0-9A-Fa-f]{2})'))) return part;
  if (RegExp('%(?![0-9A-Fa-f]{2})').hasMatch(part)) return part;
  return Uri.decodeComponent(part);
}

MusicDeeplinkAction _parseMusicLink(String action, List<String> paths, Map<String, String> params) {
  switch (action) {
    case 'search':
      String text;
      if (params.containsKey('keywords')) {
        text = params['keywords']!;
      } else {
        if (paths.isEmpty) throw const MusicDeeplinkException('Keyword missing');
        text = paths.length > 1 ? paths[1] : paths[0];
      }
      if (text.length > 128) text = text.substring(0, 128);
      return MusicDeeplinkSearch(keywords: text);

    case 'play':
      final raw = params['data'];
      if (raw == null || raw.isEmpty) throw const MusicDeeplinkException('Play link without data');
      Object decoded;
      try {
        decoded = jsonDecode(raw) as Object;
      } on FormatException {
        throw const MusicDeeplinkException('Play data is not JSON');
      }
      return MusicDeeplinkPlay(track: _trackFromDeeplinkJson(decoded));

    case 'searchPlay':
      String name;
      var singer = '';
      if (paths.isNotEmpty) {
        name = paths.first.trim();
        if (name.contains('-')) {
          final parts = name.split('-');
          name = parts.first.trim();
          singer = parts.length > 1 ? parts[1].trim() : '';
        }
      } else {
        final data = params['data'];
        if (data == null) throw const MusicDeeplinkException('searchPlay without name');
        final decoded = jsonDecode(data);
        if (decoded is! Map) throw const MusicDeeplinkException('searchPlay data is not an object');
        name = '${decoded['name'] ?? ''}'.trim();
        singer = '${decoded['singer'] ?? ''}'.trim();
      }
      if (name.isEmpty) throw const MusicDeeplinkException('searchPlay without name');
      final playLater = params['playLater'] == 'true' || params['data'] != null && _jsonFlag(params['data'], 'playLater');
      return MusicDeeplinkSearchPlay(name: name, singer: singer, playLater: playLater);

    default:
      throw MusicDeeplinkException('Unknown music action: $action');
  }
}

bool _jsonFlag(String? raw, String key) {
  if (raw == null || raw.isEmpty) return false;
  final decoded = jsonDecode(raw);
  return decoded is Map && decoded[key] == true;
}

/// Builds a track from a play link's payload, verifying the fields the
/// named source actually needs — a kw link without `songmid` is rejected,
/// not silently played as an empty id.
audio.MusicTrack _trackFromDeeplinkJson(Object? decoded) {
  if (decoded is! Map) throw const MusicDeeplinkException('Play data is not an object');
  final source = '${decoded['source'] ?? ''}';
  final idKey = kMusicDeeplinkSourceIdKeys[source];
  if (idKey == null) throw MusicDeeplinkException('Unknown source: $source');

  final id = '${decoded[idKey] ?? ''}';
  final name = '${decoded['name'] ?? ''}';
  if (id.isEmpty || name.isEmpty) throw const MusicDeeplinkException('Play data missing name or id');

  final qualities = <audio.MusicQuality>[];
  final types = decoded['types'];
  if (types is List) {
    const byScript = <String, audio.MusicQuality>{
      '128k': audio.MusicQuality.k128,
      '320k': audio.MusicQuality.k320,
      'flac': audio.MusicQuality.flac,
      'flac24bit': audio.MusicQuality.flac24bit,
      'hires': audio.MusicQuality.hires,
    };
    for (final type in types) {
      final script = type is Map ? '${type['type'] ?? ''}' : '';
      final quality = byScript[script];
      if (quality != null && !qualities.contains(quality)) qualities.add(quality);
    }
  }

  final interval = '${decoded['interval'] ?? ''}';
  final minutes = int.tryParse(interval.split(':').firstOrNull ?? '');

  return audio.MusicTrack(
    id: id,
    sourceId: source,
    title: name,
    artist: '${decoded['singer'] ?? ''}',
    album: '${decoded['albumName'] ?? ''}',
    albumId: decoded['albumId'] == null || '${decoded['albumId']}'.isEmpty ? null : '${decoded['albumId']}',
    coverUri: decoded['img'] == null || '${decoded['img']}'.isEmpty ? null : Uri.tryParse('${decoded['img']}'),
    duration: minutes == null ? null : Duration(minutes: minutes),
    qualities: qualities,
    metadata: {'strMediaMid': decoded['strMediaMid'], 'albumMid': decoded['albumMid'], 'lrcUrl': decoded['lrcUrl']}
        .cast<String, Object?>()
      ..removeWhere((key, value) => value == null),
  );
}

MusicDeeplinkAction _parseSonglistLink(String action, List<String> paths, Map<String, String> params) {
  if (action != 'open' && action != 'play') throw MusicDeeplinkException('Unknown songlist action: $action');

  String? source;
  String? id;
  int? index;
  final raw = params['data'];
  if (raw != null && raw.isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const MusicDeeplinkException('Songlist data is not an object');
    source = decoded['source'] == null ? null : '${decoded['source']}';
    id = decoded['id'] == null ? null : '${decoded['id']}';
    id ??= decoded['url'] == null ? null : '${decoded['url']}';
    if (action == 'play' && decoded['index'] is num) index = (decoded['index'] as num).toInt();
  } else {
    if (paths.isEmpty) throw const MusicDeeplinkException('id or url missing');
    source = paths[0];
    if (paths.length > 1) id = paths[1];
    if (action == 'play' && paths.length > 2) index = int.tryParse(paths[2]);
  }

  if (source == null || source.isEmpty || id == null || id.isEmpty) {
    throw const MusicDeeplinkException('id or url missing');
  }

  return action == 'open'
      ? MusicDeeplinkOpenSonglist(sourceId: source, id: id)
      : MusicDeeplinkPlaySonglist(sourceId: source, id: id, index: index);
}

/// Runs a parsed link against the module's controllers.
///
/// The OS-level `lxmusic://` registration is platform work that has not
/// landed; this executor is the hand the platform layer will call once a
/// link arrives. Unknown sources in songlist links are the online
/// playlist layer's concern at fetch time, not the parser's.
Future<void> executeMusicDeeplink(Ref ref, MusicDeeplinkAction action) async {
  switch (action) {
    case MusicDeeplinkSearch(:final keywords):
      await ref.read(musicSearchProvider.notifier).search(keywords);

    case MusicDeeplinkPlay(:final track):
      await ref.read(musicPlayerProvider.notifier).play(track);

    case MusicDeeplinkSearchPlay(:final name, :final singer, :final playLater):
      // The current source answers the lookup; its first hit plays.
      final source = ref.read(musicSourceProvider);
      final query = singer.isEmpty ? name : '$name $singer';
      final answer = await source.search(query);
      final hit = answer.items.firstOrNull;
      if (hit == null) return;
      final player = ref.read(musicPlayerProvider.notifier);
      if (playLater) {
        await player.playNext(hit);
      } else {
        await player.play(hit);
      }

    case MusicDeeplinkOpenSonglist():
      // The songlist surface is the online-playlist layer's route; the
      // parser validated the shape, navigation is the caller's concern.
      break;

    case MusicDeeplinkPlaySonglist(:final id, :final index):
      final source = ref.read(musicSourceProvider);
      // OnlinePlaylists is a mixin, so `is` cannot promote; a cast is the
      // only way to reach the mixin's methods from the base type.
      if (source is! OnlinePlaylists) return;
      final playlists = source as OnlinePlaylists;
      final (_, tracks) = await playlists.playlistDetail(id);
      if (tracks.isEmpty) return;
      await ref.read(musicPlayerProvider.notifier).playAll(tracks, index: index ?? 0);

    case MusicDeeplinkPlayer(:final command):
      final player = ref.read(musicPlayerProvider.notifier);
      switch (command) {
        case MusicDeeplinkPlayerCommand.play:
          await player.toggle();
        case MusicDeeplinkPlayerCommand.pause:
          await player.toggle();
        case MusicDeeplinkPlayerCommand.togglePlay:
          await player.toggle();
        case MusicDeeplinkPlayerCommand.skipNext:
          await player.next();
        case MusicDeeplinkPlayerCommand.skipPrev:
          await player.previous();
        case MusicDeeplinkPlayerCommand.collect:
          final track = ref.read(musicPlayerProvider).track;
          if (track != null) await ref.read(musicFavouritesProvider.notifier).toggle(track);
        case MusicDeeplinkPlayerCommand.uncollect:
          final track = ref.read(musicPlayerProvider).track;
          if (track != null) await ref.read(musicFavouritesProvider.notifier).toggle(track);
        case MusicDeeplinkPlayerCommand.dislike:
          final track = ref.read(musicPlayerProvider).track;
          if (track != null) await ref.read(musicDislikesProvider.notifier).toggle(track);
      }
  }
}

/// Parses and runs a raw link; returns the message a failed link should
/// show, or null on success — so the caller needs no try/catch.
Future<String?> handleMusicDeeplink(Ref ref, String link) async {
  try {
    await executeMusicDeeplink(ref, parseMusicDeeplink(link));
    return null;
  } on MusicDeeplinkException catch (error) {
    return error.message;
  }
}

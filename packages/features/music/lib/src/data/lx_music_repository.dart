// Module: lib/src/data/lx_music_repository.dart
// Purpose: The music domain's repository over one script host: resolve a song to its url, lyric or cover.
// Author: liuchuancong
// Created: 2026-10-10
//
// The music ContentRef carries its lx source key and quality in metadata, which is what lets a queue entry
// survive a restart without re-deriving which source it came from. This file is where that metadata contract
// is read - once, in one place, with the failure named when a ref arrives without it.
//
// An earlier version threw a bare StateError for a ref with no `lxSource` and returned nulls that could mean
// three different things. A missing source key is the ref being built wrong (a programming error worth
// raising), while no lyric is a normal answer, so the two are separated here rather than flattened.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show stringOrNull;

import '../domain/music_source_bridge.dart';

/// The metadata key holding the lx source a song came from.
const String kMusicSourceKey = 'lxSource';

/// The metadata key holding the quality label to request.
const String kMusicQualityKey = 'quality';

/// The quality asked for when a reference did not say.
const String kMusicDefaultQuality = '128k';

/// Resolves music references through one attached script host.
final class LxMusicRepository {
  const LxMusicRepository({required MusicSourceBridge bridge}) : _bridge = bridge;

  final MusicSourceBridge _bridge;

  /// The play url for [ref].
  ///
  /// Throws [MusicSourceFailure] when the ref does not name its source: that ref cannot be played by
  /// anything, and returning null would put it in the same bucket as "this source has no such song".
  Future<String> resolveUrl(ContentRef ref) async {
    final (source, id, quality) = _arguments(ref);
    final url = await _bridge.musicUrl(source: source, songId: id, quality: quality);
    if (url.isEmpty) {
      throw MusicSourceFailure('$source returned an empty play url for $id at $quality');
    }
    return url;
  }

  /// The lyric text for [ref], or null when the source serves none.
  Future<String?> lyric(ContentRef ref) async {
    final (source, id, _) = _arguments(ref);
    return _bridge.lyric(source: source, songId: id);
  }

  /// The cover url for [ref], or null when the source serves none.
  Future<String?> cover(ContentRef ref) async {
    final (source, id, _) = _arguments(ref);
    return _bridge.cover(source: source, songId: id);
  }

  /// The sources that answer musicUrl, as {source key, qualities}, or null while the script has not
  /// announced anything.
  Map<String, List<String>>? availableSources() {
    final announced = _bridge.announcedSources;
    if (announced == null) {
      return null;
    }
    return <String, List<String>>{
      for (final entry in announced.entries)
        if (entry.value.servesMusicUrl) entry.key: entry.value.qualities,
    };
  }

  /// True once the host has announced its sources, for a surface that shows a loading row instead of an
  /// empty one.
  bool get isReady => _bridge.announcedSources != null;

  (String, String, String) _arguments(ContentRef ref) {
    final source = stringOrNull(ref.metadata[kMusicSourceKey]);
    if (source == null) {
      throw MusicSourceFailure(
        'music ref ${ref.sourceId}/${ref.contentId} does not name its $kMusicSourceKey, so no source can serve it',
      );
    }
    final quality = stringOrNull(ref.metadata[kMusicQualityKey]) ?? kMusicDefaultQuality;
    return (source, ref.contentId, quality);
  }
}

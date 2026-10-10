// Module: lib/src/data/lx_music_repository.dart
// Purpose: The music domain's repository over one lx source host: resolve a
// song ref to its play url, lyric or cover through the script's handler.
// Author: liuchuancong
// Created: 2026-10-10
//
// The lx host (providers/music) speaks {action, source, info}; this repository
// is where the music domain's ContentRef vocabulary maps onto that call. A
// music ContentRef is expected to carry its lx source key and quality in
// metadata, which is what makes a queue entry survive restarts without
// re-resolving its source assignment.

import 'package:pure_live_music/pure_live_music.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

/// Resolves music refs through one attached lx source host.
final class LxMusicRepository {
  LxMusicRepository({required this.host});

  final MusicSourceScriptHost host;

  /// The play url for [ref]. Expected metadata: `lxSource` (the source key
  /// the script announced, for example wy), optional `quality` (lx quality
  /// vocabulary, default 128k).
  Future<String> resolveUrl(ContentRef ref) {
    final source = '${ref.metadata['lxSource'] ?? ''}';
    if (source.isEmpty) {
      throw StateError('music ref ${ref.contentId} does not name its lx source');
    }
    return host.musicUrl(source, ref.contentId, '${ref.metadata['quality'] ?? '128k'}');
  }

  /// The lyric text for [ref], when its source serves lyric.
  Future<String?> lyric(ContentRef ref) {
    return host.lyric('${ref.metadata['lxSource'] ?? ''}', ref.contentId);
  }

  /// The cover url for [ref], when its source serves pic.
  Future<String?> cover(ContentRef ref) {
    return host.pic('${ref.metadata['lxSource'] ?? ''}', ref.contentId);
  }

  /// The sources the script announced that answer musicUrl, as
  /// {source key, quality list}. Null until the script called lx.send('inited').
  Map<String, List<String>>? availableSources() {
    final announced = host.announced;
    if (announced == null) {
      return null;
    }
    return <String, List<String>>{
      for (final entry in announced.sources.entries)
        if (entry.value.serves('musicUrl')) entry.key: entry.value.qualitys,
    };
  }
}

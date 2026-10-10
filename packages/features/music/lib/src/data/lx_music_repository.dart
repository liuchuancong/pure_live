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
//
// This is the boundary between the domain and a script written by somebody else, so it also does the two jobs
// a boundary owes: a url that is not a url (an lx handler answers a failed lookup with the literal string
// `null`, which the player accepts and then shows nothing) and a foreign exception from the host, which the
// caller cannot classify because it did not choose the runtime that threw it.

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
  const LxMusicRepository({required MusicSourceBridge bridge, this.defaultQuality = kMusicDefaultQuality})
    : _bridge = bridge;

  final MusicSourceBridge _bridge;

  /// The label used when a reference does not carry one. A host whose sources only answer 320k should pass
  /// that here rather than have every lookup fall through to a quality the source never offered.
  final String defaultQuality;

  /// The play url for [ref].
  ///
  /// Throws [MusicSourceFailure] when the ref does not name its source: that ref cannot be played by
  /// anything, and returning null would put it in the same bucket as "this source has no such song".
  Future<String> resolveUrl(ContentRef ref) async {
    final (source, id, quality) = _arguments(ref);
    _requireAnnouncedQuality(source, quality);
    final url = await _guard(
      () => _bridge.musicUrl(source: source, songId: id, quality: quality),
      asking: 'play url of $id at $quality',
    );
    if (url.trim().isEmpty) {
      throw MusicSourceFailure('$source returned an empty play url for $id at $quality');
    }
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      // `null`, an error page, a truncated redirect - all of which reach the player as "a url" and play as
      // silence with no failure for the recovery ladder to read.
      throw MusicSourceFailure('$source returned "$url" for $id at $quality, which is not a stream url');
    }
    return url;
  }

  /// The lyric text for [ref], or null when the source serves none.
  Future<String?> lyric(ContentRef ref) async {
    final (source, id, _) = _arguments(ref);
    final text = await _guard(
      () => _bridge.lyric(source: source, songId: id),
      asking: 'lyric of $id',
    );
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    return text;
  }

  /// The cover url for [ref], or null when the source serves none.
  ///
  /// A picture is not playable audio, so an unusable value is reported as "no cover" instead of a failure: a
  /// surface with a placeholder is a worse-looking but more correct answer than a song that will not start.
  Future<String?> cover(ContentRef ref) async {
    final (source, id, _) = _arguments(ref);
    final url = await _guard(
      () => _bridge.cover(source: source, songId: id),
      asking: 'cover of $id',
    );
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }
    return url;
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

  /// The quality labels [source] answers with, or null when the script has not announced it (which includes
  /// "announced but cannot resolve urls").
  List<String>? qualitiesFor(String source) {
    final announced = _bridge.announcedSources?[source];
    if (announced == null || !announced.servesMusicUrl) {
      return null;
    }
    return announced.qualities;
  }

  /// True when the source lists [quality], or when nothing is known about the source - an unannounced host
  /// is not evidence that a label is wrong.
  bool servesQuality(String source, String quality) {
    final labels = qualitiesFor(source);
    return labels == null || labels.isEmpty || labels.contains(quality);
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
    final quality = stringOrNull(ref.metadata[kMusicQualityKey]) ?? defaultQuality;
    return (source, ref.contentId, quality);
  }

  void _requireAnnouncedQuality(String source, String quality) {
    final labels = qualitiesFor(source);
    if (labels == null || labels.isEmpty || labels.contains(quality)) {
      return;
    }
    throw MusicSourceFailure('$source does not offer "$quality"; it answers ${labels.join(', ')}');
  }

  Future<T> _guard<T>(Future<T> Function() operation, {required String asking}) async {
    try {
      return await operation();
    } on MusicSourceFailure {
      rethrow;
    } catch (error) {
      // The caller cannot classify an exception the script runtime chose, so it arrives as the contract's
      // failure with the question that produced it named.
      throw MusicSourceFailure('the script host failed while resolving the $asking', cause: error);
    }
  }
}

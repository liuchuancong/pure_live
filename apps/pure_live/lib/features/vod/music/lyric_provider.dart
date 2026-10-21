import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_vod/live_vod.dart' show LyricQuery;

/// Where music lyrics come from.
///
/// The app has no lyric service of its own, and a Bilibili video carries none
/// — the reference reaches third-party LRC services by title and artist. That
/// choice (which service, with whose key) belongs to whoever ships the build,
/// so this is the seam: [LyricProviders.none] is the shipping answer and the
/// strip stays hidden, and a provider is added by overriding [lyricProvider].
abstract interface class LyricProvider {
  /// The raw LRC for [query], or null when the service has nothing.
  Future<String?> fetch(LyricQuery query);
}

/// The shipping lyric providers.
abstract final class LyricProviders {
  /// No service: every query answers null and no lyric strip is drawn.
  static const LyricProvider none = _NoLyrics();
}

final class _NoLyrics implements LyricProvider {
  const new();

  @override
  Future<String?> fetch(LyricQuery query) async => null;
}

/// The lyric provider the app uses; override it to plug a service in.
final lyricProvider = Provider<LyricProvider>((ref) => LyricProviders.none);

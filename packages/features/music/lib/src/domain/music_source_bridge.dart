// Module: lib/src/domain/music_source_bridge.dart
// Purpose: The music domain's view of an lx script host, declared here so the domain does not import a site.
// Author: liuchuancong
// Created: 2026-10-10
//
// docs/architecture/dependency-rules.md section 3 says a feature consumes providers through the registry,
// never by importing them - and this package was importing `providers/music` for one class
// (`MusicSourceScriptHost`). The import could not be "declared" in the pubspec without turning the violation
// into an approved edge, so the edge is inverted instead: this file states the four questions the music
// domain asks, and the app that loads the lx script writes the adapter. Reversible: if lx-shaped calls turn
// out to belong in a shared contract, the port moves to ecosystem unchanged and nothing here breaks.
//
// The shape mirrors what the lx protocol actually exchanges - {action, source, info} - without naming it: a
// quality string, a song id, and what the script announced at init.

import 'package:pure_live_utils/pure_live_utils.dart' show DomainFailure;

/// One announced source's capabilities, as the script reported them.
final class MusicSourceQualities {
  const MusicSourceQualities({required this.qualities, required this.servesMusicUrl});

  /// The quality labels this source answers with, in the script's own order.
  final List<String> qualities;

  /// False means the script announced the source but does not resolve play urls from it - a row that is
  /// listed but never selectable for playback.
  final bool servesMusicUrl;
}

/// The lx-shaped host, as far as the music domain can see it.
abstract interface class MusicSourceBridge {
  /// The play url for [songId] at [quality] from [source].
  Future<String> musicUrl({required String source, required String songId, required String quality});

  /// The lyric text, or null when this source serves no lyric.
  Future<String?> lyric({required String source, required String songId});

  /// The cover url, or null when this source serves no picture.
  Future<String?> cover({required String source, required String songId});

  /// What the script announced, or null until it has initialised.
  ///
  /// Null is a real state, not an empty map: an uninitialised host answers "no sources" the same way a
  /// script that announced nothing would, and the surface has to be able to tell a loading host from an
  /// empty one.
  Map<String, MusicSourceQualities>? get announcedSources;
}

/// A music lookup could not be answered.
final class MusicSourceFailure extends DomainFailure {
  const MusicSourceFailure(super.reason, {super.cause});
}

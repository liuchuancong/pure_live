import 'package:flutter/foundation.dart' show immutable;
import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' show kMediaKitCustomInputKey;
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/core/player/core/playback_source_hints.dart';
import 'package:pure_live/core/player/kernel/owned_input_opener.dart';
import 'package:pure_live/domains/live/domain/live_player_facade.dart'
    show FacadeStreamCommit, PlaybackSourceRefreshRequest, PlaybackSourceRefreshResult;
import 'package:pure_live/shared/platforms/live_site.dart' show LiveStreamFacts;

/// Orders a refreshed plan for the kernel sweep: the preferred line first, the
/// rest in platform order, duplicates dropped.
///
/// A refresh replaces the whole plan, so the index the viewer was watching no
/// longer points at their line — moving that line to the front is what keeps
/// them on it, because the kernel starts a refreshed list at index 0. The
/// platform order behind it stays the fallback preference the sweep walks.
List<String> refreshedLineOrder({required List<String> urls, required int preferredLineIndex}) {
  if (urls.isEmpty) return const <String>[];
  final preferred = urls[preferredLineIndex.clamp(0, urls.length - 1)];
  return List<String>.unmodifiable(<String>[preferred, ...urls.where((url) => url != preferred)]);
}

/// The refresh question for the playback a commit describes.
///
/// [PlaybackSourceRefreshRequest.advanceLine] stays false: the sweep walks the
/// refreshed plan itself, so a resolver that pre-advanced would skip the line
/// the viewer was watching and land on a CDN nobody asked for.
PlaybackSourceRefreshRequest sourceRefreshRequestFor(FacadeStreamCommit commit) {
  final qualities = commit.qualities;
  final LivePlayQuality? quality = qualities.isEmpty
      ? null
      : qualities[commit.currentQuality.clamp(0, qualities.length - 1)];
  return PlaybackSourceRefreshRequest(
    currentLineIndex: commit.currentLineIndex,
    advanceLine: false,
    currentUrl: commit.currentUrl.isEmpty ? null : commit.currentUrl,
    currentSource: commit.ownedSource,
    currentQuality: quality,
  );
}

/// Whether a refresh answer may replace the lines a playback is holding.
///
/// The refresh is a round-trip to the platform, and everything that can
/// supersede a playback — a new play, a line switch, a room change, a
/// dispose — can happen while it is in flight. Adopting a stale answer would
/// publish a commit describing sources the kernel was never given, and the
/// line selector, the engine switch and the floating-window re-entry all read
/// their URLs from that commit.
bool canAdoptSourceRefresh({
  required bool disposed,
  required bool sameRoom,
  required bool revisionMoved,
  required PlaybackSourceRefreshResult result,
}) => !disposed && sameRoom && !revisionMoved && result.hasSources;

/// Builds the kernel's candidate lines for a URL plan.
///
/// One shape for every path that opens a plan — first open, engine switch,
/// recovery refresh — because a source built without the platform's declared
/// container makes the engine probe for it, and probing is exactly the cost
/// the slow lines cannot pay.
List<PlayerSource> livePlanSources(
  List<String> lines, {
  required Map<String, String> headers,
  required Map<String, LiveStreamFacts> streamFacts,
}) => List<PlayerSource>.unmodifiable(<PlayerSource>[
  for (final url in lines)
    PlayerSource(
      id: SourceId('live-$url'),
      uri: Uri.parse(url),
      type: SourceType.live,
      headers: SourceHeaders(headers),
      metadata: playbackStreamFormatMetadata(streamFacts[url]?.format.name),
    ),
]);

/// Builds the kernel's single candidate for an owned input.
///
/// The metadata must carry the **input factory**, not the source — that is the
/// only thing the engine's custom-input opener accepts (see
/// [customInputMetadataOf]). Handing it the whole `OwnedPlaybackSource` is
/// refused as "Not an owned-input recipe" and the room never opens.
PlayerSource ownedPlanSource(OwnedPlaybackSource source, LiveRoom room) => PlayerSource(
  id: SourceId('owned-${room.identityKey}'),
  uri: Uri(scheme: 'owned', path: room.identityKey),
  type: SourceType.live,
  protocol: SourceProtocol.custom,
  metadata: <String, Object?>{kMediaKitCustomInputKey: customInputMetadataOf(source)},
);

/// The commit a refresh answer turns into.
///
/// Publishing it is not bookkeeping: the commit is the only description of the
/// playback anything outside the kernel reads. The line selector counts its
/// `urls`, and an engine switch, a floating window and a re-entered room all
/// rebuild their source from `currentUrl`, `headers` and `ownedSource`. A
/// refresh that replaced expired signed URLs without a new commit would leave
/// every one of them pointing at addresses the platform has already rejected.
@immutable
class RefreshedPlaybackCommit {
  const RefreshedPlaybackCommit({
    required this.sources,
    required this.currentUrl,
    required this.urls,
    required this.lines,
    required this.qualities,
    required this.currentQuality,
    required this.streamFacts,
    this.ownedSource,
  });

  /// The kernel's candidates, in the order it will sweep them.
  final List<PlayerSource> sources;
  final String currentUrl;

  /// The platform-ordered line list the selector is written against.
  final List<String> urls;

  /// The same plan in the kernel's preference order — the line being swept
  /// first, then the platform order. Empty for an owned input, which has no
  /// reusable URL to fall back to.
  final List<String> lines;
  final List<LivePlayQuality> qualities;
  final int currentQuality;
  final Map<String, LiveStreamFacts> streamFacts;
  final Object? ownedSource;
}

/// Turns a refresh answer into the kernel's candidates and the commit that
/// describes them.
///
/// [intercept] is the app's source wiring (FFmpeg relay / manifest rewrite),
/// the same one a first open goes through: a refreshed plan that skips it
/// would lose the relay for exactly the streams that need one.
Future<RefreshedPlaybackCommit> refreshedPlaybackCommit(
  PlaybackSourceRefreshResult result, {
  required FacadeStreamCommit committed,
  required LiveRoom room,
  required Future<List<PlayerSource>> Function(List<PlayerSource> sources) intercept,
}) async {
  final ownedCandidate = result.ownedSource;
  final owned = ownedCandidate is OwnedPlaybackSource ? ownedCandidate : null;
  final selection = result.selection;
  final qualities = selection?.qualities ?? committed.qualities;
  final currentQuality = selection == null
      ? committed.currentQuality
      : selection.currentQuality.clamp(0, qualities.isEmpty ? 0 : qualities.length - 1);

  if (owned != null) {
    return RefreshedPlaybackCommit(
      sources: await intercept(<PlayerSource>[ownedPlanSource(owned, room)]),
      currentUrl: 'owned:${room.identityKey}',
      urls: const <String>[],
      lines: const <String>[],
      qualities: qualities,
      currentQuality: currentQuality,
      streamFacts: selection?.streamFacts ?? const <String, LiveStreamFacts>{},
      ownedSource: owned,
    );
  }

  final urls = List<String>.unmodifiable(result.urls);
  final lines = refreshedLineOrder(urls: urls, preferredLineIndex: result.preferredLineIndex);
  final streamFacts = selection?.streamFacts ?? const <String, LiveStreamFacts>{};

  return RefreshedPlaybackCommit(
    sources: await intercept(livePlanSources(lines, headers: committed.headers, streamFacts: streamFacts)),
    currentUrl: lines.first,
    // The platform order is what the commit reports, so the selector keeps
    // highlighting the line the viewer was on; the facade derives the index
    // from `currentUrl` against it.
    urls: urls,
    lines: lines,
    qualities: qualities,
    currentQuality: currentQuality,
    streamFacts: streamFacts,
  );
}

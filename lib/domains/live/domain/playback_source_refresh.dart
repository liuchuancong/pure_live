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

/// Preferred line first, platform order after it, duplicates dropped: the
/// kernel sweeps a refreshed plan from index 0.
List<String> refreshedLineOrder({required List<String> urls, required int preferredLineIndex}) {
  if (urls.isEmpty) return const <String>[];
  final preferred = urls[preferredLineIndex.clamp(0, urls.length - 1)];
  return List<String>.unmodifiable(<String>[preferred, ...urls.where((url) => url != preferred)]);
}

/// The refresh question for the playback a commit describes.
///
/// advanceLine stays false because the sweep walks the refreshed plan itself.
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

/// Whether a refresh answer may still replace the current lines.
///
/// The refresh is a round-trip, and anything that supersedes the playback can
/// happen while it is in flight.
bool canAdoptSourceRefresh({
  required bool disposed,
  required bool sameRoom,
  required bool revisionMoved,
  required PlaybackSourceRefreshResult result,
}) => !disposed && sameRoom && !revisionMoved && result.hasSources;

/// Candidate lines for a URL plan, shared by first open, engine switch and
/// refresh: without the declared container the engine has to probe for it.
///
/// [startAt] is the platform's declared play-start (a rotation room's
/// `video.start`), stamped into every candidate's metadata so the per-source
/// engine hook can keep those lines seekable while ordinary live lines — for
/// which a seek can only fail — are not. Only the first open carries it; engine
/// switch and refresh re-open at the live edge with no pending seek.
List<PlayerSource> livePlanSources(
  List<String> lines, {
  required Map<String, String> headers,
  required Map<String, LiveStreamFacts> streamFacts,
  Duration startAt = Duration.zero,
}) => List<PlayerSource>.unmodifiable(<PlayerSource>[
  for (final url in lines)
    PlayerSource(
      id: SourceId('live-$url'),
      uri: Uri.parse(url),
      type: SourceType.live,
      headers: SourceHeaders(headers),
      metadata: <String, Object?>{
        ...playbackStreamFormatMetadata(streamFacts[url]?.format.name),
        ...playbackSeekStartMetadata(startAt),
      },
    ),
]);

/// The single candidate for an owned input; see [customInputMetadataOf] for
/// why the metadata holds the factory rather than the source.
PlayerSource ownedPlanSource(OwnedPlaybackSource source, LiveRoom room) => PlayerSource(
  id: SourceId('owned-${room.identityKey}'),
  uri: Uri(scheme: 'owned', path: room.identityKey),
  type: SourceType.live,
  protocol: SourceProtocol.custom,
  metadata: <String, Object?>{kMediaKitCustomInputKey: customInputMetadataOf(source)},
);

/// The commit a refresh answer turns into.
///
/// Everything outside the kernel reads the playback through this: the line
/// selector, the engine switch, the floating window and a re-entered room.
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

  /// The same plan in sweep order. Empty for an owned input, which has no
  /// reusable URL to fall back to.
  final List<String> lines;
  final List<LivePlayQuality> qualities;
  final int currentQuality;
  final Map<String, LiveStreamFacts> streamFacts;
  final Object? ownedSource;
}

/// Turns a refresh answer into candidates and commit.
///
/// [intercept] is the same source wiring a first open goes through.
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
    // The commit reports the platform order and derives its index from
    // currentUrl, so the selector stays on the line being watched.
    urls: urls,
    lines: lines,
    qualities: qualities,
    currentQuality: currentQuality,
    streamFacts: streamFacts,
  );
}

import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';

import 'live_input_recipe.dart';

/// The stream URLs returned for one requested quality together with the
/// quality that the platform actually applied.
///
/// Some platforms advertise a quality in `accept_qn` but silently downgrade
/// anonymous requests. Returning only the URLs made the UI commit the tapped
/// label even though the media source was still a lower quality.
///
/// Adapters that can inspect the response should set [appliedQualityData]
/// to the server's actual stable quality identifier.
///
/// The default implementation keeps the requested
/// [LivePlayQuality.selectionId] for platforms whose URL response has no
/// separate acknowledgement.
class LivePlayUrlResolution {
  const LivePlayUrlResolution({
    required this.urls,
    this.appliedQualityData,
    this.qualityUnconfirmed = false,
    this.startAt = Duration.zero,
    this.declaredAspectRatio,
    this.streamFacts = const {},
  }) : sourceQueryPolicies = const {},
       inputRecipe = null;

  /// An owned input is a real source but has no exportable media URL.
  const LivePlayUrlResolution.owned({
    required LiveInputRecipe input,
    this.appliedQualityData,
    this.qualityUnconfirmed = false,
    this.startAt = Duration.zero,
    this.declaredAspectRatio,
  }) : inputRecipe = input,
       urls = const [],
       streamFacts = const {},
       sourceQueryPolicies = const {};

  LivePlayUrlResolution._({
    required this.urls,
    required this.sourceQueryPolicies,
    this.appliedQualityData,
    this.qualityUnconfirmed = false,
    this.startAt = Duration.zero,
    this.declaredAspectRatio,
    this.streamFacts = const {},
  }) : inputRecipe = null;

  final Duration startAt;

  final double? declaredAspectRatio;

  /// Policy-bearing sources are copied and validated together. Keys identify
  /// exact signed URLs, never only CDN positions or quality labels.
  factory LivePlayUrlResolution.withSourcePolicies({
    required List<String> urls,
    required Map<String, HlsSourceQueryPolicy> sourceQueryPolicies,
    Object? appliedQualityData,
    bool qualityUnconfirmed = false,
    Duration startAt = Duration.zero,
    double? declaredAspectRatio,
    Map<String, LiveStreamFacts> streamFacts = const {},
  }) {
    final normalized = normalizeResolvedPlayUrls(urls);
    final policies = <String, HlsSourceQueryPolicy>{};
    for (final entry in sourceQueryPolicies.entries) {
      final uri = Uri.tryParse(entry.key);
      if (!normalized.contains(entry.key) || uri == null || !entry.value.matchesSource(uri)) {
        throw const FormatException('Source query policy does not match resolved URLs');
      }
      policies[entry.key] = entry.value;
    }
    // A fact about a line that is not part of this resolution would silently
    // steer the wrong source, so undeclared and stale entries are dropped.
    final facts = <String, LiveStreamFacts>{
      for (final entry in streamFacts.entries)
        if (normalized.contains(entry.key)) entry.key: entry.value,
    };
    return LivePlayUrlResolution._(
      urls: normalized,
      sourceQueryPolicies: Map.unmodifiable(policies),
      appliedQualityData: appliedQualityData,
      qualityUnconfirmed: qualityUnconfirmed,
      startAt: startAt,
      declaredAspectRatio: declaredAspectRatio,
      streamFacts: Map.unmodifiable(facts),
    );
  }

  LivePlayUrlResolution normalized() => inputRecipe != null
      ? this
      : LivePlayUrlResolution.withSourcePolicies(
          urls: urls,
          sourceQueryPolicies: sourceQueryPolicies,
          appliedQualityData: appliedQualityData,
          qualityUnconfirmed: qualityUnconfirmed,
          startAt: startAt,
          declaredAspectRatio: declaredAspectRatio,
          streamFacts: streamFacts,
        );

  final List<String> urls;
  final LiveInputRecipe? inputRecipe;
  int get lineCount => inputRecipe == null ? urls.length : 1;
  bool get hasSources => lineCount > 0;
  final Object? appliedQualityData;
  final Map<String, HlsSourceQueryPolicy> sourceQueryPolicies;

  /// Per-line container/codec facts, keyed by the exact URL they describe.
  ///
  /// Playback turns these into the ingest decision (hand the URL over as-is,
  /// rewrite the manifest over loopback, or remux with FFmpeg) instead of
  /// branching per platform inside the player. Empty means "nothing declared",
  /// which keeps the probe and the host table as the fallback.
  final Map<String, LiveStreamFacts> streamFacts;

  /// The declared facts for [url], or null when the site did not declare any.
  LiveStreamFacts? factsFor(String url) => streamFacts[url];

  /// An adapter expected an acknowledgement but the response did not contain a
  /// usable one. False preserves the legacy contract for platforms with no ack.
  final bool qualityUnconfirmed;
}

/// Keeps request identity and display evidence separate for both playback and
/// recording. A server identifier outside a stale menu is also unconfirmed;
/// choosing the requested option as a cursor does not confirm its visible name.
LivePlayQuality resolveAppliedPlayQuality({
  required List<LivePlayQuality> qualities,
  required LivePlayQuality requested,
  required LivePlayUrlResolution resolution,
}) {
  final appliedId = resolution.appliedQualityData?.toString();
  LivePlayQuality? matched;
  if (appliedId != null) {
    for (final quality in qualities) {
      if (quality.selectionId.toString() == appliedId) {
        matched = quality;
        break;
      }
    }
  }
  return (matched ?? requested).withPlaybackUnconfirmed(
    resolution.qualityUnconfirmed || (appliedId != null && matched == null),
  );
}

/// Removes blank and duplicate lines while preserving platform priority.
///
/// Scheme validation remains adapter-specific because imported IPTV sources
/// may legitimately use non-HTTP protocols.
List<String> normalizeResolvedPlayUrls(Iterable<String> urls) {
  final result = <String>[];
  final seen = <String>{};

  for (final rawUrl in urls) {
    final url = rawUrl.trim();

    if (url.isNotEmpty && seen.add(url)) {
      result.add(url);
    }
  }

  return List<String>.unmodifiable(result);
}

/// Optional capability for platforms whose play API reports the quality that
/// was actually applied.
///
/// Use `resolvePlayUrlsRaw` intentionally here because `resolvePlayUrls` is
/// the unified extension API exposed by [LiveSite].
///
/// Most adapters can continue using [LiveSite.getPlayUrls].
/// Bilibili can implement this contract because guest requests may be
/// downgraded even when a higher `qn` was requested.
abstract interface class LivePlayUrlResolver {
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom liveroom, required LivePlayQuality quality});
}

/// Optional cursor contract for adapters that must make a separate network
/// request for every CDN line.
///
/// The ordinary playback API intentionally resolves all lines for an on-screen
/// selector. Recording needs a different latency contract: obtain only the one
/// line used by the current FFmpeg attempt and request the next line only after
/// failure. Implementations return an empty URL list when [lineIndex] is beyond
/// the platform's advertised lines.
abstract interface class LivePlayUrlCursorResolver {
  Future<LivePlayUrlResolution> resolvePlayUrlAtRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
    required int lineIndex,
  });
}

/// Optional recovery contract for signed platforms whose room metadata and
/// playback URLs have a shorter lifetime than the visible room session.
///
/// Implementations must reacquire every identity/token/room field needed for
/// a new connection. Returning the same cached URL list defeats the purpose of
/// this contract and can reopen an already-expired source indefinitely.
abstract interface class LivePlayRecoveryResolver {
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  });
}

/// Optional lease metadata for short-lived signed playback URLs.
///
/// A player can refresh the token before this timestamp rather than waiting for
/// the server to reject a later reconnect. Windows can use its first-frame
/// gated replacement transaction for sources whose transport lease is shorter
/// than the signed URL; other platforms may cache the lease for recovery.
/// Returning `null` keeps ordinary long-lived sources on the error-driven path.
abstract interface class LivePlayLeaseMetadata {
  DateTime? getPlayUrlRefreshAt(String url, {DateTime? now});

  /// The final instant at which a prefetched URL can start a new connection.
  ///
  /// This is deliberately separate from [getPlayUrlRefreshAt]. A source
  /// prefetched shortly before the active connection fails remains usable until
  /// this deadline, while an expired cache entry must be discarded.
  DateTime? getPlayUrlInvalidAt(String url, {DateTime? now});
}

/// Container of one play line.
///
/// Mirrors the upstream 4.x `StreamFormat`: `other` is a single HTTP(S) response
/// whose container is only told by its first bytes (IPTV MPEG-TS, udpxy, an FLV
/// or MP4 line without a matching path suffix).
enum LiveStreamFormat { flv, hls, other }

/// What a site knows about one of its own play lines.
///
/// [codec] is `avc` or `hevc` when the platform says so. [unresolvedChildren]
/// marks an HLS playlist whose children a native resolver cannot use as they
/// stand — either bare names (`media.95.mp4`) or absolute paths
/// (`/tc.livehls/...`). Both fail the same way: a reader that no longer knows the
/// manifest URL resolves them against itself and hands the demuxer a Windows
/// path. Which of the two it is changes nothing downstream, so one bool covers
/// both.
typedef LiveStreamFacts = ({LiveStreamFormat format, String? codec, bool unresolvedChildren});

/// Optional per-line stream declaration for sites on the default resolve path.
///
/// Playback decides "hand the URL over, rewrite the manifest over loopback, or
/// remux with FFmpeg" from these facts instead of from a per-platform branch in
/// the player. Sites that build their own [LivePlayUrlResolution] put the facts
/// on it directly; sites on the default path implement this instead. Returning
/// an empty map keeps the probe and the host table as the fallback.
abstract interface class LivePlayStreamFacts {
  Map<String, LiveStreamFacts> declareStreamFacts(List<String> urls);
}

class LiveSite {
  String id = "";
  String name = "";

  LiveDanmaku getDanmaku() {
    return EmptyDanmaku();
  }

  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    return Future.value(<LiveCategory>[]);
  }

  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveAnchorItem>[]);
  }

  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  /// Room-detail fetch. The [room] carries the request identity (platform +
  /// roomId) and any locally known metadata.
  ///
  /// Adapters MAY reuse fields the room already carries (cached link, resolved
  /// ids, avatar/cover) and pad partial responses from it instead of
  /// re-deriving everything from the identity. Callers that only hold the
  /// identity (deep links, persisted history, recorder tasks restored from
  /// disk) pass a `LiveRoom(roomId: ..., platform: ...)` stub.
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    final roomId = liveroom.roomId;
    final platform = liveroom.platform;
    if (roomId == null || roomId.isEmpty || platform == null || platform.isEmpty) {
      return liveroom;
    }
    return Future.value(
      LiveRoom(
        cover: '',
        watching: '',
        roomId: roomId,
        // The base implementation has no platform evidence. Treat it as
        // pending/unknown instead of fabricating an authoritative offline
        // response; concrete adapters must explicitly report offline/banned.
        status: null,
        platform: platform,
        liveStatus: LiveStatus.unknown,
        title: '',
        link: '',
        avatar: '',
        nick: '',
        isRecord: false,
      ),
    );
  }

  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    return Future.value(<LivePlayQuality>[]);
  }

  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    return Future.value(<String>[]);
  }

  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required LiveRoom liveroom}) async {
    return Future.value([]);
  }
}

/// Unified playback URL resolution.
///
/// Capability-aware adapters can return the quality actually applied by
/// the server through [LivePlayUrlResolver.resolvePlayUrlsRaw].
///
/// Other adapters continue using [LiveSite.getPlayUrls] and assume that
/// the requested quality was applied.
extension LiveSitePlayUrlResolution on LiveSite {
  Future<LivePlayUrlResolution> resolvePlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    final site = this;

    if (site is LivePlayUrlResolver) {
      final resolver = site as LivePlayUrlResolver;

      final resolution = await resolver.resolvePlayUrlsRaw(liveroom: liveroom, quality: quality);

      return resolution.normalized();
    }

    final urls = normalizeResolvedPlayUrls(await getPlayUrls(liveroom: liveroom, quality: quality));
    return LivePlayUrlResolution(
      urls: urls,
      appliedQualityData: quality.selectionId,
      declaredAspectRatio: quality.declaredAspectRatio,
      streamFacts: site is LivePlayStreamFacts
          ? (site as LivePlayStreamFacts).declareStreamFacts(urls)
          : const <String, LiveStreamFacts>{},
    );
  }

  Future<LivePlayUrlResolution> resolvePlayUrlsForRecovery({
    required LiveRoom liveroom,
    required LivePlayQuality quality,
  }) async {
    final site = this;
    if (site is LivePlayRecoveryResolver) {
      final resolution = await (site as LivePlayRecoveryResolver).resolvePlayUrlsForRecoveryRaw(
        liveroom: liveroom,
        quality: quality,
      );
      return resolution.normalized();
    }
    return resolvePlayUrls(liveroom: liveroom, quality: quality);
  }
}

/// Optional fast metadata path used by favourites/background verification.
///
/// Entering a room needs playback URLs, signing material and chat credentials;
/// refreshing a card needs only status/title/cover/audience metadata.
///
/// Keeping this as a separate capability lets platforms skip those extra
/// calls without changing the full room-entry contract for every site
/// implementation.
abstract interface class LiveSiteRoomRefresher {
  Future<LiveRoom> getRoomDetailForRefresh(LiveRoom liveroom);
}

/// Strict, playback-complete room lookup used before a recording starts.
///
/// The ordinary [LiveSite.getRoomDetail] contract is UI-oriented. Several
/// adapters deliberately turn transport/shape errors into an offline-looking
/// fallback room so an already mounted player can keep its last metadata.
/// That behaviour is useful for presentation, but it is unsafe for recording:
/// one temporary metadata error was interpreted as an authoritative offline
/// state and the recorder stopped before it ever asked for a stream URL.
///
/// [LiveSiteRoomRefresher] is not a substitute for this capability. Refresh
/// implementations may intentionally omit signed playback descriptors to keep
/// favourite-card refreshes cheap. Implementations of this interface must:
///
/// * propagate transport and response-shape failures;
/// * return an explicit offline/banned room only when the platform said so;
/// * retain every field required by [LiveSite.getPlayQualites].
abstract interface class LiveSiteRecordRoomResolver {
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom);
}

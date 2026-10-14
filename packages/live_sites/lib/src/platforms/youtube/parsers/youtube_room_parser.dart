import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_endpoints.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_json.dart';

const String _site = 'youtube';

/// A room read from a paired `player` (ANDROID) and `next` (WEB) answer: the
/// `room` itself, the broadcast's `videoId`, the streaming handles the playback
/// provider re-reads (`hlsManifestUrl`, `dashManifestUrl`, the progressive
/// `formats`) and the comment feed's join parameters (`continuation`,
/// `timeoutMs`, `isReplay`). The stream and danmaku handles the site builds
/// from these ride in [LiveRoom.runtime].
typedef YoutubeRoomParse = ({
  LiveRoom room,
  String videoId,
  String? hlsManifestUrl,
  String? dashManifestUrl,
  List<Map<String, dynamic>> formats,
  String continuation,
  int timeoutMs,
  bool isReplay,
});

/// A target a `navigation/resolve_url` answer names: a `videoId` (a live or a
/// watch page), a `browseId` (a channel) or neither.
typedef YoutubeResolved = ({String? videoId, String? browseId});

/// Pure parsing of InnerTube room, directory and search answers. Each function
/// takes response text (or a decoded node) and returns shared models, or
/// throws a [YouTubeFailure]; stream assembly is in `youtube_play_parser.dart`.
abstract final class YoutubeRoomParser {
  /// The room from a `player` body ([playerBody]) and a `next` body
  /// ([nextBody]) of the broadcast the caller asked for by [requestedId] (a
  /// video id or a channel id).
  ///
  /// Live is decided by `videoDetails.isLive` or
  /// `microformat…liveBroadcastDetails.isLiveNow` while the playability status
  /// is not `LIVE_STREAM_OFFLINE`. The identity is the broadcaster's channel id
  /// (`externalChannelId`); the comment feed's first continuation, its poll
  /// interval and its replay flag come out of the `next` `liveChatRenderer`.
  static YoutubeRoomParse room(String playerBody, String nextBody, {required String requestedId}) {
    final player = jsonObject(decodeJson(playerBody));
    if (player == null) {
      throw YouTubeFailure(YoutubeFailureKind.apiChanged, 'player: not a JSON object (${jsonSnippet(playerBody)})');
    }
    final status = label(fields(player['playabilityStatus'])['status']);
    _checkPlayability(status, playerBody);
    final details = fields(player['videoDetails']);
    final videoId = jsonString(details['videoId']) ?? requestedId.trim();
    final liveDetails = fields(findFirst(player['microformat'], 'liveBroadcastDetails'));
    final channelId = jsonString(details['externalChannelId']) ?? jsonString(details['channelId']) ?? '';
    final author = label(details['author']);
    final title = label(details['title']);
    final liveNow = truthy(details['isLive']) || truthy(liveDetails['isLiveNow']);
    final isLive = liveNow && status != 'LIVE_STREAM_OFFLINE';
    final next = decodeJson(nextBody);
    final viewers = _watchers(next);
    final (:continuation, :timeoutMs, :isReplay) = _firstChat(next);
    final streaming = fields(player['streamingData']);
    final room = LiveRoom.normalized(
      platform: _site,
      roomId: channelId.isNotEmpty ? channelId : videoId,
      content: RoomContent(title: title, coverUrl: lastThumbnail(details['thumbnail'])),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: channelId,
        name: author,
        profileUrl: channelId.startsWith('UC') ? '${YoutubeEndpoints.origin}/channel/$channelId' : null,
      ),
      area: LiveArea.normalized(platform: _site),
      audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(
        liveStatus: isLive ? LiveStatus.live : LiveStatus.offline,
        restriction: isLive ? LiveRestriction.none : null,
        startedAt: _isoTime(liveDetails['startTimestamp']),
      ),
      links: RoomLinks(webUrl: YoutubeEndpoints.watchUrl(videoId)),
    );
    return (
      room: room,
      videoId: videoId,
      hlsManifestUrl: jsonString(streaming['hlsManifestUrl']),
      dashManifestUrl: jsonString(streaming['dashManifestUrl']),
      formats: [for (final format in jsonList(streaming['formats'])) ?jsonObject(format)],
      continuation: continuation,
      timeoutMs: timeoutMs,
      isReplay: isReplay,
    );
  }

  /// One directory or search card from a `videoRenderer` (or the `live`
  /// variant): a live room keyed by its channel id, its LIVE badge or a
  /// "watching" line deciding the status. A renderer without a `videoId` is
  /// not a card (null).
  static LiveRoom? card(Object? renderer) {
    final item = jsonObject(renderer);
    final videoId = jsonString(item?['videoId']);
    if (item == null || videoId == null) return null;
    final byline = findFirst(item, 'browseEndpoint');
    final channelId = jsonString(fields(byline)['browseId']) ?? '';
    final name = label(item['title']);
    final author = label(item['ownerText'] ?? item['shortBylineText'] ?? item['longBylineText']);
    final watching = _renderWatchers(item);
    final live = _hasLiveBadge(item) || watching != null;
    return LiveRoom.normalized(
      platform: _site,
      roomId: channelId.isNotEmpty ? channelId : videoId,
      content: RoomContent(title: name, coverUrl: lastThumbnail(item['thumbnail'])),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: channelId,
        name: author,
        profileUrl: channelId.startsWith('UC') ? '${YoutubeEndpoints.origin}/channel/$channelId' : null,
      ),
      audience: RoomAudience(onlineViewers: watching, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(
        liveStatus: live ? LiveStatus.live : LiveStatus.offline,
        restriction: live ? LiveRestriction.none : null,
      ),
      links: RoomLinks(webUrl: YoutubeEndpoints.watchUrl(videoId)),
    );
  }

  /// Every `videoRenderer` under [node], in document order (search and browse
  /// wrap rows in `richItemRenderer`/`itemSectionRenderer`/`videoRenderer`
  /// nests of varying depth, so the renderers are collected by name).
  static List<Object?> videoRenderers(Object? node) {
    final found = <Object?>[];
    _collect(node, 'videoRenderer', found);
    return found;
  }

  /// The rooms of a `search` or `browse` page, deduped by identity.
  static List<LiveRoom> rooms(Object? node) {
    final seen = <String>{};
    return [
      for (final renderer in videoRenderers(node))
        if (card(renderer) case final room? when seen.add(room.identityKey)) room,
    ];
  }

  /// The last `continuationItemRenderer` token of a page — the "load more"
  /// command the next page is asked with — or null when the page has no
  /// continuation.
  static String? nextContinuation(Object? node) {
    final tokens = <Object?>[];
    _collect(node, 'continuationCommand', tokens);
    for (final token in tokens.reversed) {
      final value = jsonString(fields(token)['token']);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// The video id or browse id a `navigation/resolve_url` answer names: the
  /// `endpoint`'s `watchEndpoint.videoId` or `browseEndpoint.browseId` (a
  /// `browseId` alone means a channel with no live broadcast resolved).
  static YoutubeResolved resolveUrl(String body) {
    final root = jsonObject(decodeJson(body));
    if (root == null) {
      throw YouTubeFailure(YoutubeFailureKind.apiChanged, 'resolve_url: not a JSON object (${jsonSnippet(body)})');
    }
    final endpoint = fields(root['endpoint']);
    final watch = fields(endpoint['watchEndpoint']);
    final browse = fields(endpoint['browseEndpoint']);
    final videoId = jsonString(watch['videoId']);
    final browseId = jsonString(browse['browseId']);
    if (videoId == null && browseId == null) {
      throw const YouTubeFailure(YoutubeFailureKind.notFound, 'resolve_url: no watch or browse endpoint');
    }
    return (videoId: videoId, browseId: browseId);
  }

  /// The `"INNERTUBE_API_KEY":"…"` scraped from a watch page, or the public
  /// fallback when the page names none.
  static String apiKeyFromPage(String html) => YoutubeEndpoints.apiKeyPattern.firstMatch(html)?.group(1) ?? '';

  // Helpers -------------------------------------------------------------------

  /// The playability status mapped to a failure, except the two ordinary
  /// states `OK` and `LIVE_STREAM_OFFLINE` (the latter is simply not live).
  static void _checkPlayability(String status, String body) {
    switch (status) {
      case '':
      case 'OK':
      case 'LIVE_STREAM_OFFLINE':
        return;
      case 'LOGIN_REQUIRED':
        throw YouTubeFailure(YoutubeFailureKind.riskControl, 'player: LOGIN_REQUIRED (${jsonSnippet(body)})');
      case 'ERROR':
        throw const YouTubeFailure(YoutubeFailureKind.notFound, 'player: ERROR playability');
      default:
        throw YouTubeFailure(YoutubeFailureKind.streamUnavailable, 'player: $status playability');
    }
  }

  /// The current concurrent viewers of a `next` page, from the primary info
  /// view count (`videoViewCount.viewCountText`); null when it names none.
  static int? _watchers(Object? next) {
    final primary = findFirst(next, 'videoPrimaryInfoRenderer');
    if (primary == null) return null;
    return _viewers(label(findFirst(primary, 'viewCountText')));
  }

  /// YouTube's "N watching" figure (English `K`/`M` suffixes): the trailing
  /// word is stripped before parsing so its `w` is never read as 万. Null when
  /// the text names no number.
  static int? _viewers(String raw) => parseAudienceNumberOrNull(raw.toLowerCase().replaceAll('watching', '').trim());

  /// The first live-chat continuation of a `next` `liveChatRenderer`: the
  /// join token, the server's poll interval (`timeoutMs`, 0 when absent) and
  /// the replay flag.
  static ({String continuation, int timeoutMs, bool isReplay}) _firstChat(Object? next) {
    final renderer = jsonObject(findFirst(next, 'liveChatRenderer'));
    if (renderer == null) return (continuation: '', timeoutMs: 0, isReplay: false);
    final isReplay = truthy(renderer['isReplay']);
    for (final entry in jsonList(renderer['continuations'])) {
      final map = jsonObject(entry);
      if (map == null) continue;
      for (final value in map.values) {
        final data = jsonObject(value);
        if (data == null) continue;
        final continuation = jsonString(data['continuation']);
        if (continuation == null || continuation.isEmpty) continue;
        return (continuation: continuation, timeoutMs: jsonInt(data['timeoutMs']) ?? 0, isReplay: isReplay);
      }
    }
    return (continuation: '', timeoutMs: 0, isReplay: isReplay);
  }

  /// The "N watching" count of a search or directory card; null when the row
  /// is not stated as being watched live.
  static int? _renderWatchers(Map<String, dynamic> item) {
    final text = label(item['viewCountText'] ?? item['shortViewCountText']);
    if (text.toLowerCase().contains('watching')) return _viewers(text);
    return null;
  }

  /// Whether a card carries a `LIVE` badge (search's live rows do).
  static bool _hasLiveBadge(Map<String, dynamic> item) {
    for (final badge in jsonList(item['badges'])) {
      if (label(findFirst(badge, 'metadataBadgeRenderer')).toUpperCase() == 'LIVE') return true;
    }
    for (final overlay in jsonList(item['thumbnailOverlays'])) {
      if (findFirst(overlay, 'thumbnailOverlayTimeStatusRenderer') != null) continue;
      if (label(findFirst(overlay, 'accessibility')).toUpperCase().contains('LIVE')) return true;
    }
    return false;
  }

  /// An ISO-8601 timestamp parsed to a `DateTime`; null when it is absent or
  /// malformed.
  static DateTime? _isoTime(Object? value) => DateTime.tryParse(value?.toString().trim() ?? '');

  /// Appends every value stored under [key] anywhere in [node] to [sink].
  static void _collect(Object? node, String key, List<Object?> sink) {
    if (node is Map) {
      final direct = node[key];
      if (direct != null) sink.add(direct);
      for (final value in node.values) {
        _collect(value, key, sink);
      }
    } else if (node is List) {
      for (final value in node) {
        _collect(value, key, sink);
      }
    }
  }
}

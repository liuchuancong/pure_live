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
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_json.dart';

const String _site = 'twitch';

/// A category tag of `SearchCategoryTags`.
typedef TwitchTag = ({String id, String name});

/// The `PlaybackAccessToken` of a channel: the token `value` and its
/// `signature`, which usher receives as `token` and `sig`.
typedef TwitchAccessToken = ({String value, String signature});

/// Pure parsing of Twitch's GraphQL answers: the catalog, the lists, the
/// search page and the room detail (stream assembly is in the play parser).
/// Each function takes a decoded answer and returns
/// shared models or throws a [TwitchFailure].
///
/// Twitch answers numbers as strings and leaves whole objects out; the loose
/// accessors in [TwitchJson] read both as empty rather than failing.
abstract final class TwitchRoomParser {
  /// `SearchCategoryTags`: every tag in the server's order, named by `tagName`
  /// (`localizedName` only when that is empty).
  static List<TwitchTag> tags(Object? decoded) {
    final list = TwitchJson.data(decoded, 'SearchCategoryTags')['searchCategoryTags'];
    if (list is! List) throw const TwitchFailure(TwitchFailureKind.apiChanged, 'SearchCategoryTags: no list');
    return [
      for (final tag in list)
        if (TwitchJson.object(tag) case final item?)
          if (TwitchJson.stringOf(item['id']) case final id?)
            (id: id, name: TwitchJson.stringOf(item['tagName']) ?? TwitchJson.stringOf(item['localizedName']) ?? ''),
    ];
  }

  /// One `BrowsePage_AllDirectories` envelope: the directories of [tag] as
  /// areas (the game id, the slug `DirectoryPage_Game` needs, the box art),
  /// and the cursor of the next page when `pageInfo` says there is one. An
  /// envelope with errors and no data is a page without areas.
  static ({List<LiveArea> areas, String? cursor}) directories(Object? envelope, TwitchTag tag) {
    final data = TwitchJson.envelope(envelope, 'BrowsePage_AllDirectories').data;
    final connection = TwitchJson.connection(data?['directoriesWithTags']);
    final areas = [
      for (final edge in connection.edges)
        if (_node(edge) case final game?)
          if ((TwitchJson.stringOf(game['id']), TwitchJson.stringOf(game['slug'])) case (
            final String id,
            final String slug,
          ))
            LiveArea.normalized(
              platform: _site,
              areaId: id,
              areaName: gameName(game),
              parentAreaId: tag.id,
              parentAreaName: tag.name,
              iconUrl: TwitchJson.textOf(game['avatarURL']),
              shortName: slug,
            ),
    ];
    return (areas: areas, cursor: TwitchJson.nextCursor(connection));
  }

  /// `DirectoryPage_Game`: the streams of a directory as cards, and the
  /// cursor of the next page. A stream is live, or a replay when it is a
  /// rerun. The answer names no start time or restriction. An unknown
  /// directory (`game == null`) is not-found.
  static ({List<LiveRoom> rooms, String? cursor}) gameStreams(
    Object? decoded, {
    required DateTime now,
    String slug = '',
  }) {
    final game = TwitchJson.object(TwitchJson.data(decoded, 'DirectoryPage_Game')['game']);
    if (game == null) {
      throw TwitchFailure(TwitchFailureKind.notFound, 'DirectoryPage_Game: no directory $slug'.trim());
    }
    final connection = TwitchJson.connection(game['streams']);
    final rooms = [for (final edge in connection.edges) ?_streamCard(_node(edge), now: now)];
    return (rooms: rooms, cursor: TwitchJson.nextCursor(connection));
  }

  /// The raw `streams` query: the site's busiest streams as cards (the
  /// recommendations), each with its start time and restriction, and the
  /// cursor of the next page.
  static ({List<LiveRoom> rooms, String? cursor}) streams(Object? decoded, {required DateTime now}) {
    final connection = TwitchJson.connection(TwitchJson.data(decoded, 'streams')['streams']);
    final rooms = [for (final edge in connection.edges) ?_streamCard(_node(edge), now: now)];
    return (rooms: rooms, cursor: TwitchJson.nextCursor(connection));
  }

  /// `SearchResultsPage_SearchResults`: channels, live or not, as cards, and
  /// the channel index's cursor (none when the page named no channels). A
  /// stream's start time is its broadcast's `startedAt`, and only when
  /// `lastBroadcast.id` is the stream on air now. No restriction is given.
  static ({List<LiveRoom> rooms, String? cursor}) searchPage(Object? decoded, {required DateTime now}) {
    final search = TwitchJson.object(TwitchJson.data(decoded, 'SearchResultsPage_SearchResults')['searchFor']);
    final channels = TwitchJson.object(search?['channels']);
    if (channels == null) return (rooms: const [], cursor: null);
    final rooms = <LiveRoom>[];
    for (final edge in TwitchJson.list(channels['edges'])) {
      final item = TwitchJson.object(TwitchJson.object(edge)?['item']);
      final login = TwitchJson.stringOf(item?['login']);
      if (item == null || login == null) continue;
      final stream = TwitchJson.object(item['stream']);
      final broadcast = TwitchJson.object(item['lastBroadcast']);
      final onAirNow =
          stream != null &&
          TwitchJson.stringOf(stream['id']) != null &&
          TwitchJson.stringOf(stream['id']) == TwitchJson.stringOf(broadcast?['id']);
      final viewers = TwitchJson.intOf(stream?['viewersCount'] ?? 0) ?? 0;
      final name = TwitchJson.textOf(item['displayName']);
      final avatar = TwitchJson.textOf(item['profileImageURL']);
      rooms.add(
        LiveRoom.normalized(
          platform: _site,
          roomId: login,
          content: RoomContent(
            title: TwitchJson.textOf(TwitchJson.object(item['broadcastSettings'])?['title']),
            coverUrl: _cover(TwitchJson.textOf(stream?['previewImageURL']), now),
          ),
          anchor: LiveAnchor.normalized(platform: _site, anchorId: login.toLowerCase(), name: name, avatarUrl: avatar),
          area: _area(TwitchJson.object(stream?['game'])),
          audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
          broadcast: RoomBroadcast(
            liveStatus: stream == null
                ? LiveStatus.offline
                : _isRerun(stream)
                ? LiveStatus.replay
                : LiveStatus.live,
            startedAt: onAirNow ? TwitchJson.time(broadcast?['startedAt']) : null,
          ),
          links: RoomLinks(webUrl: TwitchEndpoints.roomPageUrl(login)),
        ),
      );
    }
    return (rooms: rooms, cursor: rooms.isEmpty ? null : TwitchJson.stringOf(channels['cursor']));
  }

  /// The raw `user` query: the room as the user asked for it ([requestedId];
  /// a follow keeps its identity). The requests use the lower-cased login,
  /// the room keeps the id as asked. A stream of type `live` is live, a
  /// rerun a replay, any other type or none offline. While a stream is on
  /// air the room has the preview as cover (else the profile image) with
  /// 3.x's `?&t=<Unix seconds>`, the game's localized name as area, its
  /// start time and its restriction. The channel's description is the
  /// introduction. `user == null` is not-found; another login in the answer
  /// is api-changed (the answer is not the channel asked for).
  static LiveRoom roomDetail(Object? decoded, {required String requestedId, required DateTime now}) {
    final id = requestedId.trim();
    final login = id.toLowerCase();
    final user = TwitchJson.object(TwitchJson.data(decoded, 'user')['user']);
    if (user == null) throw TwitchFailure(TwitchFailureKind.notFound, 'user: no channel $login');
    final answered = TwitchJson.stringOf(user['login'])?.toLowerCase();
    if (answered != login) {
      throw TwitchFailure(TwitchFailureKind.apiChanged, 'user: answered $answered for $login');
    }
    final stream = TwitchJson.object(user['stream']);
    final status = switch (TwitchJson.stringOf(stream?['type'])) {
      'live' => LiveStatus.live,
      'rerun' => LiveStatus.replay,
      _ => LiveStatus.offline,
    };
    final onAir = status != LiveStatus.offline;
    final viewers = onAir ? (TwitchJson.intOf(stream!['viewersCount'] ?? 0) ?? 0) : 0;
    final profile = TwitchJson.textOf(user['profileImageURL']);
    final preview = onAir ? _cover(TwitchJson.textOf(stream!['previewImageURL']), now) : '';
    final description = TwitchJson.textOf(user['description']).trim();
    final game = TwitchJson.object(stream?['game']);
    return LiveRoom.normalized(
      platform: _site,
      roomId: id,
      content: RoomContent(
        title: TwitchJson.textOf(TwitchJson.object(user['lastBroadcast'])?['title']),
        coverUrl: preview.isEmpty ? profile : preview,
        introduction: description,
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: login,
        name: TwitchJson.textOf(user['displayName']),
        avatarUrl: profile,
        introduction: description,
        liveStatus: status,
      ),
      area: _area(game),
      audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(
        liveStatus: status,
        startedAt: onAir ? TwitchJson.time(stream!['createdAt']) : null,
        restriction: onAir ? restriction(stream) : null,
      ),
      links: RoomLinks(webUrl: TwitchEndpoints.roomPageUrl(id)),
    );
  }

  /// The restriction of a stream node that was asked for its `restriction`
  /// (the raw `user` and `streams` queries do): none when the key is present
  /// and null, subscribers-only for a type naming `SUB` (`SUB_ONLY_LIVE`),
  /// unplayable for another kind (what it asks of the viewer is unknown).
  /// Null when the node has no such key — the persisted list queries do not
  /// ask for it.
  static LiveRestriction? restriction(Map<String, dynamic>? stream) {
    if (stream == null || !stream.containsKey('restriction')) return null;
    final value = stream['restriction'];
    if (value == null) return LiveRestriction.none;
    final type = '${TwitchJson.object(value)?['type'] ?? ''}'.toUpperCase();
    return type.contains('SUB') ? LiveRestriction.subscribersOnly : LiveRestriction.unplayable;
  }

  /// `PlaybackAccessToken`: a null token is an unknown channel; the token's
  /// own `claims` say whether this viewer may watch (`geo` reasons are
  /// region-blocked, others need a login).
  static TwitchAccessToken accessToken(Object? decoded, {required String login}) {
    final token = TwitchJson.object(TwitchJson.data(decoded, 'PlaybackAccessToken')['streamPlaybackAccessToken']);
    if (token == null) throw TwitchFailure(TwitchFailureKind.notFound, 'PlaybackAccessToken: no channel $login');
    final value = TwitchJson.stringOf(token['value']);
    final signature = TwitchJson.stringOf(token['signature']);
    if (value == null || signature == null) {
      throw const TwitchFailure(TwitchFailureKind.apiChanged, 'PlaybackAccessToken: incomplete');
    }
    final authorization = TwitchJson.object(TwitchJson.object(TwitchJson.tryDecode(value))?['authorization']);
    if (authorization?['forbidden'] == true) {
      final reason = TwitchJson.stringOf(authorization?['reason']) ?? '';
      if (reason.toLowerCase().contains('geo')) {
        throw TwitchFailure(TwitchFailureKind.regionBlocked, 'PlaybackAccessToken: $reason');
      }
      throw TwitchFailure(TwitchFailureKind.needsLogin, 'PlaybackAccessToken: $reason');
    }
    return (value: value, signature: signature);
  }

  /// The channel login of a room id: trimmed, and null when it is not a
  /// login (`[a-z0-9_]{1,25}`, case-insensitive).
  static String? loginOf(String roomId) {
    final login = roomId.trim().toLowerCase();
    return TwitchEndpoints.loginPattern.hasMatch(login) ? login : null;
  }

  // Helpers -------------------------------------------------------------------

  /// One stream node of a list as a card: the broadcaster's login as the
  /// room, its display name (the login without one), live or a rerun's
  /// replay, the preview as cover, the game's localized name as area. The
  /// start time and restriction come with the raw `streams` query only.
  /// Null without a broadcaster login.
  static LiveRoom? _streamCard(Map<String, dynamic>? node, {required DateTime now}) {
    final broadcaster = TwitchJson.object(node?['broadcaster']);
    final login = TwitchJson.stringOf(broadcaster?['login']);
    if (node == null || broadcaster == null || login == null) return null;
    final game = TwitchJson.object(node['game']);
    final viewers = TwitchJson.intOf(node['viewersCount'] ?? 0) ?? 0;
    final name = TwitchJson.stringOf(broadcaster['displayName']);
    return LiveRoom.normalized(
      platform: _site,
      roomId: login,
      content: RoomContent(
        title: TwitchJson.textOf(node['title']),
        coverUrl: _cover(TwitchJson.textOf(node['previewImageURL']), now),
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: login.toLowerCase(),
        name: name == null || name.isEmpty ? login : name,
        avatarUrl: TwitchJson.textOf(broadcaster['profileImageURL']),
      ),
      area: _area(game),
      audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(
        liveStatus: _isRerun(node) ? LiveStatus.replay : LiveStatus.live,
        startedAt: TwitchJson.time(node['createdAt']),
        restriction: restriction(node),
      ),
      links: RoomLinks(webUrl: TwitchEndpoints.roomPageUrl(login)),
    );
  }

  /// An edge's `node`, or the map itself when it already is one (the list
  /// parsers hand over both shapes).
  static Map<String, dynamic>? _node(Map<String, dynamic> edge) => TwitchJson.object(edge['node']) ?? edge;

  /// A game's (directory's) name as the client's language names it:
  /// `displayName`, its `name` when there is none.
  static String gameName(Map<String, dynamic> game) {
    final display = TwitchJson.textOf(game['displayName']);
    return display.isNotEmpty ? display : TwitchJson.textOf(game['name']);
  }

  /// The area a stream node names, with the game's id and slug when the node
  /// carries them (the persisted list queries name only the display name).
  static LiveArea? _area(Map<String, dynamic>? game) {
    if (game == null) return null;
    final name = gameName(game);
    if (name.isEmpty) return null;
    return LiveArea.normalized(
      platform: _site,
      areaId: TwitchJson.textOf(game['id']),
      areaName: name,
      shortName: TwitchJson.textOf(game['slug']),
    );
  }

  /// Whether a stream node is a rerun (Twitch's replay of a past broadcast).
  static bool _isRerun(Map<String, dynamic> stream) => stream['type'] == 'rerun';

  /// A stream preview with 3.x's `?&t=<Unix seconds>`, so a refresh fetches
  /// the current frame; empty without a preview.
  static String _cover(String url, DateTime now) =>
      url.trim().isEmpty ? '' : '$url?&t=${now.millisecondsSinceEpoch ~/ 1000}';
}

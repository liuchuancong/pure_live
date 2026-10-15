import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _site = 'kick';

/// A channel answer (`api/v2/channels/<slug>`): the room and what entering
/// the channel costs nothing to learn beside it.
final class KickChannel {
  /// Wraps one parsed channel answer.
  const KickChannel({required this.room, required this.channelId, this.chatroomId, this.master});

  /// The room, without stream data or danmaku arguments.
  final LiveRoom room;

  /// The channel's numeric id (`channel.<id>` carries its broadcast events).
  final int channelId;

  /// `chatroom.id`: the Pusher channel `chatrooms.<id>.v2` carries the chat.
  /// The chatroom id is not the channel id (`xqcisoffline`: channel 101691,
  /// chatroom 101689), so it is read from the answer and never guessed.
  final int? chatroomId;

  /// The signed IVS master playlist when the channel is live, else null.
  final Uri? master;

  @override
  String toString() => 'KickChannel(${room.roomId}, chatroom $chatroomId, channel $channelId)';
}

/// One of Kick's top-level categories (`api/v1/categories`).
typedef KickMainCategory = ({String slug, String name});

/// Pure parsing of Kick's public web API: the channel answer, the category
/// catalog, the live directory and the search answer. Each function takes a
/// response text and status and returns shared models or throws a
/// [KickFailure].
///
/// A bad row is left out; only an answer without any usable row fails
/// (api-changed), so a change of format is never shown as an empty list.
abstract final class KickRoomParser {
  /// The channel answer for [requestedSlug]: the room and, when live, the
  /// signed master playlist. A slug Kick does not know is not-found (HTTP
  /// 404); an answer for another channel is api-changed. The room id is the
  /// lower-cased slug (Kick finds a channel in any case), the anchor id the
  /// stringified channel id.
  static KickChannel channel(String body, {required String requestedSlug, int status = 200}) {
    if (status == 404) throw KickFailure(KickFailureKind.notFound, 'no channel "$requestedSlug"');
    checkStatus(status, body, 'channel');
    final root = jsonObject(decodeJson(body));
    final slug = KickEndpoints.normalizeSlug(jsonString(root?['slug']) ?? '');
    final channelId = jsonInt(root?['id']);
    final user = jsonObject(root?['user']);
    if (root == null || slug == null || channelId == null || channelId <= 0 || user == null) {
      throw KickFailure(KickFailureKind.apiChanged, 'channel: no slug, id or user (${jsonSnippet(body)})');
    }
    if (slug != requestedSlug.trim().toLowerCase()) {
      throw KickFailure(KickFailureKind.apiChanged, 'channel: asked for "$requestedSlug", answered "$slug"');
    }
    final banned = root['is_banned'] == true;
    final stream = jsonObject(root['livestream']);
    final live = !banned && stream != null && stream['is_live'] == true;
    final viewers = live ? jsonCount(stream['viewer_count']) : null;
    final followers = jsonCount(root['followers_count']);
    final chatroom = jsonInt(jsonObject(root['chatroom'])?['id']);
    final master = live ? ivsMaster(jsonString(root['playback_url'])) : null;
    final thumbnail = jsonObject(stream?['thumbnail']);
    final cover = live
        ? jsonString(thumbnail?['url'] ?? thumbnail?['src']) ?? ''
        : jsonString(jsonObject(root['offline_banner_image'])?['src'] ?? jsonObject(root['banner_image'])?['url']) ??
              '';
    final name = jsonString(user['username']) ?? '';
    final statusValue = banned
        ? LiveStatus.banned
        : live
        ? LiveStatus.live
        : LiveStatus.offline;
    final room = LiveRoom.normalized(
      platform: _site,
      roomId: slug,
      content: RoomContent(
        title: live ? jsonString(stream['session_title']) ?? '' : '',
        coverUrl: cover,
        introduction: jsonString(user['bio']) ?? '',
        notice: live && stream['is_mature'] == true ? KickEndpoints.matureNotice : '',
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: '$channelId',
        name: name,
        avatarUrl: jsonString(user['profile_pic'] ?? user['profilePic']),
        profileUrl: KickEndpoints.roomPageUrl(slug),
        followerCount: followers,
        introduction: jsonString(user['bio']),
        liveStatus: statusValue,
      ),
      area: live ? categoryArea(stream['categories']) : null,
      audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(liveStatus: statusValue, startedAt: live ? jsonTime(stream['start_time']) : null),
      links: RoomLinks(webUrl: KickEndpoints.roomPageUrl(slug)),
    );
    return KickChannel(
      room: room,
      channelId: channelId,
      chatroomId: chatroom != null && chatroom > 0 ? chatroom : null,
      master: master,
    );
  }

  /// The top-level categories in [body] (`api/v1/categories`), in Kick's
  /// order.
  static List<KickMainCategory> mainCategories(String body, {int status = 200}) {
    checkStatus(status, body, 'categories');
    final root = decodeJson(body);
    if (root is! List || root.length > 64) {
      throw KickFailure(KickFailureKind.apiChanged, 'categories: not a list (${jsonSnippet(body)})');
    }
    final result = <String, KickMainCategory>{};
    for (final raw in root) {
      final row = jsonObject(raw);
      final slug = jsonString(row?['slug'])?.toLowerCase();
      final name = jsonString(row?['name']);
      if (slug == null || name == null || name.isEmpty) continue;
      result.putIfAbsent(slug, () => (slug: slug, name: name));
    }
    if (result.isEmpty) {
      throw const KickFailure(KickFailureKind.apiChanged, 'categories: no usable category');
    }
    return List.unmodifiable(result.values);
  }

  /// The subcategories of [parent] (`api/v1/subcategories`), by viewers as
  /// Kick orders them. A row of another category is left out; rows that all
  /// fail to name a subcategory are api-changed, an empty list is a category
  /// Kick lists no subcategories for.
  static List<LiveArea> subcategories(String body, {required KickMainCategory parent, int status = 200}) {
    checkStatus(status, body, 'subcategories');
    final rows = jsonObject(decodeJson(body))?['data'];
    if (rows is! List || rows.length > 100) {
      throw KickFailure(KickFailureKind.apiChanged, 'subcategories: no data list (${jsonSnippet(body)})');
    }
    final areas = <String, LiveArea>{};
    for (final raw in rows) {
      final row = jsonObject(raw);
      final slug = jsonString(row?['slug']);
      final name = jsonString(row?['name']);
      final owner = jsonString(jsonObject(row?['category'])?['slug'])?.toLowerCase();
      if (slug == null || name == null || slug.length > 100 || (owner != null && owner != parent.slug)) continue;
      areas.putIfAbsent(
        slug.toLowerCase(),
        () => LiveArea.normalized(
          platform: _site,
          areaId: slug,
          areaName: name,
          parentAreaId: parent.slug,
          parentAreaName: parent.name,
          iconUrl: jsonString(jsonObject(row?['banner'])?['url']),
        ),
      );
    }
    if (rows.isNotEmpty && areas.isEmpty) {
      throw KickFailure(KickFailureKind.apiChanged, 'subcategories: no usable row (${jsonSnippet(body)})');
    }
    return List.unmodifiable(areas.values);
  }

  /// A page of live broadcasts (`stream/livestreams/en`, by viewers). With
  /// [subcategory], rows of other subcategories are left out: Kick ignores a
  /// subcategory it does not know and answers the whole directory, so a page
  /// without any row of it is not-found.
  static ({List<LiveRoom> rooms, bool hasMore}) directoryPage(
    String body, {
    required int page,
    required int pageSize,
    String? subcategory,
    int status = 200,
  }) {
    checkStatus(status, body, 'livestreams');
    final root = jsonObject(decodeJson(body));
    final rows = root?['data'];
    if (root == null || rows is! List || rows.length > pageSize * 2 || jsonInt(root['current_page']) != page) {
      throw KickFailure(KickFailureKind.apiChanged, 'livestreams: not page $page (${jsonSnippet(body)})');
    }
    final wanted = subcategory?.toLowerCase();
    final rooms = <String, LiveRoom>{};
    var usable = 0;
    var matching = 0;
    for (final raw in rows) {
      final row = jsonObject(raw);
      if (row == null) continue;
      final room = listCard(row);
      if (room == null) continue;
      usable++;
      if (wanted != null && !subcategorySlugs(row['categories']).contains(wanted)) continue;
      matching++;
      rooms.putIfAbsent(room.roomId, () => room);
    }
    if (rows.isNotEmpty && usable == 0) {
      throw KickFailure(KickFailureKind.apiChanged, 'livestreams: no usable row (${jsonSnippet(body)})');
    }
    if (wanted != null && usable > 0 && matching == 0) {
      throw KickFailure(KickFailureKind.notFound, 'livestreams: no subcategory "$subcategory"');
    }
    final next = root['next_page_url'];
    return (rooms: List.unmodifiable(rooms.values), hasMore: next is String && next.isNotEmpty && rows.isNotEmpty);
  }

  /// Channels matching a keyword (`api/search`): the channels first, by
  /// followers as Kick orders them (live or not), then the live broadcasts
  /// whose tags match and whose channel is not listed yet. Kick's search has
  /// one page.
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    checkStatus(status, body, 'search');
    final root = jsonObject(decodeJson(body));
    final channels = root?['channels'];
    final tagged = jsonObject(root?['livestreams'])?['tags'];
    if (root == null || channels is! List || channels.length > 100 || (tagged != null && tagged is! List)) {
      throw KickFailure(KickFailureKind.apiChanged, 'search: no channel list (${jsonSnippet(body)})');
    }
    final rooms = <String, LiveRoom>{};
    var usable = 0;
    for (final raw in channels) {
      final row = jsonObject(raw);
      if (row == null) continue;
      final room = searchCard(row);
      if (room == null) continue;
      usable++;
      rooms.putIfAbsent(room.roomId, () => room);
    }
    if (channels.isNotEmpty && usable == 0) {
      throw KickFailure(KickFailureKind.apiChanged, 'search: no usable channel (${jsonSnippet(body)})');
    }
    if (tagged is List) {
      for (final raw in tagged.take(100)) {
        final room = listCard(jsonObject(raw) ?? const {});
        if (room != null) rooms.putIfAbsent(room.roomId, () => room);
      }
    }
    return List.unmodifiable(rooms.values);
  }

  /// The channel of a `kick.com` page (`https://kick.com/xqc`,
  /// `www.kick.com/XQC/`), lower-cased; null for anything else: a foreign
  /// host, a multi-segment path or a slug Kick's own pages own.
  static String? slugFromUrl(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https')) ||
        !isKickHost(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    final parts = [
      for (final part in uri.pathSegments)
        if (part.isNotEmpty) part,
    ];
    return parts.length == 1 ? KickEndpoints.normalizeSlug(parts.single) : null;
  }

  /// Whether [host] (lower-cased) is Kick's site.
  static bool isKickHost(String host) => const {'kick.com', 'www.kick.com', 'm.kick.com'}.contains(host);

  /// The master playlist in a channel's `playback_url`: https on IVS
  /// (`*.live-video.net`); an offline channel answers only `?token=…`, which
  /// is not a stream.
  static Uri? ivsMaster(String? raw) {
    final uri = raw == null || raw.isEmpty ? null : Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !host.endsWith(KickEndpoints.ivsHostSuffix)) {
      return null;
    }
    return uri;
  }

  /// A list row (`stream/livestreams`, search tags) as a live card, or null
  /// when it names no channel, is banned or is not live.
  static LiveRoom? listCard(Map<String, dynamic> row) {
    final channel = jsonObject(row['channel']);
    final slug = KickEndpoints.normalizeSlug(jsonString(channel?['slug']) ?? '');
    final channelId = jsonInt(channel?['id']) ?? jsonInt(row['channel_id']);
    if (channel == null || slug == null || channelId == null || channel['is_banned'] == true) return null;
    if (row['is_live'] == false) return null;
    final user = jsonObject(channel['user']);
    final shown = row['show_view_count'] != false;
    final viewers = shown ? jsonCount(row['viewer_count'] ?? row['viewers']) : null;
    final thumbnail = jsonObject(row['thumbnail']);
    final name = jsonString(user?['username']) ?? '';
    return LiveRoom.normalized(
      platform: _site,
      roomId: slug,
      content: RoomContent(
        title: jsonString(row['session_title']) ?? '',
        coverUrl: jsonString(thumbnail?['src'] ?? thumbnail?['url']) ?? '',
        notice: row['is_mature'] == true ? KickEndpoints.matureNotice : '',
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: '$channelId',
        name: name,
        avatarUrl: jsonString(user?['profilepic'] ?? user?['profile_pic'] ?? user?['profilePic']),
        profileUrl: KickEndpoints.roomPageUrl(slug),
        liveStatus: LiveStatus.live,
      ),
      area: categoryArea(row['categories']),
      audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(liveStatus: LiveStatus.live, startedAt: jsonTime(row['start_time'])),
      links: RoomLinks(webUrl: KickEndpoints.roomPageUrl(slug)),
    );
  }

  /// A search channel (`api/search` `channels`): live or offline, without a
  /// title, cover or viewers. Keys come in both spellings (`isLive` next to
  /// `is_live`, `followersCount` next to `followers_count`).
  static LiveRoom? searchCard(Map<String, dynamic> row) {
    final slug = KickEndpoints.normalizeSlug(jsonString(row['slug']) ?? '');
    final channelId = jsonInt(row['id']);
    if (slug == null || channelId == null) return null;
    final user = jsonObject(row['user']);
    final followers = jsonCount(row['followersCount'] ?? row['followers_count']);
    final banned = row['is_banned'] == true;
    final live = row['isLive'] ?? row['is_live'];
    final status = banned
        ? LiveStatus.banned
        : live == true
        ? LiveStatus.live
        : LiveStatus.offline;
    return LiveRoom.normalized(
      platform: _site,
      roomId: slug,
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: '$channelId',
        name: jsonString(user?['username']) ?? '',
        avatarUrl: jsonString(user?['profilePic'] ?? user?['profile_pic']),
        profileUrl: KickEndpoints.roomPageUrl(slug),
        followerCount: followers,
        introduction: jsonString(user?['bio']),
        liveStatus: status,
      ),
      audience: const RoomAudience(primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(liveStatus: status),
      links: RoomLinks(webUrl: KickEndpoints.roomPageUrl(slug)),
    );
  }

  /// The first subcategory of a `categories` list as an area (Kick labels a
  /// broadcast by its game); null when the list names none.
  static LiveArea? categoryArea(Object? categories) {
    final first = jsonObject(jsonList(categories).firstOrNull);
    final name = jsonString(first?['name']);
    if (name == null || name.isEmpty) return null;
    return LiveArea.normalized(
      platform: _site,
      areaId: jsonString(first?['slug'])?.toLowerCase() ?? '',
      areaName: name,
    );
  }

  /// The subcategory slugs a row's `categories` list names, lower-cased.
  static Set<String> subcategorySlugs(Object? categories) => {
    for (final category in jsonList(categories)) ?jsonString(jsonObject(category)?['slug'])?.toLowerCase(),
  };

  /// Kick's statuses: 401/403 is Cloudflare's refusal (risk control; a bare
  /// refusal of this client), 404 not-found, 429 rate-limited, 5xx network;
  /// anything else but 2xx api-changed. A 404 of an endpoint that is not a
  /// channel is checked by the caller before this.
  static void checkStatus(int status, String body, String what) {
    if (status >= 200 && status < 300) return;
    if (status == 401 || status == 403) {
      throw KickFailure(
        KickFailureKind.riskControl,
        body.contains('security policy')
            ? '$what: Cloudflare refused this client (Kick needs a browser TLS stack)'
            : '$what: HTTP $status',
      );
    }
    if (status == 404) throw KickFailure(KickFailureKind.notFound, '$what: HTTP 404');
    if (status == 429) throw KickFailure(KickFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw KickFailure(KickFailureKind.network, '$what: HTTP $status');
    throw KickFailure(KickFailureKind.apiChanged, '$what: HTTP $status (${jsonSnippet(body)})');
  }
}

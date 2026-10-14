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
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_json.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

const _site = 'chzzk';

/// One HLS master of a live's `livePlaybackJson`: `HLS` (normal latency) or
/// `LLHLS` (low latency), with its Akamai-tokened playlist address. The media
/// id is also the line id of the variants read from that master.
final class ChzzkMedia {
  /// Wraps one master.
  const ChzzkMedia(this.id, this.url);

  /// `mediaId`.
  final String id;

  /// The master playlist, with its `hdnts` token.
  final Uri url;

  @override
  String toString() => 'ChzzkMedia($id, ${url.host})';
}

/// A CHZZK channel: the room's identity and the streamer's own page.
final class ChzzkChannel {
  /// Creates the channel.
  const ChzzkChannel({
    required this.id,
    required this.name,
    required this.avatar,
    this.description = '',
    this.followers,
    this.isLive = false,
  });

  /// `channelId`: 32 lower-case hex digits.
  final String id;

  /// `channelName`.
  final String name;

  /// `channelImageUrl`; empty unless it is an https image of NAVER's CDNs.
  final String avatar;

  /// `channelDescription`, trimmed.
  final String description;

  /// `followerCount`, when the answer has one.
  final int? followers;

  /// `openLive`. A refreshed channel may still say live after its live closed,
  /// which is why a room read believes [ChzzkLive.isLive] instead (seen
  /// 2026-09-28 on the follow page).
  final bool isLive;
}

/// The latest live of a channel, from `v3.1 live-detail`.
final class ChzzkLive {
  /// Creates the live.
  const ChzzkLive({
    required this.isLive,
    required this.title,
    required this.nick,
    required this.avatar,
    required this.cover,
    required this.area,
    required this.media,
    this.online,
    this.startedAt,
    this.adult = false,
    this.krOnly = false,
    this.abroadBlind = false,
    this.paid = false,
    this.timeMachine = false,
    this.chatChannelId,
    this.mediaError,
  });

  /// `status == OPEN` (`CLOSE` and `CLOSED` are offline; anything else is a
  /// changed API, never a guess of offline).
  final bool isLive;

  /// `liveTitle`, else the channel name.
  final String title;

  /// The live's `channel.channelName`.
  final String nick;

  /// The live's `channel.channelImageUrl`.
  final String avatar;

  /// The live's cover: `liveImageUrl` at the 480-width variant, else the
  /// platform's default thumbnail (see `cover`).
  final String cover;

  /// `liveCategoryValue`, else `liveCategory`.
  final String area;

  /// `concurrentUserCount` when `cvExposure` lets it be shown.
  final int? online;

  /// `openDate` of an open live, in UTC. A closed live's `openDate` is the
  /// previous broadcast's, so it is not read.
  final DateTime? startedAt;

  /// `adult`: an anonymous viewer gets no media source.
  final bool adult;

  /// `krOnlyViewing`: only viewers in Korea get playback.
  final bool krOnly;

  /// `blindType == ABROAD`: hidden outside Korea.
  final bool abroadBlind;

  /// A paid product is attached; it only names why a live with no playback
  /// cannot play.
  final bool paid;

  /// `timeMachineActive`: the website can rewind this live.
  final bool timeMachine;

  /// `chatChannelId` — null for a closed, region-locked or adult live, and a
  /// new one for every broadcast (a finished channel still answers a token and
  /// a join, but never sends another line, seen 2026-09-28).
  final String? chatChannelId;

  /// The HLS masters of `livePlaybackJson`, in its order; empty when it has
  /// none or cannot be read.
  final List<ChzzkMedia> media;

  /// Why `livePlaybackJson` could not be read. The stream reports it; the
  /// room's other fields still stand, so a format change cannot hide a room.
  final ChzzkFailure? mediaError;
}

/// What a room read keeps for playback: the live's HLS masters, or why the live
/// cannot be played. The masters themselves are read when the qualities are
/// asked for, so a failing master never hides the room. It rides in the room's
/// transient stream handle.
final class ChzzkRoomData {
  /// Wraps the playback answer; [unavailable] is required when [media] is empty.
  const ChzzkRoomData({required this.channelId, required this.issuedAt, this.media = const [], this.unavailable});

  /// The channel the playback belongs to.
  final String channelId;

  /// The live's HLS masters, in `livePlaybackJson` order (`HLS`, then `LLHLS`).
  final List<ChzzkMedia> media;

  /// Why there is nothing to play: offline, region-locked, adult, paid, or no
  /// usable playback data. Null when [media] is not empty.
  final ChzzkFailure? unavailable;

  /// When this answer arrived (the origin of the masters' token leases).
  final DateTime issuedAt;

  @override
  String toString() => 'ChzzkRoomData($channelId, ${media.length} masters)';
}

/// What the chat connection needs to join one live: the channel whose live
/// state names the chat, and the chat channel of the live that is on air now.
final class ChzzkDanmakuArgs {
  /// Wraps the chat arguments.
  const ChzzkDanmakuArgs({required this.channelId, required this.chatChannelId});

  /// The room's channel: its live state names the chat of a later live,
  /// because a restarted broadcast gets another chat channel.
  final String channelId;

  /// `chatChannelId` of the live that is on air.
  final String chatChannelId;

  @override
  String toString() => 'ChzzkDanmakuArgs($channelId, $chatChannelId)';
}

/// One page of a lives list: its cards and the opaque cursor of the next page.
final class ChzzkLivesPage {
  /// Creates the page.
  const ChzzkLivesPage({required this.rooms, this.nextCursor});

  /// Live cards, one per channel.
  final List<LiveRoom> rooms;

  /// The cursor of the next page; null on the last.
  final String? nextCursor;

  /// Whether another page exists: a cursor and a non-empty page.
  bool get hasMore => nextCursor != null && rooms.isNotEmpty;
}

/// One `categories/live` page: its areas and the query of the next page.
typedef ChzzkCategoryPage = ({List<LiveArea> areas, Map<String, String>? next});

/// Pure parsing of CHZZK (치지직, NAVER) answers: the catalog, the lives lists,
/// the channel search, the channel and its live, and the link rules. Each
/// function takes the answer and its status and returns shared models or throws
/// a [ChzzkFailure]; streams are assembled in `chzzk_play_parser.dart`.
abstract final class ChzzkRoomParser {
  static final RegExp _categoryType = RegExp(r'^[A-Za-z_]{1,32}$');

  /// The web page of [channelId] — the room's own link.
  static String link(String channelId) => ChzzkEndpoints.roomUrl(channelId);

  /// Whether [type] is a `categoryType` the platform routes by: letters and
  /// underscores only, at most 32.
  static bool isCategoryType(String type) => _categoryType.hasMatch(type);

  // Catalog and directory -----------------------------------------------------

  /// One `categories/live` page: an area per entry (`categoryType` the parent,
  /// `categoryId` the id, `categoryValue` the name, `posterImageUrl` the
  /// picture) and the next page's query from `page.next`, sent back as it came.
  /// A malformed entry is skipped; a page of malformed entries only is
  /// api-changed. An empty page ends the list.
  static ChzzkCategoryPage categoryPage(String body, {int status = 200}) {
    const what = 'categories/live';
    final data = object(content(body, what: what, status: status), what);
    final rows = list(data['data'], '$what.data');
    final areas = [
      for (final row in rows)
        if (row is Map) ?_categoryArea(object(row, '$what row')),
    ];
    if (areas.isEmpty && rows.isNotEmpty) {
      throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: no readable entry of ${rows.length}');
    }
    return (areas: areas, next: rows.isEmpty ? null : _nextQuery(data['page']));
  }

  static LiveArea? _categoryArea(Map<String, dynamic> row) {
    final type = text(row['categoryType']);
    final id = text(row['categoryId']);
    if (!_categoryType.hasMatch(type) || !isAreaId(id)) return null;
    final name = text(row['categoryValue']);
    return LiveArea.normalized(
      platform: _site,
      areaId: id,
      areaName: name.isEmpty ? id : name,
      parentAreaId: type,
      parentAreaName: categoryTypeName(type),
      iconUrl: image(row['posterImageUrl']),
    );
  }

  /// `page.next` as a query: its scalar fields as text; null when absent.
  static Map<String, String>? _nextQuery(Object? page) {
    final next = page is Map ? page['next'] : null;
    if (next is! Map) return null;
    final query = {
      for (final entry in next.entries)
        if (entry.value is num || (entry.value is String && (entry.value as String).isNotEmpty))
          '${entry.key}': '${entry.value}',
    };
    return query.isEmpty ? null : query;
  }

  /// The catalog from the `categories/live` pages: every area once, in the
  /// platform's order (the list is sorted by viewers, so a later page may
  /// repeat an area — the first occurrence is kept; 6 repeats in the 200 rows
  /// of the 2026-09-29 capture), returned flat with each area's `categoryType`
  /// as its parent. An area of another platform, or one whose id cannot go in
  /// a path, is refused as a caller error.
  static List<LiveArea> categories(Iterable<List<LiveArea>> pages) {
    final seen = <String>{};
    final order = <String>[];
    final areas = <LiveArea>[];
    for (final page in pages) {
      for (final area in page) {
        if (!seen.add(area.areaId)) continue;
        if (!order.contains(area.parentAreaId)) order.add(area.parentAreaId!);
        areas.add(area);
      }
    }
    final ranked = <String>[
      ...ChzzkEndpoints.categoryTypeNames.keys.where(order.contains),
      ...order.where((type) => !ChzzkEndpoints.categoryTypeNames.containsKey(type)),
    ];
    return [
      for (final type in ranked)
        for (final area in areas)
          if (area.parentAreaId == type) area,
    ];
  }

  // Lives lists ---------------------------------------------------------------

  /// A lives page of the site-wide list or of one area (the rows are the same).
  ///
  /// [cursor] is the one the previous page answered with, when this read is
  /// replaying to a page number. Unlike the reference's page parsing, a row
  /// that cannot be a card (no channel, no id, no live id) is skipped instead
  /// of failing the page, and an empty title is the channel name. When the
  /// platform sent more rows than [ChzzkEndpoints.pageSize] the extra rows are
  /// dropped and the next cursor points after the last row kept — reading the
  /// page's own `page.next` there would skip the row in between (the recorded
  /// page pair of 2026-09-27). A `page.next` that is not a cursor is
  /// api-changed. A first row that is the cursor's own live is dropped (a
  /// guard; the platform already starts after it).
  static ChzzkLivesPage lives(String body, {String? cursor, int status = 200}) {
    const what = 'lives';
    final data = object(content(body, what: what, status: status), what);
    final after = ChzzkEndpoints.decodeCursor(cursor);
    final rows = <({LiveRoom room, int liveId, int? viewers})>[];
    for (final item in list(data['data'], '$what.data')) {
      if (item is! Map) continue;
      final row = object(item, '$what row');
      final channel = row['channel'];
      final id = channel is Map ? channelId(channel['channelId']) : null;
      final liveId = jsonInt(row['liveId']);
      if (channel is! Map || id == null || liveId == null || liveId <= 0) continue;
      rows.add((
        room: liveCard(row, object(channel, '$what channel'), id),
        liveId: liveId,
        viewers: jsonCount(row['concurrentUserCount']),
      ));
    }
    if (after != null && rows.isNotEmpty && rows.first.liveId == after.liveId) rows.removeAt(0);
    String? next;
    if (rows.length > ChzzkEndpoints.pageSize) {
      rows.removeRange(ChzzkEndpoints.pageSize, rows.length);
      final last = rows.last;
      next = last.viewers == null ? null : ChzzkEndpoints.encodeCursor(last.viewers!, last.liveId);
    }
    if (next == null) {
      final pointer = data['page'] is Map ? (data['page'] as Map)['next'] : null;
      if (pointer is Map) {
        final viewers = jsonCount(pointer['concurrentUserCount']);
        final liveId = jsonInt(pointer['liveId']);
        if (viewers == null || liveId == null || liveId <= 0) {
          throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: page.next $pointer');
        }
        next = ChzzkEndpoints.encodeCursor(viewers, liveId);
      }
    }
    final seen = <String>{};
    return ChzzkLivesPage(
      rooms: [
        for (final row in rows)
          if (seen.add(row.room.roomId)) row.room,
      ],
      nextCursor: next == cursor ? null : next,
    );
  }

  /// A live card of a lives list: every row is live, with its start and what
  /// keeps it from playing — region-locked, else adult, else nothing known when
  /// a paid product is attached (of 600 lives on 2026-09-29 none had one, so
  /// its restriction stays unsaid rather than guessed).
  static LiveRoom liveCard(Map<String, dynamic> row, Map<String, dynamic> channel, String id) {
    final name = text(channel['channelName']);
    final title = text(row['liveTitle']);
    final LiveRestriction? restriction;
    if (regionLocked(row)) {
      restriction = LiveRestriction.regionBlocked;
    } else if (row['adult'] == true) {
      restriction = LiveRestriction.adult;
    } else {
      restriction = paid(row) ? null : LiveRestriction.none;
    }
    final viewers = online(row);
    return LiveRoom.normalized(
      platform: _site,
      roomId: id,
      content: RoomContent(
        title: title.isEmpty ? name : title,
        coverUrl: cover(row['liveImageUrl'], row['defaultThumbnailImageUrl']),
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: id,
        name: name,
        avatarUrl: image(channel['channelImageUrl']),
        liveStatus: LiveStatus.live,
      ),
      area: LiveArea.normalized(platform: _site, areaName: areaName(row)),
      audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(
        liveStatus: LiveStatus.live,
        startedAt: seoulTime(row['openDate']),
        restriction: restriction,
      ),
      links: RoomLinks(webUrl: link(id)),
    );
  }

  // Channel search ------------------------------------------------------------

  /// The keyword sent for [keyword]: trimmed and cut to
  /// [ChzzkEndpoints.maxKeywordLength] UTF-16 code units, never inside a
  /// surrogate pair, then trimmed again (a 100-character keyword is answered
  /// normally, 2026-09-29). Empty when there is nothing to search for.
  static String searchKeyword(String keyword) {
    var text = keyword.trim();
    if (text.length > ChzzkEndpoints.maxKeywordLength) {
      var end = ChzzkEndpoints.maxKeywordLength;
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      text = text.substring(0, end).trim();
    }
    return text;
  }

  /// Channel search results as cards: the title is the channel name, the cover
  /// its avatar, live by `openLive`. A result without a channel id is skipped.
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    const what = 'search/channels';
    final data = object(content(body, what: what, status: status), what);
    return [
      for (final item in list(data['data'], '$what.data'))
        if (item is Map && item['channel'] is Map)
          if (channel(object(item['channel'], '$what channel'), requestedId: '') case final found?) channelCard(found),
    ];
  }

  /// The channel of a `channels` answer or of a search row. [requestedId] is
  /// the id the room was asked for; an empty one (a search row, which names
  /// itself) makes a missing or malformed id a skip, not an error. [what] names
  /// the endpoint in the failure text.
  ///
  /// The platform answers an unknown id with HTTP 200, a null `channelId` and
  /// the name `(알 수 없음)`: that is not-found, not a channel (checked
  /// 2026-09-27). An answer for another channel is api-changed.
  static ChzzkChannel? channel(Map<String, dynamic> data, {required String requestedId, String what = 'channels'}) {
    final raw = data['channelId'];
    if (raw == null) {
      if (requestedId.isEmpty) return null;
      throw ChzzkFailure(ChzzkFailureKind.notFound, '$what: channelId is null for $requestedId');
    }
    final id = channelId(raw);
    if (id == null) {
      if (requestedId.isEmpty) return null;
      throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: channel $raw for $requestedId');
    }
    if (requestedId.isNotEmpty && id != requestedId) {
      throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: channel $raw for $requestedId');
    }
    return ChzzkChannel(
      id: id,
      name: text(data['channelName']),
      avatar: image(data['channelImageUrl']),
      description: text(data['channelDescription']),
      followers: jsonCount(data['followerCount']),
      isLive: data['openLive'] == true,
    );
  }

  /// The channel of `/service/v1/channels/<id>`; a null `content` (or an answer
  /// for another channel) is not-found or api-changed.
  static ChzzkChannel channelById(String body, {required String channelId, int status = 200}) {
    const what = 'channels';
    final data = content(body, what: what, status: status);
    if (data == null) throw ChzzkFailure(ChzzkFailureKind.notFound, '$what: no content for $channelId');
    final found = channel(object(data, what), requestedId: channelId);
    if (found == null) throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: no channel for $channelId');
    return found;
  }

  /// A channel as a card (also the room of a channel that is not live): live by
  /// `openLive` unless [status] says otherwise.
  static LiveRoom channelCard(ChzzkChannel channel, {LiveStatus? status}) => LiveRoom.normalized(
    platform: _site,
    roomId: channel.id,
    content: RoomContent(
      title: channel.name,
      coverUrl: channel.avatar,
      introduction: channel.description.isEmpty ? null : channel.description,
    ),
    anchor: LiveAnchor.normalized(
      platform: _site,
      anchorId: channel.id,
      name: channel.name,
      avatarUrl: channel.avatar,
      followerCount: channel.followers,
      introduction: channel.description.isEmpty ? null : channel.description,
      liveStatus: status ?? (channel.isLive ? LiveStatus.live : LiveStatus.offline),
    ),
    audience: const RoomAudience(primaryMetric: LiveAudienceMetricType.onlineViewers),
    broadcast: RoomBroadcast(liveStatus: status ?? (channel.isLive ? LiveStatus.live : LiveStatus.offline)),
    links: RoomLinks(webUrl: link(channel.id)),
  );

  // The live ------------------------------------------------------------------

  /// The latest live of [owner] from `v3.1 live-detail`; null when the channel
  /// never broadcast (the room is then its offline channel card). A live of
  /// another channel, or an unknown `status`, is api-changed — never taken for
  /// offline. `livePlaybackJson` is read only for an open live, and an
  /// unreadable one leaves the live's other fields standing with its reason in
  /// [ChzzkLive.mediaError].
  static ChzzkLive? liveDetail(String body, {required ChzzkChannel owner, int status = 200}) {
    const what = 'live-detail';
    final data = content(body, what: what, status: status);
    if (data == null) return null;
    final map = object(data, what);
    final channel = map['channel'] is Map ? object(map['channel'], '$what channel') : null;
    if (channel != null) {
      final id = channelId(channel['channelId']);
      if (id != owner.id) {
        throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: channel ${channel['channelId']} for ${owner.id}');
      }
    }
    final isLive = switch (map['status']) {
      'OPEN' => true,
      'CLOSE' || 'CLOSED' => false,
      final other => throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: status $other'),
    };
    ChzzkFailure? mediaError;
    var media = const <ChzzkMedia>[];
    if (isLive) {
      try {
        media = ChzzkPlayParser.media(map['livePlaybackJson']);
      } on ChzzkFailure catch (failure) {
        if (failure.kind != ChzzkFailureKind.apiChanged) rethrow;
        mediaError = failure;
      }
    }
    final title = text(map['liveTitle']);
    final nick = channel == null ? '' : text(channel['channelName']);
    return ChzzkLive(
      isLive: isLive,
      title: title.isEmpty ? owner.name : title,
      nick: nick.isEmpty ? owner.name : nick,
      avatar: channel == null ? owner.avatar : image(channel['channelImageUrl']),
      cover: cover(map['liveImageUrl'], map['defaultThumbnailImageUrl']),
      area: areaName(map),
      online: online(map),
      startedAt: isLive ? seoulTime(map['openDate']) : null,
      adult: map['adult'] == true,
      krOnly: map['krOnlyViewing'] == true,
      abroadBlind: map['blindType'] == 'ABROAD',
      paid: paid(map),
      timeMachine: map['timeMachineActive'] == true,
      chatChannelId: stringify(map['chatChannelId']),
      media: media,
      mediaError: mediaError,
    );
  }

  /// The room of [owner] and its latest [live]: a live that is not open (or no
  /// live at all) is the channel card, offline whatever the channel's
  /// `openLive` says; an open live is its card with the channel's followers and
  /// introduction, its start, its restriction and its reason for not playing.
  static LiveRoom room(ChzzkChannel owner, ChzzkLive? live) {
    if (live == null || !live.isLive) return channelCard(owner, status: LiveStatus.offline);
    return LiveRoom.normalized(
      platform: _site,
      roomId: owner.id,
      content: RoomContent(
        title: live.title,
        coverUrl: live.cover,
        introduction: owner.description.isEmpty ? null : owner.description,
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: owner.id,
        name: live.nick,
        avatarUrl: live.avatar,
        followerCount: owner.followers,
        introduction: owner.description.isEmpty ? null : owner.description,
        liveStatus: LiveStatus.live,
      ),
      area: LiveArea.normalized(platform: _site, areaName: live.area.isEmpty ? ChzzkEndpoints.siteName : live.area),
      audience: RoomAudience(onlineViewers: live.online, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(liveStatus: LiveStatus.live, startedAt: live.startedAt, restriction: restriction(live)),
      links: RoomLinks(webUrl: link(owner.id)),
    );
  }

  /// What keeps an open [live] from playing here: nothing when it has playback
  /// data; else region-locked, adult, paid, or unplayable, in that order. Null
  /// when it is not open, or when its playback data could not be read (the
  /// reason is then the read's own failure).
  static LiveRestriction? restriction(ChzzkLive? live) {
    if (live == null || !live.isLive) return null;
    if (live.media.isNotEmpty) return LiveRestriction.none;
    if (live.mediaError != null) return null;
    if (live.krOnly || live.abroadBlind) return LiveRestriction.regionBlocked;
    if (live.adult) return LiveRestriction.adult;
    if (live.paid) return LiveRestriction.paid;
    return LiveRestriction.unplayable;
  }

  /// Why [live] has nothing to play: not live, unreadable playback data (its
  /// own api-changed), region-locked, adult (it needs the platform's own login
  /// and age check), paid, or a live with no playback data.
  static ChzzkFailure unavailable(ChzzkLive? live) {
    if (live == null || !live.isLive) return const ChzzkFailure(ChzzkFailureKind.streamUnavailable, 'not live');
    if (live.mediaError case final failure?) return failure;
    if (live.krOnly || live.abroadBlind) {
      return const ChzzkFailure(ChzzkFailureKind.regionBlocked, 'krOnlyViewing');
    }
    if (live.adult) return const ChzzkFailure(ChzzkFailureKind.needsLogin, 'adult live');
    if (live.paid) return const ChzzkFailure(ChzzkFailureKind.streamUnavailable, 'paid live');
    return const ChzzkFailure(ChzzkFailureKind.streamUnavailable, 'live without playback');
  }

  /// What a room read keeps of [live] for playback.
  static ChzzkRoomData roomData(String channelId, ChzzkLive? live, {required DateTime issuedAt}) {
    final playable = live != null && live.isLive && live.media.isNotEmpty;
    return playable
        ? ChzzkRoomData(channelId: channelId, media: live.media, issuedAt: issuedAt)
        : ChzzkRoomData(channelId: channelId, unavailable: unavailable(live), issuedAt: issuedAt);
  }

  /// The chat arguments of [live], or null where the website opens no chat (no
  /// live, no `chatChannelId`).
  static ChzzkDanmakuArgs? danmakuArgs(ChzzkChannel owner, ChzzkLive? live) {
    final chat = live?.chatChannelId;
    if (live == null || !live.isLive || chat == null) return null;
    return ChzzkDanmakuArgs(channelId: owner.id, chatChannelId: chat);
  }

  // Links ---------------------------------------------------------------------

  /// The channel of a CHZZK page: http(s) on `chzzk.naver.com` exactly, without
  /// user info, empty path segments ignored — the live page `/live/<id>`, and
  /// the channel page `/<id>` with at most one tab (`/<id>/videos`,
  /// `/<id>/clips`, …). The id is accepted in any case and returned lower case,
  /// because that is how the platform writes it. Other pages
  /// (`/video/<number>`, `m.chzzk.naver.com`) are not rooms. There is no short
  /// link.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'chzzk.naver.com') {
      return null;
    }
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    final candidate = switch (segments) {
      [ChzzkEndpoints.livePath, final id] => id,
      [final id] || [final id, _] => id,
      _ => null,
    };
    final id = candidate?.trim().toLowerCase();
    return id != null && isChannelId(id) ? id : null;
  }
}

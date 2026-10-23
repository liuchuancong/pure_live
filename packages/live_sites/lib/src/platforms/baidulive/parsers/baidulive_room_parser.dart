import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_endpoints.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_json.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A channel of the PC feed (3.x's `BaiduLiveCategory`): the feed's `tab`
/// and its `channel_id`, one Baidu Live area.
final class BaiduliveCategory {
  /// Creates the channel.
  const BaiduliveCategory({required this.id, required this.name, required this.channelId});

  /// `type`, the feed's `tab` (`rec`, `shopping`); the area id.
  final String id;

  /// `name` (`推荐`, `购物`).
  final String name;

  /// `channel_id` (570, 574).
  final int channelId;

  @override
  String toString() => 'BaiduliveCategory($id, $channelId)';
}

/// A broadcast's state, from the room command's `status` or a card's
/// `live_status`. A paid, forbidden or banned broadcast keeps its state
/// (30-5): the restriction is told apart ([BaiduliveRoom.restriction]).
enum BaiduliveState {
  /// Broadcasting (`status` 0, a card's `live_status` 1).
  live,

  /// Announced (`status` -1 or 1, `live_status` 0).
  preview,

  /// Not broadcasting (`status` 2 or 20, `live_status` 2).
  offline,

  /// Ended (`status` 3, `live_status` 3): a room is one broadcast, and an
  /// ended one plays its recording when the platform gives one (30-4).
  replay,

  /// A state 3.x did not know.
  unknown,
}

/// One URL of a quality and its container.
typedef BaiduliveSource = ({Uri url, LiveStreamFormat format});

/// One quality of a room: a tier (the source, a height, or a recording) in
/// one codec, with its URLs in line order (30-1, 30-2, 30-4).
final class BaiduliveVariant {
  /// Creates the variant.
  BaiduliveVariant({
    required this.id,
    required this.name,
    required this.sort,
    required this.codec,
    required Iterable<BaiduliveSource> sources,
  }) : sources = List.unmodifiable(sources);

  /// The quality id: [BaidulivePlayParser.sourceQualityId] or `<height>p`, with
  /// `:hevc` for H.265; a recording's is `replay`, `replay:<key>` or
  /// `replay:<key>:hevc`.
  final String id;

  /// The quality's name (`原画`, `720p`, `原画 · H.265`, `标清`).
  final String name;

  /// Rank among the room's qualities: higher is better (see
  /// [BaidulivePlayParser.ordered]).
  final int sort;

  /// The codec, or null when the platform does not tell (the source of a room
  /// with a clarity list, see [BaidulivePlayParser.liveVariants]).
  final LiveStreamCodec? codec;

  /// The URLs, one per line, in line order.
  final List<BaiduliveSource> sources;

  @override
  String toString() => 'BaiduliveVariant($id)';
}

/// A room as read from a feed card or from the room command 371 (3.x's
/// `BaiduLiveRoom`): what room entry keeps as the room's stream handle, and
/// what the playback reads. A room is one broadcast, so its id is the only
/// platform id needed.
final class BaiduliveRoom {
  /// Creates the room.
  BaiduliveRoom({
    required this.roomId,
    required this.userId,
    required this.nick,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.category,
    required this.currentViewers,
    required this.followers,
    required this.state,
    this.introduction = '',
    this.startedAt,
    this.restriction,
    this.paid = false,
    this.blocked = false,
    Iterable<BaiduliveVariant> variants = const [],
    this.danmaku,
  }) : variants = List.unmodifiable(variants);

  /// The room id as asked for (a card's `room_id`).
  final String roomId;

  /// `host.uk`, the anchor; empty when not given.
  final String userId;

  /// `host.nick_name` (a card's `host.name`); empty when not given (30-10: no
  /// stand-in name).
  final String nick;

  /// `video.title` (a card's `title`), else the nick; empty when neither is
  /// given.
  final String title;

  /// `host.image.image_33` (a card's `host.avatar`), when on an allowed host.
  final String avatar;

  /// `video.cover.cover_100`, else `vertical_cover` (a card's `cover`).
  final String cover;

  /// `category` (a card's `live_tag`, else `left_label.text`).
  final String category;

  /// `video.description`, the broadcast's introduction (30-7); cards have
  /// none.
  final String introduction;

  /// `online_users` (a card's `audience_count`) while live.
  final int? currentViewers;

  /// `real_fans_num`, else `host.fans` (cards have none).
  final int? followers;

  /// The broadcast's state (30-4, 30-5).
  final BaiduliveState state;

  /// When the broadcast started (the room command's `create_time`), while
  /// live; cards have none.
  final DateTime? startedAt;

  /// The restriction of a live or ended broadcast (30-4, 30-5): blocked is
  /// [LiveRestriction.unplayable], paid [LiveRestriction.paid], an ended
  /// broadcast without a recording (or a live one without a stream)
  /// [LiveRestriction.unplayable], else [LiveRestriction.none]; null where
  /// the answer does not tell (a state that is not live or ended, a card
  /// without `has_pay_service`).
  final LiveRestriction? restriction;

  /// `has_pay_service > 0`.
  final bool paid;

  /// `is_forbidden_url > 0` or `ban_status > 0` (the room command only).
  final bool blocked;

  /// The qualities, best first: the live stream's while live, the
  /// recording's when ended; empty otherwise and on cards.
  final List<BaiduliveVariant> variants;

  /// The chat's message lists while live (M5.26); null otherwise and on cards.
  final BaiduliveDanmakuArgs? danmaku;

  /// This room with what [known] (an earlier card or detail of the same room)
  /// had where this one has nothing (3.x's `enrich`). Unlike 3.x, a known
  /// audience is kept only while the room is live: an ended room no longer
  /// shows the viewers of its card.
  BaiduliveRoom enrich(BaiduliveRoom known) => BaiduliveRoom(
    roomId: roomId,
    userId: userId.isEmpty ? known.userId : userId,
    nick: nick.isEmpty ? known.nick : nick,
    title: title.isEmpty ? known.title : title,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    cover: cover.isEmpty ? known.cover : cover,
    category: category.isEmpty ? known.category : category,
    introduction: introduction.isEmpty ? known.introduction : introduction,
    currentViewers: currentViewers ?? (state == BaiduliveState.live ? known.currentViewers : null),
    followers: followers ?? known.followers,
    state: state,
    startedAt: startedAt,
    restriction: restriction,
    paid: paid,
    blocked: blocked,
    variants: variants,
    danmaku: danmaku,
  );

  /// Why this room cannot be played, or null. Not live and not ended, or an
  /// ended broadcast without a recording, is stream-unavailable; so is a
  /// restricted broadcast, with the kind in the message (30-5: blocked
  /// `unplayable`, then `paid`; Baidu Live has no sign-in here), and a live
  /// one without a stream this client accepts.
  BaiduliveFailure? get unavailable {
    if (state != BaiduliveState.live && state != BaiduliveState.replay) {
      return BaiduliveFailure(BaiduliveFailureKind.streamUnavailable, '$roomId is ${state.name}');
    }
    if (blocked) {
      return BaiduliveFailure(
        BaiduliveFailureKind.streamUnavailable,
        '$roomId is restricted (unplayable: forbidden or banned)',
      );
    }
    if (paid) return BaiduliveFailure(BaiduliveFailureKind.streamUnavailable, '$roomId is restricted (paid)');
    if (variants.isEmpty) {
      return BaiduliveFailure(
        BaiduliveFailureKind.streamUnavailable,
        state == BaiduliveState.replay ? '$roomId ended without a recording (unplayable)' : '$roomId has no stream',
      );
    }
    return null;
  }
}

/// One page of the PC feed (3.x's `BaiduLivePage`).
final class BaidulivePage {
  /// Creates the page.
  BaidulivePage({
    required Iterable<BaiduliveRoom> rooms,
    required Iterable<BaiduliveCategory> categories,
    required this.sessionId,
    required this.refreshIndex,
    required this.hasMore,
  }) : rooms = List.unmodifiable(rooms),
       categories = List.unmodifiable(categories);

  /// The cards, each room once.
  final List<BaiduliveRoom> rooms;

  /// The channels of the `tab` block (the first page asks for it); empty
  /// without it.
  final List<BaiduliveCategory> categories;

  /// `session_id`: the feed session the next page continues.
  final String sessionId;

  /// `refresh_index`: the page's place in the session.
  final int refreshIndex;

  /// Whether the page was full (3.x: ten items or more).
  final bool hasMore;
}

/// Pure parsing of Baidu Live (百度直播) answers (3.x's `BaiduLiveApi` and the
/// room rules of `BaiduLiveSite`): the feed page, its channels, the cards, the
/// room command 371, the chat's message lists and the v2 rooms and areas.
///
/// Each function takes the response text and status and returns the models or
/// throws a [BaiduliveFailure].
abstract final class BaiduliveRoomParser {
  static final RegExp _tab = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

  // Catalog -------------------------------------------------------------------

  /// The catalog's areas, in the platform's order: the feed's channels under
  /// the platform itself (3.x's one `LiveCategory`, `official`, the feed tab
  /// as the area id). No request.
  static List<LiveArea> areas(List<BaiduliveCategory> channels) => [
    for (final (index, channel) in channels.indexed)
      LiveArea.normalized(
        platform: baiduliveSiteId,
        areaId: channel.id,
        areaName: channel.name,
        parentAreaId: baiduliveSiteId,
        parentAreaName: BaiduliveEndpoints.siteName,
        position: index,
      ),
  ];

  // Directory -----------------------------------------------------------------

  /// A feed page (3.x's `parseDirectoryJson`): `errno` and the feed's
  /// `inner_errno` must be 0 and the session and refresh index given
  /// (api-changed otherwise); the cards are each room once; the channels are
  /// the `tab` block's; a page of [BaiduliveEndpoints.fullPage] items or more
  /// has more.
  ///
  /// Unlike 3.x, a `tab` block that failed (`inner_errno` not 0) leaves the
  /// channels empty (the site keeps the ones it has) instead of failing the
  /// page.
  static BaidulivePage page(String body, {int status = 200}) {
    const what = 'feed';
    final data = BaiduliveJson.map(BaiduliveJson.answer(body, what: what, status: status)['data']) ?? const {};
    final feed = BaiduliveJson.object(data['feed']);
    final inner = BaiduliveJson.integer(feed['inner_errno']);
    if (inner != 0) {
      throw BaiduliveFailure(BaiduliveFailureKind.apiChanged, '$what: inner_errno ${feed['inner_errno']}');
    }
    final items = BaiduliveJson.list(feed['items']);
    final seen = <String>{};
    final rooms = [
      for (final item in items)
        if (card(BaiduliveJson.object(item)) case final room? when seen.add(room.roomId)) room,
    ];
    final sessionId = BaiduliveJson.text(feed['session_id']);
    final refreshIndex = BaiduliveJson.count(feed['refresh_index']);
    if (sessionId.isEmpty || refreshIndex == null) {
      throw BaiduliveFailure(
        BaiduliveFailureKind.apiChanged,
        '$what: session ${feed['session_id']}, refresh_index ${feed['refresh_index']}',
      );
    }
    return BaidulivePage(
      rooms: rooms,
      categories: channels(data['tab']),
      sessionId: sessionId,
      refreshIndex: refreshIndex,
      hasMore: items.length >= BaiduliveEndpoints.fullPage,
    );
  }

  /// The channels of a feed's `tab` block (3.x's `parseCategoriesJson`):
  /// `type` (a lower-case id), `name` and a positive `channel_id`, each id
  /// once. Empty without the block or when it failed.
  static List<BaiduliveCategory> channels(Object? value) {
    final tab = BaiduliveJson.map(value);
    if (tab == null || tab.isEmpty || BaiduliveJson.integer(tab['inner_errno']) != 0) return const [];
    final seen = <String>{};
    final channels = <BaiduliveCategory>[];
    for (final entry in BaiduliveJson.list(tab['items'])) {
      final item = BaiduliveJson.object(entry);
      final id = BaiduliveJson.text(item['type']).toLowerCase();
      final name = BaiduliveJson.text(item['name']);
      final channelId = BaiduliveJson.positive(item['channel_id']);
      if (!_tab.hasMatch(id) || name.isEmpty || channelId == null || !seen.add(id)) continue;
      channels.add(BaiduliveCategory(id: id, name: name, channelId: channelId));
    }
    return List.unmodifiable(channels);
  }

  /// A feed card (3.x's `_directoryCard`): `room_id`, the anchor
  /// `host.uk`/`name`/`avatar`, `title`, `cover`, `live_tag` (else
  /// `left_label.text`) and, while live, `audience_count`; `live_status` 1
  /// live, 0 preview, 2 offline, 3 ended (a replay, 30-4), else unknown.
  /// The restriction (30-4, 30-5): paid by `has_pay_service`; an ended card
  /// without a recording in its `play_url` is `unplayable`; a live card
  /// without `has_pay_service` does not tell. Null without a room id.
  static BaiduliveRoom? card(Map<String, Object?> item) {
    final roomId = BaiduliveEndpoints.parseRoomId(BaiduliveJson.text(item['room_id']));
    if (roomId == null) return null;
    final host = BaiduliveJson.object(item['host']);
    final state = switch (BaiduliveJson.integer(item['live_status'])) {
      1 => BaiduliveState.live,
      0 => BaiduliveState.preview,
      2 => BaiduliveState.offline,
      3 => BaiduliveState.replay,
      _ => BaiduliveState.unknown,
    };
    final nick = BaiduliveJson.text(host['name']);
    final payFlag = BaiduliveJson.integer(item['has_pay_service']);
    final paid = (payFlag ?? 0) > 0;
    return BaiduliveRoom(
      roomId: roomId,
      userId: BaiduliveJson.text(host['uk']),
      nick: nick,
      title: BaiduliveJson.firstText([item['title'], nick]),
      avatar: BaiduliveJson.image(host['avatar']),
      cover: BaiduliveJson.image(item['cover']),
      category: BaiduliveJson.firstText([item['live_tag'], BaiduliveJson.object(item['left_label'])['text']]),
      currentViewers: state == BaiduliveState.live ? BaiduliveJson.count(item['audience_count']) : null,
      followers: null,
      state: state,
      paid: paid,
      restriction: switch (state) {
        BaiduliveState.live || BaiduliveState.replay when paid => LiveRestriction.paid,
        BaiduliveState.live => payFlag == null ? null : LiveRestriction.none,
        BaiduliveState.replay =>
          BaidulivePlayParser.replayUrl(item['play_url'], roomId) == null
              ? LiveRestriction.unplayable
              : LiveRestriction.none,
        _ => null,
      },
    );
  }

  // Rooms ---------------------------------------------------------------------

  /// Room [expectedRoomId] from the command 371 (3.x's `parseRoomJson`):
  /// - no command (`data.371` null), `error_code` 1 or 4, or neither `host`
  ///   nor `video` is not-found; another `error_code` (or none) and a
  ///   `share_url` of another room are api-changed;
  /// - `status` 0 live, -1/1 preview, 2/20 offline, 3 ended (a replay, 30-4),
  ///   anything else unknown; paid (`has_pay_service`), forbidden
  ///   (`is_forbidden_url`) and banned (`ban_status`) keep the state and set
  ///   the [BaiduliveRoom.restriction] (30-5);
  /// - the anchor `host.uk`, `nick_name` (else `name`), `image.image_33`;
  ///   `video.title` (else the nick), `cover.cover_100` (else
  ///   `vertical_cover`), `description` (30-7); `category`; while live
  ///   `online_users` and `create_time` (the start); `real_fans_num` (else
  ///   `host.fans`); the live qualities while live, the recording's when
  ///   ended; the chat's lists while live (M5.26).
  static BaiduliveRoom room(String body, {required String expectedRoomId, int status = 200}) {
    const what = 'searchbox 371';
    final data = BaiduliveJson.map(BaiduliveJson.answer(body, what: what, status: status)['data']) ?? const {};
    final command = BaiduliveJson.object(data['371']);
    if (command.isEmpty) throw BaiduliveFailure(BaiduliveFailureKind.notFound, 'room $expectedRoomId');
    final error = BaiduliveJson.integer(command['error_code']);
    // An announced broadcast answers in another shape: no `error_code`, the
    // `template` "preview", its fields at the top (3.x refused it).
    final preview = command['error_code'] == null && BaiduliveJson.text(command['template']) == 'preview';
    if (error == 1 || error == 4) {
      throw BaiduliveFailure(BaiduliveFailureKind.notFound, 'room $expectedRoomId: error_code $error');
    }
    if (error != 0 && !preview) {
      throw BaiduliveFailure(BaiduliveFailureKind.apiChanged, '$what: error_code ${command['error_code']}');
    }
    final shared = BaiduliveEndpoints.parseRoomId(BaiduliveJson.text(command['share_url']));
    if (shared != null && shared != expectedRoomId) {
      throw BaiduliveFailure(BaiduliveFailureKind.apiChanged, '$what: share_url of room $shared for $expectedRoomId');
    }
    final host = BaiduliveJson.object(command['host']);
    final video = BaiduliveJson.object(command['video']);
    if (host.isEmpty && video.isEmpty) {
      throw BaiduliveFailure(BaiduliveFailureKind.notFound, 'room $expectedRoomId: no host or video');
    }
    final top = preview ? command : const <String, Object?>{};
    final state = switch (BaiduliveJson.integer(command['status'])) {
      0 => BaiduliveState.live,
      -1 || 1 => BaiduliveState.preview,
      2 || 20 => BaiduliveState.offline,
      3 => BaiduliveState.replay,
      _ => BaiduliveState.unknown,
    };
    final paid = (BaiduliveJson.integer(command['has_pay_service']) ?? 0) > 0;
    final blocked =
        (BaiduliveJson.integer(command['is_forbidden_url']) ?? 0) > 0 ||
        (BaiduliveJson.integer(command['ban_status']) ?? 0) > 0;
    final nick = BaiduliveJson.firstText([host['nick_name'], host['name'], top['source']]);
    final cover = BaiduliveJson.object(video['cover']);
    final live = state == BaiduliveState.live;
    final variants = switch (state) {
      BaiduliveState.live => BaidulivePlayParser.liveVariants(video, expectedRoomId),
      BaiduliveState.replay => BaidulivePlayParser.replayVariants(command['replay_list'], expectedRoomId),
      _ => const <BaiduliveVariant>[],
    };
    return BaiduliveRoom(
      roomId: expectedRoomId,
      userId: BaiduliveJson.firstText([host['uk'], top['uk']]),
      nick: nick,
      title: BaiduliveJson.firstText([video['title'], top['title'], nick]),
      avatar: BaiduliveJson.firstImage([BaiduliveJson.object(host['image'])['image_33'], top['avatar']]),
      cover: BaiduliveJson.firstImage([
        cover['cover_100'],
        cover['vertical_cover'],
        top['cover'],
        top['vertical_cover'],
      ]),
      category: BaiduliveJson.text(command['category']),
      introduction: BaiduliveJson.firstText([video['description'], top['description']]),
      currentViewers: live ? BaiduliveJson.count(command['online_users']) : null,
      followers: BaiduliveJson.count(command['real_fans_num'] ?? host['fans']),
      state: state,
      startedAt: live ? BaiduliveJson.startedAt(command['create_time']) : null,
      restriction: switch (state) {
        BaiduliveState.live || BaiduliveState.replay when blocked => LiveRestriction.unplayable,
        BaiduliveState.live || BaiduliveState.replay when paid => LiveRestriction.paid,
        BaiduliveState.live || BaiduliveState.replay when variants.isEmpty => LiveRestriction.unplayable,
        BaiduliveState.live || BaiduliveState.replay => LiveRestriction.none,
        _ => null,
      },
      paid: paid,
      blocked: blocked,
      variants: variants,
      danmaku: live ? danmakuArgs(command, expectedRoomId) : null,
    );
  }

  // Chat lists ----------------------------------------------------------------

  /// A message list of the room command (M5.26): an http or https URL on
  /// [BaiduliveEndpoints.messageListHost] whose path ends in `.m3u8`; null
  /// otherwise. http becomes https, as the room page rewrites it to its own
  /// protocol (pchome.live.fcb2dc0e.js); the signed query is kept as given.
  static Uri? messageList(Object? value) {
    final uri = Uri.tryParse(BaiduliveJson.text(value));
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    if (uri.host.toLowerCase() != BaiduliveEndpoints.messageListHost || uri.userInfo.isNotEmpty || uri.hasFragment) {
      return null;
    }
    if (!uri.path.endsWith('.m3u8')) return null;
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  /// When the signature of [list] runs out: its `authorization`
  /// (`bce-auth-v1/<key>/<UTC time>/<seconds>/<headers>/<signature>`) time
  /// plus its validity; null when the URL has no such signature.
  static DateTime? signatureExpiry(Uri list) {
    const name = 'authorization=';
    final field = list.query.split('&').where((field) => field.startsWith(name)).firstOrNull ?? '';
    // Recorded answers wrote the separators both plain and escaped.
    final parts = field
        .substring(field.isEmpty ? 0 : name.length)
        .replaceAll(RegExp('%2F', caseSensitive: false), '/')
        .replaceAll(RegExp('%3A', caseSensitive: false), ':')
        .split('/');
    if (parts.length < 4 || parts[0] != 'bce-auth-v1') return null;
    final time = parts[2];
    final signed = RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$').hasMatch(time) ? DateTime.tryParse(time) : null;
    final seconds = RegExp(r'^\d{1,10}$').hasMatch(parts[3]) ? int.parse(parts[3]) : null;
    // DateTime rolls a 13th month or a 45th day over; such a time is no time.
    if (signed == null || signed.toIso8601String().substring(0, 19) != time.substring(0, 19)) return null;
    return seconds == null || seconds == 0 ? null : signed.add(Duration(seconds: seconds));
  }

  /// The chat arguments of a live room command (M5.26): the chat list
  /// (`chat_msg_hls_url`, else `video.msg_hls_url`), the reliable and host
  /// lists when valid ([messageList]), the poll interval
  /// (`msg_hls_pull_internal_in_second`, else the video's; a positive number
  /// of seconds within 1–10, else
  /// [BaiduliveEndpoints.defaultPullInterval]) and when the chat list's
  /// signature runs out ([signatureExpiry]). Null without a valid chat list.
  static BaiduliveDanmakuArgs? danmakuArgs(Map<String, Object?> command, String roomId) {
    final video = BaiduliveJson.object(command['video']);
    final chat = messageList(command['chat_msg_hls_url']) ?? messageList(video['msg_hls_url']);
    if (chat == null) return null;
    final seconds = BaiduliveJson.integer(
      command['msg_hls_pull_internal_in_second'] ?? video['msg_hls_pull_internal_in_second'],
    );
    return BaiduliveDanmakuArgs(
      roomId: roomId,
      chatList: chat,
      reliableList: messageList(command['reliable_msg_hls_url']),
      hostList: messageList(command['host_msg_hls_url']),
      pullInterval: seconds != null && seconds > 0
          ? Duration(seconds: seconds.clamp(1, 10))
          : BaiduliveEndpoints.defaultPullInterval,
      expiresAt: signatureExpiry(chat),
    );
  }

  // The v2 room ---------------------------------------------------------------

  /// The room shown for [room] (3.x's `BaiduLiveSite._room`): the anchor id
  /// (else the room id), the avatar (else the cover), the category (else the
  /// platform's name); live, offline (preview and offline), replay (ended,
  /// 30-4) or unknown; the start and the restriction; the introduction (30-7);
  /// viewers while live; the restriction notice (paid or blocked) and
  /// [BaiduliveEndpoints.chatNotice]. [withData] keeps [room] as the room's
  /// stream handle (room entry and recordings); [withChat] (default
  /// [withData]) keeps its chat arguments ([BaiduliveRoom.danmaku]) as the
  /// danmaku handle (M5.26), which a refresh also brings so that a connection
  /// whose signature expired reconnects with fresh lists (E05.4).
  ///
  /// Unlike 3.x, no `httpHeaders`: the media headers travel on the lines; and
  /// no stand-in name or title (30-10): the UI shows the platform's name for
  /// an empty nick.
  static LiveRoom liveRoom(BaiduliveRoom room, {bool withData = false, bool? withChat}) {
    final viewers = room.currentViewers;
    final liveStatus = switch (room.state) {
      BaiduliveState.live => LiveStatus.live,
      BaiduliveState.preview || BaiduliveState.offline => LiveStatus.offline,
      BaiduliveState.replay => LiveStatus.replay,
      BaiduliveState.unknown => LiveStatus.unknown,
    };
    final keepChat = withChat ?? withData;
    return LiveRoom.normalized(
      platform: baiduliveSiteId,
      roomId: room.roomId,
      content: RoomContent.of(
        title: room.title,
        coverUrl: room.cover,
        introduction: room.introduction.isEmpty ? null : room.introduction,
        notice: [
          if (room.paid || room.blocked) BaiduliveEndpoints.restrictedNotice,
          BaiduliveEndpoints.chatNotice,
        ].join('\n'),
      ),
      anchor: LiveAnchor.normalized(
        platform: baiduliveSiteId,
        anchorId: room.userId.isEmpty ? room.roomId : room.userId,
        name: room.nick,
        avatarUrl: room.avatar.isEmpty ? room.cover : room.avatar,
        followerCount: room.followers,
        liveStatus: liveStatus,
      ),
      area: LiveArea.normalized(
        platform: baiduliveSiteId,
        areaName: room.category.isEmpty ? BaiduliveEndpoints.siteName : room.category,
      ),
      audience: RoomAudience.of(
        onlineViewers: viewers,
        primaryMetric: viewers == null ? LiveAudienceMetricType.unknown : LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast.of(liveStatus: liveStatus, startedAt: room.startedAt, restriction: room.restriction),
      links: RoomLinks.of(webUrl: BaiduliveEndpoints.roomUrl(room.roomId)),
      runtime: RoomRuntime.of(streamHandle: withData ? room : null, danmakuHandle: keepChat ? room.danmaku : null),
    );
  }
}

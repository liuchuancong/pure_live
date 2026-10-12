import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Kick public web API.
abstract final class KickParser {
  /// Desktop Chrome 140, as pure_live_TV sends.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// Web origin.
  static const String origin = 'https://kick.com';

  /// API host (Cloudflare refuses dart:io's TLS handshake only on some
  /// hosts; kick.com answers).
  static const String apiHost = 'kick.com';

  /// Headers of every API request.
  static const Map<String, String> headers = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': '$origin/',
  };

  /// Media headers of channel [slug].
  static Map<String, String> mediaHeaders(String slug) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': '${roomPageUrl(slug)}/',
  };

  /// A slug: lower-case letters, digits, dashes and underscores.
  static String? normalizeSlug(String value) {
    final slug = value.trim().toLowerCase();
    return RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(slug) ? slug : null;
  }

  /// The channel page URL.
  static String roomPageUrl(String slug) => '$origin/$slug';

  /// The channel API URL of [slug].
  static Uri channelUrl(String slug) => Uri.https(apiHost, '/api/v2/channels/$slug');

  /// Longest keyword Kick's search takes; a longer one is cut.
  static const int maxKeywordLength = 50;

  /// The `api/search` URL for [keyword], the keyword trimmed and cut to
  /// [maxKeywordLength] as 3.x sent it.
  static Uri searchUrl(String keyword) {
    final text = keyword.trim();
    final words = text.length > maxKeywordLength ? text.substring(0, maxKeywordLength) : text;
    return Uri.https(apiHost, '/api/search', {'searched_word': words});
  }

  /// Channels matching a keyword (`api/search`), by followers as Kick orders
  /// them (live or not), each slug once, then the live broadcasts tagged with
  /// it whose channel is not listed yet. A channel with no slug or id is left
  /// out; a page with channels but none usable is a changed endpoint. Kick's
  /// search is one page.
  static List<LiveRoom> search(String body, {int status = 200}) {
    final root = KickParser.decode(body, status: status, what: 'search');
    final channels = root['channels'];
    final tagged = root['livestreams'] is Map<String, Object?> ? SiteJson.object(root['livestreams'])['tags'] : null;
    if (channels is! List || channels.length > 100 || (tagged != null && tagged is! List)) {
      throw const SiteApiChangedError('kick search: no channel list of at most 100');
    }
    final rooms = <String, LiveRoom>{};
    var usable = 0;
    for (final row in SiteJson.objects(channels)) {
      final room = searchCard(row);
      if (room == null) {
        continue;
      }
      usable++;
      rooms.putIfAbsent(room.roomId, () => room);
    }
    if (channels.isNotEmpty && usable == 0) {
      throw const SiteApiChangedError('kick search: no usable channel');
    }
    if (tagged is List) {
      for (final row in SiteJson.objects(tagged.take(100))) {
        final room = listCard(row);
        if (room != null) {
          rooms.putIfAbsent(room.roomId, () => room);
        }
      }
    }
    return List.unmodifiable(rooms.values);
  }

  /// One `api/search` channel row as a room, or null when it names no slug or
  /// id. The profile carries no stream, so the room is the channel: banned
  /// when Kick says so, else live or offline by its `is_live` flag.
  static LiveRoom? searchCard(Map<String, Object?> row) {
    final slug = normalizeSlug(row['slug']?.toString() ?? '');
    final channelId = SiteCounts.integer(row['id']);
    if (slug == null || channelId == null) {
      return null;
    }
    final user = row['user'] is Map<String, Object?> ? row['user']! as Map<String, Object?> : const <String, Object?>{};
    final banned = row['is_banned'] == true;
    final live = row['isLive'] ?? row['is_live'];
    return LiveRoom(
      platform: SiteIds.kick,
      roomId: slug,
      nick: user['username']?.toString() ?? '',
      avatar: _image(user['profilePic'] ?? user['profile_pic']),
      status: banned
          ? LiveStatus.banned
          : live == true
          ? LiveStatus.live
          : LiveStatus.offline,
    );
  }

  /// The largest live-list page asked for; 30 is the site's own page.
  static const int pageSize = 30;

  /// Subcategories asked for per top-level category (the API caps `limit`).
  static const int subcategoryLimit = 32;

  /// The top-level categories in Chinese; others keep Kick's name.
  static const Map<String, String> categoryNames = {
    'games': '游戏',
    'irl': '生活',
    'music': '音乐',
    'gambling': '博彩',
    'creative': '创作',
    'alternative': '其他',
  };

  static final RegExp _slugPattern = RegExp(r'^[a-z0-9_-]{1,100}$');

  /// Whether [value] names a subcategory Kick's list filter takes.
  static bool isSubcategory(String value) => RegExp(r'^[A-Za-z0-9:+_-]{1,100}$').hasMatch(value.trim());

  /// The top-level categories URL.
  static Uri categoriesUrl() => Uri.https(apiHost, '/api/v1/categories');

  /// The most watched subcategories of category [category].
  static Uri subcategoriesUrl(String category) =>
      Uri.https(apiHost, '/api/v1/subcategories', {'category': category, 'limit': '$subcategoryLimit', 'page': '1'});

  /// The live-broadcasts page [page] of [pageSize], by viewers; a [subcategory]
  /// narrows it to that subcategory.
  static Uri livestreamsUrl({required int page, required int pageSize, String? subcategory}) => Uri.https(
    apiHost,
    '/stream/livestreams/en',
    {'page': '${page < 1 ? 1 : page}', 'limit': '$pageSize', 'sort': 'desc', 'subcategory': ?subcategory},
  );

  /// The top-level categories (`api/v1/categories`), in Kick's order, each by
  /// slug with its display name. A row without a valid slug or name is left
  /// out; not a list, more than 64, or no usable row is a changed endpoint.
  static List<({String slug, String name})> mainCategories(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kick categories: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('kick categories: body is not JSON');
    }
    if (decoded is! List || decoded.length > 64) {
      throw const SiteApiChangedError('kick categories: not a list of at most 64');
    }
    final result = <String, ({String slug, String name})>{};
    for (final row in SiteJson.objects(decoded)) {
      final slug = row['slug']?.toString().toLowerCase() ?? '';
      final name = row['name']?.toString() ?? '';
      if (!_slugPattern.hasMatch(slug) || name.isEmpty) {
        continue;
      }
      result.putIfAbsent(slug, () => (slug: slug, name: categoryNames[slug] ?? name));
    }
    if (result.isEmpty) {
      throw const SiteApiChangedError('kick categories: no usable category');
    }
    return List.unmodifiable(result.values);
  }

  /// The subcategories of category [parentSlug] (`api/v1/subcategories`), as
  /// flat areas under it, by viewers as Kick orders them. A row without a slug
  /// or name, longer than 100, or of another category is left out; not a data
  /// list, more than 100, or rows none of which are usable is a changed
  /// endpoint.
  static List<LiveArea> subcategories(
    String body, {
    required String parentSlug,
    required String parentName,
    int status = 200,
  }) {
    final root = KickParser.decode(body, status: status, what: 'subcategories');
    final rows = root['data'];
    if (rows is! List || rows.length > 100) {
      throw const SiteApiChangedError('kick subcategories: no data list of at most 100');
    }
    final areas = <String, LiveArea>{};
    for (final row in SiteJson.objects(rows)) {
      final slug = row['slug']?.toString() ?? '';
      final name = row['name']?.toString() ?? '';
      final owner = SiteJson.object(row['category'])['slug']?.toString().toLowerCase();
      if (slug.isEmpty || name.isEmpty || slug.length > 100 || (owner != null && owner != parentSlug)) {
        continue;
      }
      areas.putIfAbsent(slug.toLowerCase(), () => LiveArea(id: slug, name: name, parentId: parentSlug));
    }
    if (rows.isNotEmpty && areas.isEmpty) {
      throw const SiteApiChangedError('kick subcategories: no usable row');
    }
    return List.unmodifiable(areas.values);
  }

  /// A page of live broadcasts (`stream/livestreams/en`, by viewers), each
  /// channel once. With [subcategory], rows of other subcategories are left
  /// out — and since Kick answers the whole directory for a subcategory it
  /// does not know, a page with usable rows but none of it is `not found`. A
  /// page whose every row is unusable is a changed endpoint; the page must
  /// echo [page]. More pages follow while the answer names a next one.
  static LivePage<LiveRoom> directoryPage(
    String body, {
    required int page,
    required int pageSize,
    String? subcategory,
    int status = 200,
  }) {
    final root = KickParser.decode(body, status: status, what: 'livestreams');
    final rows = root['data'];
    if (rows is! List || rows.length > pageSize * 2 || SiteCounts.integer(root['current_page']) != page) {
      throw SiteApiChangedError('kick livestreams: not page $page');
    }
    final wanted = subcategory?.toLowerCase();
    final rooms = <String, LiveRoom>{};
    var usable = 0;
    var matching = 0;
    for (final row in SiteJson.objects(rows)) {
      final room = listCard(row);
      if (room == null) {
        continue;
      }
      usable++;
      if (wanted != null && !_subcategorySlugs(row['categories']).contains(wanted)) {
        continue;
      }
      matching++;
      rooms.putIfAbsent(room.roomId, () => room);
    }
    if (rows.isNotEmpty && usable == 0) {
      throw const SiteApiChangedError('kick livestreams: no usable row');
    }
    if (wanted != null && usable > 0 && matching == 0) {
      throw SiteNotFoundError('kick: no subcategory $subcategory');
    }
    final hasMore = root['next_page_url'] is String && rows.isNotEmpty;
    return LivePage<LiveRoom>(
      items: List.unmodifiable(rooms.values),
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
    );
  }

  /// A live-broadcast list row (`stream/livestreams`, or a search tag) as a
  /// room, or null when it names no channel, has no id, is banned, or is not
  /// live. The room is the channel, on air; the audience is `viewer_count`
  /// unless Kick hides it, the area the first category name, and the play
  /// needs the channel's media headers. The mature flag would set a notice the
  /// reduced room has no field for, so it is dropped.
  static LiveRoom? listCard(Map<String, Object?> row) {
    final channel = row['channel'] is Map<String, Object?> ? row['channel']! as Map<String, Object?> : null;
    if (channel == null) {
      return null;
    }
    final slug = normalizeSlug(channel['slug']?.toString() ?? '');
    final channelId = SiteCounts.integer(channel['id']) ?? SiteCounts.integer(row['channel_id']);
    if (slug == null || channelId == null || channel['is_banned'] == true) {
      return null;
    }
    if (row['is_live'] == false) {
      return null;
    }
    final user = channel['user'] is Map<String, Object?>
        ? channel['user']! as Map<String, Object?>
        : const <String, Object?>{};
    final viewers = row['show_view_count'] == false ? null : SiteCounts.integer(row['viewer_count'] ?? row['viewers']);
    final thumbnail = row['thumbnail'] is Map<String, Object?>
        ? row['thumbnail']! as Map<String, Object?>
        : const <String, Object?>{};
    return LiveRoom(
      platform: SiteIds.kick,
      roomId: slug,
      nick: user['username']?.toString() ?? '',
      title: row['session_title']?.toString() ?? '',
      avatar: _image(user['profilepic'] ?? user['profile_pic'] ?? user['profilePic']),
      cover: _image(thumbnail['src'] ?? thumbnail['url']),
      areaName: _subcategoryName(row['categories']),
      watching: viewers,
      onlineViewers: viewers,
      status: LiveStatus.live,
      restriction: LiveRestriction.none,
      startedAt: _time(row['start_time']),
      httpHeaders: mediaHeaders(slug),
    );
  }

  /// The subcategory slugs a list row carries, lower-cased.
  static Set<String> _subcategorySlugs(Object? categories) => {
    if (categories is List)
      for (final category in categories)
        ?(category is Map<String, Object?> ? category['slug']?.toString().toLowerCase() : null),
  };

  /// The first category name of a list row, or null.
  static String? _subcategoryName(Object? categories) {
    if (categories is! List) {
      return null;
    }
    for (final category in categories) {
      final name = category is Map<String, Object?> ? category['name']?.toString() ?? '' : '';
      if (name.isNotEmpty) {
        return name;
      }
    }
    return null;
  }

  /// Decodes an answer.
  static Map<String, Object?> decode(String body, {int status = 200, String what = 'channel'}) {
    if (status == 404) {
      throw SiteNotFoundError('kick $what: no channel');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kick $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('kick $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('kick $what: body is not an object');
    }
    return decoded;
  }

  /// A channel answer → the room with its signed master in `data`. A
  /// banned channel is banned; `is_live` marks on-air.
  static LiveRoom room(String body, {required String requestedSlug, int status = 200}) {
    final root = KickParser.decode(body, status: status);
    final slug = normalizeSlug(root['slug']?.toString() ?? '');
    final channelId = SiteCounts.integer(root['id']);
    final user = root['user'];
    if (slug == null || channelId == null || channelId <= 0 || user is! Map<String, Object?>) {
      throw const SiteApiChangedError('kick channel: no slug, id or user');
    }
    if (slug != requestedSlug.trim().toLowerCase()) {
      throw SiteApiChangedError('kick channel: asked "$requestedSlug", answered "$slug"');
    }
    final banned = root['is_banned'] == true;
    final stream = root['livestream'];
    final streamMap = stream is Map<String, Object?> ? stream : const <String, Object?>{};
    final live = !banned && stream is Map<String, Object?> && streamMap['is_live'] == true;
    final master = live ? _master(root['playback_url']?.toString()) : null;
    // The chatroom id is not the channel id (`xqcisoffline`: channel 101691,
    // chatroom 101689); the Pusher chat channel is named by the chatroom.
    final chatroomObj = root['chatroom'];
    final rawChatroom = chatroomObj is Map ? chatroomObj['id'] : null;
    final chatroomId = rawChatroom is num ? rawChatroom.toInt() : int.tryParse('$rawChatroom');
    return LiveRoom(
      platform: SiteIds.kick,
      roomId: slug,
      title: live ? streamMap['session_title']?.toString() ?? '' : '',
      nick: user['username']?.toString() ?? '',
      avatar: _image(user['profile_pic'] ?? user['profilePic']),
      cover: live
          ? _image(_nested(streamMap['thumbnail'], 'url') ?? _nested(streamMap['thumbnail'], 'src'))
          : _image(_nested(root['offline_banner_image'], 'src') ?? _nested(root['banner_image'], 'url')),
      areaName: _firstCategoryName(streamMap['categories']),
      watching: live ? SiteCounts.integer(streamMap['viewer_count']) : null,
      status: banned
          ? LiveStatus.banned
          : live
          ? LiveStatus.live
          : LiveStatus.offline,
      startedAt: live ? _time(streamMap['start_time']) : null,
      data: <String, Object?>{
        'channelId': channelId,
        if (chatroomId != null && chatroomId > 0) 'chatroomId': chatroomId,
        'master': ?master,
      },
    );
  }

  /// The play lines of a live room's master playlist.
  static List<LivePlayLine> playLines(Object? data, String slug) {
    final master = data is Map<String, Object?> ? data['master'] : null;
    if (master is! Uri) {
      return const [];
    }
    return [
      LivePlayLine(
        url: data.toString(),
        headers: mediaHeaders(slug),
        format: StreamFormat.hls,
        codec: 'avc',
        lineId: 'master',
      ),
    ];
  }

  /// The master playlist in a `playback_url`: https on IVS
  /// (`*.live-video.net`); an offline channel answers only `?token=…`.
  static Uri? _master(String? raw) {
    final uri = raw == null ? null : Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || !host.endsWith('.live-video.net')) {
      return null;
    }
    return uri;
  }

  /// `2026-09-30 19:24:14` (UTC) or ISO 8601.
  static DateTime? _time(Object? value) {
    final text = value?.toString();
    if (text == null) {
      return null;
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]00:?00)?$')
        .firstMatch(text);
    if (match == null) {
      return null;
    }
    final parts = [for (var group = 1; group <= 6; group++) int.parse(match.group(group)!)];
    final time = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
    return time.year == parts[0] && time.month == parts[1] && time.day == parts[2] && time.year > 2000 ? time : null;
  }

  static String? _firstCategoryName(Object? categories) =>
      categories is List && categories.isNotEmpty ? _nested(categories.first, 'name') : null;

  static String? _nested(Object? value, String key) => value is Map<String, Object?> ? value[key]?.toString() : null;

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}

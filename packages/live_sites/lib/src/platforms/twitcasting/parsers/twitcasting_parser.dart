import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the TwitCasting channel pages and streamserver.
abstract final class TwitcastingParser {
  /// Web origin.
  static const String origin = 'https://twitcasting.tv';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
  };

  /// Media headers of channel [channel].
  static Map<String, String> mediaHeaders(String channel) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/$channel',
  };

  /// The lower-case channel of a reference: a bare name, or a
  /// `twitcasting.tv/<channel>` link.
  static String? channelName(String reference) {
    var value = reference.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.host.isNotEmpty) {
      if (uri.host != 'twitcasting.tv' && uri.host != 'www.twitcasting.tv') {
        return null;
      }
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.isEmpty) {
        return null;
      }
      value = segments.first;
    }
    final match = RegExp(r'^[A-Za-z0-9_]{1,64}$').firstMatch(value);
    return match == null ? null : value.toLowerCase();
  }

  static final RegExp _meta = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
  static final RegExp _metaAttr = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');

  static Map<String, String> _attributes(String source) => {
    for (final match in _metaAttr.allMatches(source)) match.group(1)!: match.group(2)!,
  };

  /// The broadcasts one `top/category` answer holds: the site answers a
  /// single window of this many, and the pages a caller asks for are cut from
  /// it.
  static const int directoryWindow = 60;

  /// How many rooms one directory page shows.
  static const int directoryPageSize = 30;

  /// The highest page a caller may ask for.
  static const int maxPage = 10000;

  /// A homepage tab key (`data-channel`).
  static final RegExp areaIdPattern = RegExp(r'^[a-zA-Z0-9_]{1,80}$');

  /// The homepage's top tabs (`a.tw-top-tab-item[data-channel]`) as the
  /// site's areas, in page order; "For You" carries no key and is left out.
  ///
  /// The tabs *are* the catalogue — the site has no catalogue endpoint — so a
  /// tab without a usable key or label fails the catalogue, as does a page
  /// with none or more than a hundred: a homepage without its tabs is a
  /// changed page, not a page with nothing to browse.
  static List<LiveArea> areas(String body, {int status = 200}) {
    if (status != 200) {
      throw SiteApiChangedError('twitcasting home: HTTP $status');
    }
    final areas = <LiveArea>[];
    final seen = <String>{};
    for (final match in _anchor.allMatches(body)) {
      final tag = match.group(0)!;
      if (!tag.contains('tw-top-tab-item')) {
        continue;
      }
      final key = _attributes(tag)['data-channel'];
      if (key == null) {
        continue;
      }
      final label = _anchorText(body, match.end);
      if (!areaIdPattern.hasMatch(key) || label.isEmpty) {
        throw SiteApiChangedError('twitcasting home: tab "$key" "$label"');
      }
      if (seen.add(key)) {
        areas.add(LiveArea(id: key, name: label, sort: areas.length));
      }
    }
    if (areas.isEmpty || areas.length > 100) {
      throw SiteApiChangedError('twitcasting home: ${areas.length} category tabs');
    }
    return areas;
  }

  /// The `top/category` window of tab [areaId] (the empty string for the whole
  /// site): the room each row shows, or null when the row is left out.
  ///
  /// Left out are broadcasts that ended, were deleted or are group broadcasts
  /// — what a group broadcast is was never seen, 0 of 837 rows on 2026-09-29
  /// — and a row that cannot be read (a flag that is not a boolean, or a bad
  /// channel, movie id, `live_url` or viewer count), which costs that row
  /// rather than the page (the unified fault-tolerance rule); 3.x failed the
  /// whole list on one. A window whose every row is malformed, one over
  /// [directoryWindow] rows or one that is not a list at all is a changed
  /// endpoint. A locked broadcast (the site's secret word) is a live room
  /// restricted to [LiveRestriction.password] and any other to
  /// [LiveRestriction.none]; 3.x left locked rooms out. A start time is [now]
  /// less the broadcast's `elapsed_time`, when [now] is known.
  static List<LiveRoom?> window(String body, {required String areaId, int status = 200, DateTime? now}) {
    if (status != 200) {
      throw SiteApiChangedError('twitcasting top/category $areaId: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('twitcasting top/category $areaId: body is not JSON');
    }
    final root = decoded is Map<String, Object?> ? decoded : null;
    final rows = root?['movies'];
    if (rows is! List || rows.length > directoryWindow) {
      throw SiteApiChangedError(
        'twitcasting top/category $areaId: movies is ${rows is List ? '${rows.length} rows' : rows.runtimeType}',
      );
    }
    final window = [for (final row in rows) _row(row, now)];
    if (rows.isNotEmpty && window.every((room) => room.malformed)) {
      throw SiteApiChangedError('twitcasting top/category $areaId: all ${rows.length} rows malformed');
    }
    return [for (final row in window) row.room];
  }

  /// One `top/category` page: the rooms of the window's rows [page] of
  /// [directoryPageSize] shows, cut after the rows left out were dropped — so
  /// a page may hold fewer rooms — with a channel repeated on the page listed
  /// once.
  ///
  /// The site answers one window and no more, so the last page of it is the
  /// last page there is.
  static LivePage<LiveRoom> directory(
    String body, {
    required int page,
    required String areaId,
    int status = 200,
    DateTime? now,
  }) {
    if (page < 1 || page > maxPage) {
      throw RangeError.range(page, 1, maxPage, 'page');
    }
    final offset = (page - 1) * directoryPageSize;
    if (offset >= directoryWindow) {
      return const LivePage<LiveRoom>(items: []);
    }
    final rooms = <String, LiveRoom>{};
    for (final room in window(body, areaId: areaId, status: status, now: now).skip(offset).take(directoryPageSize)) {
      if (room != null) {
        rooms.putIfAbsent(room.roomId, () => room);
      }
    }
    final hasMore = offset + directoryPageSize < directoryWindow;
    return LivePage(
      items: rooms.values.toList(),
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: directoryWindow,
    );
  }

  /// One `top/category` row: its room, or none because the row is left out or
  /// cannot be read ([window] explains both).
  static ({LiveRoom? room, bool malformed}) _row(Object? raw, DateTime? now) {
    const malformed = (room: null, malformed: true);
    final row = raw is Map<String, Object?> ? raw : SiteJson.object(raw);
    if (row.isEmpty) {
      return malformed;
    }
    const flags = ['is_live', 'is_locked', 'is_group', 'is_deleted'];
    if (flags.any((flag) => row[flag] is! bool)) {
      return malformed;
    }
    if (row['is_live'] != true || row['is_group'] != false || row['is_deleted'] != false) {
      return (room: null, malformed: false);
    }
    final channel = channelName(SiteText.text(row['user_id']));
    final movie = SiteCounts.integer(row['id']);
    final link = Uri.tryParse(SiteText.trimmed(row['live_url']));
    final viewers = SiteCounts.integer(row['current_viewer_count']);
    if (channel == null ||
        movie == null ||
        movie <= 0 ||
        link == null ||
        link.hasAuthority ||
        link.hasQuery ||
        link.hasFragment ||
        link.pathSegments.where((segment) => segment.isNotEmpty).join('/') != '$channel/movie/$movie' ||
        viewers == null ||
        viewers < 0) {
      return malformed;
    }
    final telop = SiteText.title(SiteText.text(row['telop']));
    final elapsed = SiteCounts.integer(row['elapsed_time']);
    return (
      room: LiveRoom(
        platform: SiteIds.twitcasting,
        roomId: channel,
        title: telop.isEmpty ? SiteText.title(SiteText.text(row['title'])) : telop,
        nick: SiteText.title(SiteText.text(row['user_name'])),
        cover: _picture(row['thumbnail_url']),
        avatar: _picture(row['user_icon_url']),
        watching: viewers,
        status: LiveStatus.live,
        startedAt: now == null || elapsed == null || elapsed < 0 ? null : startedBefore(now, elapsed),
        restriction: row['is_locked'] == true ? LiveRestriction.password : LiveRestriction.none,
      ),
      malformed: false,
    );
  }

  /// [now] less [seconds], to the whole second: the start of a broadcast the
  /// site says has run that long.
  static DateTime startedBefore(DateTime now, int seconds) {
    final utc = now.toUtc();
    return DateTime.fromMillisecondsSinceEpoch(
      utc.millisecondsSinceEpoch - utc.millisecondsSinceEpoch % 1000,
      isUtc: true,
    ).subtract(Duration(seconds: seconds));
  }

  /// A `//host/…` or `https://host/…` picture as it is served.
  static String? _picture(Object? value) {
    final url = SiteText.trimmed(value);
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }

  static final RegExp _anchor = RegExp(r'<a\b[^>]*>', caseSensitive: false);

  /// The text of the anchor whose tag ended at [from]: up to its `</a>`, with
  /// tags stripped and whitespace collapsed.
  static String _anchorText(String body, int from) {
    final close = body.indexOf('</a>', from);
    if (close < 0) {
      return '';
    }
    return SiteText.title(SiteText.stripTags(body.substring(from, close)));
  }

  /// The channel page → the room. A redirect (>=300) is "not found"; a
  /// secret-word page marks the broadcast protected.
  static ({LiveRoom room, bool secretWord, int? movieId, DateTime? liveStartedAt}) channelPage(
    String body, {
    required String roomId,
    required String channel,
    int status = 200,
  }) {
    if (status >= 300 && status < 400) {
      throw SiteNotFoundError('twitcasting channel page of $channel: HTTP $status (sent home)');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('twitcasting channel page: HTTP $status');
    }
    if (body.contains('Enter the secret word to access')) {
      return (
        room: LiveRoom(platform: SiteIds.twitcasting, roomId: roomId),
        secretWord: true,
        movieId: null,
        liveStartedAt: null,
      );
    }
    String? meta(String attribute, String name) {
      for (final tag in _meta.allMatches(body)) {
        final attributes = _attributes(tag.group(0)!);
        if (attributes[attribute] == name) {
          return attributes['content'];
        }
      }
      return null;
    }

    final creator = meta('name', 'twitter:creator') ?? '';
    if (channelName(creator) != channel) {
      throw SiteApiChangedError('twitcasting channel page of $channel: creator "$creator"');
    }
    final title = meta('name', 'twitter:title') ?? '';
    final telop = _classText(body, 'tw-player-page-title-description');
    final name = _classText(body, 'tw-user-nav2-name');
    final avatar = _classAttribute(body, 'tw-user-nav2-icon', 'img', 'src');
    final movieMatch = RegExp(r'data-movie-id="(\d+)"').firstMatch(body);
    final timerMatch = RegExp('<[^>]*id="updatetimer"[^>]*>', caseSensitive: false).firstMatch(body);
    final timerAttributes = timerMatch == null ? const <String, String>{} : _attributes(timerMatch.group(0)!);
    final started = int.tryParse(timerAttributes['data-started-at'] ?? '');
    return (
      room: LiveRoom(
        platform: SiteIds.twitcasting,
        roomId: roomId,
        title: telop.isNotEmpty ? telop : title,
        nick: name.isEmpty ? channel : name,
        avatar: avatar,
        cover: meta('property', 'og:image'),
      ),
      secretWord: false,
      movieId: movieMatch == null ? null : int.tryParse(movieMatch.group(1)!),
      liveStartedAt: timerAttributes['data-live-type'] == 'live' && started != null && started > 0
          ? DateTime.fromMillisecondsSinceEpoch(started, isUtc: true)
          : null,
    );
  }

  /// The text of the first element carrying [className] (tags stripped).
  static String _classText(String body, String className) {
    final match = RegExp('<[^>]*class="[^"]*$className[^"]*"[^>]*>', caseSensitive: false).firstMatch(body);
    if (match == null) {
      return '';
    }
    final start = match.end;
    final end = body.indexOf('<', start);
    return _stripTags(body.substring(start, end < 0 ? body.length : end)).trim();
  }

  /// The [attribute] of the first [tag] inside the first element carrying
  /// [className].
  static String? _classAttribute(String body, String className, String tag, String attribute) {
    final match = RegExp('<[^>]*class="[^"]*$className[^"]*"[^>]*>', caseSensitive: false).firstMatch(body);
    if (match == null) {
      return null;
    }
    final rest = body.substring(match.end);
    final inner = RegExp('<$tag\\b[^>]*>', caseSensitive: false).firstMatch(rest);
    if (inner == null) {
      return null;
    }
    final value = _attributes(inner.group(0)!)[attribute] ?? '';
    return value.isEmpty ? null : value;
  }

  static String _stripTags(String text) => text.replaceAll(RegExp('<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ');

  /// `streamserver.php` → the broadcast state, movie id and HLS tiers.
  /// `{}` is a channel that does not exist; a private broadcast is not
  /// live for an anonymous client.
  static ({bool live, int? movieId, Map<String, String> streams}) streamServer(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('twitcasting streamserver: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('twitcasting streamserver: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('twitcasting streamserver: body is not an object');
    }
    if (decoded.isEmpty) {
      throw const SiteNotFoundError('twitcasting streamserver: no such channel');
    }
    final movie = decoded['movie'];
    if (movie is! Map<String, Object?>) {
      throw const SiteApiChangedError('twitcasting streamserver: no movie');
    }
    final live = movie['live'];
    if (live is! bool) {
      throw const SiteApiChangedError('twitcasting streamserver: movie.live is not a boolean');
    }
    final streams = <String, String>{};
    final tc = decoded['tc-hls'];
    final rawStreams = tc is Map<String, Object?> ? tc['streams'] : null;
    if (rawStreams is Map<String, Object?>) {
      for (final key in const ['high', 'medium', 'low']) {
        final url = rawStreams[key]?.toString() ?? '';
        if (url.isNotEmpty) {
          streams[key] = url;
        }
      }
    }
    return (live: live, movieId: SiteCounts.integer(movie['id']), streams: streams);
  }

  /// The play lines of a live, unprotected broadcast: the HLS tiers with
  /// their labels, best first.
  static List<LivePlayLine> playLines(({bool live, int? movieId, Map<String, String> streams}) stream, String channel) {
    if (!stream.live) {
      throw const SiteNotFoundError('twitcasting streamserver: not broadcasting');
    }
    final movie = stream.movieId;
    if (movie == null || movie <= 0) {
      throw const SiteApiChangedError('twitcasting streamserver: no movie id');
    }
    final labels = {'high': 'HLS high', 'medium': 'HLS medium', 'low': 'HLS low'};
    final lines = <LivePlayLine>[];
    for (final key in const ['high', 'medium', 'low']) {
      final url = stream.streams[key];
      if (url == null || !url.startsWith('https://') || !url.contains('twitcasting.tv')) {
        continue;
      }
      lines.add(
        LivePlayLine(
          url: url,
          headers: mediaHeaders(channel),
          format: StreamFormat.hls,
          codec: 'avc',
          lineId: labels[key] ?? key,
        ),
      );
    }
    if (lines.isEmpty) {
      throw const SiteApiChangedError('twitcasting streamserver: no valid HLS tier');
    }
    return lines;
  }
}

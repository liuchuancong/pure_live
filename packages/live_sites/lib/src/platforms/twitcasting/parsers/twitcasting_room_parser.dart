import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_html.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

const _site = 'twitcasting';

/// What `streamserver.php` said about a channel's broadcast (3.x kept the
/// qualities made of it in `data`). Only `movie.live` is authoritative: an
/// offline answer still carries the HLS URLs of another broadcast, which are
/// never kept (REG-TWITCASTING-001).
final class TwitcastingRoomData {
  /// Creates the data.
  const TwitcastingRoomData({required this.live, this.movieId, this.streams = const {}, this.secretWord = false});

  /// `movie.live`: whether the channel is broadcasting.
  final bool live;

  /// `movie.id`: the broadcast (a new one each time the channel goes live).
  final int? movieId;

  /// `tc-hls.streams` of a live channel by tier (`high`, `medium`, `low`),
  /// as answered and not yet checked; null when the answer had none. Empty
  /// when offline.
  final Map<String, String>? streams;

  /// Whether the channel page of the same room detail asked for the secret
  /// word: the broadcast is password-protected and is not played (the
  /// unified rule for restricted rooms). False when only `streamserver.php`
  /// was asked.
  final bool secretWord;
}

/// What a channel page says, before `streamserver.php` gives the state: the
/// channel and the broadcast the page shows (the live one, or the last
/// recording when offline).
final class TwitcastingChannelPage {
  /// Creates the page.
  const TwitcastingChannelPage({
    required this.room,
    required this.channel,
    this.movieId,
    this.liveStartedAt,
    this.secretWord = false,
  });

  /// The lower-case channel the page was asked for.
  final String channel;

  /// Names, pictures and the title; no state.
  final LiveRoom room;

  /// `data-movie-id`: the broadcast the page shows.
  final int? movieId;

  /// `data-started-at` of the duration timer when it counts a live
  /// broadcast (`data-live-type="live"`); null for a recording.
  final DateTime? liveStartedAt;

  /// Whether the page asks for the secret word (a protected broadcast).
  final bool secretWord;
}

/// Pure parsing of TwitCasting responses (3.x's `TwitcastingApi`): the
/// homepage tabs, the `top/category` window, the text search page, the
/// channel page, `streamserver.php`, and the v2 rooms, qualities and lines.
/// Each function takes the response text and status.
abstract final class TwitcastingRoomParser {
  // Catalog -------------------------------------------------------------------

  /// The homepage's top tabs (`a.tw-top-tab-item[data-channel]`) as the
  /// areas of the one category, in page order ("For You" has no key and is
  /// left out). A tab without a valid key or label, no tab or more than 100
  /// fail the catalog (api-changed), as in 3.x.
  static List<LiveArea> areas(String body, {int status = 200}) {
    const what = 'home';
    TwitcastingJson.checkStatus(status, what);
    final page = TwitcastingHtml(body);
    final areas = <String, LiveArea>{};
    for (final tag in page.tags()) {
      final key = tag.attributes['data-channel'];
      if (tag.name != 'a' || key == null || !tag.hasClass('tw-top-tab-item')) continue;
      final label = page.textOf(tag).trim();
      if (!TwitcastingEndpoints.areaIdPattern.hasMatch(key) || label.isEmpty) {
        throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: tab "$key" "$label"');
      }
      areas.putIfAbsent(
        key,
        () => LiveArea.normalized(
          platform: _site,
          areaId: key,
          areaName: label,
          parentAreaId: _site,
          parentAreaName: TwitcastingEndpoints.categoryName,
        ),
      );
    }
    if (areas.isEmpty || areas.length > 100) {
      throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: ${areas.length} category tabs');
    }
    return [...areas.values];
  }

  // Directory -----------------------------------------------------------------

  /// The `top/category` window, one entry per row in the site's order: the
  /// room a row shows, or null when it is left out. Left out are ended,
  /// deleted and group broadcasts (3.x; what a group broadcast is was never
  /// seen, 0 of 837 rows on 2026-09-29) and a malformed row (a flag that is
  /// not a boolean, a bad channel, broadcast, `live_url` or viewer count),
  /// which 3.x let fail the whole list (the unified fault-tolerance rule).
  /// A window whose every row is malformed, over
  /// [TwitcastingEndpoints.directoryWindow] rows or not the list is
  /// api-changed.
  ///
  /// A locked broadcast (the secret word) is a live room restricted to
  /// [LiveRestriction.password], where 3.x left it out; any other is
  /// [LiveRestriction.none]. The start time is [now] less `elapsed_time`
  /// (seconds), when [now] is given.
  static List<LiveRoom?> directoryRows(String body, {int status = 200, DateTime? now}) {
    const what = 'top/category';
    TwitcastingJson.checkStatus(status, what);
    final rows = TwitcastingJson.object(TwitcastingJson.decode(body, what), what)['movies'];
    if (rows is! List || rows.length > TwitcastingEndpoints.directoryWindow) {
      throw TwitcastingFailure(
        TwitcastingFailureKind.apiChanged,
        '$what: movies is ${rows is List ? '${rows.length} rows' : rows.runtimeType}',
      );
    }
    final window = [for (final row in rows) _directoryRow(row, now)];
    if (rows.isNotEmpty && window.every((row) => row.malformed)) {
      throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: all ${rows.length} rows malformed');
    }
    return [for (final row in window) row.room];
  }

  /// One `top/category` row: its room, or none when it is left out or
  /// malformed.
  static ({LiveRoom? room, bool malformed}) _directoryRow(Object? raw, DateTime? now) {
    const malformed = (room: null, malformed: true);
    if (raw is! Map) return malformed;
    final row = raw.cast<Object?, Object?>();
    const flags = ['is_live', 'is_locked', 'is_group', 'is_deleted'];
    if (flags.any((flag) => row[flag] is! bool)) return malformed;
    if (row['is_live'] != true || row['is_group'] != false || row['is_deleted'] != false) {
      return (room: null, malformed: false);
    }
    final channel = TwitcastingEndpoints.channelName(TwitcastingJson.text(row['user_id']));
    final movie = TwitcastingJson.integer(row['id']);
    final link = Uri.tryParse(TwitcastingJson.text(row['live_url']));
    final count = TwitcastingJson.integer(row['current_viewer_count']);
    if (channel == null ||
        movie == null ||
        movie <= 0 ||
        link == null ||
        link.hasAuthority ||
        link.hasQuery ||
        link.hasFragment ||
        TwitcastingJson.segments(link) != '$channel/movie/$movie' ||
        count == null ||
        count < 0) {
      return malformed;
    }
    final telop = TwitcastingJson.text(row['telop']);
    final elapsed = TwitcastingJson.integer(row['elapsed_time']);
    final started = now == null || elapsed == null || elapsed < 0 ? null : startedBefore(now, elapsed);
    final room = LiveRoom.normalized(
      platform: _site,
      roomId: channel,
      content: RoomContent.of(
        title: telop.isNotEmpty ? telop : TwitcastingJson.text(row['title']),
        coverUrl: TwitcastingJson.picture(row['thumbnail_url']),
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: channel,
        name: TwitcastingJson.text(row['user_name']),
        avatarUrl: TwitcastingJson.picture(row['user_icon_url']),
        liveStatus: LiveStatus.live,
      ),
      audience: RoomAudience.of(onlineViewers: count, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast.of(
        liveStatus: LiveStatus.live,
        startedAt: started != null && started.millisecondsSinceEpoch > 0 ? started : null,
        restriction: row['is_locked'] == true ? LiveRestriction.password : LiveRestriction.none,
      ),
      links: RoomLinks.of(webUrl: TwitcastingEndpoints.roomUrl(channel)),
    );
    return (room: room, malformed: false);
  }

  /// Rows [offset] to [offset] + [pageSize] of a list [window], as 3.x
  /// sliced it: the rows left out are dropped after slicing, so a page may
  /// hold fewer rooms, and a channel repeated on the page is shown once.
  static List<LiveRoom> slice(List<LiveRoom?> window, {required int offset, required int pageSize}) {
    final rooms = <String, LiveRoom>{};
    for (final room in window.skip(offset).take(pageSize)) {
      if (room != null) rooms.putIfAbsent(room.roomId, () => room);
    }
    return rooms.values.toList(growable: false);
  }

  /// [now] less [seconds], to the whole second: the start of a broadcast
  /// the site says has run that long.
  static DateTime startedBefore(DateTime now, int seconds) {
    final utc = now.toUtc();
    return DateTime.fromMillisecondsSinceEpoch(
      utc.millisecondsSinceEpoch - utc.millisecondsSinceEpoch % 1000,
      isUtc: true,
    ).subtract(Duration(seconds: seconds));
  }

  // Search --------------------------------------------------------------------

  /// The search page's live section (`#tw-search-result-live`; the user,
  /// Premier and recording sections are not live), one entry per row in the
  /// page's order: the room a row shows, or null when it is left out.
  ///
  /// - A row with the LIVE badge that can be played is a live room without
  ///   restriction ([LiveRestriction.none]).
  /// - A private broadcast (the "Private" badge, `data-can-play="false"`) is
  ///   a live room restricted to [LiveRestriction.private] (12-5; M4.12 left
  ///   it out, 3.x failed the whole page). Another row the site will not
  ///   play is [LiveRestriction.unplayable].
  /// - A row that can be played without the LIVE badge is left out (3.x),
  ///   and so is a malformed row (links that do not agree), which 3.x let
  ///   fail the page (the unified fault-tolerance rule).
  ///
  /// The start time is the row's `time[datetime]`. No audience: the page
  /// shows viewers only for private rows. A page without the live section
  /// (a challenge), over [TwitcastingEndpoints.searchWindow] rows or rows
  /// that are all malformed are api-changed.
  static List<LiveRoom?> searchRows(String body, {int status = 200}) {
    const what = 'search';
    TwitcastingJson.checkStatus(status, what);
    final html = TwitcastingHtml(body);
    final section = html.first((tag) => tag.attributes['id'] == 'tw-search-result-live');
    if (section == null) {
      throw const TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: no live section');
    }
    final rows = html.all((tag) => tag.hasClass('tw-search-result-row'), within: section);
    if (rows.length > TwitcastingEndpoints.searchWindow) {
      throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: ${rows.length} live rows');
    }
    final window = [for (final row in rows) _searchRow(html, row)];
    if (rows.isNotEmpty && window.every((row) => row.malformed)) {
      throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: all ${rows.length} live rows malformed');
    }
    return [for (final row in window) row.room];
  }

  /// One live search row: its room, or none when it is left out or
  /// malformed.
  static ({LiveRoom? room, bool malformed}) _searchRow(TwitcastingHtml html, TwitcastingTag row) {
    final badges = html.all((tag) => tag.hasClass('tw-movie-thumbnail2-badge'), within: row);
    final playable = html.first(
      (tag) => tag.hasClass('tw-movie-thumbnail2-image-wrapper') && tag.attributes['data-can-play'] == 'true',
      within: row,
    );
    final LiveRestriction restriction;
    if (playable != null) {
      if (!badges.any((badge) => badge.attributes['data-status'] == 'live')) return (room: null, malformed: false);
      restriction = LiveRestriction.none;
    } else {
      final private = badges.any((badge) => html.textOf(badge).trim().toLowerCase() == 'private');
      restriction = private ? LiveRestriction.private : LiveRestriction.unplayable;
    }
    final user = html.first((tag) => tag.hasClass('tw-search-result-row-user-name'), within: row);
    final userText = user == null ? null : html.first((tag) => tag.hasClass('usertext'), within: user);
    final channelHref = userText == null ? null : html.first((tag) => tag.name == 'a', within: userText);
    final movieHref = html.first((tag) => tag.name == 'a' && tag.hasClass('tw-movie-thumbnail2'), within: row);
    final channel = _searchChannel(movieHref?.attributes['href'] ?? '', channelHref?.attributes['href'] ?? '');
    if (channel == null) return (room: null, malformed: true);
    final title = html.first((tag) => tag.hasClass('tw-movie-thumbnail-title'), within: row);
    final name = user == null ? null : html.first((tag) => tag.hasClass('username'), within: user);
    final cover = html.first((tag) => tag.hasClass('tw-movie-thumbnail2-image'), within: row);
    final avatarBox = html.first((tag) => tag.hasClass('userimage32'), within: row);
    final avatar = avatarBox == null ? null : html.first((tag) => tag.name == 'img', within: avatarBox);
    final date = html.first((tag) => tag.name == 'time' && tag.hasClass('tw-movie-thumbnail-date'), within: row);
    final room = LiveRoom.normalized(
      platform: _site,
      roomId: channel,
      content: RoomContent.of(
        title: title == null ? '' : html.textOf(title).trim(),
        coverUrl: TwitcastingJson.picture(cover?.attributes['src']),
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: channel,
        name: name == null ? channel : html.textOf(name).trim(),
        avatarUrl: TwitcastingJson.picture(avatar?.attributes['src']),
        liveStatus: LiveStatus.live,
      ),
      // The page shows viewers only for private rows: no audience figures.
      audience: RoomAudience.of(primaryMetric: LiveAudienceMetricType.unknown),
      broadcast: RoomBroadcast.of(
        liveStatus: LiveStatus.live,
        startedAt: pageDate(date?.attributes['datetime'] ?? ''),
        restriction: restriction,
      ),
      links: RoomLinks.of(webUrl: TwitcastingEndpoints.roomUrl(channel)),
    );
    return (room: room, malformed: false);
  }

  /// The channel of a live search row, or null when `/{channel}` and
  /// `/{channel}/movie/{movie}` do not agree (3.x's checks).
  static String? _searchChannel(String movieHref, String channelHref) {
    final movieUri = Uri.tryParse(movieHref);
    final channelUri = Uri.tryParse(channelHref);
    if (movieUri == null ||
        channelUri == null ||
        movieUri.hasAuthority ||
        channelUri.hasAuthority ||
        movieUri.hasQuery ||
        movieUri.hasFragment ||
        channelUri.hasQuery ||
        channelUri.hasFragment) {
      return null;
    }
    try {
      final channelParts = channelUri.pathSegments;
      final movieParts = movieUri.pathSegments;
      if (channelParts.length != 1 || movieParts.length != 3) return null;
      final channel = TwitcastingEndpoints.channelName(channelParts.single);
      final movie = TwitcastingJson.integer(movieParts.last);
      if (channel == null ||
          movieParts.first.toLowerCase() != channel ||
          movieParts[1] != 'movie' ||
          movie == null ||
          movie <= 0) {
        return null;
      }
      return channel;
    } on FormatException {
      return null;
    }
  }

  static final RegExp _pageDate = RegExp(
    r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun), (\d{1,2}) ([A-Z][a-z]{2}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$',
  );

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// A page's `datetime` (`Sun, 27 Sep 2026 23:26:34 +0900`, Japan time on
  /// the samples) in UTC, or null when it is not one or not after 1970.
  static DateTime? pageDate(String text) {
    final match = _pageDate.firstMatch(text.trim());
    if (match == null) return null;
    final month = _months.indexOf(match.group(2)!) + 1;
    final [day, year, hour, minute, second, offsetHours, offsetMinutes] = [
      for (final group in [1, 3, 4, 5, 6, 8, 9]) int.parse(match.group(group)!),
    ];
    if (month == 0 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59 || offsetMinutes > 59) {
      return null;
    }
    final local = DateTime.utc(year, month, day, hour, minute, second);
    if (local.day != day) return null;
    final offset = Duration(hours: offsetHours, minutes: offsetMinutes);
    final utc = match.group(7) == '+' ? local.subtract(offset) : local.add(offset);
    return utc.millisecondsSinceEpoch > 0 ? utc : null;
  }

  // Rooms ---------------------------------------------------------------------

  /// The channel page of [channel] ([roomId] as the user asked for it): who
  /// the channel is and which broadcast the page shows, before its state is
  /// asked for.
  ///
  /// - A redirect is an unknown channel: the site sends it to the homepage
  ///   (3.x followed it and reported a schema failure);
  /// - a page asking for the secret word is a protected broadcast: the room
  ///   carries no names (the page shows none that could be checked; a
  ///   follow keeps what it stored) and [TwitcastingChannelPage.secretWord]
  ///   (3.x and M4.12 failed it);
  /// - otherwise the `twitter:creator` meta and the header's `data-user-id`
  ///   must name [channel] (api-changed).
  ///
  /// The title is the broadcast's telop, the text the page shows under its
  /// title (`span.tw-player-page-title-description`, without the hashtags
  /// inside it; 12-1, REG-TWITCASTING-004); without one, the page's
  /// `twitter:title` as 3.x showed it ("Live #…" when the streamer set
  /// none). `twitter:description` is not used: without a telop it is the
  /// channel's profile text (sample S04-page-live-tags).
  static TwitcastingChannelPage channelPage(
    String body, {
    required String roomId,
    required String channel,
    int status = 200,
  }) {
    if (status >= 300 && status < 400) {
      throw TwitcastingFailure(TwitcastingFailureKind.notFound, 'channel page of $channel: HTTP $status (sent home)');
    }
    TwitcastingJson.checkStatus(status, 'channel page');
    if (body.contains('Enter the secret word to access')) {
      return TwitcastingChannelPage(
        room: LiveRoom.normalized(
          platform: _site,
          roomId: roomId,
          links: RoomLinks.of(webUrl: TwitcastingEndpoints.roomUrl(channel)),
        ),
        channel: channel,
        secretWord: true,
      );
    }
    final page = TwitcastingHtml(body);
    String? meta(String attribute, String name) =>
        page.first((tag) => tag.name == 'meta' && tag.attributes[attribute] == name)?.attributes['content'];
    final creators = [
      for (final tag in page.tags())
        if (tag.name == 'meta' && tag.attributes['name'] == 'twitter:creator') tag.attributes['content'] ?? '',
    ];
    if (creators.length != 1 || TwitcastingEndpoints.channelName(creators.single) != channel) {
      throw TwitcastingFailure(
        TwitcastingFailureKind.apiChanged,
        'channel page of $channel: twitter:creator $creators',
      );
    }
    final header = page.first((tag) => tag.hasClass('tw-user-header'));
    if (header == null || TwitcastingEndpoints.channelName(header.attributes['data-user-id'] ?? '') != channel) {
      throw TwitcastingFailure(
        TwitcastingFailureKind.apiChanged,
        'channel page of $channel: header of ${header?.attributes['data-user-id']}',
      );
    }
    final title = meta('name', 'twitter:title') ?? '';
    final telopTag = page.first((tag) => tag.hasClass('tw-player-page-title-description'));
    final telop = telopTag == null ? '' : page.ownText(telopTag).trim();
    final name = page.first((tag) => tag.hasClass('tw-user-nav2-name'));
    final icon = page.first((tag) => tag.hasClass('tw-user-nav2-icon'));
    final avatar = icon == null ? null : page.first((tag) => tag.name == 'img', within: icon);
    final timer = page.first((tag) => tag.hasClass('tw-player-duration-time') && tag.attributes['id'] == 'updatetimer');
    final started = TwitcastingJson.integer(timer?.attributes['data-started-at']);
    final movie = page.first((tag) => tag.attributes.containsKey('data-movie-id'));
    return TwitcastingChannelPage(
      room: LiveRoom.normalized(
        platform: _site,
        roomId: roomId,
        content: RoomContent.of(
          title: telop.isNotEmpty ? telop : (title.trim().isEmpty ? '' : title),
          coverUrl: TwitcastingJson.picture(meta('property', 'og:image')),
        ),
        anchor: LiveAnchor.normalized(
          platform: _site,
          anchorId: channel,
          name: name == null ? channel : page.textOf(name).trim(),
          avatarUrl: TwitcastingJson.picture(avatar?.attributes['src']),
        ),
        links: RoomLinks.of(webUrl: TwitcastingEndpoints.roomUrl(channel)),
      ),
      channel: channel,
      movieId: TwitcastingJson.integer(movie?.attributes['data-movie-id']),
      liveStartedAt: timer?.attributes['data-live-type'] == 'live' && started != null && started > 0
          ? DateTime.fromMillisecondsSinceEpoch(started, isUtc: true)
          : null,
    );
  }

  /// `streamserver.php`: the broadcast state and, when live, its HLS tiers
  /// (checked only when played). `{}` is a channel that does not exist; no
  /// boolean `movie.live` is api-changed. A private broadcast is not live
  /// here, for an anonymous client (sample S05-stream-private).
  static TwitcastingRoomData streamServer(String body, {int status = 200}) {
    const what = 'streamserver';
    TwitcastingJson.checkStatus(status, what);
    final decoded = TwitcastingJson.decode(body, what);
    if (decoded is Map && decoded.isEmpty) {
      throw const TwitcastingFailure(TwitcastingFailureKind.notFound, '$what: {} (no such channel)');
    }
    final root = TwitcastingJson.object(decoded, what);
    final movie = root['movie'];
    if (movie is! Map || movie['live'] is! bool) {
      throw const TwitcastingFailure(TwitcastingFailureKind.apiChanged, '$what: no movie.live');
    }
    final live = movie['live'] == true;
    final id = TwitcastingJson.integer(movie['id']);
    if (!live) return TwitcastingRoomData(live: false, movieId: id);
    final hls = root['tc-hls'];
    final streams = hls is Map ? hls['streams'] : null;
    return TwitcastingRoomData(
      live: true,
      movieId: id,
      streams: streams is Map
          ? {
              for (final key in TwitcastingEndpoints.qualityKeys)
                if (streams.containsKey(key)) key: TwitcastingJson.text(streams[key]),
            }
          : null,
    );
  }

  /// The room of [page] in the state [stream] reports, carrying it for the
  /// streams. When live:
  /// - the start time is the page's, if the page shows the same broadcast
  ///   (a channel that went live between the two requests has none);
  /// - the restriction is [LiveRestriction.password] when the page asked
  ///   for the secret word, else [LiveRestriction.none]: a private broadcast
  ///   is never live to an anonymous client (samples S04/S05-private), so a
  ///   live broadcast is one it can watch;
  /// - the comment arguments are [TwitcastingDanmakuArgs] (12-3, M5).
  ///
  /// Offline, it has neither a start time nor a restriction (unified rule).
  static LiveRoom roomDetail(TwitcastingChannelPage page, TwitcastingRoomData stream) {
    final movie = stream.movieId;
    if (!stream.live) {
      return page.room.rebuild(
        (b) => b
          ..anchor = page.room.anchor?.rebuild((b) => b..liveStatus = LiveStatus.offline).toBuilder()
          ..broadcast.replace(RoomBroadcast.of(liveStatus: LiveStatus.offline))
          ..runtime = RoomRuntime.of(streamHandle: stream).toBuilder(),
      );
    }
    final sameBroadcast = page.movieId == null || movie == null || page.movieId == movie;
    return page.room.rebuild(
      (b) => b
        ..anchor = page.room.anchor?.rebuild((b) => b..liveStatus = LiveStatus.live).toBuilder()
        ..broadcast.replace(
          RoomBroadcast.of(
            liveStatus: LiveStatus.live,
            startedAt: sameBroadcast ? page.liveStartedAt : null,
            restriction: page.secretWord ? LiveRestriction.password : LiveRestriction.none,
          ),
        )
        ..runtime = RoomRuntime.of(
          streamHandle: TwitcastingRoomData(
            live: true,
            movieId: movie,
            streams: stream.streams,
            secretWord: page.secretWord,
          ),
          danmakuHandle: movie != null && movie > 0
              ? TwitcastingDanmakuArgs(channel: page.channel, movieId: movie)
              : null,
        ).toBuilder(),
    );
  }

  // Streams -------------------------------------------------------------------

  /// 3.x's qualities: one per tier of `tc-hls.streams`, labelled `HLS high`,
  /// `HLS medium`, `HLS low`, best first. A channel that is not broadcasting
  /// has none (stream-unavailable), and neither has a password-protected
  /// broadcast ([TwitcastingRoomData.secretWord], stream-unavailable naming
  /// it). A tier URL that is not an https `*.twitcasting.tv` playlist of
  /// this broadcast is left out, the other tiers still play (the unified
  /// fault-tolerance rule; 3.x rejected the whole answer); no valid tier at
  /// all is api-changed.
  static List<LivePlayQuality> qualities(TwitcastingRoomData data) {
    if (!data.live) {
      throw const TwitcastingFailure(TwitcastingFailureKind.streamUnavailable, 'streamserver: not broadcasting');
    }
    if (data.secretWord) {
      throw const TwitcastingFailure(
        TwitcastingFailureKind.streamUnavailable,
        'channel page: the broadcast is password-protected (secret word)',
      );
    }
    final movie = data.movieId;
    final streams = data.streams;
    if (movie == null || movie <= 0) {
      throw TwitcastingFailure(TwitcastingFailureKind.apiChanged, 'streamserver: movie id $movie');
    }
    if (streams == null) {
      throw const TwitcastingFailure(TwitcastingFailureKind.apiChanged, 'streamserver: no tc-hls streams');
    }
    final path = TwitcastingEndpoints.playlistPath(movie);
    final qualities = <LivePlayQuality>[];
    for (final key in TwitcastingEndpoints.qualityKeys) {
      final url = streams[key];
      if (url == null) continue;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.isScheme('https') ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          (uri.hasPort && uri.port != 443) ||
          !(uri.host == TwitcastingEndpoints.host || uri.host.endsWith('.${TwitcastingEndpoints.host}')) ||
          !path.hasMatch(uri.path)) {
        continue;
      }
      qualities.add(LivePlayQuality.of(label: 'HLS $key', qualityId: key, platformOrder: 3 - qualities.length));
    }
    if (qualities.isEmpty) {
      throw TwitcastingFailure(
        TwitcastingFailureKind.apiChanged,
        'streamserver: no valid tc-hls tier of movie $movie: $streams',
      );
    }
    return List.unmodifiable(qualities);
  }

  /// The one line of the tier [qualityId] in [data]: its playlist with 3.x's
  /// media headers (no cookie). The URL carries no signature or expiry, so
  /// there is no lease; the segments need the `lvhls_ssid_{movie}` cookie
  /// the playlist sets, which the player keeps (REG-TWITCASTING-002, M7).
  /// The line is labelled with its CDN node (3.x's line identity). A tier
  /// [qualityId] does not offer is stream-unavailable.
  static List<LivePlayLine> lines(TwitcastingRoomData data, String qualityId) {
    final offered = qualities(data).where((option) => option.qualityId == qualityId).firstOrNull;
    if (offered == null) {
      throw TwitcastingFailure(
        TwitcastingFailureKind.streamUnavailable,
        'streamserver: tier $qualityId is not offered',
      );
    }
    final url = data.streams![qualityId]!;
    return [
      LivePlayLine.of(
        url: url,
        format: LiveStreamFormat.hls,
        formatSource: LivePlayFormatSource.declared,
        headers: TwitcastingEndpoints.headers,
        lineLabel: Uri.parse(url).host,
      ),
    ];
  }
}

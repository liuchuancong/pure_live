// Module: lib/src/twitcasting/twitcasting_api.dart
// Purpose: TwitCasting 的请求面:首页抓出来的分类表、60 行的目录窗口、搜索页 HTML、房间页与 streamserver
// 的在播判定,以及 high/medium/low 三档 hls 地址。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the bounded directory window, the flag checks, the `movie.live` rule, the stale-address
// observation and the media path shape follow the v1-maintained TwitCasting line (origin/master
// lib/shared/platforms/twitcasting/). Fresh implementation against the v2 capability contracts, not a file merge
// (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, twitcasting_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **`movie.live` is the only authority on air-ness, and the page is the only authority on identity.** v1
//     observed offline answers carrying HLS urls for a *different* movie. Every address is therefore read only
//     when that boolean is true, and every address is checked against the movie id the same answer names.
//   * **the directory is a bounded window, not an offset API.** `/top/category` refreshes the top 60; pages are
//     slices of it, and a page past the window is empty rather than an invented continuation.
//   * **four flags have to be booleans.** `is_live`/`is_locked`/`is_group`/`is_deleted` arriving as `0`/`1` is a
//     changed endpoint, not a falsy value - reading it loosely would drop every room or keep every gated one.
//   * **the room is a channel, and a channel name is a whitelist.** The site's own page words (`search`, `show`,
//     `index`, …) are reserved, and a movie/archive url is *not* the channel's current session - substituting the
//     latest broadcast for an old one is how a recorder ends up filing the wrong show.
//   * **the media path is checked before it is trusted**: `/tc.livehls/v1/streams/<movieId>/hls/<n>.<n>/media.m3u8`
//     on the site's own host. A url that names another movie belongs to another broadcast.
//   * **no viewer count is stated on the search page**, so those rooms carry none; 0 would be a number the site
//     never gave us.

import 'dart:convert';

import 'package:html/dom.dart' show Element, Text;
import 'package:html/parser.dart' as html;
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

const String twitcastingSourceId = 'twitcasting.live';
const String twitcastingWebOrigin = 'https://twitcasting.tv';
const String twitcastingDirectoryOrigin = 'https://frontendapi.twitcasting.tv';
const String twitcastingSearchOrigin = 'https://search.twitcasting.tv';

const String twitcastingUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

/// The site checks the origin pair on the player endpoints, and every document it hands us is one of its own pages.
const Map<String, String> twitcastingHeaders = <String, String>{
  'user-agent': twitcastingUserAgent,
  'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'origin': twitcastingWebOrigin,
  'referer': '$twitcastingWebOrigin/',
};

/// The top list the site keeps: 60 broadcasts, paged locally at UI widths. The search page keeps 50.
const int twitcastingDirectoryWindow = 60;
const int twitcastingSearchWindow = 50;
const int twitcastingPageSize = 30;

/// `c:`/`g:`/`f:`/`ig:` are the prefixes the site's own ids carry for a group / global / favourite broadcast.
final RegExp twitcastingChannelPattern = RegExp(r'^(?:(?:c|g|f|ig):)?[a-z0-9_]{1,64}$');

/// A category key as the tab markup states it.
final RegExp twitcastingDirectoryKeyPattern = RegExp(r'^[a-zA-Z0-9_]{1,80}$');

/// The site's own page words: none of these can be somebody's channel, and a url that says so is not a room.
const Set<String> twitcastingReservedChannels = <String>{
  'search',
  'help',
  'login',
  'logout',
  'settings',
  'signup',
  'register',
  'terms',
  'privacy',
  'about',
  'index',
  'show',
  'categories',
};

/// The sentence the password page renders. It is a string match on a document, so it is a heuristic and is
/// recorded as one (`twitcasting.passwordGate`) instead of silently becoming a state the site never stated.
const String twitcastingPasswordMarker = 'Enter the secret word to access';

/// A TwitCasting answer that is not the answer we asked for.
final class TwitcastingFailure implements Exception {
  const TwitcastingFailure(this.message, {this.code, this.cause, this.missing = false});

  final String message;

  /// The http status, when the site's own status is what refused us.
  final int? code;
  final Object? cause;

  /// "No such channel." Not an offline room and not the service being down.
  final bool missing;

  @override
  String toString() =>
      'TwitcastingFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// One category tab of the site's own top bar.
final class TwitcastingCategory {
  const TwitcastingCategory({required this.id, required this.name});

  final String id;
  final String name;

  ContentCategory toContentCategory() => ContentCategory(id: id, name: name);
}

/// One tier of the player answer. The site names exactly three; anything else in the map is not a tier we can
/// label, and inventing a row the answer never named is a promise this path cannot keep.
final class TwitcastingTier {
  const TwitcastingTier({required this.name, required this.label, required this.rank, required this.url});

  /// `high`, `medium` or `low` - the key the site's own stream map uses.
  final String name;
  final String label;

  /// Menu weight: the site's order, not a bitrate (the answer states none).
  final int rank;
  final Uri url;
}

/// The live facts of one channel, as the room page and the stream server agreed on them.
final class TwitcastingRoom {
  const TwitcastingRoom({
    required this.channel,
    required this.state,
    required this.title,
    required this.nick,
    this.avatar = '',
    this.cover = '',
    this.viewers,
    this.movieId,
    this.tiers = const <TwitcastingTier>[],
    this.restriction,
    this.passwordGate = false,
    this.reportedLive,
  });

  final String channel;
  final LiveRoomState state;
  final String title;
  final String nick;
  final String avatar;
  final String cover;

  /// The concurrent count, when the answer stated one. The room page does not; the directory does.
  final int? viewers;

  /// This broadcast's id. Per-broadcast on purpose: it is the danmaku join and the media path segment, and
  /// storing it as the ref would orphan the room the moment the anchor goes off air.
  final int? movieId;
  final List<TwitcastingTier> tiers;
  final LiveRestriction? restriction;

  /// The page rendered its password prompt, so nothing else about it was read.
  final bool passwordGate;

  /// The raw `movie.live`, or null when the answer we have never gave one.
  final bool? reportedLive;

  bool get isLive => state == LiveRoomState.live;

  /// The same room with its tiers. A channel the site calls live while naming no tier stays live and becomes
  /// unplayable - that is the site's answer, and marking it ended would be our invention.
  TwitcastingRoom withTiers(List<TwitcastingTier> found) => TwitcastingRoom(
    channel: channel,
    state: state,
    title: title,
    nick: nick,
    avatar: avatar,
    cover: cover,
    viewers: viewers,
    movieId: movieId,
    tiers: found,
    restriction: isLive && found.isEmpty ? LiveRestriction.unplayable : restriction,
    passwordGate: passwordGate,
    reportedLive: reportedLive,
  );

  /// The room as described, with the addresses left out - the read still says whether the channel is on air.
  TwitcastingRoom withoutTiers() => withTiers(const <TwitcastingTier>[]);

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: twitcastingSourceId, contentId: channel, kind: ContentKind.liveRoom),
    state: state,
    title: title,
    anchorName: nick.isEmpty ? null : nick,
    avatar: avatar.isEmpty ? null : avatar,
    cover: cover.isEmpty ? null : cover,
    link: '$twitcastingWebOrigin/$channel',
    audience: viewers == null ? null : LiveAudience.ofMetric(viewers, LiveAudienceMetric.onlineViewers),
    viewers: viewers,
    viewersMetric: viewers == null ? LiveAudienceMetric.unknown : LiveAudienceMetric.onlineViewers,
    restriction: restriction,
    reportedStateCode: switch (reportedLive) {
      true => 1,
      false => 0,
      null => null,
    },
    streamId: movieId == null ? null : '$movieId',
    danmakuPayload: <String, Object?>{'channel': channel, if (movieId != null) 'movieId': movieId},
    headers: twitcastingHeaders,
    extra: <String, Object?>{if (passwordGate) 'twitcasting.passwordGate': true},
  );
}

/// A list row: the channel, what the site says about it, and the audience it stated.
final class TwitcastingCard {
  const TwitcastingCard({
    required this.channel,
    required this.title,
    required this.nick,
    this.avatar = '',
    this.cover = '',
    this.viewers,
    this.movieId,
    this.restriction,
  });

  final String channel;
  final String title;
  final String nick;
  final String avatar;
  final String cover;
  final int? viewers;
  final int? movieId;
  final LiveRestriction? restriction;

  TwitcastingRoom toRoom() => TwitcastingRoom(
    channel: channel,
    // A row only reaches here when the site listed it as live; that is the site's claim, and the room read is
    // what turns it into a playable fact.
    state: LiveRoomState.live,
    title: title,
    nick: nick,
    avatar: avatar,
    cover: cover,
    viewers: viewers,
    movieId: movieId,
    restriction: restriction,
    reportedLive: true,
  );
}

/// A channel id, normalised the way the site spells it. Invalid or reserved is refused before any request goes
/// out - a page word sent as a channel would come back as a 200-shaped something else.
String twitcastingChannelName(String value) {
  final name = value.trim().toLowerCase();
  if (!twitcastingChannelPattern.hasMatch(name) || twitcastingReservedChannels.contains(name)) {
    throw TwitcastingFailure('not a twitcasting channel: "$value"');
  }
  return name;
}

/// The channel id in a twitcasting url, or null. A movie link and an archive link identify a broadcast rather
/// than the channel's current session, so they yield nothing here.
String? twitcastingChannelFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      !const <String>{'twitcasting.tv', 'www.twitcasting.tv'}.contains(uri.host.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  final parts = uri.pathSegments.toList();
  while (parts.isNotEmpty && parts.last.isEmpty) {
    parts.removeLast();
  }
  if (parts.length != 1) {
    return null;
  }
  try {
    return twitcastingChannelName(parts.single);
  } on TwitcastingFailure {
    return null;
  }
}

/// The category table, scraped from the site's own top bar.
List<TwitcastingCategory> twitcastingCategories(String body) {
  final found = <String, TwitcastingCategory>{};
  for (final Element element in html.parse(body).querySelectorAll('a.tw-top-tab-item[data-channel]')) {
    final key = (element.attributes['data-channel'] ?? '').trim();
    final name = element.text.trim();
    if (!twitcastingDirectoryKeyPattern.hasMatch(key) || name.isEmpty) {
      throw TwitcastingFailure('a category tab names a key we cannot send back: "$key"');
    }
    found.putIfAbsent(key, () => TwitcastingCategory(id: key, name: name));
  }
  if (found.isEmpty || found.length > 100) {
    throw TwitcastingFailure('the category table came back empty or unreasonably long');
  }
  return found.values.toList(growable: false);
}

/// The directory window, as the site filled it. Filtering is the site's own: only a live, unlocked, non-group,
/// non-deleted row is a room this path may show.
List<TwitcastingCard> twitcastingDirectoryRows(Object? value) {
  final rows = jsonMap(value)?['movies'];
  if (rows is! List || rows.length > twitcastingDirectoryWindow) {
    throw TwitcastingFailure('the directory answer carries no list within the window');
  }
  final seen = <String>{};
  final cards = <TwitcastingCard>[];
  for (final Object? raw in rows) {
    final row = jsonMap(raw);
    if (row == null) {
      throw TwitcastingFailure('a directory row is not an object');
    }
    for (final String flag in const <String>['is_live', 'is_locked', 'is_group', 'is_deleted']) {
      if (row[flag] is! bool) {
        throw TwitcastingFailure('the directory flag "$flag" is no longer a boolean');
      }
    }
    if (row['is_live'] != true || row['is_locked'] != false || row['is_group'] != false || row['is_deleted'] != false) {
      continue;
    }
    final channel = twitcastingChannelName('${row['user_id'] ?? ''}');
    final movie = jsonInt(row['id']);
    if (movie == null || movie <= 0) {
      throw TwitcastingFailure('directory row for "$channel" carries no broadcast id');
    }
    // The link the site hands out has to name this channel and this broadcast - a row whose url points elsewhere
    // is a changed endpoint, not a room we can list under two identities.
    final link = Uri.tryParse('${row['live_url'] ?? ''}');
    if (link == null ||
        link.hasAuthority ||
        link.hasQuery ||
        link.hasFragment ||
        link.pathSegments.join('/') != '$channel/movie/$movie') {
      throw TwitcastingFailure('directory row for "$channel" names a url that is not its own broadcast');
    }
    final viewers = jsonInt(row['current_viewer_count']);
    if (viewers == null || viewers < 0) {
      throw TwitcastingFailure('directory row for "$channel" states no concurrent audience');
    }
    if (!seen.add(channel)) {
      continue;
    }
    final telop = twitcastingText(row['telop']);
    cards.add(
      TwitcastingCard(
        channel: channel,
        title: telop.isEmpty ? twitcastingText(row['title']) : telop,
        nick: twitcastingText(row['user_name']),
        cover: twitcastingImage(row['thumbnail_url']),
        avatar: twitcastingImage(row['user_icon_url']),
        viewers: viewers,
        movieId: movie,
        // `is_locked == false` was the filter above, so a listed row is affirmatively openable.
        restriction: LiveRestriction.none,
      ),
    );
  }
  return cards;
}

/// The search page's live section. Text search yields no audience figure, so those rooms carry none.
List<TwitcastingCard> twitcastingSearchRows(String body) {
  final section = html.parse(body).querySelector('#tw-search-result-live');
  if (section == null) {
    throw TwitcastingFailure('the search page carries no live section');
  }
  final rows = section.querySelectorAll('.tw-search-result-row');
  if (rows.length > twitcastingSearchWindow) {
    throw TwitcastingFailure('the search window is longer than the site states');
  }
  final seen = <String>{};
  final cards = <TwitcastingCard>[];
  for (final Element row in rows) {
    if (row.querySelector('.tw-movie-thumbnail2-badge[data-status="live"]') == null) {
      continue;
    }
    final movieUri = Uri.tryParse(row.querySelector('a.tw-movie-thumbnail2')?.attributes['href'] ?? '');
    final channelUri = Uri.tryParse(
      row.querySelector('.tw-search-result-row-user-name .usertext a')?.attributes['href'] ?? '',
    );
    if (movieUri == null ||
        channelUri == null ||
        movieUri.hasAuthority ||
        channelUri.hasAuthority ||
        movieUri.hasQuery ||
        movieUri.hasFragment ||
        channelUri.hasQuery ||
        channelUri.hasFragment ||
        channelUri.pathSegments.length != 1 ||
        movieUri.pathSegments.length != 3) {
      continue;
    }
    final String channel;
    try {
      channel = twitcastingChannelName(channelUri.pathSegments.single);
    } on TwitcastingFailure {
      continue;
    }
    final movie = jsonInt(movieUri.pathSegments.last);
    if (movieUri.pathSegments.first.toLowerCase() != channel ||
        movieUri.pathSegments[1] != 'movie' ||
        movie == null ||
        movie <= 0) {
      throw TwitcastingFailure('a search row names a broadcast that is not its own channel');
    }
    if (!seen.add(channel)) {
      continue;
    }
    final playable = row.querySelector('.tw-movie-thumbnail2-image-wrapper[data-can-play="true"]') != null;
    final passworded =
        !playable &&
        row
            .querySelectorAll('.tw-movie-thumbnail2-badge')
            .any((Element badge) => badge.text.trim().toLowerCase() == 'private');
    cards.add(
      TwitcastingCard(
        channel: channel,
        title: (row.querySelector('.tw-movie-thumbnail-title')?.text ?? '').trim(),
        nick: (row.querySelector('.tw-search-result-row-user-name .username')?.text ?? '').trim(),
        cover: twitcastingImage(row.querySelector('.tw-movie-thumbnail2-image')?.attributes['src']),
        avatar: twitcastingImage(row.querySelector('.userimage32 img')?.attributes['src']),
        movieId: movie,
        // Not playable and not marked private is the site's own "this one will not open", which is a different
        // claim from a room a viewer might be allowed into.
        restriction: playable
            ? LiveRestriction.none
            : passworded
            ? LiveRestriction.private
            : LiveRestriction.unplayable,
      ),
    );
  }
  return cards;
}

/// What the room page says about itself, and whether it says anything at all about a gated broadcast.
///
/// The two identity marks (`twitter:creator` and the header's `data-user-id`) both have to name the channel we
/// asked for: a page that redirects to a different account is not "the same room with new fields".
TwitcastingRoom twitcastingRoomPage(String body, {required String channel}) {
  if (body.contains(twitcastingPasswordMarker)) {
    return TwitcastingRoom(
      channel: channel,
      state: LiveRoomState.live,
      title: '',
      nick: channel,
      passwordGate: true,
      // The gate is a password, and this contract has no password row of its own: `private` is the honest
      // "restricted in a way our session cannot prove". The marker itself stays in the room's extra.
      restriction: LiveRestriction.private,
    );
  }
  final document = html.parse(body);
  final creators = document.querySelectorAll('meta[name="twitter:creator"]');
  if (creators.length != 1) {
    throw TwitcastingFailure('the room page carries ${creators.length} creator marks for "$channel"');
  }
  final declared = (creators.single.attributes['content'] ?? '').trim();
  if (declared.isEmpty || twitcastingChannelName(declared) != channel) {
    throw TwitcastingFailure('the room page is about "${declared.isEmpty ? '?' : declared}", not "$channel"');
  }
  final header = document.querySelector('.tw-user-header');
  if (header == null || twitcastingChannelName(header.attributes['data-user-id'] ?? '') != channel) {
    throw TwitcastingFailure('the room page header does not name "$channel"');
  }
  final telopTag = document.querySelector('.tw-player-page-title-description');
  // Only the element's own text nodes: the title element also holds badges, whose words are not the title.
  final telop = telopTag == null ? '' : telopTag.nodes.whereType<Text>().map((Text node) => node.text).join().trim();
  final twitterTitle = (document.querySelector('meta[name="twitter:title"]')?.attributes['content'] ?? '').trim();
  return TwitcastingRoom(
    channel: channel,
    state: LiveRoomState.unknown,
    title: telop.isEmpty ? twitterTitle : telop,
    nick: (document.querySelector('.tw-user-nav2-name')?.text ?? channel).trim(),
    avatar: twitcastingImage(document.querySelector('.tw-user-nav2-icon img')?.attributes['src']),
    cover: twitcastingImage(document.querySelector('meta[property="og:image"]')?.attributes['content']),
  );
}

/// The stream server's answer: whether the channel is on air, and the tiers it will sign for.
///
/// The page is not consulted here, so an offline answer that still carries an address is read as what it is -
/// a stale url for a broadcast this channel is not airing.
TwitcastingRoom twitcastingStream(Object? value, {required String channel, required TwitcastingRoom page}) {
  final root = jsonMap(value);
  final movie = jsonMap(root?['movie']);
  if (movie == null || movie['live'] is! bool) {
    throw TwitcastingFailure('the stream server did not say whether "$channel" is live');
  }
  final described = TwitcastingRoom(
    channel: channel,
    state: movie['live'] == true ? LiveRoomState.live : LiveRoomState.ended,
    title: page.title,
    nick: page.nick,
    avatar: page.avatar,
    cover: page.cover,
    viewers: page.viewers,
    movieId: movie['live'] == true ? twitcastingMovieId(movie['id'], channel) : null,
    restriction: page.restriction,
    passwordGate: page.passwordGate,
    reportedLive: movie['live'] as bool,
  );
  if (!described.isLive) {
    return described;
  }
  return described.withTiers(
    twitcastingTiers(jsonMap(jsonMap(root?['tc-hls'])?['streams']), movieId: described.movieId!),
  );
}

int twitcastingMovieId(Object? value, String channel) {
  final movie = jsonInt(value);
  if (movie == null || movie <= 0) {
    throw TwitcastingFailure('the stream server calls "$channel" live without naming the broadcast');
  }
  return movie;
}

/// The three tiers, each checked against the broadcast that names it.
List<TwitcastingTier> twitcastingTiers(Object? streams, {required int movieId}) {
  final map = streams is String ? jsonMap(jsonDecode(streams)) : jsonMap(streams);
  if (map == null) {
    throw TwitcastingFailure('the live answer carries no stream map');
  }
  const List<(String, String, int)> known = <(String, String, int)>[
    ('high', 'HLS high', 3),
    ('medium', 'HLS medium', 2),
    ('low', 'HLS low', 1),
  ];
  final tiers = <TwitcastingTier>[];
  for (final (String key, String label, int rank) in known) {
    if (!map.containsKey(key)) {
      continue;
    }
    tiers.add(
      TwitcastingTier(
        name: key,
        label: label,
        rank: rank,
        url: twitcastingMediaUrl('${map[key]}', movieId: movieId),
      ),
    );
  }
  return List<TwitcastingTier>.unmodifiable(tiers);
}

/// One playable address. The path names the broadcast, so a url for another movie is refused instead of being
/// played as "probably the same show".
Uri twitcastingMediaUrl(String raw, {required int movieId}) {
  final uri = Uri.tryParse(raw.trim());
  final host = uri?.host.toLowerCase() ?? '';
  final expected = RegExp('^/tc[.]livehls/v1/streams/$movieId/hls/[0-9]+[.][0-9]+/media[.]m3u8\$');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != 443) ||
      !(host == 'twitcasting.tv' || host.endsWith('.twitcasting.tv')) ||
      !expected.hasMatch(uri.path)) {
    throw TwitcastingFailure('the address for broadcast $movieId is not a twitcasting hls path: "$raw"');
  }
  return uri;
}

String twitcastingText(Object? value) => value is String ? value.trim() : '';

/// The site serves protocol-relative picture urls; a url we cannot open is kept as no picture rather than as a
/// broken string.
String twitcastingImage(Object? value) {
  var text = twitcastingText(value);
  if (text.startsWith('//')) {
    text = 'https:$text';
  }
  final uri = Uri.tryParse(text);
  return uri != null &&
          const <String>{'http', 'https'}.contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? text
      : '';
}

/// One page of a bounded window: the site answers the whole window, so paging is a slice of what it filled.
List<TwitcastingCard> twitcastingWindowPage(List<TwitcastingCard> rows, {required int page, required int pageSize}) {
  final offset = (page - 1) * pageSize;
  if (offset >= rows.length) {
    return const <TwitcastingCard>[];
  }
  final end = offset + pageSize;
  return rows.sublist(offset, end > rows.length ? rows.length : end);
}

/// The TwitCasting client: two documents, one json list and one stream-server answer per room read.
final class TwitcastingApi {
  TwitcastingApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<List<TwitcastingCategory>> categories() async =>
      twitcastingCategories(await _text('$twitcastingWebOrigin/', <String, String>{}));

  /// One page of the bounded window. The window is re-read per page because the site refreshes it continuously -
  /// caching it would freeze a top list, and inventing an offset would claim rows the site never ranked.
  Future<List<TwitcastingCard>> directory({
    int page = 1,
    int pageSize = twitcastingPageSize,
    String category = '',
  }) async {
    if (page < 1 || page > 10000) {
      throw const TwitcastingFailure('directory pages are 1..10000');
    }
    if (pageSize < 1 || pageSize > twitcastingDirectoryWindow) {
      throw const TwitcastingFailure('the directory window is 60 rows wide');
    }
    final key = category.trim();
    if (key.isNotEmpty && !twitcastingDirectoryKeyPattern.hasMatch(key)) {
      throw TwitcastingFailure('not a twitcasting category key: "$category"');
    }
    if ((page - 1) * pageSize >= twitcastingDirectoryWindow) {
      return const <TwitcastingCard>[];
    }
    final rows = await _json('$twitcastingDirectoryOrigin/top/category', <String, String>{
      'id': key,
      'count': '$twitcastingDirectoryWindow',
    });
    return twitcastingWindowPage(twitcastingDirectoryRows(rows), page: page, pageSize: pageSize);
  }

  /// The public text search. A channel url is not a search term - the caller routes it to [room] instead, because
  /// a shared link has to find an offline channel too.
  Future<List<TwitcastingCard>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final term = keyword.trim();
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > twitcastingSearchWindow) {
      throw const TwitcastingFailure('search is 1..10000 pages of at most 50 rows');
    }
    if (term.isEmpty || term.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(term)) {
      throw const TwitcastingFailure('a search term must be 1-100 printable characters');
    }
    if ((page - 1) * pageSize >= twitcastingSearchWindow) {
      return const <TwitcastingCard>[];
    }
    final uri = '$twitcastingSearchOrigin/search/text/${Uri.encodeComponent(term)}';
    return twitcastingWindowPage(
      twitcastingSearchRows(await _text(uri, <String, String>{'hl': 'en'})),
      page: page,
      pageSize: pageSize,
    );
  }

  /// The room, read as the page and the stream server together.
  Future<TwitcastingRoom> room(String input, {bool includeMedia = true}) async {
    final channel = twitcastingChannelName(input);
    final page = twitcastingRoomPage(
      await _text('$twitcastingWebOrigin/$channel', <String, String>{}),
      channel: channel,
    );
    if (page.passwordGate) {
      return page;
    }
    final agreed = twitcastingStream(await _stream(channel), channel: channel, page: page);
    return includeMedia ? agreed : agreed.withoutTiers();
  }

  /// The stream server alone: the cheapest answer that is authoritative about air-ness.
  Future<TwitcastingRoom> status(String input) async {
    final channel = twitcastingChannelName(input);
    return twitcastingStream(
      await _stream(channel),
      channel: channel,
      page: TwitcastingRoom(channel: channel, state: LiveRoomState.unknown, title: '', nick: channel),
    );
  }

  Future<Object?> _stream(String channel) => _json('$twitcastingWebOrigin/streamserver.php', <String, String>{
    'target': channel,
    'mode': 'client',
    'player': 'pc_web',
  });

  Future<Object?> _json(String url, Map<String, String> query) async {
    final body = await _text(url, query);
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw TwitcastingFailure('${Uri.parse(url).host} answered something that is not json', cause: error);
    }
  }

  Future<String> _text(String url, Map<String, String> query) async {
    try {
      final response = await _client.getText(url, headers: twitcastingHeaders, queryParameters: query);
      if (response.statusCode != 200) {
        throw TwitcastingFailure(
          '${Uri.parse(url).host} answered ${response.statusCode}',
          code: response.statusCode,
          missing: response.statusCode == 404,
        );
      }
      return response.body;
    } on NetworkFailure catch (error) {
      throw switch (error.kind) {
        NetworkFailureKind.notFound => TwitcastingFailure(
          'no such channel or page',
          code: error.statusCode,
          missing: true,
        ),
        NetworkFailureKind.forbidden => TwitcastingFailure(
          'the site will not answer this client',
          code: error.statusCode,
        ),
        NetworkFailureKind.rateLimited => TwitcastingFailure(
          'the site is rate-limiting this client',
          code: error.statusCode,
        ),
        NetworkFailureKind.cancelled => TwitcastingFailure('the request was cancelled', code: error.statusCode),
        _ => TwitcastingFailure('the request to ${Uri.parse(url).host} failed', code: error.statusCode, cause: error),
      };
    }
  }
}

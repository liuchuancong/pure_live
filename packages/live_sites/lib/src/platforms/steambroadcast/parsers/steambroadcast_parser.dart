import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Steam Broadcast community APIs.
abstract final class SteamBroadcastParser {
  /// The Steam 64-bit account base for the mini profile path.
  static final BigInt accountBase = BigInt.parse('76561197960265728');

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://steamcommunity.com/',
  };

  /// A Steam id: 17 digits starting with 7656.
  static bool isSteamId(String value) => RegExp(r'^7656\d{13}$').hasMatch(value.trim());

  /// The mini profile URL of [steamId].
  static Uri profileUrl(String steamId) =>
      Uri.https('steamcommunity.com', '/miniprofile/${BigInt.parse(steamId) - accountBase}/json');

  /// `getbroadcastmpd` of [steamId]'s current broadcast.
  static Uri mpdUrl(String steamId) => Uri.https('steamcommunity.com', '/broadcast/getbroadcastmpd/', {
    'broadcastid': '0',
    'steamid': steamId,
    'viewertoken': '0',
    'sessionid': '',
  });

  /// `getbroadcastinfo` of [steamId]'s current broadcast.
  static Uri infoUrl(String steamId) => Uri.https('steamcommunity.com', '/broadcast/getbroadcastinfo/', {
    'steamid': steamId,
    'broadcastid': '0',
    'location': '5',
  });

  /// The watch page of [steamId].
  static String watchUrl(String steamId) => 'https://steamcommunity.com/broadcast/watch/$steamId';

  /// Media headers of [steamId].
  static Map<String, String> mediaHeaders(String steamId) => {
    'user-agent': headers['user-agent']!,
    'referer': watchUrl(steamId),
  };

  /// The mini profile → the broadcaster's name and avatar.
  static ({String name, String avatar}) profile(String body, {required String steamId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('steambroadcast miniprofile: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('steambroadcast miniprofile: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('steambroadcast miniprofile: body is not an object');
    }
    final name = decoded['persona_name'];
    if (name is! String) {
      throw const SiteApiChangedError('steambroadcast miniprofile: no persona_name');
    }
    return (name: name, avatar: decoded['avatar_url']?.toString() ?? '');
  }

  /// `getbroadcastmpd` → the state, restriction, title, viewers and (for
  /// ready broadcasts) the HLS master. A missing/non-text `success` or
  /// `title` is an API change.
  static ({
    LiveStatus status,
    LiveRestriction? restriction,
    String title,
    int? viewers,
    String? broadcastId,
    String? master,
  })
  broadcast(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('steambroadcast getbroadcastmpd: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('steambroadcast getbroadcastmpd: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('steambroadcast getbroadcastmpd: body is not an object');
    }
    final success = decoded['success']?.toString().toLowerCase();
    final title = decoded['title']?.toString() ?? '';
    if (success == null) {
      throw const SiteApiChangedError('steambroadcast getbroadcastmpd: no success');
    }
    final replay = decoded['is_replay'] == true;
    final (state, restriction) = switch (success) {
      'ready' => (replay ? LiveStatus.replay : LiveStatus.live, null),
      'missing_subscription' => (LiveStatus.live, LiveRestriction.subscribersOnly),
      'unavailable' || 'offline' || 'not_live' || 'no_broadcast' => (LiveStatus.offline, null),
      'user_restricted' => (LiveStatus.banned, null),
      _ => (LiveStatus.unknown, null),
    };
    String? master;
    final hls = decoded['hls_url']?.toString() ?? '';
    if (success == 'ready' && hls.startsWith('http')) {
      final cdn = decoded['cdn_auth_url_parameters']?.toString() ?? '';
      master = cdn.isEmpty ? hls : '$hls$cdn';
    }
    return (
      status: state,
      restriction: restriction,
      title: title,
      viewers: SiteCounts.integer(decoded['num_viewers']),
      broadcastId: decoded['broadcastid']?.toString(),
      master: master,
    );
  }

  /// `getbroadcastinfo` → the live facts (the refresh path). `success` 42
  /// is offline; 1 with `is_online` is live or a replay.
  static ({LiveStatus status, String title, String? cover, int? viewers}) info(
    String body, {
    required String steamId,
    int status = 200,
  }) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('steambroadcast getbroadcastinfo: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('steambroadcast getbroadcastinfo: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('steambroadcast getbroadcastinfo: body is not an object');
    }
    final success = SiteCounts.integer(decoded['success']);
    if (success != 1 && success != 42) {
      throw const SiteApiChangedError('steambroadcast getbroadcastinfo: bad success');
    }
    final online = success == 1 && decoded['is_online'] == true;
    if (!online) {
      return (status: LiveStatus.offline, title: '', cover: null, viewers: null);
    }
    final game = decoded['app_title']?.toString() ?? '';
    final title = decoded['title']?.toString() ?? '';
    final thumbnail = decoded['thumbnail_url']?.toString() ?? '';
    return (
      status: decoded['is_replay'] == true ? LiveStatus.replay : LiveStatus.live,
      title: title.isEmpty ? game : title,
      cover: _thumbnail(thumbnail, game),
      viewers: SiteCounts.integer(decoded['viewer_count']),
    );
  }

  /// Builds a room from the clip facts.
  static LiveRoom room({
    required String steamId,
    required LiveStatus status,
    required ({String name, String avatar}) profile,
    String title = '',
    String? cover,
    int? viewers,
    LiveRestriction? restriction,
    String? master,
  }) => LiveRoom(
    platform: SiteIds.steamBroadcast,
    roomId: steamId,
    title: title,
    nick: profile.name,
    avatar: profile.avatar.isEmpty ? null : profile.avatar,
    cover: cover,
    watching: viewers,
    status: status,
    restriction: restriction,
    data: master,
  );

  /// The play lines of a ready broadcast's master.
  static List<LivePlayLine> playLines(Object? data, String steamId) {
    if (data is! String || !data.startsWith('http')) {
      return const [];
    }
    return [
      LivePlayLine(url: data, headers: mediaHeaders(steamId), format: StreamFormat.hls, codec: 'avc', lineId: 'master'),
    ];
  }

  /// The id of the one area: the trending broadcasts.
  static const String areaId = 'trend';

  /// The one area's name.
  static const String areaName = '热门直播';

  /// Broadcasts one directory page carries (the site's own page size, which
  /// the paging form echoes).
  static const int directoryPageSize = 10;

  /// The catalogue: one area, and it is constant — the trending broadcasts —
  /// so no request is spent finding it out.
  static List<LiveArea> areas() => const [LiveArea(id: areaId, name: areaName)];

  /// Whether [area] is the one area this site has.
  static bool isArea(LiveArea area) => area.id.trim() == areaId;

  /// The URL of directory page [page] (the store hub's own trending feed,
  /// asked anonymously).
  static Uri directoryUrl(int page) => Uri.https('steamcommunity.com', '/apps/allcontenthome', {
    'l': 'english',
    'browsefilter': 'trend',
    'appHubSubSection': '13',
    'forceanon': '1',
    'p': '$page',
    'broadcastsoffset': '${(page - 1) * directoryPageSize}',
    'numperpage': '$directoryPageSize',
  });

  /// A directory page — an HTML fragment, one card per broadcast: the
  /// trending broadcasts, each broadcaster once, and whether the site has
  /// another page.
  ///
  /// A card names its broadcast by the watch link it carries; a card without
  /// a usable one, a repeated broadcaster or one that cannot be read is
  /// skipped (Steam writes no JSON here). The hidden form at the end names
  /// the next page: it must echo this page number plus one and the matching
  /// offset — anything else is an ended listing rather than a guess.
  static LivePage<LiveRoom> directory(String body, {required int page, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('steambroadcast allcontenthome: HTTP $status');
    }
    final fragment = html_parser.parseFragment(body);
    final seen = <String>{};
    final items = <LiveRoom>[];
    for (final card in fragment.querySelectorAll('.Broadcast_Card')) {
      final steamId = _cardSteamId(card);
      if (steamId == null || !seen.add(steamId)) {
        continue;
      }
      if (cardRoom(card, steamId) case final room?) {
        items.add(room);
      }
    }
    String? hidden(String name) => fragment.querySelector('input[name="$name"]')?.attributes['value'];
    final nextPage = int.tryParse(hidden('p') ?? '');
    final nextOffset = int.tryParse(hidden('broadcastsoffset') ?? '');
    final hasMore = items.isNotEmpty && nextPage == page + 1 && nextOffset == page * directoryPageSize;
    return LivePage<LiveRoom>(items: items, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// The Steam id a card's watch link names, or null.
  static String? _cardSteamId(dom.Element card) {
    for (final anchor in card.querySelectorAll('a')) {
      final href = anchor.attributes['href'] ?? '';
      final match = RegExp(r'/broadcast/watch/(7656\d{13})').firstMatch(href);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// One card as a room, or null when it names neither a title nor a game.
  ///
  /// The title is the card's content type without its `: Broadcast` suffix,
  /// else the game; the author's name (the account number when Steam writes
  /// no name, which is dropped rather than shown); the thumbnail by the
  /// site's own rule ([_thumbnail]); the avatar at 184 px; the viewers from
  /// its `6,763 viewers` line; and the room is live, because the feed
  /// carries nothing else.
  static LiveRoom? cardRoom(dom.Element card, String steamId) {
    final contentType = _textOf(card.querySelector('.apphub_CardContentType'));
    final game = _textOf(card.querySelector('.apphub_CardContentTitle'));
    if (contentType.isEmpty && game.isEmpty) {
      return null;
    }
    var broadcaster = _textOf(card.querySelector('.apphub_CardContentAuthorName'));
    if (broadcaster == steamId) {
      broadcaster = '';
    }
    final viewersText = _textOf(card.querySelector('.apphub_CardContentViewers'));
    return LiveRoom(
      platform: SiteIds.steamBroadcast,
      roomId: steamId,
      title: _stripBroadcastSuffix(contentType.isEmpty ? game : contentType),
      nick: broadcaster,
      avatar: _avatar(card.querySelector('.appHubIconHolder img')?.attributes['src']),
      cover: _thumbnail(card.querySelector('.apphub_CardContentPreviewImage')?.attributes['src'] ?? '', game),
      watching: _viewers(viewersText),
      status: LiveStatus.live,
    );
  }

  /// `6,763 viewers` → 6763: digits with `,`, `.`, `_` or spaces, then
  /// `viewer(s)`; null for anything else or more than twelve digits.
  static int? _viewers(String text) {
    final match = RegExp(r'^\s*([0-9][0-9,._\s]*)\s+viewers?\b', caseSensitive: false).firstMatch(text);
    final digits = match?.group(1)?.replaceAll(RegExp('[^0-9]'), '') ?? '';
    if (digits.isEmpty || digits.length > 12) {
      return null;
    }
    return int.tryParse(digits);
  }

  /// The avatar Steam serves a card at, at 184 px when it can be rewritten.
  static String? _avatar(String? raw) {
    final url = raw?.trim() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.replaceAll(RegExp(r'/medium(/|$)'), r'/full$1');
  }

  /// An element's own text, tags stripped and whitespace collapsed.
  static String _textOf(dom.Element? element) =>
      element == null ? '' : element.text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// A card title's `: Broadcast` suffix, which the content type carries.
  static String _stripBroadcastSuffix(String title) =>
      title.replaceAll(RegExp(r'\s*:\s*Broadcast\s*$', caseSensitive: false), '').trim();

  /// The thumbnail rule: Steam writes paths that need the hash image host.
  static String? _thumbnail(String raw, String game) {
    if (raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('http')) {
      return raw;
    }
    return 'https://cdn.cloudflare.steamstatic.com/steam/apps/$raw';
  }
}

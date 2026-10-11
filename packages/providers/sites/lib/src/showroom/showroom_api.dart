// Module: lib/src/showroom/showroom_api.dart
// Purpose: SHOWROOM 的请求面:完整在播快照与它的本地翻页、room_url_key→room_id 解析、房间档案、在播状态与聊天服务器、
// 以及 hls / hls_all 两型流地址。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the snapshot-not-paged directory, the cell_type message rows, the durable numeric room id
// beside the public url key, the `live_status == 2` rule, the `view_num` reading and the stream type filter follow
// the v1-maintained SHOWROOM line (origin/master lib/shared/platforms/showroom/). Fresh implementation against the
// v2 capability contracts, not a file merge (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, showroom_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **the room has two names**. `room_id` is the durable number the APIs take; `room_url_key` is the handle in
//     the shared url. The ref is the number, and the handle is resolved once through the status endpoint - which
//     is why a renamed room keeps its favourites.
//   * **the directory is one complete snapshot**. `/api/live/onlives` is not server-paged, so paging is slicing of
//     that snapshot and the total is the snapshot's size; it is reused for half a minute and a failure is never
//     cached as an empty directory.
//   * **a genre with nobody in it carries a message cell, not an empty list.** `cell_type` rows have no `room_id`
//     and are skipped; a row that *does* look like a live is validated strictly, so a real schema change still
//     fails rather than being swallowed with the filler.
//   * **`view_num` is session traffic**, not a concurrent headcount, so it lands on total viewers and a surface
//     that says 人在看 is the surface's mistake, not this reader's.
//   * **on air is `live_status == 2` and the profile's agreement**. `0`/`1` are not live and anything above `2` is
//     a schema change. The status and the chat server come from one endpoint, so they are read once.
//   * **only `hls` and `hls_all` are streams**. The list also carries other types; `hls_all` is the site's own
//     automatic tier and is ranked above a fixed one rather than being treated as a bigger bitrate.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';

const String showroomSourceId = 'showroom.live';
const String showroomOrigin = 'https://www.showroom-live.com';

const String showroomUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

const Map<String, String> showroomHeaders = <String, String>{
  'user-agent': showroomUserAgent,
  'accept': 'application/json, text/plain, */*',
  'referer': '$showroomOrigin/',
};

/// The snapshot's own reuse window, and the width it is paged at locally.
const Duration showroomCatalogLifetime = Duration(seconds: 30);
const int showroomPageSize = 30;

/// The genre id the site uses for its "popular" block; a catalog without it falls back to every live room.
const int showroomPopularGenreId = 0;

/// The most groups, lives or streams one snapshot may carry before it is read as a changed endpoint.
const int showroomGroupLimit = 128;
const int showroomGenreLiveLimit = 5000;
const int showroomStreamLimit = 64;

/// The words the site uses for its own pages, which are therefore never a room handle.
const Set<String> showroomReservedSlugs = <String>{
  'api',
  'room',
  'event',
  'ranking',
  'search',
  'login',
  'register',
  'mypage',
  'premium_live',
};

/// A showroom answer that is not the answer we asked for.
final class ShowroomFailure implements Exception {
  const ShowroomFailure(this.message, {this.code, this.cause, this.missing = false});

  final String message;
  final int? code;
  final Object? cause;

  /// "No such room." Not an offline room and not the service.
  final bool missing;

  @override
  String toString() =>
      'ShowroomFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// One stream address as the site labelled it.
final class ShowroomStream {
  const ShowroomStream({
    required this.id,
    required this.type,
    required this.label,
    required this.quality,
    required this.url,
    required this.isDefault,
  });

  final int id;

  /// `hls` or `hls_all`; the only two this path plays.
  final String type;

  /// The site's own label for the row, which it does ship.
  final String label;
  final int quality;
  final String url;
  final bool isDefault;

  /// The automatic tier ranks above a fixed one because that is what the site's own player does, and `quality`
  /// is a tier code rather than a bitrate.
  int get rank => type == 'hls_all' ? 2000 : quality;

  String get id0 => '$type:$id:$quality';

  /// The site's tier names for its own `quality` bands, in the bands it publishes them.
  String get tierLabel => switch ((type, quality)) {
    ('hls_all', _) => '自動',
    (_, >= 1000) => '原画',
    (_, >= 200) => '中画質',
    (_, _) => '低画質',
  };
}

/// One live room inside the snapshot.
final class ShowroomLive {
  const ShowroomLive({
    required this.roomId,
    required this.slug,
    required this.name,
    required this.genreId,
    required this.telop,
    this.cover = '',
    this.genreName = '',
    this.followers,
    this.totalViewers,
    this.restriction,
    this.streams = const <ShowroomStream>[],
  });

  final int roomId;

  /// `room_url_key` - the public handle in the shared url.
  final String slug;
  final String name;
  final int genreId;
  final String genreName;

  /// The on-screen caption, which is what the site shows as the room's title.
  final String telop;
  final String cover;
  final int? followers;

  /// `view_num`: session traffic. See the file header.
  final int? totalViewers;
  final LiveRestriction? restriction;
  final List<ShowroomStream> streams;

  String get url => '$showroomOrigin/r/$slug';

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: showroomSourceId, contentId: '$roomId', kind: ContentKind.liveRoom),
    // A snapshot row is an on-air listing by construction; the room pipeline is what contradicts it.
    state: LiveRoomState.live,
    title: telop.isEmpty ? name : telop,
    anchorName: name.isEmpty ? null : name,
    anchorId: '$roomId',
    avatar: cover.isEmpty ? null : cover,
    cover: cover.isEmpty ? null : cover,
    area: genreName.isEmpty ? null : genreName,
    areaId: '$genreId',
    link: url,
    audience: totalViewers == null ? null : LiveAudience.ofMetric(totalViewers, LiveAudienceMetric.totalViewers),
    followers: followers,
    restriction: restriction,
    danmakuPayload: <String, Object?>{'roomId': roomId, 'roomUrlKey': slug},
    headers: showroomHeaders,
    sitePayload: const <String, Object?>{},
    extra: <String, Object?>{},
  );
}

/// One genre of the snapshot.
final class ShowroomGenre {
  const ShowroomGenre({required this.id, required this.name, required this.lives});

  final int id;
  final String name;
  final List<ShowroomLive> lives;
}

/// The whole in-air snapshot.
final class ShowroomCatalog {
  ShowroomCatalog(this.genres);

  final List<ShowroomGenre> genres;

  /// The popular block: the site's own genre 0, falling back to every live room only when it is absent.
  List<ShowroomLive> get popular {
    for (final genre in genres) {
      if (genre.id == showroomPopularGenreId) {
        return genre.lives;
      }
    }
    return uniqueLives;
  }

  /// Every live room once, in genre order.
  List<ShowroomLive> get uniqueLives {
    final seen = <int>{};
    return <ShowroomLive>[
      for (final genre in genres)
        for (final live in genre.lives)
          if (seen.add(live.roomId)) live,
    ];
  }

  ShowroomGenre? genre(int id) {
    for (final genre in genres) {
      if (genre.id == id) {
        return genre;
      }
    }
    return null;
  }
}

/// The room profile: what a room is, independent of whether it is on air.
final class ShowroomProfile {
  const ShowroomProfile({
    required this.roomId,
    required this.slug,
    required this.name,
    required this.isOnAir,
    this.cover = '',
    this.genreId,
    this.genreName = '',
    this.description = '',
    this.followers,
    this.totalViewers,
    this.restriction,
    this.startedAt,
  });

  final int roomId;
  final String slug;
  final String name;

  /// `is_onlive`, the profile's own claim.
  final bool isOnAir;
  final String cover;
  final int? genreId;
  final String genreName;
  final String description;
  final int? followers;
  final int? totalViewers;
  final LiveRestriction? restriction;
  final DateTime? startedAt;

  String get url => '$showroomOrigin/r/$slug';
}

/// A room put together: profile, the live-info answer, and the streams when it is on air.
final class ShowroomRoom {
  const ShowroomRoom({
    required this.profile,
    required this.liveStatus,
    required this.streams,
    this.chatHost = '',
    this.chatKey = '',
  });

  final ShowroomProfile profile;

  /// `live_status`: 2 is on air, 0 and 1 are not.
  final int liveStatus;
  final List<ShowroomStream> streams;
  final String chatHost;
  final String chatKey;

  /// On air is the profile's claim **and** the status endpoint's. One saying yes is not enough.
  bool get isLive => profile.isOnAir && liveStatus == 2;

  bool get disagree => profile.isOnAir != (liveStatus == 2);

  LiveRoom toLiveRoom() {
    final ordered = <ShowroomStream>[...streams]
      ..sort((ShowroomStream left, ShowroomStream right) {
        final byRank = right.rank.compareTo(left.rank);
        if (byRank != 0) {
          return byRank;
        }
        // Same tier: the site's own row order breaks the tie, so the menu is stable across reads.
        return left.id0.compareTo(right.id0);
      });
    final quality = isLive
        ? (ordered.isEmpty ? LiveRestriction.unplayable : (profile.restriction ?? LiveRestriction.none))
        : null;
    return LiveRoom(
      ref: ContentRef(sourceId: showroomSourceId, contentId: '${profile.roomId}', kind: ContentKind.liveRoom),
      state: switch ((isLive, disagree)) {
        (true, _) => LiveRoomState.live,
        // One endpoint says on air and the other says not: that is the site not telling, not a room that ended.
        (false, true) => LiveRoomState.unknown,
        (false, false) => LiveRoomState.ended,
      },
      // The profile has no caption field: the room's name is what the site puts on the card.
      title: profile.name,
      anchorName: profile.name.isEmpty ? null : profile.name,
      anchorId: '${profile.roomId}',
      avatar: profile.cover.isEmpty ? null : profile.cover,
      cover: profile.cover.isEmpty ? null : profile.cover,
      area: profile.genreName.isEmpty ? null : profile.genreName,
      areaId: profile.genreId == null ? null : '${profile.genreId}',
      link: profile.url,
      introduction: profile.description.isEmpty ? null : profile.description,
      audience: isLive && profile.totalViewers != null
          ? LiveAudience.ofMetric(profile.totalViewers, LiveAudienceMetric.totalViewers)
          : null,
      followers: profile.followers,
      startedAt: isLive ? profile.startedAt : null,
      restriction: quality,
      reportedStateCode: liveStatus,
      danmakuPayload: <String, Object?>{
        if (isLive && chatHost.isNotEmpty && chatKey.isNotEmpty) 'host': chatHost,
        if (isLive && chatHost.isNotEmpty && chatKey.isNotEmpty) 'key': chatKey,
        'roomId': profile.roomId,
        'roomUrlKey': profile.slug,
      },
      headers: showroomHeaders,
      sitePayload: const <String, Object?>{},
      extra: <String, Object?>{
        if (disagree) 'showroom.disagreement': true,
        if (isLive) 'showroom.streams': ordered.length,
      },
    );
  }
}

/// A durable room id, or the public handle. SHOWROOM takes both in its urls.
String showroomRoomReference(String value) {
  final reference = value.trim();
  if (RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(reference)) {
    return reference;
  }
  return showroomSlug(reference);
}

/// A `room_url_key`: the site's own handle shape, minus the words its pages use.
String showroomSlug(String value) {
  final slug = value.trim();
  if (showroomReservedSlugs.contains(slug.toLowerCase()) || !RegExp(r'^[A-Za-z0-9_\-]{1,128}$').hasMatch(slug)) {
    throw ShowroomFailure('not a showroom room handle: "$slug"');
  }
  return slug;
}

/// The room id or handle in a showroom url, or null.
///
/// `/room/profile?room_id=` is the durable form, `/<handle>` and `/r/<handle>` are the shared ones. A bare
/// number in a path is not a room - the site has no such url - so it is refused here and accepted only as text.
String? showroomRoomFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      !showroomTrustedHost(uri.host.toLowerCase()) ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  final segments = <String>[
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.length == 2 && segments.first == 'room' && segments.last == 'profile') {
    final id = uri.queryParameters['room_id']?.trim() ?? '';
    return RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id) ? id : null;
  }
  if (segments.length == 2 && segments.first == 'r') {
    try {
      return showroomSlug(segments.last);
    } on ShowroomFailure {
      return null;
    }
  }
  if (segments.length == 1) {
    try {
      return showroomSlug(segments.single);
    } on ShowroomFailure {
      return null;
    }
  }
  return null;
}

bool showroomTrustedHost(String host) =>
    host == 'showroom-live.com' ||
    host.endsWith('.showroom-live.com') ||
    host == 'showroom-txlive.com' ||
    host.endsWith('.showroom-txlive.com');

/// A stream address. The two delivery families only, over https, with nothing that could ride along in a fragment.
String showroomMediaUrl(Object? raw) {
  final value = _optional(raw);
  if (raw is! String || raw.length > 8192 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) {
    throw ShowroomFailure('an address this path will not open: "$value"');
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !showroomTrustedHost(uri.host.toLowerCase())) {
    throw ShowroomFailure('an address outside the site\'s own hosts: "$value"');
  }
  return value;
}

/// The chat server's host. It is interpolated into a socket address, so it is shape-checked first.
String showroomCommentHost(Object? raw) {
  final value = _optional(raw).trim().toLowerCase();
  if (value.isEmpty) {
    return '';
  }
  if (value.contains('/') || value.contains(':') || value.contains(' ')) {
    return '';
  }
  return value == 'showroom-live.com' || value.endsWith('.showroom-live.com') ? value : '';
}

/// The chat key: opaque, printable and bounded, or nothing.
String showroomCommentKey(Object? raw) {
  final value = _optional(raw).trim();
  if (value.isEmpty || value.length > 256) {
    return '';
  }
  for (final unit in value.codeUnits) {
    if (unit <= 0x20 || unit == 0x7f) {
      return '';
    }
  }
  return value;
}

/// `premium_room_type`. Zero is the site saying this one is open; a non-zero value is it saying the room is
/// gated without saying how, which is [LiveRestriction.unknown] rather than a guessed 有料.
LiveRestriction? showroomRestriction(Object? raw) {
  if (raw == null || raw == '') {
    return null;
  }
  final value = jsonInt(raw);
  if (value == null || value < 0) {
    return LiveRestriction.unknown;
  }
  return value == 0 ? LiveRestriction.none : LiveRestriction.unknown;
}

/// `current_live_started_at` as unix seconds, and only inside a plausible range.
DateTime? showroomStartedAt(Object? raw) {
  final seconds = jsonInt(raw);
  if (seconds == null || seconds <= 0) {
    return null;
  }
  final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  return time.year >= 2000 && time.year <= 2100 ? time : null;
}

String _image(Object? raw) {
  final value = _optional(raw);
  if (value.isEmpty || value.length > 8192) {
    return '';
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return '';
  }
  return showroomTrustedHost(uri.host.toLowerCase()) ? value : '';
}

String _optional(Object? raw) => raw == null ? '' : '${raw}'.trim();

Map<String, Object?> _object(Object? raw, String what) {
  final map = jsonMap(raw);
  if (map == null) {
    throw ShowroomFailure('$what is not an object');
  }
  return map;
}

List<Object?> _list(Object? raw, {required int max, required String what}) {
  if (raw is! List || raw.length > max) {
    throw ShowroomFailure('$what is missing or unreasonably long');
  }
  return raw;
}

int _positive(Object? raw, String what) {
  final value = jsonInt(raw);
  if (value == null || value < 1) {
    throw ShowroomFailure('$what carries "$raw" where a positive id is expected');
  }
  return value;
}

int _nonNegative(Object? raw, String what) {
  final value = jsonInt(raw);
  if (value == null || value < 0) {
    throw ShowroomFailure('$what carries "$raw" where a number is expected');
  }
  return value;
}

int? _optionalNonNegative(Object? raw) {
  if (raw == null || raw == '') {
    return null;
  }
  return _nonNegative(raw, 'a count');
}

bool _boolean(Object? raw, String what) {
  if (raw is! bool) {
    throw ShowroomFailure('$what carries "$raw" where a bool is expected');
  }
  return raw;
}

String _required(Object? raw, String what) {
  final value = raw is String ? raw.trim() : '';
  if (value.isEmpty || value.length > 8192) {
    throw ShowroomFailure('$what is missing or unreadable');
  }
  return value;
}

/// One live row of the snapshot, or null when it is a filler cell.
///
/// A genre with nobody broadcasting carries a `cell_type` message row rather than an empty list. Those are
/// skipped; a row that looks like a live keeps every strict check, so a real change still fails loudly instead of
/// being swallowed together with the filler.
ShowroomLive? showroomSnapshotLive(Object? raw) {
  final data = _object(raw, 'a live row');
  if (data['room_id'] == null) {
    if (data['cell_type'] == null) {
      throw const ShowroomFailure('a live row carries neither a room id nor a cell type');
    }
    return null;
  }
  final streams = <ShowroomStream>[];
  final seen = <String>{};
  final rows = data['streaming_url_list'];
  if (rows is List) {
    for (final raw in _list(rows, max: showroomStreamLimit, what: 'a snapshot stream list')) {
      final stream = showroomStream(raw);
      if (stream != null && seen.add(stream.url)) {
        streams.add(stream);
      }
    }
  }
  return ShowroomLive(
    roomId: _positive(data['room_id'], 'a live row'),
    slug: showroomSlug('${data['room_url_key'] ?? ''}'),
    name: _required(data['main_name'], 'a live row'),
    cover: _image(data['image_square'] ?? data['image']),
    genreId: _nonNegative(data['genre_id'], 'a genre id'),
    genreName: _optional(data['genre_name']),
    followers: _optionalNonNegative(data['follower_num']),
    totalViewers: _optionalNonNegative(data['view_num']),
    telop: _optional(data['telop']),
    restriction: showroomRestriction(data['premium_room_type']),
    streams: List<ShowroomStream>.unmodifiable(streams),
  );
}

/// One stream row. Types this path cannot play return null rather than being guessed at.
ShowroomStream? showroomStream(Object? raw) {
  final row = _object(raw, 'a stream row');
  final type = _optional(row['type']);
  if (type != 'hls' && type != 'hls_all') {
    return null;
  }
  return ShowroomStream(
    id: _nonNegative(row['id'], 'a stream id'),
    type: type,
    label: _required(row['label'], 'a stream label'),
    quality: _nonNegative(row['quality'], 'a stream quality'),
    url: showroomMediaUrl(row['url']),
    isDefault: _boolean(row['is_default'], 'a stream row'),
  );
}

/// The in-air snapshot.
ShowroomCatalog showroomCatalog(Object? raw) {
  final root = _object(raw, 'the snapshot');
  final groups = _list(root['onlives'], max: showroomGroupLimit, what: 'the genre list');
  final seen = <int>{};
  final genres = <ShowroomGenre>[];
  for (final rawGroup in groups) {
    final group = _object(rawGroup, 'a genre group');
    final id = _nonNegative(group['genre_id'], 'a genre id');
    // The same genre twice is the site repeating a block, and the second copy would double every room under it.
    if (!seen.add(id)) {
      continue;
    }
    final lives = <ShowroomLive>[];
    for (final rawLive in _list(group['lives'], max: showroomGenreLiveLimit, what: 'a genre block')) {
      if (showroomSnapshotLive(rawLive) case final ShowroomLive live) {
        lives.add(live);
      }
    }
    genres.add(ShowroomGenre(id: id, name: _required(group['genre_name'], 'a genre name'), lives: lives));
  }
  if (genres.isEmpty) {
    throw const ShowroomFailure('the snapshot carries no genres');
  }
  return ShowroomCatalog(genres);
}

/// The SHOWROOM client.
final class ShowroomApi {
  ShowroomApi({NetworkClient? client, Clock? clock})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _clock = clock ?? systemClock;

  final NetworkClient _client;
  final bool _ownsClient;
  final Clock _clock;

  ShowroomCatalog? _catalog;
  DateTime? _catalogAt;
  Future<ShowroomCatalog>? _catalogInFlight;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The in-air snapshot, reused for the length of one scroll.
  ///
  /// A failure is not cached - one抖 should not blank the directory for the rest of the process - and concurrent
  /// callers share one request.
  Future<ShowroomCatalog> catalog() {
    final at = _catalogAt;
    final cached = _catalog;
    final now = _clock();
    if (cached != null && at != null && now.difference(at) < showroomCatalogLifetime) {
      return Future<ShowroomCatalog>.value(cached);
    }
    final running = _catalogInFlight;
    if (running != null) {
      return running;
    }
    late final Future<ShowroomCatalog> operation;
    operation = _fetchCatalog()
        .then((ShowroomCatalog catalog) {
          _catalog = catalog;
          _catalogAt = _clock();
          return catalog;
        })
        .whenComplete(() {
          if (identical(_catalogInFlight, operation)) {
            _catalogInFlight = null;
          }
        });
    _catalogInFlight = operation;
    return operation;
  }

  Future<ShowroomCatalog> _fetchCatalog() async =>
      showroomCatalog(await _get('/api/live/onlives', const <String, String>{}));

  /// The room id behind a reference: the number when one was given, otherwise the handle resolved once.
  Future<int> resolveRoomId(String reference) async {
    final normalized = reference.trim();
    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric > 0) {
      return numeric;
    }
    final data = _object(
      await _get('/api/room/status', <String, String>{'room_url_key': showroomSlug(normalized)}),
      'the status answer',
    );
    return _positive(data['room_id'], 'the status answer');
  }

  Future<ShowroomProfile> profile(int roomId) async {
    final data = _object(await _get('/api/room/profile', <String, String>{'room_id': '$roomId'}), 'the profile answer');
    final actual = _positive(data['room_id'], 'the profile answer');
    if (actual != roomId) {
      throw ShowroomFailure('the profile answer is about ${actual} while asking about $roomId');
    }
    return ShowroomProfile(
      roomId: actual,
      slug: showroomSlug('${data['room_url_key'] ?? ''}'),
      name: _required(data['main_name'] ?? data['room_name'], 'the profile answer'),
      isOnAir: _boolean(data['is_onlive'], 'the profile answer'),
      cover: _image(data['image_square']),
      genreId: _optionalNonNegative(data['genre_id']),
      genreName: _optional(data['genre_name']),
      description: _optional(data['description']),
      followers: _optionalNonNegative(data['follower_num']),
      // Session traffic, not a concurrent headcount: see the file header.
      totalViewers: _optionalNonNegative(data['view_num']),
      restriction: showroomRestriction(data['premium_room_type']),
      startedAt: showroomStartedAt(data['current_live_started_at']),
    );
  }

  /// The live status **and** the chat server, which the same endpoint answers.
  Future<({int status, String host, String key})> liveInfo(int roomId) async {
    final data = _object(
      await _get('/api/live/live_info', <String, String>{'room_id': '$roomId'}),
      'the live info answer',
    );
    final actual = _positive(data['room_id'], 'the live info answer');
    if (actual != roomId) {
      throw ShowroomFailure('the live info answer is about $actual while asking about $roomId');
    }
    final status = _nonNegative(data['live_status'], 'the live info answer');
    if (status > 2) {
      throw ShowroomFailure('the live info answer reports status $status');
    }
    return (status: status, host: showroomCommentHost(data['bcsvr_host']), key: showroomCommentKey(data['bcsvr_key']));
  }

  /// The stream addresses. Types other than hls are not asked for here and not played elsewhere either.
  Future<List<ShowroomStream>> streams(int roomId) async {
    final data = _object(
      await _get('/api/live/streaming_url', <String, String>{'room_id': '$roomId', 'abr_available': '1'}),
      'the stream answer',
    );
    final seen = <String>{};
    final streams = <ShowroomStream>[];
    for (final raw in _list(data['streaming_url_list'], max: showroomStreamLimit, what: 'the stream list')) {
      final stream = showroomStream(raw);
      if (stream != null && seen.add(stream.url)) {
        streams.add(stream);
      }
    }
    return List<ShowroomStream>.unmodifiable(streams);
  }

  /// A room, in the fewest calls that answer it: profile, one live-info read, and streams only when it is on air.
  Future<ShowroomRoom> room(String reference, {bool withMedia = false}) async {
    final roomId = await resolveRoomId(reference);
    final profileResult = await profile(roomId);
    final info = await liveInfo(roomId);
    final onAir = profileResult.isOnAir && info.status == 2;
    return ShowroomRoom(
      profile: profileResult,
      liveStatus: info.status,
      chatHost: info.host,
      chatKey: info.key,
      streams: !onAir || !withMedia ? const <ShowroomStream>[] : await streams(roomId),
    );
  }

  Future<Object?> _get(String path, Map<String, String> query) async {
    final response = await _client.getText('$showroomOrigin$path', headers: showroomHeaders, queryParameters: query);
    if (response.statusCode != 200) {
      throw ShowroomFailure(
        switch (response.statusCode) {
          401 || 403 => 'the site asked for an account this path does not have',
          404 => 'no such room',
          429 => 'the site is rate-limiting this client',
          _ when response.statusCode >= 500 => 'the site failed the request',
          _ => 'the $path endpoint did not answer',
        },
        code: response.statusCode,
        missing: response.statusCode == 404,
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ShowroomFailure('$path answered something that is not json', cause: error);
    }
  }
}

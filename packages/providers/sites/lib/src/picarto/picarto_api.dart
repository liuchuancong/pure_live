// Module: lib/src/picarto/picarto_api.dart
// Purpose: Picarto 的请求面:explore 分页与它的自我核对、频道详情里的负载均衡源与唯一流、语言分类表、
// 主播搜索,以及主清单按身份分组出来的清晰度。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the pagination self-check, the adult and playable filters, the single-stream match, the
// load-balancer origin rule and the quality identity all follow the v1-maintained Picarto line (origin/master
// lib/shared/platforms/picarto/). Fresh implementation against the v2 capability contracts, not a file merge
// (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, picarto_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **the room is the channel name**, not a number. It is `[A-Za-z0-9_]{1,50}` and the site's own page words
//     (`search`, `login`, `about`, …) are reserved: they are paths the site has for other reasons, and resolving
//     one as someone's channel gives a room that never existed.
//   * **the paginated answer has to describe the request**. `current_page`, `per_page`, `last_page` and `total`
//     are all checked against what was asked, and a page past `last_page` carrying rows is a schema change - a
//     pager that ignored that would loop the same rooms forever.
//   * **filtering is not a status**. An adult row or an unplayable row is dropped from the grid; the site's own
//     page does not get padded by fetching more pages, and its `hasNext` is not followed blindly.
//   * **one channel, one stream**. The multi-stream list is matched against the channel's own id and must return
//     exactly one row; two is a changed endpoint and zero is a room with no stream to name.
//   * **the load-balancer origin is a hostname fragment**, matched to `[a-z0-9]+(-[a-z0-9]+)*` and length-limited
//     before it is interpolated into a url: an origin the answer made up would send the player somewhere else.
//   * **quality identity excludes the cdn host, the signed path and the fluctuating bandwidth.** Two renditions of
//     the same resolution/frame-rate/codec are one quality with two addresses, and the master is kept as an
//     explicit "auto" option whenever the playlist carries external audio, because picking a bare video variant
//     there would silently drop the sound.

import 'dart:convert';

import 'package:html/parser.dart' show parseFragment;
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

const String picartoSourceId = 'picarto.live';
const String picartoOrigin = 'https://picarto.tv';
const String picartoApiOrigin = 'https://ptvintern.picarto.tv';

const String picartoUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const Map<String, String> picartoHeaders = <String, String>{
  'user-agent': picartoUserAgent,
  'referer': '$picartoOrigin/',
  'origin': picartoOrigin,
  'accept': 'application/json, text/plain, */*',
};

/// The explore page's own row count. It is the server's number, so a caller asking for 60 is told what came back.
const int picartoServerPageSize = 30;

/// The words the site uses for its own pages, which are therefore never a channel name.
const Set<String> picartoReservedNames = <String>{
  'explore',
  'search',
  'settings',
  'login',
  'signup',
  'register',
  'password',
  'terms',
  'privacy',
  'help',
  'about',
};

final RegExp _channelPattern = RegExp(r'^[a-zA-Z0-9_]{1,50}$');

/// A Picarto answer that is not the answer we asked for.
final class PicartoFailure implements Exception {
  const PicartoFailure(this.message, {this.code, this.cause, this.missing = false});

  final String message;
  final int? code;
  final Object? cause;

  /// "No such channel." A fact about the name, not an offline room and not the service.
  final bool missing;

  @override
  String toString() =>
      'PicartoFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// One channel as an answer described it.
final class PicartoChannel {
  const PicartoChannel({
    required this.name,
    required this.channelId,
    required this.online,
    this.isPrivate,
    this.title = '',
    this.avatar = '',
    this.cover = '',
    this.category = '',
    this.viewers,
    this.totalViews,
    this.introduction,
    this.followers,
  });

  /// The room key: the channel name in the url.
  final String name;
  final String channelId;

  /// `online`: the site's own boolean. A row that does not carry it is not a channel.
  final bool online;

  /// `private`, and only where the answer states it. Null means this endpoint never said.
  final bool? isPrivate;
  final String title;
  final String avatar;
  final String cover;

  /// The channel's categories, joined with the site's own separator.
  final String category;

  /// `viewers` - concurrent, and `total_views` - cumulative. Two different questions.
  final int? viewers;
  final int? totalViews;
  final String? introduction;
  final int? followers;

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: picartoSourceId, contentId: name, kind: ContentKind.liveRoom),
    state: online ? LiveRoomState.live : LiveRoomState.ended,
    title: title,
    anchorName: name,
    anchorId: channelId,
    avatar: avatar.isEmpty ? null : avatar,
    cover: cover.isEmpty ? null : cover,
    area: category.isEmpty ? null : category,
    link: picartoChannelUrl(name),
    introduction: introduction,
    followers: followers,
    audience: (viewers == null && totalViews == null)
        ? null
        : LiveAudience(onlineViewers: viewers, totalViewers: totalViews, metric: LiveAudienceMetric.onlineViewers),
    restriction: restriction,
    danmakuPayload: <String, Object?>{'channelName': name},
    headers: picartoHeaders,
    sitePayload: const <String, Object?>{},
    extra: <String, Object?>{},
  );

  LiveRestriction? get restriction {
    if (!online) {
      return null;
    }
    if (isPrivate == true) {
      return LiveRestriction.private;
    }
    // The detail endpoint states `private`; a listing that never mentions it has not claimed the room is open.
    return isPrivate == null ? null : LiveRestriction.none;
  }

  AnchorSummary toAnchorSummary() => AnchorSummary(
    ref: ContentRef(sourceId: picartoSourceId, contentId: name, kind: ContentKind.anchor),
    name: name,
    avatar: avatar.isEmpty ? null : avatar,
    fans: followers,
    description: introduction,
    currentRoom: online ? ContentRef(sourceId: picartoSourceId, contentId: name, kind: ContentKind.liveRoom) : null,
  );
}

/// The channel page for a name.
String picartoChannelUrl(String name) => '$picartoOrigin/${Uri.encodeComponent(picartoChannelName(name))}';

/// A channel name, checked against the site's own shape and its reserved words.
String picartoChannelName(String value) {
  final name = value.trim();
  if (!_channelPattern.hasMatch(name) || picartoReservedNames.contains(name.toLowerCase())) {
    throw PicartoFailure('not a picarto channel name: "$name"');
  }
  return name;
}

/// The channel in a picarto url, or null. One path segment and nothing else: `/channel/artwork` is a page the
/// site has, not a streamer.
String? picartoChannelFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      !const <String>{'picarto.tv', 'www.picarto.tv'}.contains(uri.host.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  final parts = <String>[
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (parts.length != 1) {
    return null;
  }
  try {
    return picartoChannelName(parts.single);
  } on PicartoFailure {
    return null;
  }
}

/// A picture address, or the empty string when it is not one.
String picartoImage(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return '';
  }
  final candidate = value.startsWith('//') ? 'https:$value' : value;
  final uri = Uri.tryParse(candidate);
  if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
    return '';
  }
  return uri.userInfo.isNotEmpty ? '' : candidate;
}

/// A bio, unescaped. The site stores html entities in it (`&amp;`, `&nbsp;`), and showing those to a viewer is
/// the profile text being wrong rather than the profile being empty.
String? picartoBio(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  return value.contains('&') ? (parseFragment(value).text ?? value).trim() : value;
}

/// One channel row. `detail` is the endpoint that also states `private`; a listing that omits it is not a
/// channel that said it is open.
PicartoChannel picartoChannel(Object? raw, {String? expectedName, bool detail = false}) {
  final row = _object(raw, 'a channel row');
  final name = picartoChannelName(_text(row['name']));
  final id = jsonInt(row['id']);
  final online = row['online'];
  final private = row['private'];
  if (id == null || id <= 0) {
    throw PicartoFailure('the channel $name carries no usable id');
  }
  if (online is! bool) {
    throw PicartoFailure('the channel $name carries no online flag');
  }
  if (expectedName != null && name.toLowerCase() != expectedName.toLowerCase()) {
    throw PicartoFailure('the answer is about $name while asking about $expectedName');
  }
  if (detail && private is! bool) {
    throw PicartoFailure('the channel detail for $name carries no privacy flag');
  }
  final viewers = jsonInt(row['viewers']);
  final total = jsonInt(row['total_views']);
  return PicartoChannel(
    name: name,
    channelId: '$id',
    online: online,
    isPrivate: private is bool ? private : null,
    title: _text(row['title']),
    avatar: picartoImage(row['avatar']),
    cover: picartoImage(row['image_thumbnail']),
    category: _categoryNames(row['categories']),
    viewers: viewers != null && viewers >= 0 ? viewers : null,
    totalViews: total != null && total >= 0 ? total : null,
    introduction: picartoBio(row['bio']),
    followers: _nonNegative(row['follower_count']),
  );
}

String _categoryNames(Object? raw) {
  if (raw is! List) {
    return '';
  }
  return <String>[
    for (final value in raw)
      if (_text(jsonMap(value)?['name']) case final String label when label.isNotEmpty) label,
  ].join(' / ');
}

/// The language/category table.
List<PicartoCategory> picartoCategories(Object? raw) {
  final data = _object(raw, 'the category answer');
  final rows = data['categories'];
  if (rows is! List || rows.isEmpty || rows.length > 200) {
    throw const PicartoFailure('the category table is missing, empty or unreasonably long');
  }
  final result = <int, PicartoCategory>{};
  for (final raw in rows) {
    final category = _object(raw, 'a category row');
    final id = jsonInt(category['id']);
    final label = _text(category['label']);
    if (id == null || id <= 0 || label.isEmpty || label.length > 100) {
      throw PicartoFailure('a category row carries "$id"/"$label"');
    }
    if (result.containsKey(id)) {
      throw PicartoFailure('the category table repeats id $id');
    }
    result[id] = PicartoCategory(id: id, name: label);
  }
  return List<PicartoCategory>.unmodifiable(result.values);
}

final class PicartoCategory {
  const PicartoCategory({required this.id, required this.name});

  final int id;
  final String name;

  ContentCategory toContentCategory() => ContentCategory(id: '$id', name: name);
}

/// One explore page, checked against the request it answers.
({List<PicartoChannel> rooms, int page, int lastPage, int total, bool hasMore}) picartoDirectory(
  Object? raw, {
  required int page,
  required int pageSize,
  int? categoryId,
}) {
  final data = _object(raw, 'the explore answer');
  final rows = data['data'];
  final lastPage = jsonInt(data['last_page']);
  final total = jsonInt(data['total']);
  if (rows is! List ||
      rows.length > pageSize ||
      jsonInt(data['current_page']) != page ||
      jsonInt(data['per_page']) != pageSize ||
      lastPage == null ||
      lastPage < 1 ||
      total == null ||
      total < 0 ||
      (page > lastPage && rows.isNotEmpty)) {
    // A page that does not describe the request is not a page: trusting it makes a pager repeat or skip rooms.
    throw const PicartoFailure('the explore answer does not describe this request');
  }
  final rooms = <String, PicartoChannel>{};
  for (final raw in rows) {
    final row = _object(raw, 'an explore row');
    if (row['adult'] is! bool) {
      throw PicartoFailure('the row ${row['name']} carries no adult flag');
    }
    if (categoryId != null) {
      // A filtered answer must actually contain the filter. A server that ignored it would otherwise fill a
      // category with rooms that are not in it.
      final categories = row['categories'];
      if (categories is! List || !categories.any((Object? value) => jsonInt(jsonMap(value)?['id']) == categoryId)) {
        throw PicartoFailure('a category row is not in the category that was asked for');
      }
    }
    final channel = picartoChannel(row);
    // Adult rows and offline rows are dropped from this grid - and dropping is not the same as marking them
    // offline, which is why nothing here invents a status for them.
    if (row['adult'] != false || !channel.online) {
      continue;
    }
    rooms.putIfAbsent(channel.name.toLowerCase(), () => channel);
  }
  return (
    rooms: rooms.values.toList(growable: false),
    page: page,
    lastPage: lastPage,
    total: total,
    hasMore: page < lastPage,
  );
}

/// The profile search block. Its `count` is inconsistent across pages, so continuation is decided on returned
/// rows, never on the total the endpoint claims.
List<PicartoChannel> picartoProfiles(Object? raw, {required int pageSize}) {
  final payload = _object(raw, 'the search answer');
  final result = _object(payload['searchProfiles'], 'the profile search block');
  final rows = result['data'];
  if (rows is! List || rows.length > pageSize) {
    throw const PicartoFailure('the profile search returned more rows than were asked for');
  }
  final rooms = <String, PicartoChannel>{};
  for (final raw in rows) {
    final channel = picartoChannel(raw);
    rooms.putIfAbsent(channel.name.toLowerCase(), () => channel);
  }
  return List<PicartoChannel>.unmodifiable(rooms.values);
}

/// One rendition group of the master playlist.
final class PicartoQuality {
  const PicartoQuality({
    required this.id,
    required this.label,
    required this.rank,
    required this.urls,
    this.isAuto = false,
  });

  final String id;
  final String label;

  /// The highest bandwidth the site stated for this identity; the value the menu sorts by.
  final int rank;
  final List<String> urls;

  /// The master itself, offered when the playlist cannot be reduced to named variants.
  final bool isAuto;
}

/// The playlist, grouped by identity.
///
/// Identity is resolution, frame rate and codec - **not** the cdn host, not the signed path and not the
/// bandwidth, all three of which the site varies while meaning the same picture. Metadata and its address are
/// paired while walking the file rather than matched by position, because a playlist that skips a variant line
/// would otherwise be read as a shifted menu.
List<PicartoQuality> picartoQualities(String content, Uri master) {
  if (content.length > 1024 * 1024 || content.trimLeft().split('\n').first.trim() != '#EXTM3U') {
    throw const PicartoFailure('the playlist is not an m3u8');
  }
  final grouped = <String, _PicartoDraft>{};
  Map<String, String>? pending;
  var hasExternalAudio = false;
  var hasMedia = false;
  var hasMediaUri = false;
  for (final raw in const LineSplitter().convert(content)) {
    final line = raw.trim();
    if (line.startsWith('#EXT-X-MEDIA:') && line.contains('TYPE=AUDIO') && line.contains('URI=')) {
      hasExternalAudio = true;
    }
    if (line.startsWith('#EXTINF:')) {
      hasMedia = true;
    }
    if (line.startsWith('#EXT-X-STREAM-INF:')) {
      if (pending != null) {
        throw const PicartoFailure('two variant lines with no address between them');
      }
      pending = <String, String>{
        for (final match in RegExp('([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(line.substring(18)))
          match.group(1)!: (match.group(2) ?? '').replaceAll('"', ''),
      };
      continue;
    }
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (pending == null) {
      if (hasMedia) {
        // A media-address-bearing playlist whose addresses are segments: this is a media playlist, and its own
        // address is what plays.
        _requireAddress(master.resolve(line));
        hasMediaUri = true;
      }
      continue;
    }
    final attrs = pending;
    pending = null;
    final uri = master.resolve(line);
    _requireAddress(uri);
    final bandwidth = int.tryParse(attrs['BANDWIDTH'] ?? '');
    final resolution = attrs['RESOLUTION'] ?? '';
    final size = RegExp(r'^([1-9][0-9]*)x([1-9][0-9]*)$').firstMatch(resolution);
    final fps = double.tryParse(attrs['FRAME-RATE'] ?? '0');
    if (bandwidth == null ||
        bandwidth <= 0 ||
        (resolution.isNotEmpty && size == null) ||
        fps == null ||
        !fps.isFinite ||
        fps < 0) {
      throw const PicartoFailure('a variant states no usable bandwidth, resolution or frame rate');
    }
    final codec = attrs['CODECS'] ?? '';
    // The identity deliberately excludes the bandwidth when a resolution exists: two renditions of one picture
    // shipped at different target rates are one choice, and the better rate is the one that ranks.
    final id = jsonEncode(<Object?>[
      resolution,
      fps,
      codec,
      attrs['VIDEO'],
      attrs['AUDIO'],
      if (size == null) bandwidth,
    ]);
    final label = size == null
        ? 'HLS ${(bandwidth / 1000000).toStringAsFixed(1)} Mbps'
        : '${size.group(2)}p${fps > 0 ? ' ${fps == fps.roundToDouble() ? fps.toInt() : fps}fps' : ''}';
    (grouped[id] ??= _PicartoDraft(id: id, label: label)).add(bandwidth: bandwidth, url: uri.toString());
  }
  if (pending != null || (grouped.isEmpty && !hasMediaUri)) {
    throw const PicartoFailure('the playlist names no variant and no media');
  }
  // External audio means a bare video variant would drop the sound. The master is kept as an explicit automatic
  // choice rather than claimed as a tier.
  if (hasExternalAudio || grouped.isEmpty) {
    return <PicartoQuality>[
      PicartoQuality(
        id: 'master',
        label: 'HLS Auto',
        rank: 0,
        urls: List<String>.unmodifiable(<String>[master.toString()]),
        isAuto: true,
      ),
    ];
  }
  final qualities = grouped.values.map((_PicartoDraft draft) => draft.quality).toList(growable: false)
    ..sort((PicartoQuality left, PicartoQuality right) => right.rank.compareTo(left.rank));
  return List<PicartoQuality>.unmodifiable(qualities);
}

void _requireAddress(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const PicartoFailure('a playlist address is not one this path can open');
  }
}

final class _PicartoDraft {
  _PicartoDraft({required this.id, required this.label});

  /// The identity json: resolution, frame rate, codec and the variant's own stream ids.
  final String id;
  final String label;
  int rank = 0;
  final Set<String> urls = <String>{};

  void add({required int bandwidth, required String url}) {
    if (bandwidth > rank) {
      rank = bandwidth;
    }
    urls.add(url);
  }

  PicartoQuality get quality => PicartoQuality(id: id, label: label, rank: rank, urls: List<String>.unmodifiable(urls));
}

Map<String, Object?> _object(Object? raw, String what) {
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } on FormatException catch (error) {
      throw PicartoFailure('$what is not readable json', cause: error);
    }
  }
  final map = jsonMap(raw);
  if (map == null) {
    throw PicartoFailure('$what is not an object');
  }
  return map;
}

String _text(Object? raw) => raw is String ? raw.trim() : '';

int? _nonNegative(Object? raw) {
  final value = jsonInt(raw);
  return value != null && value >= 0 ? value : null;
}

/// The Picarto client.
final class PicartoApi {
  PicartoApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<List<PicartoCategory>> categories() async =>
      picartoCategories(await _get('$picartoApiOrigin/api/languages-categories'));

  /// One explore page, optionally filtered by a category id.
  Future<({List<PicartoChannel> rooms, int page, int lastPage, int total, bool hasMore})> directory({
    int page = 1,
    int pageSize = picartoServerPageSize,
    int? categoryId,
  }) async {
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > 60) {
      throw const PicartoFailure('explore pages are 1..10000 and 1..60 rows');
    }
    final query = <String, String>{
      'first': '$pageSize',
      'page': '$page',
      'filter_params[adult]': 'false',
      'order_by[field]': 'viewers',
      'order_by[order]': 'DESC',
      'type': 'stream',
      if (categoryId != null) 'filter_params[languages]': '',
      if (categoryId != null) 'filter_params[categories]': '$categoryId: true',
    };
    final uri = Uri.parse('$picartoApiOrigin/api/explore').replace(queryParameters: query);
    return picartoDirectory(await _get(uri.toString()), page: page, pageSize: pageSize, categoryId: categoryId);
  }

  /// Profile search. Offline channels are part of this answer, so callers show their state instead of assuming.
  Future<List<PicartoChannel>> searchProfiles(String keyword, {int page = 1, int pageSize = 20}) async {
    final query = keyword.trim();
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > 60 || query.length > 100) {
      throw const PicartoFailure('profile search: 1..10000 pages, 1..60 rows, a term of at most 100 characters');
    }
    if (query.isEmpty) {
      return const <PicartoChannel>[];
    }
    final uri = Uri.parse('$picartoApiOrigin/api/search').replace(
      queryParameters: <String, String>{
        'first': '$pageSize',
        'page': '$page',
        'q': query,
        'type': 'searchProfiles',
        'tag_search': 'false',
      },
    );
    return picartoProfiles(await _get(uri.toString()), pageSize: pageSize);
  }

  /// The channel, its privacy flag and the one stream that belongs to it.
  Future<({PicartoChannel channel, Uri? master})> detail(String input) async {
    final name = picartoChannelName(input);
    final data = _object(await _get('$picartoApiOrigin/api/channel/detail/$name'), 'the channel detail');
    final channel = picartoChannel(_object(data['channel'], 'the channel block'), expectedName: name, detail: true);
    if (!channel.online || channel.isPrivate == true) {
      // An offline or private room is described, not played: the load balancer has nothing for it.
      return (channel: channel, master: null);
    }
    // The origin is a hostname fragment that goes straight into the url, so it is shape-checked before it is used.
    final origin = _text(_object(data['getLoadBalancerUrl'], 'the load balancer answer')['origin']);
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(origin) || origin.length > 63) {
      throw PicartoFailure('the load balancer named an unusable origin: "$origin"');
    }
    final streams = _object(data['getMultiStreams'], 'the multi-stream answer')['streams'];
    if (streams is! List || streams.length > 100) {
      throw const PicartoFailure('the stream list is missing or unreasonably long');
    }
    final matches = <Map<String, Object?>>[];
    for (final value in streams) {
      final row = _object(value, 'a stream row');
      if ('${jsonInt(row['channelId'])}' == channel.channelId) {
        matches.add(row);
      }
    }
    if (matches.length != 1) {
      throw PicartoFailure(
        'the stream list names ${matches.length} streams for channel $name; exactly one is expected',
      );
    }
    final stream = matches.single;
    final streamName = _text(stream['stream_name']);
    if (!RegExp(r'^[a-zA-Z0-9_+-]{1,150}$').hasMatch(streamName)) {
      throw PicartoFailure('the stream name "$streamName" is not usable in a url');
    }
    return (
      channel: PicartoChannel(
        name: channel.name,
        channelId: channel.channelId,
        online: channel.online,
        isPrivate: channel.isPrivate,
        title: channel.title,
        avatar: channel.avatar,
        // The live thumbnail from the stream row is the current picture; the channel's own is the fallback.
        cover: picartoImage(stream['thumbnail_image']).isEmpty
            ? channel.cover
            : picartoImage(stream['thumbnail_image']),
        category: channel.category,
        viewers: channel.viewers,
        totalViews: channel.totalViews,
        introduction: channel.introduction,
        followers: channel.followers,
      ),
      master: Uri.parse('https://$origin.picarto.tv/stream/hls/$streamName/index.m3u8'),
    );
  }

  /// One playlist, read as text.
  Future<String> playlist(Uri uri) async {
    final response = await _client.getText(uri.toString(), headers: picartoHeaders);
    _expect(response);
    return response.body;
  }

  Future<Object?> _get(String url) async {
    final response = await _client.getText(url, headers: picartoHeaders);
    _expect(response);
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw PicartoFailure('the endpoint answered something that is not json', cause: error);
    }
  }

  void _expect(TextResponse response) {
    if (response.statusCode == 200) {
      return;
    }
    throw PicartoFailure(
      'the endpoint answered ${response.statusCode}',
      code: response.statusCode,
      missing: response.statusCode == 404,
    );
  }
}

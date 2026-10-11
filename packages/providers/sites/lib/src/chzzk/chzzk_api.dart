// Module: lib/src/chzzk/chzzk_api.dart
// Purpose: CHZZK 的请求面:游标目录、频道与直播详情、频道搜索、回放清单里的 HLS/LLHLS 媒体,以及主清单的变体读法。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the inclusive server cursor, the `cvExposure` rule, the `{type}` cover template, the
// media-host family and the master-variant grouping follow the v1-maintained CHZZK line (origin/master
// lib/shared/platforms/chzzk/). Fresh implementation against the v2 capability contracts, not a file merge
// (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, chzzk_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **the channel is the room**. A channel id is 32 hex characters and is what the site addresses; `liveId` is
//     per broadcast and travels as a stream id.
//   * **the server cursor is inclusive**. Continuing asks for one row more than the page and drops the repeated
//     boundary item; a `next` block that hands back the cursor we just sent is the end of the list, not a loop to
//     follow.
//   * **a hidden viewer count is hidden on purpose**. `cvExposure` gates the number: when it is not true the room
//     reports no audience, and 0 would be a figure the site chose not to publish.
//   * **the answer's media list is a manifest address, not a stream**. `livePlaybackJson` is itself a json string
//     holding HLS/LLHLS manifests on the akamaized family; the playable set only exists after those manifests are
//     read, so a room can be "on air with no qualities we can name" and that is not offline.
//   * **a variant without a resolution or a bandwidth is not a variant**. v1 refused the manifest rather than
//     inventing a menu row for it, and the grouping key is `{height}p{60?}` because the site ships 60fps and 30fps
//     at the same height as separate renditions.
//   * **region and age gates are stated by the site, and they are not the same fact**. `krOnlyViewing` says this
//     path cannot serve it; `adult` says a group check the anonymous session cannot prove; `timeMachineActive` is
//     the site's own word for "the finished part is watchable", so it is the only one of the three that maps to
//     [LiveCatchUp].

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

const String chzzkSourceId = 'chzzk.live';
const String chzzkApiOrigin = 'https://api.chzzk.naver.com';
const String chzzkWebOrigin = 'https://chzzk.naver.com';

const String chzzkUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

const Map<String, String> chzzkApiHeaders = <String, String>{
  'user-agent': chzzkUserAgent,
  'accept': 'application/json, text/plain, */*',
  'origin': chzzkWebOrigin,
  'referer': '$chzzkWebOrigin/',
};

/// The headers the cdn checks for the manifest and its segments.
const Map<String, String> chzzkMediaHeaders = <String, String>{
  'user-agent': chzzkUserAgent,
  'referer': '$chzzkWebOrigin/',
};

/// The directory's own page size, and the most rows any list answer may carry.
const int chzzkDirectoryPageSize = 30;
const int chzzkSearchPageSize = 20;
const int chzzkRowLimit = 64;

/// The most media entries one playback bundle may name.
const int chzzkMediaLimit = 16;

const int chzzkKeywordLimit = 100;

/// A chzzk answer that is not the answer we asked for.
final class ChzzkFailure implements Exception {
  const ChzzkFailure(this.message, {this.code, this.cause, this.missing = false});

  final String message;
  final int? code;
  final Object? cause;

  /// "No such channel or no such broadcast." Not an offline room and not the service.
  final bool missing;

  @override
  String toString() => 'ChzzkFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// A channel: what CHZZK addresses, whether or not anything is broadcasting in it.
final class ChzzkChannel {
  const ChzzkChannel({
    required this.id,
    required this.name,
    required this.isLive,
    this.avatar = '',
    this.description = '',
    this.followers,
  });

  final String id;
  final String name;
  final String avatar;
  final String description;
  final int? followers;

  /// `openLive`, when the row carried it.
  final bool isLive;

  ContentRef get ref => ContentRef(sourceId: chzzkSourceId, contentId: id, kind: ContentKind.liveRoom);
}

/// One manifest the playback bundle names.
final class ChzzkMedia {
  const ChzzkMedia({required this.id, required this.url, required this.lowLatency});

  /// `HLS` or `LLHLS` - the site's own two media ids.
  final String id;
  final String url;
  final bool lowLatency;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'url': url, 'lowLatency': lowLatency};
}

/// One rendition group: a height (and a frame rate) with the addresses that serve it.
final class ChzzkVariant {
  const ChzzkVariant({
    required this.key,
    required this.height,
    required this.fps,
    required this.rank,
    required this.urls,
    required this.bitrateKbps,
  });

  /// `{height}p{60}` - built from the manifest's own attributes, since the site names nothing else.
  final String key;
  final int height;

  /// The stated frame rate, or 0 when the rendition carried none.
  final double fps;

  /// `height * 10^7 + bandwidth`: the site's renditions order by resolution first, and the frame rate is inside
  /// the group, so a 1080p30 never outranks a 1080p60.
  final int rank;
  final List<String> urls;

  /// The best bandwidth in the group, in kbps. A group merges HLS and LLHLS renditions of the same shape, and
  /// their bandwidths differ, so this is the one the site stated for the top address.
  final int bitrateKbps;

  String get label => '$key · HLS';
}

/// One broadcast.
final class ChzzkLive {
  const ChzzkLive({
    required this.liveId,
    required this.channel,
    required this.title,
    required this.cover,
    required this.category,
    required this.viewers,
    required this.adult,
    required this.regionRestricted,
    required this.isLive,
    required this.timeMachine,
    required this.media,
    required this.chatChannelId,
  });

  final int liveId;
  final ChzzkChannel channel;
  final String title;
  final String cover;
  final String category;

  /// `concurrentUserCount`, and only when `cvExposure` let the site publish it.
  final int? viewers;
  final bool adult;

  /// `krOnlyViewing`: the site will not serve this path, whatever else the answer says.
  final bool regionRestricted;
  final bool isLive;

  /// `timeMachineActive`: the finished part of this broadcast is watchable.
  final bool timeMachine;

  /// The manifests the playback bundle named. Empty while nothing has been read yet.
  final List<ChzzkMedia> media;
  final String chatChannelId;

  LiveRoom toLiveRoom() => LiveRoom(
    ref: channel.ref,
    state: isLive ? LiveRoomState.live : LiveRoomState.ended,
    title: title.isEmpty ? channel.name : title,
    anchorName: channel.name,
    anchorId: channel.id,
    avatar: channel.avatar.isEmpty ? null : channel.avatar,
    cover: cover.isEmpty ? null : cover,
    area: category.isEmpty ? null : category,
    link: chzzkChannelUrl(channel.id),
    introduction: channel.description.isEmpty ? null : channel.description,
    followers: channel.followers,
    audience: viewers == null ? null : LiveAudience.ofMetric(viewers, LiveAudienceMetric.onlineViewers),
    restriction: restriction,
    streamId: '$liveId',
    catchUp: timeMachine ? const LiveCatchUp(active: true, source: 'chzzk.timeMachineActive') : null,
    danmakuPayload: <String, Object?>{
      if (chatChannelId.isNotEmpty && isLive) 'chatChannelId': chatChannelId,
      'channelId': channel.id,
    },
    headers: chzzkMediaHeaders,
    sitePayload: <String, Object?>{
      'chzzk.media': <Map<String, Object?>>[for (final item in media) item.toJson()],
    },
    // The gates are the site's facts, kept as facts: a surface words the warning, and "0 viewers" for a hidden
    // count is never written here.
    extra: <String, Object?>{if (adult) 'chzzk.adult': true, if (regionRestricted) 'chzzk.krOnly': true},
  );

  LiveRestriction? get restriction {
    if (!isLive) {
      return null;
    }
    if (regionRestricted) {
      // The site says this path cannot watch it. That is a refusal, not a paid gate and not "no address".
      return LiveRestriction.unplayable;
    }
    if (adult) {
      return LiveRestriction.private;
    }
    return media.isEmpty ? LiveRestriction.unplayable : LiveRestriction.none;
  }
}

/// A channel plus whatever is broadcasting in it.
final class ChzzkRoom {
  const ChzzkRoom({required this.channel, this.live});

  final ChzzkChannel channel;
  final ChzzkLive? live;

  LiveRoom toLiveRoom() {
    final broadcast = live;
    if (broadcast == null) {
      return ChzzkLive(
        liveId: 0,
        channel: channel,
        title: channel.name,
        cover: channel.avatar,
        category: '',
        viewers: null,
        adult: false,
        regionRestricted: false,
        isLive: false,
        timeMachine: false,
        media: const <ChzzkMedia>[],
        chatChannelId: '',
      ).toLiveRoom();
    }
    return broadcast.toLiveRoom();
  }
}

/// One cursor page of the directory.
final class ChzzkDirectoryPage {
  const ChzzkDirectoryPage({required this.lives, required this.cursor, required this.hasMore});

  final List<ChzzkLive> lives;
  final String? cursor;
  final bool hasMore;
}

/// A channel id: 32 hex characters, lower-cased.
String chzzkChannelId(String value) {
  final id = value.trim().toLowerCase();
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
    throw ChzzkFailure('not a chzzk channel id: "$value"');
  }
  return id;
}

/// The watch page.
String chzzkChannelUrl(String channelId) => '$chzzkWebOrigin/live/${chzzkChannelId(channelId)}';

/// The channel id in a chzzk url, or null. `/live/<id>` and the bare `/<id>` forms are the pages the site shares;
/// `/{a}/{b}/{c}` is something else.
String? chzzkChannelFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      uri.host.toLowerCase() != 'chzzk.naver.com') {
    return null;
  }
  final segments = <String>[
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  final candidate = switch (segments) {
    <String>['live', final String id] => id,
    <String>[final String id] => id,
    <String>[final String id, _] => id,
    _ => null,
  };
  if (candidate == null) {
    return null;
  }
  try {
    return chzzkChannelId(candidate);
  } on ChzzkFailure {
    return null;
  }
}

/// A search term, cut at the site's limit **without splitting a surrogate pair**.
///
/// A Korean or emoji-bearing title can end in a pair; slicing between the two halves would send a term the site
/// cannot decode and read back as "nothing found".
String chzzkKeyword(String keyword) {
  var text = keyword.trim();
  if (text.length > chzzkKeywordLimit) {
    var end = chzzkKeywordLimit;
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xd800 && last <= 0xdbff) {
      end--;
    }
    text = text.substring(0, end).trim();
  }
  return text;
}

/// The directory cursor: the two numbers the server's own `next` block is keyed on.
String chzzkEncodeCursor(int viewers, int liveId) => jsonEncode(<String, int>{'v': viewers, 'l': liveId});

({int viewers, int liveId}) chzzkDecodeCursor(String cursor) {
  if (cursor.length > 128) {
    throw const ChzzkFailure('a directory cursor is too long');
  }
  Object? decoded;
  try {
    decoded = jsonDecode(cursor);
  } on FormatException catch (error) {
    throw ChzzkFailure('a directory cursor is not json', cause: error);
  }
  final data = jsonMap(decoded);
  if (data == null || data.length != 2 || !data.containsKey('v') || !data.containsKey('l')) {
    throw const ChzzkFailure('a directory cursor is not the two numbers the site issued');
  }
  final viewers = jsonInt(data['v']);
  final liveId = jsonInt(data['l']);
  if (viewers == null || viewers < 0 || liveId == null || liveId < 1) {
    throw const ChzzkFailure('a directory cursor carries unusable numbers');
  }
  return (viewers: viewers, liveId: liveId);
}

/// The renditions of one master manifest, grouped by height and frame rate.
///
/// A rendition line is `#EXT-X-STREAM-INF:<attributes>` followed by its address, resolved against the manifest's
/// own url. `RESOLUTION` and `BANDWIDTH` are required: v1 refused the manifest rather than inventing a menu row
/// for a rendition whose place in it cannot be known.
List<ChzzkVariant> chzzkVariants(String manifest, Uri base) {
  if (!manifest.trimLeft().startsWith('#EXTM3U')) {
    throw const ChzzkFailure('the manifest is not an m3u8');
  }
  final grouped = <String, _ChzzkDraft>{};
  Map<String, String>? pending;
  for (final raw in const LineSplitter().convert(manifest)) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.startsWith('#')) {
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        pending = _attributes(line.substring(line.indexOf(':') + 1));
      }
      continue;
    }
    if (pending == null) {
      // A bare address with no STREAM-INF above it is a media segment list, not a master.
      continue;
    }
    final resolution = pending['RESOLUTION'] ?? '';
    final bandwidth = int.tryParse(pending['BANDWIDTH'] ?? '');
    final fps = double.tryParse(pending['FRAME-RATE'] ?? '');
    final height = int.tryParse(resolution.split('x').last.trim());
    if (height == null || height <= 0 || bandwidth == null || bandwidth <= 0) {
      throw const ChzzkFailure('a rendition states no resolution or no bandwidth');
    }
    final key = '${height}p${(fps ?? 0) >= 50 ? '60' : ''}';
    final draft = grouped.putIfAbsent(key, () => _ChzzkDraft(height: height, key: key));
    final url = base.resolve(line).toString();
    if (!draft.urls.contains(url)) {
      draft.urls.add(url);
      if (bandwidth > draft.bandwidth) {
        draft.bandwidth = bandwidth;
        draft.fps = fps ?? 0;
      }
    }
    pending = null;
  }
  if (grouped.isEmpty) {
    throw const ChzzkFailure('the manifest names no rendition');
  }
  final variants = <ChzzkVariant>[
    for (final draft in grouped.values)
      ChzzkVariant(
        key: draft.key,
        height: draft.height,
        fps: draft.fps,
        rank: draft.height * 10000000 + draft.bandwidth,
        bitrateKbps: (draft.bandwidth / 1000).round(),
        urls: List<String>.unmodifiable(draft.urls),
      ),
  ]..sort((ChzzkVariant left, ChzzkVariant right) => right.rank.compareTo(left.rank));
  return List<ChzzkVariant>.unmodifiable(variants);
}

/// `KEY=value,KEY="quoted, value"` - the attribute list of one rendition line.
Map<String, String> _attributes(String source) {
  final result = <String, String>{};
  var index = 0;
  while (index < source.length) {
    final equals = source.indexOf('=', index);
    if (equals < 0) {
      break;
    }
    final name = source.substring(index, equals).trim();
    var cursor = equals + 1;
    String value;
    if (cursor < source.length && source[cursor] == '"') {
      final end = source.indexOf('"', cursor + 1);
      if (end < 0) {
        throw const ChzzkFailure('a rendition attribute never closes its quote');
      }
      value = source.substring(cursor + 1, end);
      cursor = end + 1;
      if (cursor < source.length && source[cursor] == ',') {
        cursor++;
      }
    } else {
      final end = source.indexOf(',', cursor);
      value = end < 0 ? source.substring(cursor) : source.substring(cursor, end);
      cursor = end < 0 ? source.length : end + 1;
    }
    result[name] = value.trim();
    index = cursor;
  }
  return result;
}

final class _ChzzkDraft {
  _ChzzkDraft({required this.key, required this.height});

  final String key;
  final int height;
  double fps = 0;
  int bandwidth = 0;
  final List<String> urls = <String>[];
}

/// The playback bundle: a json *string* inside the answer, naming HLS and LLHLS manifests.
List<ChzzkMedia> chzzkPlaybackMedia(Object? raw) {
  if (raw == null || raw == '') {
    return const <ChzzkMedia>[];
  }
  if (raw is! String) {
    throw const ChzzkFailure('the playback bundle is not a json string');
  }
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw ChzzkFailure('the playback bundle is not readable json', cause: error);
  }
  final result = <ChzzkMedia>[];
  final seen = <String>{};
  for (final value in _rows(_map(decoded, 'the playback bundle')['media'], chzzkMediaLimit)) {
    final media = _map(value, 'a media entry');
    if (_string(media['protocol']) != 'HLS') {
      continue;
    }
    final id = _string(media['mediaId']);
    // The two ids the site issues. Anything else is a transport this path has not read, and guessing that a new
    // one is "probably hls" is how a broken address gets into a player.
    if (id != 'HLS' && id != 'LLHLS') {
      continue;
    }
    final url = chzzkMediaUrl(_string(media['path'])).toString();
    if (seen.add(url)) {
      result.add(ChzzkMedia(id: id, url: url, lowLatency: id == 'LLHLS'));
    }
  }
  return List<ChzzkMedia>.unmodifiable(result);
}

/// A directory row, read the way the site means it.
ChzzkLive chzzkDirectoryLive(Object? raw) {
  final data = _map(raw, 'a directory row');
  return ChzzkLive(
    liveId: _positive(data['liveId']),
    channel: _channel(_map(data['channel'], 'a directory channel block'), isLive: true),
    title: _string(data['liveTitle']),
    cover: _cover(data['liveImageUrl'], data['defaultThumbnailImageUrl']),
    category: _optional(data['liveCategoryValue'] ?? data['liveCategory']),
    viewers: _visibleViewers(data),
    adult: _flag(data['adult']),
    // A directory row says nothing about regions or time machines; only the live detail does.
    regionRestricted: false,
    isLive: true,
    timeMachine: false,
    media: const <ChzzkMedia>[],
    chatChannelId: '',
  );
}

/// The CHZZK client.
ChzzkChannel _channel(Map<String, Object?> data, {String description = '', int? followers, bool? isLive}) =>
    ChzzkChannel(
      id: chzzkChannelId('${data['channelId'] ?? ''}'),
      name: _string(data['channelName']),
      avatar: _image(data['channelImageUrl']),
      // A row that carries the field at all (even empty) is the answer about the description; a row that omits it
      // is the search shape, which never knows - so the owner's value is kept rather than a blank overwriting it.
      description: data.containsKey('channelDescription') ? _optional(data['channelDescription']) : description,
      followers: data.containsKey('followerCount') ? _optionalNonNegative(data['followerCount']) : followers,
      isLive: isLive ?? (data['openLive'] is bool ? data['openLive']! as bool : false),
    );

/// The playback bundle: a json *string* inside the answer, naming HLS and LLHLS manifests.
/// The viewer count, and only when the site chose to publish it.
int? _visibleViewers(Map<String, Object?> data) {
  if (data['cvExposure'] != true) {
    return null;
  }
  return _optionalNonNegative(data['concurrentUserCount']);
}

/// The cover. The site stores a `{type}` template, and the public size is 480.
String _cover(Object? primary, Object? fallback) {
  for (final value in <Object?>[primary, fallback]) {
    if (value is! String || value.isEmpty) {
      continue;
    }
    final expanded = value.replaceAll('{type}', '480');
    final image = _image(expanded);
    if (image.isNotEmpty) {
      return image;
    }
  }
  return '';
}

String _image(Object? value) {
  if (value is! String || value.length > 8192) {
    return '';
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
    return '';
  }
  final host = uri.host.toLowerCase();
  return host == 'pstatic.net' ||
          host.endsWith('.pstatic.net') ||
          host == 'akamaized.net' ||
          host.endsWith('.akamaized.net')
      ? value
      : '';
}

final class ChzzkApi {
  ChzzkApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// One cursor page of the live directory.
  ///
  /// The server's cursor is inclusive: continuation asks for one row more and removes the repeated boundary item,
  /// so a full logical page comes back rather than `size - 1` rows. A `next` block that hands back the cursor we
  /// just sent is the end of the list, and saying so is what stops a pager spinning on one page forever.
  Future<ChzzkDirectoryPage> directory({String? cursor, int size = chzzkDirectoryPageSize}) async {
    if (size < 1 || size > chzzkDirectoryPageSize) {
      throw const ChzzkFailure('the directory fills at most 30 rows');
    }
    final continuation = cursor == null ? null : chzzkDecodeCursor(cursor);
    final content = await _content('/service/v1/lives', <String, String>{
      'size': '${continuation == null ? size : size + 1}',
      if (continuation != null) 'concurrentUserCount': '${continuation.viewers}',
      if (continuation != null) 'liveId': '${continuation.liveId}',
    });
    final block = _map(content, 'the directory answer');
    final rows = _rows(block['data'], chzzkRowLimit);
    final lives = <ChzzkLive>[for (final raw in rows) chzzkDirectoryLive(raw)];
    if (continuation != null && lives.isNotEmpty && lives.first.liveId == continuation.liveId) {
      lives.removeAt(0);
    }
    final trimmed = lives.length > size ? lives.sublist(0, size) : lives;
    final next = _map(jsonMap(block['page'])?['next'], 'the cursor block');
    var issued = chzzkEncodeCursor(_nonNegative(next['concurrentUserCount']), _positive(next['liveId']));
    if (issued == cursor) {
      issued = '';
    }
    return ChzzkDirectoryPage(
      lives: trimmed,
      cursor: issued.isEmpty ? null : issued,
      hasMore: issued.isNotEmpty && trimmed.isNotEmpty,
    );
  }

  /// Channel search. Rows are people, and the site's own page size is 20.
  Future<List<ChzzkChannel>> searchChannels(String keyword, {int offset = 0, int size = chzzkSearchPageSize}) async {
    final query = chzzkKeyword(keyword);
    if (query.isEmpty || offset < 0 || offset > 1000000 || size < 1 || size > chzzkSearchPageSize) {
      throw const ChzzkFailure('a chzzk search needs a term, an offset within a million and at most 20 rows');
    }
    final block = _map(
      await _content('/service/v1/search/channels', <String, String>{
        'keyword': query,
        'offset': '$offset',
        'size': '$size',
      }),
      'the search answer',
    );
    return <ChzzkChannel>[
      for (final raw in _rows(block['data'], chzzkSearchPageSize))
        _channel(_map(jsonMap(raw)?['channel'], 'a search row')),
    ];
  }

  /// The channel itself, whether or not anything is broadcasting.
  Future<ChzzkChannel> channel(String channelId) async {
    final id = chzzkChannelId(channelId);
    final content = await _content('/service/v1/channels/$id', <String, String>{});
    if (content == null) {
      throw ChzzkFailure('no such channel', missing: true);
    }
    final result = _channel(_map(content, 'the channel answer'));
    if (result.id != id) {
      throw ChzzkFailure('the channel answer is about ${result.id} while asking about $id');
    }
    return result;
  }

  /// The broadcast inside one channel, or null when nothing is open.
  Future<ChzzkLive?> liveDetail(String channelId, ChzzkChannel owner) async {
    final id = chzzkChannelId(channelId);
    if (owner.id != id) {
      throw ChzzkFailure('the channel and the live detail name different broadcasters');
    }
    // v2 answers an overseas-restricted live with HTTP 500 / code 9004 and no detail; the web player's own v3.1
    // answers the same fields with `krOnlyViewing` set and no playback. The newer one is what can be read.
    final content = await _content('/service/v3.1/channels/$id/live-detail', <String, String>{});
    if (content == null) {
      return null;
    }
    final detail = _map(content, 'the live detail');
    final status = _string(detail['status']);
    final isLive = status == 'OPEN';
    if (!isLive && status != 'CLOSE' && status != 'CLOSED') {
      throw ChzzkFailure('the live detail reports status "$status"');
    }
    final liveChannel = _channel(
      _map(detail['channel'], 'the live channel block'),
      description: owner.description,
      followers: owner.followers,
      isLive: isLive,
    );
    if (liveChannel.id != id) {
      throw ChzzkFailure('the live detail belongs to ${liveChannel.id} while asking about $id');
    }
    return ChzzkLive(
      liveId: _positive(detail['liveId']),
      channel: liveChannel,
      title: _optional(detail['liveTitle'], fallback: owner.name),
      cover: _cover(detail['liveImageUrl'], detail['defaultThumbnailImageUrl']),
      category: _optional(detail['liveCategoryValue'] ?? detail['liveCategory']),
      viewers: _visibleViewers(detail),
      adult: _flag(detail['adult']),
      regionRestricted: _flag(detail['krOnlyViewing']),
      isLive: isLive,
      timeMachine: _flag(detail['timeMachineActive']),
      media: isLive ? chzzkPlaybackMedia(detail['livePlaybackJson']) : const <ChzzkMedia>[],
      chatChannelId: isLive ? _optional(detail['chatChannelId']) : '',
    );
  }

  /// The channel and its broadcast, in the two calls the site needs.
  Future<ChzzkRoom> room(String channelId) async {
    final owner = await channel(channelId);
    return ChzzkRoom(channel: owner, live: await liveDetail(owner.id, owner));
  }

  /// One manifest, read as text. The address is validated before it is fetched.
  Future<String> manifest(String url) async {
    final response = await _client.getText(chzzkMediaUrl(url).toString(), headers: chzzkMediaHeaders);
    _expectStatus(response, 'the manifest');
    return response.body;
  }

  /// The renditions of one media entry's manifest.
  Future<List<ChzzkVariant>> variantsFor(ChzzkMedia media) async =>
      chzzkVariants(await manifest(media.url), Uri.parse(media.url));

  Future<Object?> _content(String path, Map<String, String> query) async {
    final response = await _client.getText('$chzzkApiOrigin$path', headers: chzzkApiHeaders, queryParameters: query);
    _expectStatus(response, path);
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ChzzkFailure('$path answered something that is not json', cause: error);
    }
    final root = _map(decoded, path);
    final code = jsonInt(root['code']);
    if (code == null) {
      throw ChzzkFailure('$path carried no code');
    }
    if (code != 200) {
      // 400-style codes inside a 200 envelope are the site's own refusals; keep the number visible.
      throw ChzzkFailure('$path refused', code: code, missing: code == 404);
    }
    return root['content'];
  }

  void _expectStatus(TextResponse response, String what) {
    final failure = switch (response.statusCode) {
      200 => null,
      400 => 'the request was not understood',
      401 || 403 => 'the site asked for an account this path does not have',
      404 => 'no such channel or broadcast',
      429 => 'the site is rate-limiting this client',
      _ when response.statusCode >= 500 => 'the site failed the request',
      _ => 'the $what endpoint did not answer',
    };
    if (failure == null) {
      return;
    }
    throw ChzzkFailure(failure, code: response.statusCode, missing: response.statusCode == 404);
  }

  static Uri _mediaUri(String value) {
    if (value.length > 16384 || value.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw ChzzkFailure('a manifest address is not readable: "${value.length} chars"');
    }
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'akamaized.net' || host.endsWith('.akamaized.net'))) {
      throw const ChzzkFailure('an address outside the site\'s delivery family is never opened');
    }
    return uri;
  }
}

/// An address may only be fetched when it is https on the site's own delivery family, carries no credentials, no
/// fragment and no whitespace that could turn into a second request line.
Uri chzzkMediaUrl(String value) => ChzzkApi._mediaUri(value);

Map<String, Object?> _map(Object? value, String what) {
  final map = jsonMap(value);
  if (map == null) {
    throw ChzzkFailure('$what is not an object');
  }
  return map;
}

List<Object?> _rows(Object? value, int max) {
  if (value is! List || value.length > max) {
    throw const ChzzkFailure('a list is missing or unreasonably long');
  }
  return value;
}

String _string(Object? value) {
  if (value is! String || value.trim().isEmpty || value.length > 8192) {
    throw const ChzzkFailure('a required text field is missing or unreasonably long');
  }
  return value.trim();
}

String _optional(Object? value, {String fallback = ''}) {
  if (value == null || value == '') {
    return fallback;
  }
  if (value is! String || value.length > 131072) {
    throw const ChzzkFailure('a text field is not text');
  }
  final result = value.trim();
  return result.isEmpty ? fallback : result;
}

bool _flag(Object? value) {
  if (value is! bool) {
    throw ChzzkFailure('a flag arrived as "$value"');
  }
  return value;
}

int _positive(Object? value) {
  final number = jsonInt(value);
  if (number == null || number < 1) {
    throw ChzzkFailure('an id arrived as "$value"');
  }
  return number;
}

int _nonNegative(Object? value) {
  final number = jsonInt(value);
  if (number == null || number < 0) {
    throw ChzzkFailure('a count arrived as "$value"');
  }
  return number;
}

int? _optionalNonNegative(Object? value) {
  if (value == null || value == '') {
    return null;
  }
  return _nonNegative(value);
}

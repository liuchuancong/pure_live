// Module: lib/src/huya_source.dart
// Purpose: The Huya live source: recommend feed and HLS resolve over the public web endpoints.
// Author: liuchuancong
// Created: 2026-10-09
//
// Provenance: endpoint knowledge follows the v1-maintained huya line
// (origin/master lib/shared/platforms/huya/huya_site.dart, itself synced from
// dart_simple_live). This is a fresh implementation against the capability
// contracts, not a merge (UPSTREAM_REVIEW_POLICY.md). Deliberately smaller than
// the v1 line for this first slice: no login cookies, no TARS token lease, no
// quality/line selection - anonymous HLS only, which is what the feed-to-room
// chain needs to be real end to end.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import 'huya_signing.dart';

/// The source id every huya row carries.
const String huyaSourceId = 'huya.live';

/// A desktop Chrome UA: the web endpoints answer to it without a login.
const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36';

const Map<String, String> _webHeaders = <String, String>{
  'user-agent': _userAgent,
  'origin': 'https://www.huya.com',
  'referer': 'https://www.huya.com/',
};

/// Extracts an int-like field that Huya returns sometimes as int, sometimes as string.
int _asInt(Object? value) => int.tryParse('$value') ?? 0;

/// The Huya source. One [NetworkClient] for the process the source lives in; the
/// source owns it and closes it in [dispose].
final class HuyaSource implements FeedCapability, ResolveCapability {
  HuyaSource({NetworkClient? client}) : _client = client ?? NetworkClient();

  final NetworkClient _client;

  /// Releases the source's own transport. Tickets already handed out stay
  /// valid until their own lease ends; nothing here can shorten them.
  void dispose() => _client.close();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    final result = await _client.getJson(
      'https://www.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{'m': 'LiveList', 'do': 'getLiveListByPage', 'tagAll': 0, 'page': page.page},
    );
    final data = result['data'] as Map<String, Object?>?;
    final rows = data?['datas'] as List?;
    if (data == null || rows == null) {
      throw FormatException('Huya feed answered without data.datas (page ${page.page})');
    }
    final items = <ContentSummary>[for (final row in rows) _summaryFromListRow(row! as Map<String, Object?>)];
    final hasMore = _asInt(data['page']) < _asInt(data['totalPage']);
    return PageResult<ContentSummary>(items: items, page: page.page, pageSize: page.pageSize, hasMore: hasMore);
  }

  ContentSummary _summaryFromListRow(Map<String, Object?> row) {
    var cover = '${row['screenshot'] ?? ''}';
    if (cover.isNotEmpty && !cover.contains('?')) {
      cover += '?x-oss-process=style/w338_h190&';
    }
    final title = '${row['introduction'] ?? ''}';
    final nick = '${row['nick'] ?? ''}';
    final area = '${row['gameFullName'] ?? ''}';
    return ContentSummary(
      ref: ContentRef(sourceId: huyaSourceId, contentId: '${row['profileRoom'] ?? ''}', kind: ContentKind.liveRoom),
      title: title.isNotEmpty ? title : '${row['roomName'] ?? ''}',
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: cover.isNotEmpty ? cover : null,
      metadata: ContentMetadata(popularity: _asInt(row['totalCount'])),
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final result = await _client.getJson(
      'https://mp.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{'m': 'Live', 'do': 'profileRoom', 'roomid': ref.contentId, 'showSecret': '1'},
    );
    if (result['status'] != 200) {
      throw StateError('Huya room ${ref.contentId} answered status ${result['status']}');
    }
    final data = result['data'] as Map<String, Object?>?;
    final stream = data?['stream'] as Map<String, Object?>?;
    final bases = stream?['baseSteamInfoList'] as List?;
    if (stream == null || bases == null || bases.isEmpty) {
      throw StateError('Huya room ${ref.contentId} is not streaming');
    }

    // First usable base entry: each one carries the same stream on a different
    // CDN; line selection is a later slice, so the first entry is the line.
    final Map<String, Object?> entry = bases.first! as Map<String, Object?>;
    final streamName = '${entry['sStreamName'] ?? ''}';
    final flvBase = '${entry['sFlvUrl'] ?? ''}';
    if (streamName.isEmpty || flvBase.isEmpty) {
      throw StateError('Huya room ${ref.contentId} carries no usable stream entry');
    }
    final antiCode = '${entry['sHlsAntiCode'] ?? entry['sFlvAntiCode'] ?? ''}';
    final signed = buildAntiCode(streamName, createFallbackViewerUid(), antiCode);
    final uri = Uri.parse('${flvBase.replaceFirst('flv', 'hls')}/$streamName.m3u8?$signed&codec=264');

    final liveData = data?['liveData'] as Map<String, Object?>?;
    return MediaTicket(
      id: '$huyaSourceId/${ref.contentId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: DateTime.now().toUtc(),
      headers: const <String, String>{'user-agent': _userAgent, 'referer': 'https://www.huya.com/'},
      // The anti-code lease is minutes long; a hard deadline would be a guess
      // at which minute, and the contract makes expiresAt the prefetch trigger.
      refresh: const MediaTicketRefreshInfo(supported: true),
      metadata: MediaPlaybackMetadata(
        title: '${liveData?['introduction'] ?? liveData?['sRoomName'] ?? ref.contentId}',
        artist: '${liveData?['nick'] ?? ''}',
        isLive: true,
        extra: <String, Object?>{if (liveData?['screenshot'] != null) 'cover': liveData!['screenshot']},
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) {
    // The ticket id is the room: re-running resolve for the same ref is exactly
    // what a fresh lease is, and no state lives in this source to preserve.
    final roomId = expired.id.startsWith('$huyaSourceId/') ? expired.id.substring(huyaSourceId.length + 1) : '';
    if (roomId.isEmpty) {
      throw StateError('Huya ticket ${expired.id} does not name a room');
    }
    return resolve(ContentRef(sourceId: huyaSourceId, contentId: roomId, kind: ContentKind.liveRoom));
  }
}

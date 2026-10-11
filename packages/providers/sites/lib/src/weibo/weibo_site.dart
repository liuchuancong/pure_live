// Module: lib/src/weibo/weibo_site.dart
// Purpose: The Weibo live source: the anonymous recommendation snapshot, the room answer and the gated play url.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Weibo line (origin/master
// lib/shared/platforms/weibo/weibo_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site. What this site does **not** declare is deliberate:
//   * no SearchCapability - the anonymous surface has no search endpoint, and a search box that browses a
//     recommendation list is a lie of omission;
//   * no FeedCapability paging - `pc_recommend/list.json` is one finite snapshot, so the answer says
//     [PageMode.singleShot] and `hasMore: false`;
//   * no categories - the site offers no category table.
// A surface that asks for any of those gets "this source does not serve it" from the registry rather than a
// fabricated empty success, which is what the contract's declaration rule is for.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'weibo_api.dart';

/// The Weibo live source. One [NetworkClient] for the process the source lives in.
final class WeiboSource
    implements
        FeedCapability,
        BrowseCapability,
        ResolveCapability,
        LineCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  WeiboSource({NetworkClient? client, Clock? clock}) : _api = WeiboApi(client: client), _clock = clock ?? systemClock;

  final WeiboApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    if (page.page > 1) {
      // Asking for a second page of a snapshot would otherwise be answered with the same rooms again, which
      // reads downstream as a list that never ends.
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: page.page,
        pageSize: page.pageSize,
        mode: PageMode.singleShot,
      );
    }
    final cards = await _api.directory();
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final card in cards) card.toSummary()],
      page: 1,
      pageSize: cards.length,
      // The endpoint states no total and no continuation: the whole answer is this page.
      hasMore: false,
      total: cards.length,
      mode: PageMode.singleShot,
    );
  }

  /// Empty: weibo's anonymous surface has no category table. A browser with one fake "全部" row would be a
  /// category UI over nothing.
  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category;
    if (category != null && category.isNotEmpty) {
      // async on purpose: a Future-typed method that throws synchronously escapes the caller's `await` and the
      // error handling sitting behind it.
      throw StateError('$weiboSourceId has no categories; it serves one recommendation snapshot');
    }
    return feed(query.page);
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final detail = await _api.room(ref.contentId);
    return ContentDetail(
      summary: detail.toLiveRoom().summary,
      description: detail.title,
      metadata: <String, Object?>{'access': detail.access.name, 'watchLimit': detail.watchLimit},
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    final detail = await _api.room(ref.contentId);
    final room = detail.toLiveRoom();
    return LiveRoomStatus(
      ref: ref,
      state: room.state,
      viewers: null,
      title: detail.title.isEmpty ? null : detail.title,
      cover: detail.cover,
      anchorName: detail.nickname.isEmpty ? null : detail.nickname,
    );
  }

  /// The delivery paths the room states. Weibo ships an flv and an hls url for the same broadcast and names
  /// neither, so a line is an ordinal - the rule huya's CDN rows and acfun's manifest urls follow too.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final detail = await _api.room(ref.contentId);
    return <StreamOption>[
      for (var index = 0; index < detail.mediaUrls.length; index++)
        StreamOption(
          id: '${index + 1}',
          kind: StreamOptionKind.line,
          isDefault: index == 0,
          available: detail.access == WeiboAccess.public,
        ),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final detail = await _api.room(ref.contentId, expectedOwnerId: _ownerOf(ref));
    if (detail.state != WeiboBroadcast.live) {
      throw StateError('Weibo room ${detail.liveId} is not broadcasting');
    }
    if (detail.access != WeiboAccess.public) {
      // Named rather than played: `watch_limit` says who may watch, and a viewer who pressed play needs the
      // reason instead of a black screen.
      throw StateError(
        'Weibo room ${detail.liveId} is gated (watch_limit ${detail.watchLimit}, '
        'access ${detail.access.name}); the anonymous path cannot open it',
      );
    }
    if (detail.mediaUrls.isEmpty) {
      throw StateError('Weibo room ${detail.liveId} is on air but shipped no playable url');
    }
    final index = _lineIndex(line, detail.mediaUrls.length);
    final uri = Uri.parse(detail.mediaUrls[index]);
    return MediaTicket(
      id: '$weiboSourceId/${detail.liveId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: _protocolOf(uri),
      createdAt: _clock().toUtc(),
      headers: Map<String, String>.from(weiboHeaders),
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: weiboSourceId, contentId: detail.liveId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        isLive: true,
        title: detail.title.isEmpty ? detail.nickname : detail.title,
        artist: detail.nickname.isEmpty ? null : detail.nickname,
        extra: <String, Object?>{
          'container': _containerOf(uri),
          'weibo.line': index + 1,
          if (quality != null) 'weibo.requestedQuality': quality.id,
        },
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$weiboSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await.
      throw StateError('Weibo ticket ${expired.id} does not name a room');
    }
    return resolve(
      ContentRef(sourceId: weiboSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      line: expired.metadata.extra['weibo.line'] == null
          ? null
          : SelectionRef('${expired.metadata.extra['weibo.line']}'),
    );
  }

  /// The owner the caller is holding, when the ref carries it. Checked against the answer's own uid so one
  /// anchor's room cannot be opened under another's name.
  static int? _ownerOf(ContentRef ref) {
    final raw = ref.metadata['ownerId'];
    if (raw == null) {
      return null;
    }
    final id = int.tryParse('$raw');
    if (id == null || id <= 0) {
      throw StateError('Weibo ref carries an ownerId that is not an id: "$raw"');
    }
    return id;
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'Weibo offers $available url(s) for this room; line "${line.id}" is not one of them '
        '(the source names none of them, so they are numbered)',
      );
    }
    return wanted - 1;
  }

  static MediaProtocol _protocolOf(Uri uri) {
    if (uri.path.toLowerCase().endsWith('.m3u8')) {
      return MediaProtocol.hls;
    }
    return uri.scheme == 'http' ? MediaProtocol.http : MediaProtocol.https;
  }

  static String _containerOf(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8')) {
      return 'm3u8';
    }
    if (path.endsWith('.flv')) {
      return 'flv';
    }
    return 'unknown';
  }
}

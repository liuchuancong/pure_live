// Module: lib/src/kuaishou/kuaishou_site.dart
// Purpose: The Kuaishou live source: the recommendation block, the per-category grids, streamer search, the room
// page's state and the per-codec quality/line pair.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Kuaishou line (origin/master
// lib/shared/platforms/kuaishou/kuaishou_site.dart). Fresh implementation against the v2 capability contracts,
// not a merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: kuaishou_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// What this source declares is bounded by what its endpoints answer: the recommendation block has no page
// parameter, so it is one shot rather than a paged feed; the grids have the site's own 20-row pages, so a caller
// that asked for 50 is told it got 20; and the quality menu is per codec, which is the one place this site is
// richer than the others - an H.265 row is a separate choice, because a decoder that cannot open it has to be
// able to see that.
//
// Not declared, and said here rather than found later:
//   * **replay cards**. v1 played a finished broadcast by keeping the signed urls that were on the card the user
//     selected (`CurrentLiveRoom`), because the room page itself reports offline. A source in this architecture
//     has no "currently open card" to borrow from, so `resolve` reads the page and an offline page is offline.
//     Recording a replay therefore needs the replay endpoint this port has not sampled; it is a queue item, not a
//     silent gap.
//   * **the danmaku socket**. Its handshake material (`liveStreamId`, the session cookie, the emoji table) rides
//     in `LiveRoom.danmakuPayload`, but no socket exists yet in this package - see the danmaku layer in
//     docs/roadmap/packages-rebuild-progress.md.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'kuaishou_api.dart';

/// The Kuaishou source. One [NetworkClient] for the process the source lives in.
final class KuaishouSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        AnchorSearchCapability,
        ResolveCapability,
        QualityCapability,
        LineCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  KuaishouSource({NetworkClient? client, String? cookie, Clock? clock})
    : _api = KuaishouApi(client: client, cookie: cookie),
      _clock = clock ?? systemClock;

  final KuaishouApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  /// The recommendation block: one shot, because the endpoint takes no page parameter.
  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    if (page.page > 1) {
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: page.page,
        pageSize: page.pageSize,
        mode: PageMode.singleShot,
      );
    }
    return _singleShot(await _api.home(), 1);
  }

  @override
  Future<List<ContentCategory>> categories() async {
    final list = await _api.categories();
    return <ContentCategory>[for (final category in list) category.toContentCategory()];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isEmpty) {
      // No category was chosen, and the site has no "everything" grid. Its recommendation block is what the
      // landing page shows, so that is what is returned - as one shot, not as if it paged.
      return _singleShot(await _api.home(), 1);
    }
    final rooms = await _api.directory(categoryId: category, page: query.page.page);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in rooms) room.toLiveRoom().summary],
      page: query.page.page,
      // The server's own page size, stated as itself: a caller that asked for 50 has to be able to see that it
      // got 20, or its "short page means the end" logic stops the list early.
      pageSize: kuaishouServerPageSize,
      hasMore: rooms.length >= kuaishouServerPageSize,
      mode: PageMode.fixedPage,
    );
  }

  PageResult<ContentSummary> _singleShot(List<KuaishouRoom> rooms, int page) => PageResult<ContentSummary>(
    items: <ContentSummary>[for (final room in rooms) room.toLiveRoom().summary],
    page: page,
    pageSize: rooms.length,
    hasMore: false,
    total: rooms.length,
    mode: PageMode.singleShot,
  );

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final live = room.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: room.notice,
      metadata: <String, Object?>{
        'state': room.state.name,
        if (room.liveStreamId != null) 'liveStreamId': room.liveStreamId,
        'qualities': room.variants.length,
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // One page read and no manifest parsing: the flag on the page answers on-air-ness by itself.
    final room = await _api.room(ref.contentId, withMedia: false);
    return LiveRoomStatus(
      ref: ref,
      state: room.state,
      viewers: room.viewers,
      title: room.title,
      cover: room.cover,
      anchorName: room.nick,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final rooms = await _api.search(query.keyword, page: query.page.page);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in rooms) room.toLiveRoom().summary],
      page: query.page.page,
      // The endpoint states no total and no page size of its own, so the honest continuation evidence is whether it
      // kept answering rows at all. The requested page size is not echoed back as if it had been honoured.
      pageSize: rooms.length,
      hasMore: rooms.isNotEmpty,
      mode: PageMode.fixedPage,
    );
  }

  /// The same rows as people. Kuaishou indexes streamers, not rooms, so this is the search the site actually has -
  /// the room-shaped [search] above is the same answer read the other way.
  @override
  Future<PageResult<AnchorSummary>> searchAnchors(SearchQuery query) async {
    final rooms = await _api.search(query.keyword, page: query.page.page);
    return PageResult<AnchorSummary>(
      items: <AnchorSummary>[for (final room in rooms) room.toAnchorSummary()],
      page: query.page.page,
      pageSize: rooms.length,
      hasMore: rooms.isNotEmpty,
      mode: PageMode.fixedPage,
    );
  }

  /// One option per codec row, labelled with the site's own words.
  ///
  /// H.265 rows appear separately even when the site named them exactly like their H.264 siblings: a menu that
  /// merged them would offer one label whose url some players cannot decode, and the failure would look like the
  /// stream being broken rather than like a codec choice.
  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    return <StreamOption>[
      for (final variant in room.variants)
        StreamOption(
          id: variant.id,
          kind: StreamOptionKind.quality,
          label: variant.name,
          codec: variant.codec,
          rank: variant.sort,
          bitrateKbps: variant.bitrateKbps,
          isDefault: variant == room.variants.first,
          available: variant.isPlayable,
        ),
    ];
  }

  /// The cdn addresses inside the top profile, numbered.
  ///
  /// Scoped to one profile on purpose: kuaishou signs each row separately, so an H.264 address cannot stand in
  /// for an H.265 one and a menu that mixed them would offer combinations the endpoint never issued.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final top = room.variants.isEmpty ? null : room.variants.first;
    if (top == null) {
      return const <StreamOption>[];
    }
    return <StreamOption>[
      for (var index = 0; index < top.urls.length; index++)
        StreamOption(id: '${index + 1}', kind: StreamOptionKind.line, isDefault: index == 0),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final room = await _api.room(ref.contentId);
    if (room.state == LiveRoomState.ended) {
      throw StateError('Kuaishou room ${room.authorId} is not broadcasting');
    }
    if (room.variants.isEmpty) {
      // `unknown` lands here too, and it has to stay distinguishable from offline: this says the page shipped no
      // address, not that the broadcast stopped.
      throw StateError('Kuaishou room ${room.authorId} answered with no address we are willing to open');
    }
    final variant = _variant(room.variants, quality);
    final index = _lineIndex(line, variant.urls.length);
    final uri = Uri.parse(variant.urls[index]);
    return MediaTicket(
      id: '$kuaishouSourceId/${room.authorId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: uri.path.toLowerCase().endsWith('.m3u8') ? MediaProtocol.hls : MediaProtocol.https,
      createdAt: _clock().toUtc(),
      headers: <String, String>{
        'user-agent': kuaishouUserAgent,
        'referer': kuaishouRoomUrl(room.authorId),
        if (room.cookie.isNotEmpty) 'cookie': room.cookie,
      },
      // The address carries its own expiry and the endpoint states no lease length we could turn into a prefetch
      // trigger, so none is invented: the host re-reads the page when the stream dies.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: room.ref(),
      metadata: MediaPlaybackMetadata(
        title: (room.title?.isNotEmpty ?? false) ? room.title : room.nick,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': uri.path.toLowerCase().endsWith('.m3u8') ? 'm3u8' : 'flv',
          'kuaishou.quality': variant.id,
          'kuaishou.codec': variant.codec,
          'kuaishou.line': index + 1,
          if (quality != null && quality.id.trim() != variant.id) 'kuaishou.requestedQuality': quality.id,
        },
      ),
    );
  }

  KuaishouVariant _variant(List<KuaishouVariant> variants, SelectionRef? quality) {
    final id = quality?.id.trim() ?? '';
    if (id.isEmpty) {
      return variants.first;
    }
    for (final variant in variants) {
      if (variant.id == id && variant.isPlayable) {
        return variant;
      }
    }
    // The manifest can change between the menu read and the play read. The viewer still gets a stream, and the
    // ticket records what they asked for so the surface can say the choice could not be honoured.
    return variants.first;
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'Kuaishou offers $available address(es) for this profile; line "${line.id}" is not one of them '
        '(the site names none of them, so they are numbered)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$kuaishouSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('Kuaishou ticket ${expired.id} does not name a room');
    }
    final extra = expired.metadata.extra;
    return resolve(
      // The page is re-read rather than the old url reused: a signed address dies with its own expiry, and an
      // offline page must not be replayed from a cached one.
      ContentRef(
        sourceId: kuaishouSourceId,
        contentId: expired.id.substring(prefix.length),
        kind: ContentKind.liveRoom,
      ),
      quality: extra['kuaishou.quality'] is String ? SelectionRef('${extra['kuaishou.quality']}') : null,
      line: extra['kuaishou.line'] == null ? null : SelectionRef('${extra['kuaishou.line']}'),
    );
  }
}

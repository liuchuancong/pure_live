// Module: lib/src/cc/cc_site.dart
// Purpose: The NetEase CC live source: the assembled Dashen menu, the fixed-width grids, the two-call room, the
// tier/cdn pair and the anchor search read as rooms and people.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained CC line (origin/master lib/shared/platforms/cc/).
// Fresh implementation against the v2 capability contracts, not a merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: cc_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// Two axes, honestly separated: a tier (`blueray`, `high`, …) is a quality, and the cdn families inside it are its
// lines - ordered by the site's own preference table, so the first line is the one CC would have picked. The
// caller's page size is not honoured by either grid: the offsets are the site's fixed 30, and echoing 30 back is
// what keeps a resized grid from resampling the same rooms.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'cc_api.dart';

/// The NetEase CC source. One [NetworkClient] for the process the source lives in.
final class CcSource
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
  CcSource({NetworkClient? client, Clock? clock}) : _api = CcApi(client: client), _clock = clock ?? systemClock;

  final CcApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async => _page(await _api.home(page: page.page), page.page);

  @override
  Future<List<ContentCategory>> categories() async {
    final entries = await _api.catalog();
    return <ContentCategory>[for (final entry in entries) entry.toContentCategory()];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isEmpty) {
      return _page(await _api.home(page: query.page.page), query.page.page);
    }
    if (category.startsWith('official:')) {
      // async on purpose: an entry that is a destination rather than a listing has to reach the caller as a Future
      // error, and the message names the page the viewer should be sent to.
      throw CcFailure('this cc entry is a destination, not a listing; open ${ccOfficialEntryUri(category)} instead');
    }
    return _page(await _api.directory(gameId: category, page: query.page.page), query.page.page);
  }

  PageResult<ContentSummary> _page(List<CcRoom> rooms, int page) => PageResult<ContentSummary>(
    items: <ContentSummary>[for (final room in rooms) room.toLiveRoom().summary],
    page: page,
    // The width the endpoint was asked at, echoed as itself.
    pageSize: ccNativePageSize,
    hasMore: rooms.length >= ccNativePageSize,
    mode: PageMode.fixedPage,
  );

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final live = room.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: live.notice,
      metadata: <String, Object?>{
        'state': live.state.name,
        'qualities': room.qualities.length,
        if (room.isReplayTitle) 'replayTitle': true,
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // The site has no status-only endpoint: on-air-ness lives in the channel answer, so a follow-list poll costs
    // the same two calls as the room page. Declared here rather than pretending it is cheap.
    final room = await _api.room(ref.contentId);
    return LiveRoomStatus(
      ref: ref,
      state: room.state,
      viewers: room.onlineViewers ?? room.popularity,
      title: room.title.isEmpty ? null : room.title,
      cover: room.cover,
      anchorName: room.nick.isEmpty ? null : room.nick,
      startedAt: room.startedAt,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final rooms = await _api.search(query.keyword, page: query.page.page, pageSize: query.page.pageSize);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in rooms) room.toLiveRoom().summary],
      page: query.page.page,
      // The endpoint caps its own block; the size actually served is the clamped one.
      pageSize: rooms.length,
      hasMore: rooms.length >= query.page.pageSize.clamp(1, ccSearchPageSizeLimit),
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<PageResult<AnchorSummary>> searchAnchors(SearchQuery query) async {
    final rooms = await _api.search(query.keyword, page: query.page.page, pageSize: query.page.pageSize);
    return PageResult<AnchorSummary>(
      items: <AnchorSummary>[for (final room in rooms) room.toAnchorSummary()],
      page: query.page.page,
      pageSize: rooms.length,
      hasMore: rooms.length >= query.page.pageSize.clamp(1, ccSearchPageSizeLimit),
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    if (room.qualities.isEmpty) {
      // No tiers is not an empty menu: a room that ships only its m3u8 has one unnameable choice, and saying so
      // with a single option is what keeps a picker from showing "清晰度" for a stream that has none.
      return room.playUrl == null
          ? const <StreamOption>[]
          : <StreamOption>[
              StreamOption(id: 'source', kind: StreamOptionKind.quality, isDefault: true, available: true),
            ];
    }
    return <StreamOption>[
      for (final quality in room.qualities)
        StreamOption(
          id: quality.key,
          kind: StreamOptionKind.quality,
          label: quality.label,
          rank: quality.sort,
          bitrateKbps: quality.bitrateKbps,
          isDefault: quality == room.qualities.first,
          available: quality.urls.isNotEmpty,
        ),
    ];
  }

  /// The cdn families of the top tier, in the site's own preference order.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final top = room.qualities.isEmpty ? null : room.qualities.first;
    final count = top?.urls.length ?? (room.playUrl == null ? 0 : 1);
    return <StreamOption>[
      for (var index = 0; index < count; index++)
        StreamOption(id: '${index + 1}', kind: StreamOptionKind.line, isDefault: index == 0),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final room = await _api.room(ref.contentId);
    if (room.state != LiveRoomState.live) {
      throw StateError(switch (room.state) {
        LiveRoomState.ended => 'CC room ${room.roomId} is not broadcasting',
        LiveRoomState.notStarted => 'CC room ${room.roomId} has not started',
        _ => 'CC room ${room.roomId} did not state whether it is broadcasting',
      });
    }
    final chosen = _quality(room, quality);
    final index = _lineIndex(line, chosen.urls.length);
    final uri = Uri.parse(chosen.urls[index]);
    return MediaTicket(
      id: '$ccSourceId/${room.roomId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: uri.path.toLowerCase().endsWith('.m3u8') ? MediaProtocol.hls : MediaProtocol.https,
      createdAt: _clock().toUtc(),
      headers: <String, String>{...ccWebHeaders, 'referer': '$ccWebOrigin/${room.roomId}/'},
      // The lines are re-issued with each channel answer and the site states no lease length, so none is invented:
      // a refresh is another two-call read rather than a guess about when the address dies.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: ccSourceId, contentId: room.roomId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.title.isEmpty ? room.nick : room.title,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': uri.path.toLowerCase().endsWith('.m3u8') ? 'm3u8' : 'flv',
          'cc.quality': chosen.key,
          'cc.line': index + 1,
          if (room.isReplayTitle) 'cc.replayTitle': true,
          if (quality != null && quality.id.trim() != chosen.key) 'cc.requestedQuality': quality.id,
        },
      ),
    );
  }

  ({String key, List<String> urls}) _quality(CcRoom room, SelectionRef? quality) {
    if (room.qualities.isEmpty) {
      final url = room.playUrl;
      if (url == null) {
        throw StateError('CC room ${room.roomId} is on air but shipped no address we are willing to open');
      }
      return (key: 'source', urls: <String>[url]);
    }
    final id = quality?.id.trim() ?? '';
    if (id.isEmpty) {
      return (key: room.qualities.first.key, urls: room.qualities.first.urls);
    }
    for (final tier in room.qualities) {
      if (tier.key == id && tier.urls.isNotEmpty) {
        return (key: tier.key, urls: tier.urls);
      }
    }
    // The tier list can differ between the menu read and the play read. The viewer still gets a stream and the
    // ticket records the ask, so the surface can say the choice could not be honoured.
    return (key: room.qualities.first.key, urls: room.qualities.first.urls);
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'CC offers $available cdn line(s) for that tier; line "${line.id}" is not one of them '
        '(the site names them by cdn family, and those are ordered by its own preference table)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$ccSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('CC ticket ${expired.id} does not name a room');
    }
    final extra = expired.metadata.extra;
    return resolve(
      ContentRef(sourceId: ccSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      quality: extra['cc.quality'] is String ? SelectionRef('${extra['cc.quality']}') : null,
      line: extra['cc.line'] == null ? null : SelectionRef('${extra['cc.line']}'),
    );
  }
}

// Module: lib/src/missevan/missevan_site.dart
// Purpose: The Missevan FM live source: native-paged open rooms, tabs, creator search and the bilibili-CDN pull.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Missevan line (origin/master
// lib/shared/platforms/missevan/missevan_site.dart). Fresh implementation against the v2 capability contracts,
// not a merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site. What this source declares is bounded by what the endpoints can answer: pages are
// the **server's** 20-row pages (a caller asking for 50 does not get 50, and pretending otherwise makes the
// pager's math wrong), quality is a single "原画" entry because the site ships one profile with two containers -
// flv and hls - which is a line axis, not two qualities.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'missevan_api.dart';

/// The Missevan source. One [NetworkClient] for the process the source lives in.
final class MissevanSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        ResolveCapability,
        QualityCapability,
        LineCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  MissevanSource({NetworkClient? client, Clock? clock})
    : _api = MissevanApi(client: client),
      _clock = clock ?? systemClock;

  final MissevanApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) => _page(page, null);

  @override
  Future<List<ContentCategory>> categories() async {
    final tabs = await _api.tabs();
    return <ContentCategory>[
      for (final tab in tabs) ContentCategory(id: MissevanTab.encode(tab.type, tab.id), name: tab.name, icon: tab.icon),
    ];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) => _page(query.page, query.category);

  Future<PageResult<ContentSummary>> _page(PageRequest request, String? tab) async {
    final data = await _api.directory(page: request.page, tab: tab);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in data.rooms) room.toLiveRoom().summary],
      page: data.page,
      // The server's page size, stated as itself: a caller that asked for 50 must be able to see that it got 20,
      // or its "short page means the end" logic ends the list early.
      pageSize: missevanServerPageSize,
      hasMore: data.hasMore,
      total: data.count,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final live = room.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: room.introduction,
      metadata: <String, Object?>{'isOpen': room.isOpen, 'notice': room.notice},
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    return LiveRoomStatus(
      ref: ref,
      state: room.isOpen ? LiveRoomState.live : LiveRoomState.ended,
      title: room.title.isEmpty ? null : room.title,
      cover: room.cover,
      anchorName: room.nick.isEmpty ? null : room.nick,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final rooms = await _api.search(query.keyword, page: query.page.page);
    final items = <ContentSummary>[for (final room in rooms) room.toLiveRoom().summary];
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: missevanServerPageSize,
      // The search endpoint states its own total inside the pagination block; the list here is what came back for
      // this page, and `hasMore` is decided by the page arithmetic rather than by a full-page guess.
      hasMore: items.length >= missevanServerPageSize,
      mode: PageMode.fixedPage,
    );
  }

  /// The site ships one profile ("原画") carrying two containers. They are listed as one quality because that is
  /// what it is - a second "quality" that is the same encode over a different transport would be two menu rows
  /// whose only difference is a file extension.
  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    if (room.streamUrls.isEmpty) {
      return const <StreamOption>[];
    }
    return <StreamOption>[
      StreamOption(id: 'origin', kind: StreamOptionKind.quality, label: '原画', isDefault: true, available: true),
    ];
  }

  /// The flv and hls pull addresses of that one profile, numbered in the site's own order.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    return <StreamOption>[
      for (var index = 0; index < room.streamUrls.length; index++)
        StreamOption(id: '${index + 1}', kind: StreamOptionKind.line, isDefault: index == 0),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final room = await _api.room(ref.contentId);
    if (!room.isOpen) {
      throw StateError('Missevan room ${room.roomId} is not broadcasting');
    }
    if (room.streamUrls.isEmpty) {
      throw StateError('Missevan room ${room.roomId} is open but shipped no pull address');
    }
    if (quality != null && quality.id.trim() != 'origin') {
      throw StateError('Missevan serves one profile (原画); quality "${quality.id}" does not exist');
    }
    final index = _lineIndex(line, room.streamUrls.length);
    final uri = Uri.parse(room.streamUrls[index]);
    // The address carries its own signed `expires`; the site states no lease length beyond it, and the query is
    // kept verbatim because the signature is in it.
    return MediaTicket(
      id: '$missevanSourceId/${room.roomId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: uri.path.toLowerCase().endsWith('.m3u8') ? MediaProtocol.hls : MediaProtocol.https,
      createdAt: _clock().toUtc(),
      headers: <String, String>{
        'user-agent': missevanUserAgent,
        'referer': '$missevanOrigin/',
        'origin': missevanOrigin,
      },
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: missevanSourceId, contentId: room.roomId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.title.isEmpty ? room.nick : room.title,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': uri.path.toLowerCase().endsWith('.m3u8') ? 'm3u8' : 'flv',
          'missevan.line': index + 1,
        },
      ),
    );
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'Missevan offers $available pull address(es) for this room; line "${line.id}" is not one of them '
        '(they are the site\'s containers, in its own order)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$missevanSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('Missevan ticket ${expired.id} does not name a room');
    }
    final line = expired.metadata.extra['missevan.line'];
    // Re-read the room: the signed address dies with its `expires`, and an offline room must not be replayed
    // from a cached url.
    return resolve(
      ContentRef(
        sourceId: missevanSourceId,
        contentId: expired.id.substring(prefix.length),
        kind: ContentKind.liveRoom,
      ),
      line: line == null ? null : SelectionRef('$line'),
    );
  }
}

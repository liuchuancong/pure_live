// Module: lib/src/baidulive/baidulive_site.dart
// Purpose: The Baidu live source: the session-cursored feed, its tab block, the room command, and the
// protocol/resolution/codec quality menu.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Baidu line (origin/master
// lib/shared/platforms/baidulive/baidu_live_site.dart). Fresh implementation against the v2 capability contracts,
// not a merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: baidulive_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// What this source declares is bounded by what its endpoints answer. It is the second site with both selection
// axes - a variant is `protocol:resolution:codec`, and the cdn urls inside one variant are the lines - and its
// directory is the second cursor-paged one after acfun, because the site continues a list by session id plus a
// refresh counter rather than by a page number.
//
// Declared absent, in the open rather than as an empty result:
//   * **no keyword search**. The anonymous surface indexes broadcasts by room id only; a search box that returned
//     "nothing found" for every word would be a lie about what the site can be asked. Opening a pasted room link
//     is the resolve path's job, and `baiduliveRoomFromUri` serves it.
//   * **no separate status endpoint**. `liveStatus` is the same room command that the room page reads, so a
//     follow-list poll costs one request and gets no manifest it did not need.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'baidulive_api.dart';

/// The Baidu live source. One [NetworkClient] for the process the source lives in.
final class BaiduliveSource
    implements
        FeedCapability,
        BrowseCapability,
        ResolveCapability,
        QualityCapability,
        LineCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  BaiduliveSource({NetworkClient? client, Clock? clock})
    : _api = BaiduliveApi(client: client, clock: clock),
      _clock = clock ?? systemClock;

  final BaiduliveApi _api;
  final Clock _clock;

  /// The tab block as the last directory answer described it. Seeded lazily and replaced wholesale, never merged:
  /// a tab the site dropped has to stop being offered.
  List<BaiduliveCategory> _categories = baiduliveFallbackCategories;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async => _directory(_categories.first, page);

  /// The site has no category endpoint. Its tab block arrives with the first page of the feed, so that is where
  /// the menu comes from - and if that answer carries no tabs, the list the site's own landing page ships is used
  /// rather than an empty menu.
  @override
  Future<List<ContentCategory>> categories() async {
    if (!identical(_categories, baiduliveFallbackCategories)) {
      return <ContentCategory>[for (final category in _categories) category.toContentCategory()];
    }
    final page = await _api.directory(category: baiduliveFallbackCategories.first, page: 1);
    if (page.categories.isNotEmpty) {
      _categories = page.categories;
    }
    return <ContentCategory>[for (final category in _categories) category.toContentCategory()];
  }

  // async on purpose: an unknown tab is a refusal the caller should see as a Future error, not a synchronous throw
  // that escapes the await site and its recovery ladder.
  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async =>
      _directory(_category(query.category), query.page);

  BaiduliveCategory _category(String? requested) {
    final id = requested?.trim().toLowerCase() ?? '';
    if (id.isEmpty) {
      return _categories.first;
    }
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    // An unknown tab is refused instead of quietly answered with the recommendation list: showing 推荐 under a
    // category name the viewer chose reads as that category being empty.
    throw BaiduliveFailure('not a baidulive tab this source has seen: "$id"');
  }

  Future<PageResult<ContentSummary>> _directory(BaiduliveCategory category, PageRequest page) async {
    final result = await _api.directory(category: category, cursor: page.cursor, page: page.page);
    if (result.categories.isNotEmpty) {
      _categories = result.categories;
    }
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in result.rooms) room.toLiveRoom().summary],
      page: page.page,
      // The server's own fill, stated as itself: a caller that asked for 30 has to see it got ten.
      pageSize: baiduliveFeedPageSize,
      hasMore: result.hasMore,
      mode: PageMode.cursor,
      nextCursor: result.cursor.isEmpty ? null : result.cursor,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final live = room.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: live.notice,
      metadata: <String, Object?>{
        'state': room.state.name,
        'qualities': room.variants.length,
        if (room.danmaku.isNotEmpty) 'chat': 'poll',
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async =>
      (await _api.room(ref.contentId)).toLiveRoom(catchUpSource: 'baidulive.status');

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    final room = await _api.room(ref.contentId, fillFromListing: false);
    return LiveRoomStatus(
      ref: ref,
      state: switch (room.state) {
        BaiduliveState.live => LiveRoomState.live,
        BaiduliveState.preview => LiveRoomState.notStarted,
        BaiduliveState.replay || BaiduliveState.offline => LiveRoomState.ended,
        BaiduliveState.unknown => LiveRoomState.unknown,
      },
      viewers: room.viewers,
      title: room.title.isEmpty ? null : room.title,
      cover: room.cover.isEmpty ? null : room.cover,
      anchorName: room.nick.isEmpty ? null : room.nick,
    );
  }

  /// One option per `protocol:resolution:codec` row.
  ///
  /// The site does not name its qualities, so the label is built from the three things the answer states rather
  /// than from an invented 蓝光/高清 word. [StreamOption.rank] carries the site's own resolution number and
  /// nothing else: a resolution of 0 was never stated and is not sorted as if it were the lowest quality.
  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    return <StreamOption>[
      for (final variant in room.variants)
        StreamOption(
          id: variant.id,
          kind: StreamOptionKind.quality,
          label: variant.label,
          codec: variant.codec,
          rank: variant.resolution > 0 ? variant.resolution : null,
          isDefault: variant == room.variants.first,
          available: variant.urls.isNotEmpty,
        ),
    ];
  }

  /// The cdn addresses of the top variant, numbered.
  ///
  /// Scoped to one variant because baidulive issues separate signed addresses per protocol and per codec: an flv
  /// address is not an alternative route to an hls stream, and a menu mixing them would offer combinations the
  /// endpoint never handed out.
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
    if (room.state != BaiduliveState.live) {
      // Named per state: "not started yet", "this broadcast ended" and "the site would not say" are three things
      // a viewer needs told apart.
      throw StateError(switch (room.state) {
        BaiduliveState.preview => 'Baidu live room ${room.roomId} has not started broadcasting',
        BaiduliveState.replay => 'Baidu live room ${room.roomId} is a replay and this path plays live streams',
        BaiduliveState.offline => 'Baidu live room ${room.roomId} is not broadcasting',
        BaiduliveState.unknown => 'Baidu live room ${room.roomId} did not state whether it is broadcasting',
        BaiduliveState.live => 'Baidu live room ${room.roomId} is not broadcasting',
      });
    }
    if (room.variants.isEmpty) {
      throw StateError('Baidu live room ${room.roomId} is on air but shipped no address we are willing to open');
    }
    final variant = _variant(room.variants, quality);
    final index = _lineIndex(line, variant.urls.length);
    final uri = Uri.parse(variant.urls[index]);
    return MediaTicket(
      id: '$baiduliveSourceId/${room.roomId}',
      uri: uri,
      kind: MediaKind.live,
      // `flv-live.bdstatic.com` is served over http by the site's own client; saying https for it would describe a
      // connection this address cannot make.
      protocol: switch ((variant.protocol, uri.scheme)) {
        ('hls', _) => MediaProtocol.hls,
        (_, 'http') => MediaProtocol.http,
        _ => MediaProtocol.https,
      },
      createdAt: _clock().toUtc(),
      headers: baiduliveMediaHeaders(room.roomId),
      // The answer states no lease length for its addresses, so none is invented: the host re-reads the room
      // command when the stream dies.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: baiduliveSourceId, contentId: room.roomId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.title.isEmpty ? room.nick : room.title,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': variant.protocol == 'hls' ? 'm3u8' : 'flv',
          'baidulive.quality': variant.id,
          'baidulive.codec': variant.codec,
          'baidulive.line': index + 1,
          if (quality != null && quality.id.trim() != variant.id) 'baidulive.requestedQuality': quality.id,
        },
      ),
    );
  }

  BaiduliveVariant _variant(List<BaiduliveVariant> variants, SelectionRef? quality) {
    final id = quality?.id.trim() ?? '';
    if (id.isEmpty) {
      return variants.first;
    }
    for (final variant in variants) {
      if (variant.id == id && variant.urls.isNotEmpty) {
        return variant;
      }
    }
    // The variant list can differ between the menu read and the play read. The viewer still gets a stream and the
    // ticket records what they asked for, so the surface can say the choice could not be honoured.
    return variants.first;
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'Baidu live offers $available address(es) for this variant; line "${line.id}" is not one of them '
        '(the site names none of them, so they are numbered)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$baiduliveSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder sitting behind it.
      throw StateError('Baidu live ticket ${expired.id} does not name a room');
    }
    final extra = expired.metadata.extra;
    return resolve(
      // The room command is re-read: the addresses are signed against this broadcast, and a cached one outliving
      // it would play yesterday's show under today's title.
      ContentRef(
        sourceId: baiduliveSourceId,
        contentId: expired.id.substring(prefix.length),
        kind: ContentKind.liveRoom,
      ),
      quality: extra['baidulive.quality'] is String ? SelectionRef('${extra['baidulive.quality']}') : null,
      line: extra['baidulive.line'] == null ? null : SelectionRef('${extra['baidulive.line']}'),
    );
  }
}

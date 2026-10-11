// Module: lib/src/showroom/showroom_site.dart
// Purpose: The SHOWROOM source: the snapshot directory paged locally, the genre table, the room pipeline and the
// hls / hls_all menu.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained SHOWROOM line (origin/master
// lib/shared/platforms/showroom/showroom_site.dart). Fresh implementation against the v2 capability contracts, not
// a merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: showroom_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// What this source declares is bounded by what its endpoints answer. The directory is one snapshot, so paging is
// slicing of it and `total` is the snapshot's size; the room pipeline reads profile and live-info once each and
// reaches for streams only when the room is on air; and the search is a filter over the same snapshot, because
// SHOWROOM's public surface has no keyword index of its own.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'showroom_api.dart';

/// The SHOWROOM source. One [NetworkClient] for the process the source lives in.
final class ShowroomSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        AnchorSearchCapability,
        ResolveCapability,
        QualityCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  ShowroomSource({NetworkClient? client, Clock? clock})
    : _api = ShowroomApi(client: client, clock: clock),
      _clock = clock ?? systemClock;

  final ShowroomApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    final catalog = await _api.catalog();
    return _slice(catalog.popular, page, unfiltered: true);
  }

  @override
  Future<List<ContentCategory>> categories() async {
    final catalog = await _api.catalog();
    return <ContentCategory>[for (final genre in catalog.genres) ContentCategory(id: '${genre.id}', name: genre.name)];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final catalog = await _api.catalog();
    final genre = query.category?.trim() ?? '';
    if (genre.isEmpty) {
      return _slice(catalog.popular, query.page, unfiltered: true);
    }
    final id = int.tryParse(genre);
    if (id == null || id < 0) {
      // async on purpose: an unknown genre reaches the caller as a Future error.
      throw ShowroomFailure('not a showroom genre this source has seen: "$genre"');
    }
    final block = catalog.genre(id);
    if (block == null) {
      throw ShowroomFailure('no showroom genre $id', missing: true);
    }
    return _slice(block.lives, query.page);
  }

  PageResult<ContentSummary> _slice(List<ShowroomLive> lives, PageRequest request, {bool unfiltered = false}) {
    if (request.page < 1) {
      throw const ShowroomFailure('pages start at 1');
    }
    final start = (request.page - 1) * showroomPageSize;
    final rooms = start >= lives.length
        ? const <ShowroomLive>[]
        : lives.sublist(start, (start + showroomPageSize).clamp(0, lives.length));
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final live in rooms) live.toLiveRoom().summary],
      page: request.page,
      // The width this source pages at, which is not the caller's - the snapshot has no server-side size to honour.
      pageSize: rooms.length,
      hasMore: start + rooms.length < lives.length,
      total: lives.length,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final live = room.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: room.profile.description,
      metadata: <String, Object?>{'liveStatus': room.liveStatus, 'onlive': room.profile.isOnAir},
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId, withMedia: true)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // Profile plus one live-info read: no stream list, so a poll does not pay for addresses it will not use.
    final room = await _api.room(ref.contentId);
    return LiveRoomStatus(
      ref: ref,
      state: room.toLiveRoom().state,
      viewers: room.isLive ? room.profile.totalViewers : null,
      title: room.profile.name,
      cover: room.profile.cover.isEmpty ? null : room.profile.cover,
      anchorName: room.profile.name,
      startedAt: room.isLive ? room.profile.startedAt : null,
    );
  }

  /// A filter over the snapshot, which is what this site's public surface allows.
  ///
  /// SHOWROOM has no anonymous keyword index; v1's search was the same scan. Saying so here is what keeps the
  /// result count honest: it is "nobody in the current on-air list matches that", not "nobody on SHOWROOM".
  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final lives = await _matches(query.keyword);
    return _slice(lives, query.page);
  }

  @override
  Future<PageResult<AnchorSummary>> searchAnchors(SearchQuery query) async {
    final lives = await _matches(query.keyword);
    return PageResult<AnchorSummary>(
      items: <AnchorSummary>[
        for (final live in lives)
          AnchorSummary(
            ref: ContentRef(sourceId: showroomSourceId, contentId: '${live.roomId}', kind: ContentKind.anchor),
            name: live.name,
            avatar: live.cover.isEmpty ? null : live.cover,
            fans: live.followers,
            description: live.telop.isEmpty ? null : live.telop,
            // Every row here came from the on-air snapshot, so the room it is in is known.
            currentRoom: ContentRef(
              sourceId: showroomSourceId,
              contentId: '${live.roomId}',
              kind: ContentKind.liveRoom,
            ),
          ),
      ],
      page: query.page.page,
      pageSize: lives.length,
      mode: PageMode.fixedPage,
    );
  }

  Future<List<ShowroomLive>> _matches(String keyword) async {
    final term = keyword.trim().toLowerCase();
    if (term.isEmpty || term.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(term)) {
      throw const ShowroomFailure('a search term must be 1-100 printable characters');
    }
    final catalog = await _api.catalog();
    final numeric = int.tryParse(term);
    return <ShowroomLive>[
      for (final live in catalog.uniqueLives)
        if (numeric != null && numeric > 0
            ? live.roomId == numeric
            : live.slug.toLowerCase() == term ||
                  live.name.toLowerCase().contains(term) ||
                  live.telop.toLowerCase().contains(term) ||
                  live.genreName.toLowerCase().contains(term))
          live,
    ];
  }

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId, withMedia: true);
    if (!room.isLive) {
      return const <StreamOption>[];
    }
    final streams = _ordered(room);
    return <StreamOption>[
      for (final stream in streams)
        StreamOption(
          id: stream.id0,
          kind: StreamOptionKind.quality,
          // The site does label its rows, and the tier bands are its own `quality` codes: 自動 for the adaptive
          // hls_all row, then 原画 / 中画質 / 低画質 by the number it published.
          label: stream.tierLabel,
          rank: stream.rank,
          isDefault: stream.isDefault,
          available: stream.url.isNotEmpty,
        ),
    ];
  }

  /// The site's own order: the automatic tier first, then by its quality band.
  List<ShowroomStream> _ordered(ShowroomRoom room) {
    final streams = <ShowroomStream>[...room.streams]
      ..sort((ShowroomStream left, ShowroomStream right) {
        final byRank = right.rank.compareTo(left.rank);
        return byRank != 0 ? byRank : left.id0.compareTo(right.id0);
      });
    return streams;
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final room = await _api.room(ref.contentId, withMedia: true);
    if (line != null) {
      // One address per row: SHOWROOM's list varies the tier, not the route, so there is no line axis to offer.
      throw StateError('showroom serves one address per tier; line "${line.id}" does not exist');
    }
    if (!room.isLive) {
      throw StateError(
        room.disagree
            ? 'showroom room ${room.profile.roomId} disagrees with itself about being on air'
            : 'showroom room ${room.profile.roomId} is not broadcasting',
      );
    }
    final streams = _ordered(room);
    if (streams.isEmpty) {
      throw StateError('showroom room ${room.profile.roomId} is on air but shipped no address we will open');
    }
    final chosen = _stream(streams, quality);
    final uri = Uri.parse(chosen.url);
    return MediaTicket(
      id: '$showroomSourceId/${room.profile.roomId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: Map<String, String>.from(showroomHeaders),
      // The address is issued per read and the site states no lease, so the host re-asks rather than prefetching
      // on an invented schedule.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: showroomSourceId, contentId: '${room.profile.roomId}', kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.profile.name,
        artist: room.profile.name,
        isLive: true,
        extra: <String, Object?>{
          'container': 'm3u8',
          'showroom.quality': chosen.id0,
          'showroom.label': chosen.tierLabel,
          'showroom.type': chosen.type,
          if (quality != null && quality.id.trim() != chosen.id0) 'showroom.requestedQuality': quality.id,
        },
      ),
    );
  }

  ShowroomStream _stream(List<ShowroomStream> streams, SelectionRef? quality) {
    final id = quality?.id.trim() ?? '';
    if (id.isEmpty) {
      return streams.firstWhere((ShowroomStream stream) => stream.isDefault, orElse: () => streams.first);
    }
    for (final stream in streams) {
      if (stream.id0 == id) {
        return stream;
      }
    }
    // The tier list can change between the menu read and the play read; the site's default row is the answer that
    // keeps the viewer watching, and the ask is recorded so the surface can say it was not honoured.
    return streams.firstWhere((ShowroomStream stream) => stream.isDefault, orElse: () => streams.first);
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$showroomSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('showroom ticket ${expired.id} does not name a room');
    }
    final extra = expired.metadata.extra;
    return resolve(
      ContentRef(
        sourceId: showroomSourceId,
        contentId: expired.id.substring(prefix.length),
        kind: ContentKind.liveRoom,
      ),
      quality: extra['showroom.quality'] is String ? SelectionRef('${extra['showroom.quality']}') : null,
    );
  }
}

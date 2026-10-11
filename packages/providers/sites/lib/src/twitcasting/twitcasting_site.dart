// Module: lib/src/twitcasting/twitcasting_site.dart
// Purpose: The TwitCasting source: the scraped category bar, the bounded directory window, the search page, the
// two-read room pipeline and the three-tier hls menu.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: capability answers follow the v1-maintained TwitCasting line (origin/master
// lib/shared/platforms/twitcasting/twitcasting_site.dart). Fresh implementation against the v2 contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: twitcasting_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// What this source declares is bounded by what its endpoints answer. `liveStatus` and `qualities` read the stream
// server only - the page is for display fields, and the boolean on the stream server is what decides whether an
// address means anything. There is **no line axis**: one tier is one address, and a second picker could only ever
// say "1". A search term that is a channel url resolves the room instead of searching, because a shared link has to
// find an offline channel too - and a movie url is refused rather than answered with the channel's *current*
// broadcast, which would be a different show.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'twitcasting_api.dart';

/// The TwitCasting source. One [NetworkClient] for the process the source lives in.
final class TwitcastingSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        ResolveCapability,
        QualityCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  TwitcastingSource({NetworkClient? client, Clock? clock})
    : _api = TwitcastingApi(client: client),
      _clock = clock ?? systemClock;

  final TwitcastingApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    final width = _width(page.pageSize, twitcastingDirectoryWindow);
    final rows = await _api.directory(page: page.page, pageSize: width);
    return _window(rows, page, width: width);
  }

  @override
  Future<List<ContentCategory>> categories() async {
    final found = await _api.categories();
    return <ContentCategory>[for (final category in found) category.toContentCategory()];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isNotEmpty && !twitcastingDirectoryKeyPattern.hasMatch(category)) {
      throw TwitcastingFailure('not a twitcasting category key: "$category"');
    }
    final width = _width(query.page.pageSize, twitcastingDirectoryWindow);
    final rows = await _api.directory(page: query.page.page, pageSize: width, category: category);
    return _window(rows, query.page, width: width);
  }

  /// A page is filled when the site still had rows past this slice; the window is filtered server-side and the
  /// answer states no total, so "it kept filling" is the honest continuation and not a number we invented.
  PageResult<ContentSummary> _window(List<TwitcastingCard> rows, PageRequest request, {required int width}) =>
      PageResult<ContentSummary>(
        items: <ContentSummary>[for (final row in rows) row.toRoom().toLiveRoom().summary],
        page: request.page,
        pageSize: rows.length,
        hasMore: rows.length >= width,
        mode: PageMode.fixedPage,
      );

  int _width(int requested, int limit) => requested < 1
      ? twitcastingPageSize
      : requested > limit
      ? limit
      : requested;

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(_channel(ref));
    return ContentDetail(
      summary: room.toLiveRoom().summary,
      metadata: <String, Object?>{
        'live': room.reportedLive,
        'tiers': room.tiers.length,
        if (room.movieId != null) 'movieId': room.movieId,
        if (room.passwordGate) 'passwordGate': true,
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(_channel(ref))).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // The stream server alone: one read, and the only field on it that decides anything.
    final room = await _api.status(_channel(ref));
    return LiveRoomStatus(
      ref: ref,
      state: room.state,
      viewers: room.viewers,
      title: room.title.isEmpty ? null : room.title,
      cover: room.cover.isEmpty ? null : room.cover,
      anchorName: room.nick.isEmpty ? null : room.nick,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final term = query.keyword.trim();
    final request = query.page;
    final channel = twitcastingChannelFromUri(Uri.tryParse(term) ?? Uri());
    if (channel != null) {
      // One room is the whole answer: a channel url has no second page, and a movie or archive url is not routed
      // here at all - that identifies a broadcast, not the channel's current session.
      if (request.page != 1) {
        return _hits(const <TwitcastingCard>[], request);
      }
      try {
        return PageResult<ContentSummary>(
          items: <ContentSummary>[(await _api.room(channel)).toLiveRoom().summary],
          page: request.page,
          pageSize: 1,
          mode: PageMode.fixedPage,
        );
      } on TwitcastingFailure catch (error) {
        // A channel the site does not serve is "no results", not an error a search surface should raise.
        if (error.missing) {
          return _hits(const <TwitcastingCard>[], request);
        }
        rethrow;
      }
    }
    final width = _width(request.pageSize, twitcastingSearchWindow);
    return _hits(
      await _api.search(term, page: request.page, pageSize: width),
      request,
      width: width,
    );
  }

  PageResult<ContentSummary> _hits(List<TwitcastingCard> rows, PageRequest request, {int width = 0}) =>
      PageResult<ContentSummary>(
        items: <ContentSummary>[for (final row in rows) row.toRoom().toLiveRoom().summary],
        page: request.page,
        pageSize: rows.length,
        hasMore: width > 0 && rows.length >= width,
        mode: PageMode.fixedPage,
      );

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.status(_channel(ref));
    if (!room.isLive) {
      return const <StreamOption>[];
    }
    return <StreamOption>[
      for (final tier in room.tiers)
        StreamOption(
          id: tier.name,
          kind: StreamOptionKind.quality,
          label: tier.label,
          rank: tier.rank,
          // The answer states no bitrate, width or codec for a tier, and none of them are invented here.
          available: true,
          isDefault: tier == room.tiers.first,
        ),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    if (line != null) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('TwitCasting serves one address per tier; line "${line.id}" does not exist');
    }
    final room = await _api.room(_channel(ref));
    if (room.passwordGate) {
      throw StateError('TwitCasting channel ${room.channel} is behind a password this path does not answer');
    }
    if (!room.isLive) {
      throw StateError(
        room.state == LiveRoomState.ended
            ? 'TwitCasting channel ${room.channel} is not broadcasting'
            : 'TwitCasting channel ${room.channel} did not state that it is broadcasting',
      );
    }
    if (room.tiers.isEmpty) {
      throw StateError('TwitCasting channel ${room.channel} is live but names no tier to sign for');
    }
    final chosen = _tier(room, quality);
    final movieId = room.movieId!;
    return MediaTicket(
      id: '$twitcastingSourceId/${room.channel}',
      uri: chosen.url,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: twitcastingHeaders,
      // The path carries no signature of its own, but the broadcast id does change between sessions, so a
      // recovery re-reads the stream server rather than reusing an address for a show that has ended.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: twitcastingSourceId, contentId: room.channel, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.title,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': 'm3u8',
          'twitcasting.tier': chosen.name,
          'twitcasting.movieId': movieId,
          if (quality != null && !_sameTier(quality.id, chosen)) 'twitcasting.requestedTier': quality.id.trim(),
        },
      ),
    );
  }

  /// The site's keys are lower-cased already; an ask that came from a stored selection is matched without case
  /// so a menu that capitalised its label still gets the tier it showed.
  static bool _sameTier(String asked, TwitcastingTier tier) => asked.trim().toLowerCase() == tier.name;

  TwitcastingTier _tier(TwitcastingRoom room, SelectionRef? wanted) {
    final id = (wanted?.id ?? '').trim().toLowerCase();
    if (id.isEmpty) {
      return room.tiers.first;
    }
    for (final tier in room.tiers) {
      if (tier.name == id) {
        return tier;
      }
    }
    // A tier the channel no longer offers falls back to the best one it does offer, and the ask is written down
    // so the surface can say it was not honoured.
    return room.tiers.first;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$twitcastingSourceId/';
    if (!expired.id.startsWith(prefix)) {
      throw StateError('TwitCasting ticket ${expired.id} does not name a channel');
    }
    final extra = expired.metadata.extra;
    return resolve(
      ContentRef(
        sourceId: twitcastingSourceId,
        contentId: expired.id.substring(prefix.length),
        kind: ContentKind.liveRoom,
      ),
      quality: extra['twitcasting.tier'] is String ? SelectionRef('${extra['twitcasting.tier']}') : null,
    );
  }

  String _channel(ContentRef ref) {
    if (ref.sourceId != twitcastingSourceId) {
      throw TwitcastingFailure('ref ${ref.sourceId}/${ref.contentId} is not a twitcasting channel');
    }
    return twitcastingChannelName(ref.contentId);
  }
}

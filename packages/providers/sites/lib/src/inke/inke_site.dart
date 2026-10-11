// Module: lib/src/inke/inke_site.dart
// Purpose: The Inke live source: the finite website showcase, its tabs, the room answer and the verbatim flv url.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Inke line (origin/master
// lib/shared/platforms/inke/inke_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// What this site declares is small on purpose. Inke's anonymous surface gives three **finite** catalogues and a
// room endpoint; it gives no pagination, no server-side nickname index and no audience number. So:
//   * feed and browse answer [PageMode.singleShot] - page 2 is empty by fact, not by failure;
//   * search is the local filter over those catalogues, and the page says so in [PageResult.total] plus a
//     declared limit: it cannot discover an anchor who is not in the two showcases;
//   * no quality axis and no line axis are declared - there is one verbatim flv per broadcast.
// Declaring search as a full index would be the lie: a viewer who types a name outside the showcases gets "no
// results" and reads that as "they are not live".

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'inke_api.dart';

/// The keyword ceiling the showcase filter accepts.
const int inkeSearchKeywordLimit = 100;

/// The Inke source. One [NetworkClient] for the process the source lives in.
final class InkeSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        ResolveCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  InkeSource({NetworkClient? client, Clock? clock}) : _api = InkeApi(client: client), _clock = clock ?? systemClock;

  final InkeApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    if (page.page > 1) {
      // One finite showcase; inventing an offset API from its size is how the same rooms come back forever.
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: page.page,
        pageSize: page.pageSize,
        mode: PageMode.singleShot,
      );
    }
    final rows = await _api.showcase();
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final row in rows) row.toSummary()],
      page: 1,
      pageSize: rows.length,
      hasMore: false,
      total: rows.length,
      mode: PageMode.singleShot,
    );
  }

  @override
  Future<List<ContentCategory>> categories() async {
    final channels = await _api.channels();
    return <ContentCategory>[for (final channel in channels) ContentCategory(id: channel.key, name: channel.name)];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category;
    if (category == null || category.isEmpty) {
      return feed(query.page);
    }
    if (query.page.page > 1) {
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: query.page.page,
        pageSize: query.page.pageSize,
        mode: PageMode.singleShot,
      );
    }
    final channels = await _api.channels();
    final matches = <InkeChannel>[
      for (final channel in channels)
        if (channel.key == category) channel,
    ];
    if (matches.length != 1) {
      throw InkeFailure('the showcase has no tab "$category"');
    }
    final rows = matches.single.rows;
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final row in rows) row.toSummary()],
      page: 1,
      pageSize: rows.length,
      hasMore: false,
      total: rows.length,
      mode: PageMode.singleShot,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final keyword = query.keyword.trim();
    if (keyword.length > inkeSearchKeywordLimit) {
      throw InkeFailure('a showcase filter cannot take a $keyword-length query');
    }
    // Both catalogues are read, then filtered by the name the site displays. This is a local substring match
    // over a finite list, and the caller is told which: `total` is what matched here, not what the site knows.
    final rows = <String, InkeShowcaseRow>{
      for (final row in [
        ...await _api.showcase(),
        ...[for (final c in await _api.channels()) ...c.rows],
      ])
        row.uid: row,
    };
    final needle = keyword.toLowerCase();
    final matches = <ContentSummary>[
      if (needle.isNotEmpty)
        for (final row in rows.values)
          if (row.nick.toLowerCase().contains(needle)) row.toSummary(),
    ];
    return PageResult<ContentSummary>(
      items: matches,
      page: 1,
      pageSize: matches.length,
      hasMore: false,
      total: matches.length,
      mode: PageMode.singleShot,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(ref.contentId, withStream: false);
    final live = room.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: live.introduction ?? room.title,
      metadata: <String, Object?>{'isLive': room.isStreaming},
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // withStream:false is the point of this method: a follow-list poll must not read three catalogues per room
    // just to learn whether anyone is on air.
    final room = await _api.room(ref.contentId, withStream: false);
    return LiveRoomStatus(
      ref: ref,
      state: room.isStreaming ? LiveRoomState.live : LiveRoomState.ended,
      title: room.title.isEmpty ? null : room.title,
      cover: room.cover,
      anchorName: room.nick.isEmpty ? null : room.nick,
      startedAt: room.startedAt,
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final room = await _api.room(ref.contentId);
    if (!room.isStreaming) {
      throw StateError('Inke anchor ${room.uid} has no broadcast in progress');
    }
    if (room.streamUrls.isEmpty) {
      // The broadcast is live; our anonymous catalogue simply has no verified address for it. Saying so is what
      // keeps this from being reported downstream as "the stream ended".
      throw StateError(
        'Inke broadcast ${room.broadcastId} is on air, but the anonymous showcase carries no verified '
        'stream address for it',
      );
    }
    if (line != null) {
      throw StateError('$inkeSourceId serves one verified address per broadcast; line "${line.id}" does not exist');
    }
    if (quality != null) {
      throw StateError('$inkeSourceId offers no quality choice on the anonymous path');
    }
    final uri = Uri.parse(room.streamUrls.first);
    return MediaTicket(
      id: '$inkeSourceId/${room.uid}',
      uri: uri,
      kind: MediaKind.live,
      // The path ends in `.flv` over https: FLV is the container and goes to the metadata, the enum records the
      // transport - the split docs/architecture/platform-models.md §11 asks for.
      protocol: MediaProtocol.https,
      createdAt: _clock().toUtc(),
      headers: Map<String, String>.from(inkeHeaders),
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: inkeSourceId, contentId: room.uid, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.title.isEmpty ? room.nick : room.title,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': 'flv',
          if (room.broadcastId != null) 'inke.broadcastId': room.broadcastId,
        },
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$inkeSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await
      // and the recovery ladder behind it.
      throw StateError('Inke ticket ${expired.id} does not name a room');
    }
    // The signed query is the site's, so a refresh re-reads the catalogue for a fresh verbatim url rather than
    // reusing or tweaking the expired one.
    return resolve(
      ContentRef(sourceId: inkeSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
    );
  }
}

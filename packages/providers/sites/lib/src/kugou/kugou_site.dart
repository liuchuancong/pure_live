// Module: lib/src/kugou/kugou_site.dart
// Purpose: The Kugou (Fanxing) live source: recommend feed, scraped categories, search, room state and the
// quality/line pair the multi-line endpoint ships.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Kugou line (origin/master
// lib/shared/platforms/kugoulive/kugou_live_site.dart). Fresh implementation against the v2 capability
// contracts, not a merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: kugou_api.dart owns the requests and the readers, this class only answers the
// capability interfaces. It is also the site that finally uses both axes: the stream-address endpoint ships
// rate/codec/layout profiles, and each profile carries several cdn urls. Those are two different menus, and the
// resolve signature has always had exactly two slots for them.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'kugou_api.dart';

/// The Kugou source. One [NetworkClient] for the process the source lives in.
final class KugouSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        ResolveCapability,
        QualityCapability,
        LineCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  KugouSource({NetworkClient? client, Clock? clock}) : _api = KugouApi(client: client), _clock = clock ?? systemClock;

  final KugouApi _api;
  final Clock _clock;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) => _page(page, kugouRecommendCategoryId);

  @override
  Future<List<ContentCategory>> categories() async {
    final list = await _api.categories();
    return <ContentCategory>[for (final category in list) ContentCategory(id: category.id, name: category.name)];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) =>
      _page(query.page, query.category?.trim().isEmpty ?? true ? kugouRecommendCategoryId : query.category!.trim());

  Future<PageResult<ContentSummary>> _page(PageRequest request, String categoryId) async {
    final data = await _api.directory(page: request.page, categoryId: categoryId);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final card in data.rooms) card.toSummary()],
      page: request.page,
      pageSize: request.pageSize,
      // The endpoint states its own continuation. Anything it does not state is answered false here: a guessed
      // true keeps a list spinning past the end.
      hasMore: data.hasMore,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final info = await _api.room(ref.contentId);
    final room = info.toLiveRoom();
    return ContentDetail(
      summary: room.summary,
      description: info.notice,
      metadata: <String, Object?>{'state': info.state.name},
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // One request, no media lookup: the entry-info answer carries the two fields that decide on-air-ness.
    final info = await _api.room(ref.contentId);
    return LiveRoomStatus(
      ref: ref,
      state: switch (info.state) {
        KugouBroadcast.live => LiveRoomState.live,
        KugouBroadcast.offline => LiveRoomState.ended,
        KugouBroadcast.unknown => LiveRoomState.unknown,
      },
      title: info.title,
      cover: info.cover,
      anchorName: info.nick,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    if (query.page.page > 1) {
      // The jsonp endpoint returns one fixed-size block (nums=200,0,0,0); there is no second page to ask for,
      // and pretending there is would rescan the same block.
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: query.page.page,
        pageSize: query.page.pageSize,
        mode: PageMode.singleShot,
      );
    }
    final cards = await _api.search(query.keyword);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final card in cards) card.toSummary()],
      page: 1,
      pageSize: cards.length,
      hasMore: false,
      total: cards.length,
      mode: PageMode.singleShot,
    );
  }

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId, withStream: true);
    return <StreamOption>[
      for (final variant in room.variants)
        StreamOption(
          id: variant.id,
          kind: StreamOptionKind.quality,
          // The site gives a number, not a name. A label of "720p" would be our inference about what a rate
          // means, and inference is what the platform-models rule on quality wording forbids.
          label: '${variant.container} ${variant.rate}',
          isDefault: variant == room.variants.first,
          bitrateKbps: variant.rate,
          available: variant.urls.isNotEmpty,
        ),
    ];
  }

  /// The cdn urls of the top profile, numbered.
  ///
  /// Lines are scoped to one profile on purpose: kugou's urls are signed per profile, so an hls address cannot
  /// stand in for an flv one and a menu that mixed them would offer combinations the endpoint never issued.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final room = await _api.room(ref.contentId, withStream: true);
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
    final room = await _api.room(ref.contentId, withStream: true);
    if (room.state == KugouBroadcast.offline) {
      throw StateError('Kugou room ${room.roomId} is offline');
    }
    if (room.variants.isEmpty) {
      // `unknown` reaches here too, and it must stay distinguishable from offline: this says the endpoint
      // stopped telling us, not that the broadcast stopped.
      throw StateError('Kugou room ${room.roomId} carries no address we are allowed to open');
    }
    final variant = _variant(room.variants, quality);
    final index = _lineIndex(line, variant.urls.length);
    final uri = Uri.parse(variant.urls[index]);
    return MediaTicket(
      id: '$kugouSourceId/${room.roomId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: variant.container == 'hls' ? MediaProtocol.hls : MediaProtocol.https,
      createdAt: _clock().toUtc(),
      headers: Map<String, String>.from(kugouHeaders),
      // The signature carries its own expiry in `txTime`; the endpoint states no lease length we could turn
      // into a prefetch trigger, so none is invented and the host re-resolves when the stream dies.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: kugouSourceId, contentId: room.roomId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: (room.title?.isNotEmpty ?? false) ? room.title : room.nick,
        artist: room.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': variant.container,
          'kugou.rate': variant.rate,
          'kugou.quality': variant.id,
          'kugou.line': index + 1,
          if (quality != null && quality.id.trim() != variant.id) 'kugou.requestedQuality': quality.id,
        },
      ),
    );
  }

  KugouVariant _variant(List<KugouVariant> variants, SelectionRef? quality) {
    final id = quality?.id.trim() ?? '';
    if (id.isEmpty) {
      return variants.first;
    }
    for (final variant in variants) {
      if (variant.id == id && variant.urls.isNotEmpty) {
        return variant;
      }
    }
    // The profile list changes between the menu read and the play read; the viewer still gets a stream, and the
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
        'Kugou offers $available url(s) for this profile; line "${line.id}" is not one of them '
        '(the site names none of them, so they are numbered)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$kugouSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await
      // and the recovery ladder sitting behind it.
      throw StateError('Kugou ticket ${expired.id} does not name a room');
    }
    final extra = expired.metadata.extra;
    return resolve(
      ContentRef(sourceId: kugouSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      // The signed url dies with its `txTime`; a refresh re-asks the endpoint and stays on the same profile and
      // the same cdn position rather than reusing the dead address.
      quality: extra['kugou.quality'] is String ? SelectionRef('${extra['kugou.quality']}') : null,
      line: extra['kugou.line'] == null ? null : SelectionRef('${extra['kugou.line']}'),
    );
  }
}

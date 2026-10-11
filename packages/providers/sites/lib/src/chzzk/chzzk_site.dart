// Module: lib/src/chzzk/chzzk_site.dart
// Purpose: The CHZZK source: the inclusive-cursor directory, channel search read as rooms and people, the two-call
// room and the master-manifest renditions.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained CHZZK line (origin/master
// lib/shared/platforms/chzzk/chzzk_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: chzzk_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// What this source declares is bounded by what its endpoints answer. The playable menu is not in the room answer:
// `livePlaybackJson` names manifests, and the renditions only exist once those are read - so `qualities` and
// `resolve` each cost the room's two calls plus one fetch per manifest, and a room can honestly be "on air with no
// qualities we can name". The directory continues by the server's inclusive cursor, and the search indexes
// channels rather than broadcasts.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'chzzk_api.dart';

/// The CHZZK source. One [NetworkClient] for the process the source lives in.
final class ChzzkSource
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
  ChzzkSource({NetworkClient? client, Clock? clock}) : _api = ChzzkApi(client: client), _clock = clock ?? systemClock;

  final ChzzkApi _api;
  final Clock _clock;

  /// The one directory the site publishes.
  static const String _directory = 'popular';

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async => _page(page);

  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[
    // v1's own wording for it: this is the public live directory, and the site has no other browsable list.
    ContentCategory(id: _directory, name: '公共目录'),
  ];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isNotEmpty && category != _directory) {
      // async on purpose: an unknown listing is a Future error, not a throw that escapes the await site.
      throw ChzzkFailure('chzzk publishes one live directory; "$category" is not it');
    }
    return _page(query.page);
  }

  Future<PageResult<ContentSummary>> _page(PageRequest request) async {
    if (request.page < 1) {
      throw const ChzzkFailure('directory pages start at 1');
    }
    if (request.page > 1 && (request.cursor ?? '').isEmpty) {
      throw const ChzzkFailure('a chzzk directory page past the first needs the cursor the previous answer gave');
    }
    final result = await _api.directory(cursor: request.cursor);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[
        // Two rows can name one channel when it is listed twice; a list that shows the same room twice makes the
        // second tap ambiguous.
        for (final live in _deduped(result.lives)) live.toLiveRoom().summary,
      ],
      page: request.page,
      pageSize: chzzkDirectoryPageSize,
      hasMore: result.hasMore,
      mode: PageMode.cursor,
      nextCursor: result.cursor,
    );
  }

  List<ChzzkLive> _deduped(List<ChzzkLive> lives) {
    final seen = <String>{};
    return <ChzzkLive>[
      for (final live in lives)
        if (seen.add(live.channel.id)) live,
    ];
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    final live = room.toLiveRoom();
    final broadcast = room.live;
    return ContentDetail(
      summary: live.summary,
      description: room.channel.description,
      metadata: <String, Object?>{
        'state': live.state.name,
        if (broadcast != null) 'liveId': broadcast.liveId,
        if (broadcast != null) 'media': broadcast.media.length,
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // Two calls: the channel and its live detail. There is no cheaper status endpoint, and saying so here is
    // better than a poll that quietly costs more than the room page does.
    final room = await _api.room(ref.contentId);
    final live = room.live;
    return LiveRoomStatus(
      ref: ref,
      state: live == null || !live.isLive ? LiveRoomState.ended : LiveRoomState.live,
      viewers: live?.viewers,
      title: live == null ? room.channel.name : (live.title.isEmpty ? null : live.title),
      cover: (live?.cover ?? '').isEmpty ? room.channel.avatar : live!.cover,
      anchorName: room.channel.name,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final channels = await _channels(query);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final channel in channels) _card(channel).summary],
      page: query.page.page,
      pageSize: chzzkSearchPageSize,
      // The endpoint states an offset rather than a continuation, so a short block is the end.
      hasMore: channels.length >= chzzkSearchPageSize,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<PageResult<AnchorSummary>> searchAnchors(SearchQuery query) async {
    final channels = await _channels(query);
    return PageResult<AnchorSummary>(
      items: <AnchorSummary>[
        for (final channel in channels)
          AnchorSummary(
            ref: ContentRef(sourceId: chzzkSourceId, contentId: channel.id, kind: ContentKind.anchor),
            name: channel.name,
            avatar: channel.avatar.isEmpty ? null : channel.avatar,
            fans: channel.followers,
            description: channel.description.isEmpty ? null : channel.description,
            currentRoom: channel.isLive ? channel.ref : null,
          ),
      ],
      page: query.page.page,
      pageSize: chzzkSearchPageSize,
      hasMore: channels.length >= chzzkSearchPageSize,
      mode: PageMode.fixedPage,
    );
  }

  Future<List<ChzzkChannel>> _channels(SearchQuery query) async {
    final page = query.page.page;
    if (page < 1) {
      throw const ChzzkFailure('search pages start at 1');
    }
    return _api.searchChannels(query.keyword, offset: (page - 1) * chzzkSearchPageSize);
  }

  /// A search row as a room. The search answer says only whether a channel is open, so an offline row is offline
  /// and an open one still has to be read before anything can be played.
  LiveRoom _card(ChzzkChannel channel) => ChzzkLive(
    liveId: 0,
    channel: channel,
    title: channel.name,
    cover: channel.avatar,
    category: '',
    viewers: null,
    adult: false,
    regionRestricted: false,
    isLive: channel.isLive,
    timeMachine: false,
    media: const <ChzzkMedia>[],
    chatChannelId: '',
  ).toLiveRoom();

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final variants = await _renditions((await _api.room(ref.contentId)).live);
    return <StreamOption>[
      for (final variant in variants)
        StreamOption(
          id: variant.key,
          kind: StreamOptionKind.quality,
          label: variant.label,
          codec: 'h264',
          rank: variant.rank,
          bitrateKbps: variant.bitrateKbps,
          height: variant.height,
          isDefault: variant == variants.first,
          available: variant.urls.isNotEmpty,
        ),
    ];
  }

  /// The addresses inside the top rendition group.
  ///
  /// HLS and LLHLS renditions of one shape merge into the same group, so they are two ways to reach the same
  /// picture rather than two qualities - and a viewer who asks for "the low-latency one" is asking for a line.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final variants = await _renditions((await _api.room(ref.contentId)).live);
    final top = variants.isEmpty ? null : variants.first;
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
    final live = room.live;
    if (live == null || !live.isLive) {
      throw StateError('CHZZK channel ${room.channel.id} is not broadcasting');
    }
    final variants = await _renditions(live);
    if (variants.isEmpty) {
      // The gates are named because they are the reason: a region-restricted answer ships no playback at all,
      // and that is the site refusing this path rather than a stream that stopped.
      throw StateError(
        live.regionRestricted
            ? 'CHZZK channel ${live.channel.id} is not viewable from this path (the site limits it to Korea)'
            : live.adult
            ? 'CHZZK channel ${live.channel.id} is an age-gated broadcast with no address this path was given'
            : 'CHZZK channel ${live.channel.id} is on air but its manifests name no rendition we can open',
      );
    }
    final chosen = _variant(variants, quality);
    final index = _lineIndex(line, chosen.urls.length);
    final uri = Uri.parse(chosen.urls[index]);
    return MediaTicket(
      id: '$chzzkSourceId/${live.channel.id}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: Map<String, String>.from(chzzkMediaHeaders),
      // The addresses come from a manifest that is itself signed, and neither states a lease length: none is
      // invented, and the host re-reads when the stream dies.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: live.channel.ref,
      metadata: MediaPlaybackMetadata(
        title: live.title.isEmpty ? live.channel.name : live.title,
        artist: live.channel.name,
        isLive: true,
        extra: <String, Object?>{
          'container': 'm3u8',
          'chzzk.quality': chosen.key,
          'chzzk.line': index + 1,
          'chzzk.liveId': live.liveId,
          'chzzk.height': chosen.height,
          if (uri.toString().contains('llhls')) 'chzzk.lowLatency': true,
          if (quality != null && quality.id.trim() != chosen.key) 'chzzk.requestedQuality': quality.id,
        },
      ),
    );
  }

  /// The renditions of one already-read broadcast: one manifest fetch per media entry.
  ///
  /// The room is read by the caller and passed in, because a play path that fetched it twice would double the
  /// cost of every quality menu and still get the same answer.
  Future<List<ChzzkVariant>> _renditions(ChzzkLive? live) async {
    if (live == null || !live.isLive || live.media.isEmpty) {
      return const <ChzzkVariant>[];
    }
    final grouped = <String, _RenditionDraft>{};
    for (final media in live.media) {
      for (final variant in await _api.variantsFor(media)) {
        final draft = grouped.putIfAbsent(variant.key, () => _RenditionDraft(variant));
        draft.merge(variant);
      }
    }
    final variants = grouped.values.map((_RenditionDraft draft) => draft.variant).toList(growable: false)
      ..sort((ChzzkVariant left, ChzzkVariant right) => right.rank.compareTo(left.rank));
    return List<ChzzkVariant>.unmodifiable(variants);
  }

  ChzzkVariant _variant(List<ChzzkVariant> variants, SelectionRef? quality) {
    final id = quality?.id.trim() ?? '';
    if (id.isEmpty) {
      return variants.first;
    }
    for (final variant in variants) {
      if (variant.key == id && variant.urls.isNotEmpty) {
        return variant;
      }
    }
    // The manifest can change between the menu read and the play read; the viewer still gets a stream and the
    // ticket records the ask.
    return variants.first;
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'CHZZK offers $available address(es) for that rendition; line "${line.id}" is not one of them '
        '(the manifests name no lines, so they are numbered in the order the site listed them)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$chzzkSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('CHZZK ticket ${expired.id} does not name a channel');
    }
    final extra = expired.metadata.extra;
    return resolve(
      // Re-read the room and its manifests: the renditions are re-issued per broadcast, and a cached address from
      // the previous one would play yesterday's show under today's title.
      ContentRef(sourceId: chzzkSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      quality: extra['chzzk.quality'] is String ? SelectionRef('${extra['chzzk.quality']}') : null,
      line: extra['chzzk.line'] == null ? null : SelectionRef('${extra['chzzk.line']}'),
    );
  }
}

final class _RenditionDraft {
  _RenditionDraft(ChzzkVariant first)
    : height = first.height,
      key = first.key,
      fps = first.fps,
      rank = first.rank,
      bitrateKbps = first.bitrateKbps,
      urls = <String>[...first.urls];

  final String key;
  final int height;
  double fps;
  int rank;
  int bitrateKbps;
  final List<String> urls;

  void merge(ChzzkVariant variant) {
    for (final url in variant.urls) {
      if (!urls.contains(url)) {
        urls.add(url);
      }
    }
    if (variant.rank > rank) {
      rank = variant.rank;
    }
    if (variant.bitrateKbps > bitrateKbps) {
      bitrateKbps = variant.bitrateKbps;
    }
    if (variant.fps > fps) {
      fps = variant.fps;
    }
  }

  ChzzkVariant get variant => ChzzkVariant(
    key: key,
    height: height,
    fps: fps,
    rank: rank,
    bitrateKbps: bitrateKbps,
    urls: List<String>.unmodifiable(urls),
  );
}

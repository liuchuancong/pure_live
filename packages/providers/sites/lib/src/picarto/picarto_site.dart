// Module: lib/src/picarto/picarto_site.dart
// Purpose: The Picarto source: the self-checking explore grid, the profile search, the single-stream detail and
// the playlist-grouped quality menu.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Picarto line (origin/master
// lib/shared/platforms/picarto/picarto_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: picarto_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// The play path is three requests deep - the channel detail to learn the stream, the master playlist to learn the
// renditions, and then the chosen address - which is why `liveStatus` deliberately stops at the detail and never
// fetches a playlist, and why an answer whose stream list does not hold exactly one row for this channel is a
// failure rather than a guess.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'picarto_api.dart';

/// The Picarto source. One [NetworkClient] for the process the source lives in.
final class PicartoSource
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
  PicartoSource({NetworkClient? client, Clock? clock})
    : _api = PicartoApi(client: client),
      _clock = clock ?? systemClock;

  final PicartoApi _api;
  final Clock _clock;

  /// The unfiltered explore grid, which is the site's own landing view.
  static const String _all = 'live';

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async => _page(page, null);

  @override
  Future<List<ContentCategory>> categories() async {
    final categories = await _api.categories();
    return <ContentCategory>[
      ContentCategory(id: _all, name: '全部直播'),
      for (final category in categories) category.toContentCategory(),
    ];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isEmpty || category == _all) {
      return _page(query.page, null);
    }
    final id = int.tryParse(category);
    if (id == null || id <= 0 || '$id' != category) {
      // async on purpose: an unknown category is a Future error, not a throw past the caller's await.
      throw PicartoFailure('not a picarto category this source has seen: "$category"');
    }
    return _page(query.page, id);
  }

  Future<PageResult<ContentSummary>> _page(PageRequest request, int? categoryId) async {
    final page = await _api.directory(
      page: request.page,
      // The server fills 30 and the answer is validated against the request, so the caller's size is not passed
      // on as if it had been honoured.
      categoryId: categoryId,
    );
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final channel in page.rooms) channel.toLiveRoom().summary],
      page: page.page,
      pageSize: picartoServerPageSize,
      hasMore: page.hasMore,
      total: page.total,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    // One detail read answers the description, the privacy flag and the summary.
    final channel = (await _api.detail(ref.contentId)).channel;
    final live = channel.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: channel.introduction,
      metadata: <String, Object?>{
        'online': channel.online,
        if (channel.isPrivate != null) 'private': channel.isPrivate,
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.detail(ref.contentId)).channel.toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // The detail answer alone: no playlist is read to answer "is it on".
    final detail = await _api.detail(ref.contentId);
    final channel = detail.channel;
    return LiveRoomStatus(
      ref: ref,
      state: channel.online ? LiveRoomState.live : LiveRoomState.ended,
      viewers: channel.viewers,
      title: channel.title.isEmpty ? null : channel.title,
      cover: channel.cover.isEmpty ? null : channel.cover,
      anchorName: channel.name,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final pageSize = query.page.pageSize.clamp(1, 60);
    final channels = await _api.searchProfiles(query.keyword, page: query.page.page, pageSize: pageSize);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final channel in channels) channel.toLiveRoom().summary],
      page: query.page.page,
      // The endpoint's own `count` is inconsistent across pages, so continuation is decided on what came back.
      pageSize: channels.length,
      hasMore: channels.length >= pageSize,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<PageResult<AnchorSummary>> searchAnchors(SearchQuery query) async {
    final pageSize = query.page.pageSize.clamp(1, 60);
    final channels = await _api.searchProfiles(query.keyword, page: query.page.page, pageSize: pageSize);
    return PageResult<AnchorSummary>(
      items: <AnchorSummary>[for (final channel in channels) channel.toAnchorSummary()],
      page: query.page.page,
      pageSize: channels.length,
      hasMore: channels.length >= pageSize,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final playlist = await _playlist(ref);
    return <StreamOption>[
      for (final quality in playlist.qualities)
        StreamOption(
          id: quality.id,
          kind: StreamOptionKind.quality,
          // The automatic master is the site's own fallback choice, and it is labelled because it is a decision
          // the player takes on the viewer's behalf rather than a rendition the site named.
          label: quality.label,
          rank: quality.isAuto ? null : quality.rank,
          isDefault: quality == playlist.qualities.first,
          available: quality.urls.isNotEmpty,
        ),
    ];
  }

  /// The cdn addresses inside the first quality, numbered.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final playlist = await _playlist(ref);
    final top = playlist.qualities.first;
    return <StreamOption>[
      for (var index = 0; index < top.urls.length; index++)
        StreamOption(id: '${index + 1}', kind: StreamOptionKind.line, isDefault: index == 0),
    ];
  }

  /// The channel, its master address and the renditions inside it - one detail read, one playlist read.
  Future<({PicartoChannel channel, Uri master, List<PicartoQuality> qualities})> _playlist(ContentRef ref) async {
    final detail = await _api.detail(ref.contentId);
    final master = detail.master;
    if (master == null) {
      throw StateError(
        detail.channel.isPrivate == true
            ? 'Picarto channel ${detail.channel.name} is private and serves no stream to this path'
            : 'Picarto channel ${detail.channel.name} is not broadcasting',
      );
    }
    return (channel: detail.channel, master: master, qualities: picartoQualities(await _api.playlist(master), master));
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final playlist = await _playlist(ref);
    final chosen = _quality(playlist.qualities, quality);
    final index = _lineIndex(line, chosen.urls.length);
    final uri = Uri.parse(chosen.urls[index]);
    return MediaTicket(
      id: '$picartoSourceId/${ref.contentId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: Map<String, String>.from(picartoHeaders),
      // The load balancer issues the address per call and states no lease, so the host re-resolves rather than
      // prefetching on an invented schedule.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: picartoSourceId, contentId: playlist.channel.name, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: playlist.channel.title,
        artist: playlist.channel.name,
        isLive: true,
        extra: <String, Object?>{
          'container': 'm3u8',
          'picarto.quality': chosen.id,
          'picarto.label': chosen.label,
          'picarto.line': index + 1,
          if (chosen.isAuto) 'picarto.auto': true,
          if (quality != null && quality.id.trim() != chosen.id) 'picarto.requestedQuality': quality.id,
        },
      ),
    );
  }

  PicartoQuality _quality(List<PicartoQuality> qualities, SelectionRef? wanted) {
    final id = wanted?.id.trim() ?? '';
    if (id.isEmpty) {
      return qualities.first;
    }
    for (final quality in qualities) {
      if (quality.id == id && quality.urls.isNotEmpty) {
        return quality;
      }
    }
    // The playlist can differ between the menu read and the play read; the first entry is the site's own order.
    return qualities.first;
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'Picarto offers $available address(es) for that rendition; line "${line.id}" is not one of them '
        '(the site lists them without naming them, so they are numbered)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$picartoSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('Picarto ticket ${expired.id} does not name a channel');
    }
    final extra = expired.metadata.extra;
    return resolve(
      ContentRef(sourceId: picartoSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      quality: extra['picarto.quality'] is String ? SelectionRef('${extra['picarto.quality']}') : null,
      line: extra['picarto.line'] == null ? null : SelectionRef('${extra['picarto.line']}'),
    );
  }
}

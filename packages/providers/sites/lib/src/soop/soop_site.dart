// Module: lib/src/soop/soop_site.dart
// Purpose: The SOOP source: the category grid, the homepage block, the channel answer and the per-tier signed
// stream address.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained SOOP line (origin/master
// lib/shared/platforms/soop/soop_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: soop_api.dart owns the requests and the readers, this class only answers the
// capability answers.
//
// Play costs three reads here - the channel, the tier assignment and the aid signature - so `liveStatus` stops at
// the channel and `qualities` never touches the signing pair. A line is not offered: one tier has one address, so
// the second axis would be a picker that can only ever say "1".
//
// The cookie this source accepts is an operator's own session for the channels the anonymous path is not handed.
// Nothing here logs in, and a room the site gates is reported as such rather than played by stealth.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'soop_api.dart';

/// The SOOP source. One [NetworkClient] for the process the source lives in.
final class SoopSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        ResolveCapability,
        QualityCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  SoopSource({NetworkClient? client, Clock? clock, String? cookie})
    : _api = SoopApi(client: client, clock: clock, cookie: cookie),
      _cookie = (cookie ?? '').trim(),
      _clock = clock ?? systemClock;

  final SoopApi _api;
  final Clock _clock;
  final String _cookie;

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    final rooms = await _api.home(page: page.page);
    return _page(rooms, page, pageSize: rooms.length);
  }

  @override
  Future<List<ContentCategory>> categories() async {
    final categories = await _api.categories();
    return <ContentCategory>[for (final category in categories) category.toContentCategory()];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isEmpty) {
      return feed(query.page);
    }
    final rooms = await _api.directory(categoryNo: category, page: query.page.page);
    return _page(rooms, query.page, pageSize: rooms.length);
  }

  PageResult<ContentSummary> _page(List<SoopChannel> rooms, PageRequest request, {required int pageSize}) =>
      PageResult<ContentSummary>(
        items: <ContentSummary>[for (final room in rooms) room.toLiveRoom(cookie: _cookie).summary],
        page: request.page,
        pageSize: pageSize,
        // The site answers a block and states no total; the honest continuation is whether it kept filling one.
        hasMore: rooms.length >= (pageSize == 0 ? 1 : pageSize),
        mode: PageMode.fixedPage,
      );

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final channel = await _api.channel(ref.contentId);
    return ContentDetail(
      summary: channel.toLiveRoom(cookie: _cookie).summary,
      metadata: <String, Object?>{
        'result': channel.resultCode,
        'tiers': channel.qualities.length,
        if (channel.chatNo.isNotEmpty) 'chatNo': channel.chatNo,
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.channel(ref.contentId)).toLiveRoom(cookie: _cookie);

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // The channel answer alone: no assignment, no signature.
    final channel = await _api.channel(ref.contentId);
    final live = channel.toLiveRoom(cookie: _cookie);
    return LiveRoomStatus(
      ref: ref,
      state: live.state,
      viewers: channel.viewers,
      title: channel.title.isEmpty ? null : channel.title,
      cover: channel.cover.isEmpty ? null : channel.cover,
      anchorName: channel.nick.isEmpty ? null : channel.nick,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final rooms = await _api.search(query.keyword, page: query.page.page, pageSize: query.page.pageSize);
    return _page(rooms, query.page, pageSize: rooms.length);
  }

  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final channel = await _api.channel(ref.contentId);
    if (!channel.isLiving) {
      return const <StreamOption>[];
    }
    return <StreamOption>[
      for (final quality in channel.qualities)
        StreamOption(
          id: quality.name,
          kind: StreamOptionKind.quality,
          label: quality.name,
          rank: quality.rank,
          // `bps` is a bits-per-second figure, not the kbps this field asks for; converting it here would put a
          // 3,000,000 bps tier next to a 3,000 kbps one and let a surface add them.
          isDefault: quality == channel.qualities.first,
          available: channel.isPlayable,
        ),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    if (line != null) {
      throw StateError('SOOP serves one address per tier; line "${line.id}" does not exist');
    }
    final channel = await _api.channel(ref.contentId);
    if (channel.banned) {
      throw StateError('SOOP channel ${channel.roomId} is banned by the site');
    }
    if (!channel.isLiving) {
      throw StateError(
        channel.resultCode == soopResultNoLive
            ? 'SOOP channel ${channel.roomId} is not broadcasting'
            : 'SOOP channel ${channel.roomId} did not state that it is broadcasting',
      );
    }
    if (channel.qualities.isEmpty || !channel.isPlayable) {
      throw StateError('SOOP channel ${channel.roomId} is on air but names no tier this path can sign for');
    }
    final chosen = _quality(channel, quality);
    final uri = await _api.streamUrl(channel: channel, quality: chosen);
    return MediaTicket(
      id: '$soopSourceId/${channel.roomId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: soopHeaders(cookie: _cookie),
      // The aid is signed per request and the site states no lease, so a refresh re-signs rather than reusing
      // an address whose signature may already be dead.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: soopSourceId, contentId: channel.roomId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: channel.title,
        artist: channel.nick,
        isLive: true,
        extra: <String, Object?>{
          'container': uri.path.toLowerCase().contains('.m3u8') ? 'm3u8' : 'hls',
          'soop.quality': chosen.name,
          if (channel.broadcastId.isNotEmpty) 'soop.bno': channel.broadcastId,
          if (quality != null && !_sameTier(quality.id, chosen)) 'soop.requestedQuality': quality.id.trim(),
        },
      ),
    );
  }

  /// The site's spelling wins, but a selection the surface echoes back is matched case-insensitively - the preset
  /// list is deduplicated on the lower-cased name, so `hd` and `HD` name the same tier.
  static bool _sameTier(String asked, SoopQuality tier) => asked.trim().toLowerCase() == tier.name.toLowerCase();

  SoopQuality _quality(SoopChannel channel, SelectionRef? wanted) {
    final id = (wanted?.id ?? '').trim().toLowerCase();
    if (id.isEmpty) {
      return channel.qualities.first;
    }
    for (final quality in channel.qualities) {
      if (quality.name.toLowerCase() == id) {
        return quality;
      }
    }
    // The preset list is the channel's own; when the asked-for tier is gone the top tier is the answer that keeps
    // the viewer watching, and the ask is recorded so the surface can say it was not honoured.
    return channel.qualities.first;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$soopSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's await and
      // the recovery ladder behind it.
      throw StateError('SOOP ticket ${expired.id} does not name a channel');
    }
    final extra = expired.metadata.extra;
    return resolve(
      ContentRef(sourceId: soopSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      quality: extra['soop.quality'] is String ? SelectionRef('${extra['soop.quality']}') : null,
    );
  }
}

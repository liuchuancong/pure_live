// Module: lib/src/iptv_source.dart
// Purpose: The IPTV source: one playlist + one optional EPG document, served
// through the browse and resolve contracts.
// Author: liuchuancong
// Created: 2026-10-09
//
// The channel list comes from the shared M3U parser (external_tvbox owns that
// format); the guide comes from XMLTV here. The two join on the channel name,
// which is the only key an M3U carries.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_external_tvbox/pure_live_external_tvbox.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'xmltv_parser.dart';

/// The IPTV source for one playlist, with an optional guide attached.
final class IptvSource implements BrowseCapability, SearchCapability, ResolveCapability {
  IptvSource({
    required this.sourceId,
    required List<TvBoxChannel> channels,
    XmltvGuide? guide,
    this.searchLimit = 60,
    Clock? clock,
  }) : _channels = channels,
       _guide = guide,
       _groups = _groupChannels(channels),
       _clock = clock ?? systemClock;

  final SourceId sourceId;
  final List<TvBoxChannel> _channels;
  final XmltvGuide? _guide;
  final Map<String, List<TvBoxChannel>> _groups;
  final Clock _clock;

  /// Rows one search may return: an IPTV list can hold thousands of channels, and a search box shows a page.
  final int searchLimit;

  int get channelCount => _channels.length;

  /// The guide's own report for the attached EPG document, for a diagnostics view.
  String? get guideReport {
    final guide = _guide;
    if (guide == null) {
      return null;
    }
    return 'guide: ${guide.channels.length} channels'
        ', ${guide.programmeCount} programmes'
        '${guide.skippedEntries > 0 ? ', ${guide.skippedEntries} unusable' : ''}'
        '${guide.truncated ? ', truncated' : ''}';
  }

  /// What airs now on a channel, when an EPG document is attached and knows the channel's xmltv id or name.
  String? nowPlaying(String channelName, DateTime at) => programmeFor(channelName, at)?.title;

  /// The whole row behind a channel name, for a UI that wants "News · 18:00-19:00" rather than a bare title.
  ///
  /// The join is by name because an M3U carries no xmltv id: the guide's id is matched first, then its display
  /// names with spaces and punctuation ignored, which is how "CCTV-1综合" finds "CCTV 1 综合".
  XmltvProgramme? programmeFor(String channelName, DateTime at) {
    final guide = _guide;
    if (guide == null) {
      return null;
    }
    final channel = guide.channelFor(channelName);
    if (channel == null) {
      return null;
    }
    return guide.nowOn(channel.id, at);
  }

  /// The next [limit] rows on a channel, soonest first; empty without a guide.
  List<XmltvProgramme> schedule(String channelName, {DateTime? from, int limit = 12}) {
    final guide = _guide;
    if (guide == null) {
      return const <XmltvProgramme>[];
    }
    final channel = guide.channelFor(channelName);
    if (channel == null) {
      return const <XmltvProgramme>[];
    }
    return guide.upcoming(channel.id, from ?? _clock(), limit: limit);
  }

  @override
  Future<List<ContentCategory>> categories() async => <ContentCategory>[
    for (final group in _groups.keys) ContentCategory(id: group, name: group),
  ];

  /// Finds channels by name or group.
  ///
  /// An IPTV list is a flat file, so the only thing to search on is what the list itself says: this is a
  /// substring match that preserves the list's order, not a relevance ranking, and it says so by reporting
  /// `hasMore: false` with the total it kept rather than pretending a 4000-row list paged.
  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final keyword = query.keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return PageResult<ContentSummary>.empty();
    }
    final now = _clock();
    final matches = <ContentSummary>[];
    for (final channel in _channels) {
      if (!channel.name.toLowerCase().contains(keyword) && !channel.group.toLowerCase().contains(keyword)) {
        continue;
      }
      matches.add(
        ContentSummary(
          ref: ContentRef(sourceId: sourceId, contentId: channel.name, kind: ContentKind.liveChannel),
          title: channel.name,
          subtitle: channel.group,
          description: nowPlaying(channel.name, now),
        ),
      );
      if (matches.length >= searchLimit) {
        break;
      }
    }
    return PageResult<ContentSummary>(
      items: List<ContentSummary>.unmodifiable(matches),
      page: query.page.page,
      pageSize: query.page.pageSize,
      hasMore: false,
      total: matches.length,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final group = query.category;
    final channels = (group == null || group.isEmpty || !_groups.containsKey(group) ? _channels : _groups[group]!)
        .toList(growable: false);
    final start = (query.page.page - 1) * query.page.pageSize;
    final slice = start >= channels.length
        ? const <TvBoxChannel>[]
        : channels.sublist(start, (start + query.page.pageSize).clamp(0, channels.length));
    final now = _clock();
    return PageResult<ContentSummary>(
      items: <ContentSummary>[
        for (final channel in slice)
          ContentSummary(
            ref: ContentRef(sourceId: sourceId, contentId: channel.name, kind: ContentKind.liveChannel),
            title: channel.name,
            subtitle: group ?? channel.group,
            // What is on right now, when the guide knows: the one thing an
            // IPTV row offers that a bare name cannot.
            description: nowPlaying(channel.name, now),
            metadata: ContentMetadata(
              extra: <String, Object?>{
                if (channel.urls.length > 1) 'backupUrls': <String>[for (final url in channel.urls.skip(1)) '$url'],
              },
            ),
          ),
      ],
      page: query.page.page,
      pageSize: query.page.pageSize,
      hasMore: start + query.page.pageSize < channels.length,
      total: channels.length,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    for (final channel in _channels) {
      if (channel.name == ref.contentId) {
        final now = _clock();
        final programme = nowPlaying(channel.name, now);
        return ContentDetail(
          summary: ContentSummary(ref: ref, title: channel.name, subtitle: channel.group, description: programme),
          description: programme,
        );
      }
    }
    throw StateError('$sourceId has no channel ${ref.contentId}');
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    for (final channel in _channels) {
      if (channel.name == ref.contentId) {
        final url = channel.urls.first;
        return MediaTicket(
          id: '$sourceId/${ref.contentId}',
          uri: url,
          kind: MediaKind.live,
          protocol: url.path.endsWith('.m3u8') ? MediaProtocol.hls : MediaProtocol.http,
          createdAt: _clock().toUtc(),
          headers: <String, String>{'user-agent': 'PureLive', ...channel.headers},
          refresh: const MediaTicketRefreshInfo(supported: false),
          metadata: const MediaPlaybackMetadata(isLive: true),
        );
      }
    }
    throw StateError('$sourceId has no channel ${ref.contentId}');
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async =>
      throw StateError('$sourceId channels are static; refresh is not supported');

  static Map<String, List<TvBoxChannel>> _groupChannels(List<TvBoxChannel> channels) {
    final groups = <String, List<TvBoxChannel>>{};
    for (final channel in channels) {
      groups.putIfAbsent(channel.group, () => <TvBoxChannel>[]).add(channel);
    }
    return groups;
  }
}

/// Builds the source from an M3U playlist and an optional XMLTV document.
IptvSource iptvContent({required SourceId sourceId, required String playlistText, String? epgText}) {
  final channels = const M3uParser().parse(playlistText);
  final guide = epgText == null ? null : const XmltvParser().parse(epgText);
  return IptvSource(sourceId: sourceId, channels: channels, guide: guide);
}

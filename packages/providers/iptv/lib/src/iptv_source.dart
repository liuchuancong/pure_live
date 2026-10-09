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

import 'xmltv_parser.dart';

/// The IPTV source for one playlist, with an optional guide attached.
final class IptvSource implements BrowseCapability, ResolveCapability {
  IptvSource({required this.sourceId, required List<TvBoxChannel> channels, XmltvGuide? guide})
    : _channels = channels,
      _guide = guide,
      _groups = _groupChannels(channels);

  final SourceId sourceId;
  final List<TvBoxChannel> _channels;
  final XmltvGuide? _guide;
  final Map<String, List<TvBoxChannel>> _groups;

  int get channelCount => _channels.length;

  /// What airs now on a channel, when an EPG document is attached and knows
  /// the channel's xmltv id or name.
  String? nowPlaying(String channelName, DateTime at) {
    final guide = _guide;
    if (guide == null) {
      return null;
    }
    final programme = guide.nowOn(channelName, at.toUtc()) ?? _byName(guide, channelName, at);
    return programme?.title;
  }

  XmltvProgramme? _byName(XmltvGuide guide, String channelName, DateTime at) {
    for (final channel in guide.channels) {
      final matches = channel.names.any((name) => name.trim().toLowerCase() == channelName.trim().toLowerCase());
      if (matches) {
        return guide.nowOn(channel.id, at);
      }
    }
    return null;
  }

  @override
  Future<List<ContentCategory>> categories() async => <ContentCategory>[
    for (final group in _groups.keys) ContentCategory(id: group, name: group),
  ];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final group = query.category;
    final channels = (group == null || group.isEmpty || !_groups.containsKey(group) ? _channels : _groups[group]!)
        .toList(growable: false);
    final start = (query.page.page - 1) * query.page.pageSize;
    final slice = start >= channels.length
        ? const <TvBoxChannel>[]
        : channels.sublist(start, (start + query.page.pageSize).clamp(0, channels.length));
    final now = DateTime.now();
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
        final now = DateTime.now();
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
          createdAt: DateTime.now().toUtc(),
          headers: const <String, String>{'user-agent': 'PureLive'},
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

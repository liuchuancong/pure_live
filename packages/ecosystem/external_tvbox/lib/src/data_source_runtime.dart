// Module: lib/src/data_source_runtime.dart
// Purpose: The data-plugin runtime: turns parsed config content into contract
// providers, no code involved.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/data-plugin.md - a data plugin is configuration only; its
// manifest is derived by the parser, and its "runtime" is the parser plus the
// adapters here. The first fully-servable shape is the live playlist: browse
// by group, resolve straight to the channel url. TVBox spider sites are
// inventoried as pending - the framework names what they need instead of
// registering something that cannot serve.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import 'tvbox_repository.dart';

/// The live source one playlist produces. Categories are the playlist's
/// groups; resolution is the channel's own url, so no runtime beyond this
/// parser is ever needed to watch an IPTV list.
final class PlaylistLiveSource implements BrowseCapability, ResolveCapability {
  PlaylistLiveSource({required this.sourceId, required List<TvBoxChannel> channels})
    : _groups = _groupChannels(channels);

  final SourceId sourceId;

  /// group name -> channels, insertion-ordered, so the category list is as the
  /// playlist ordered it.
  final Map<String, List<TvBoxChannel>> _groups;

  /// The category names this source serves, in playlist order.
  List<String> get categories => _groups.keys.toList(growable: false);

  int get channelCount => _groups.values.fold(0, (sum, channels) => sum + channels.length);

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final group = query.category;
    final channels =
        (group == null || group.isEmpty || !_groups.containsKey(group)
                ? _groups.values.expand((entries) => entries)
                : _groups[group]!)
            .toList(growable: false);
    // Fixed-page paging over an in-memory list: the whole list is already
    // local, so a page is a slice and hasMore is arithmetic, not a guess.
    final start = (query.page.page - 1) * query.page.pageSize;
    final slice = start >= channels.length
        ? const <TvBoxChannel>[]
        : channels.sublist(start, (start + query.page.pageSize).clamp(0, channels.length));
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final channel in slice) _summary(sourceId, channel, group: group)],
      page: query.page.page,
      pageSize: query.page.pageSize,
      hasMore: start + query.page.pageSize < channels.length,
      total: channels.length,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    for (final channels in _groups.values) {
      for (final channel in channels) {
        if (channel.name == ref.contentId) {
          return ContentDetail(summary: _summary(sourceId, channel));
        }
      }
    }
    throw StateError('$sourceId has no channel ${ref.contentId}');
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    for (final channels in _groups.values) {
      for (final channel in channels) {
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
    }
    throw StateError('$sourceId has no channel ${ref.contentId}');
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async =>
      throw StateError('$sourceId channels are static; refresh is not supported');

  ContentSummary _summary(SourceId id, TvBoxChannel channel, {String? group}) {
    return ContentSummary(
      ref: ContentRef(sourceId: id, contentId: channel.name, kind: ContentKind.liveChannel),
      title: channel.name,
      subtitle: group,
      metadata: ContentMetadata(
        extra: <String, Object?>{
          if (channel.urls.length > 1) 'backupUrls': <String>[for (final url in channel.urls.skip(1)) '$url'],
        },
      ),
    );
  }

  static Map<String, List<TvBoxChannel>> _groupChannels(List<TvBoxChannel> channels) {
    final groups = <String, List<TvBoxChannel>>{};
    for (final channel in channels) {
      groups.putIfAbsent(channel.group, () => <TvBoxChannel>[]).add(channel);
    }
    return groups;
  }
}

/// What one data plugin holds after parsing, ready for the host to register.
final class DataPluginContent {
  const DataPluginContent({required this.provider, required this.summary});

  /// The provider object the host registers on the capability registry.
  final Object provider;

  /// One line for the management page, for example "42 频道 / 6 分组".
  final String summary;
}

/// Builds the servable content of a data plugin from its parsed playlist.
DataPluginContent playlistContent(SourceId sourceId, List<TvBoxChannel> channels) {
  final source = PlaylistLiveSource(sourceId: sourceId, channels: channels);
  final groups = source.categories.length;
  return DataPluginContent(provider: source, summary: '${source.channelCount} 频道 / $groups 分组');
}

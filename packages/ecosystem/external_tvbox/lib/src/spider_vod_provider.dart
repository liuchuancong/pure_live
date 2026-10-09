// Module: lib/src/spider_vod_provider.dart
// Purpose: The universal vod provider: drives any SpiderHandle and answers the
// capability contracts, whatever runtime executes the spider.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/sources/vod/tvbox.md - "TVBox 只是一个 Universal Source Adapter".
// This provider is that adapter. One instance per site (key): failure stays
// per site because the handle it drives is per site. A spider answer that
// cannot be parsed becomes a StateError naming the site and the call - the
// caller sees which source broke, never a silently empty page.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import 'spider_contract.dart';

/// The site identity one provider serves. The manifest the installer derives
/// carries the same id, so enable/disable in the plugin store and rows on the
/// capability registry always mean the same source.
final class SpiderSite {
  const SpiderSite({required this.key, required this.name, required this.extend});

  /// The repo's site key; also the ContentRef sourceId (prefixed).
  final String key;
  final String name;

  /// The repo's ext payload for this site, passed to init.
  final String extend;
}

/// Drives one site's spider through the capability contracts.
final class SpiderVodProvider implements BrowseCapability, SearchCapability, ResolveCapability {
  SpiderVodProvider({required this.site, required SpiderHandle handle})
    : _handle = handle,
      sourceId = 'tvbox.${site.key}';

  final SpiderSite site;
  final SourceId sourceId;
  final SpiderHandle _handle;
  bool _initialized = false;

  /// The home classes, read once per process. Spiders answer homeContent with
  /// the category table; browse without a category serves its vod list.
  List<SpiderClass> _classes = const <SpiderClass>[];

  /// The category ids this site serves, for the host's category UI.
  List<SpiderClass> get classes => _classes;

  Future<void> _ensureInit() async {
    if (_initialized) {
      return;
    }
    await _call('init', () => _handle.init(site.extend));
    _initialized = true;
  }

  Future<Map<String, Object?>?> _call(String what, Future<Map<String, Object?>?> Function() run) async {
    await _ensureInit();
    try {
      return await run();
    } catch (error) {
      throw StateError('tvbox ${site.key} $what failed: $error');
    }
  }

  @override
  Future<List<ContentCategory>> categories() async {
    // The spider contract carries the category table on homeContent; reading
    // it here keeps category chips available before the first browse.
    final home = await _call('homeContent', () => _handle.homeContent(const <String, Object?>{}));
    if (home == null) {
      return const <ContentCategory>[];
    }
    _classes = parseSpiderClasses(home);
    return <ContentCategory>[
      for (final spiderClass in _classes) ContentCategory(id: spiderClass.typeId, name: spiderClass.typeName),
    ];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category;
    final page = query.page;
    if (category == null || category.isEmpty) {
      final home = await _call('homeContent', () => _handle.homeContent(const <String, Object?>{}));
      if (home == null) {
        return const PageResult<ContentSummary>.empty();
      }
      _classes = parseSpiderClasses(home);
      final featured = home['list'];
      final vods = <ContentSummary>[
        if (featured is List)
          for (final row in featured)
            if (row is Map) _summary(parseSpiderVod(Map<String, Object?>.from(row))),
      ];
      return PageResult<ContentSummary>(
        items: vods,
        page: 1,
        pageSize: page.pageSize,
        hasMore: false,
        mode: PageMode.fixedPage,
      );
    }
    final answer = await _call(
      'categoryContent',
      () => _handle.categoryContent(category, '${page.page}', false, const <String, Object?>{}),
    );
    final spiderPage = parseSpiderPage(answer ?? const <String, Object?>{});
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final vod in spiderPage.vods) _summary(vod)],
      page: page.page,
      pageSize: page.pageSize,
      hasMore: spiderPage.hasMore,
      total: spiderPage.total,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final answer = await _call('detailContent', () => _handle.detailContent(<String>[ref.contentId]));
    if (answer == null) {
      throw StateError('tvbox ${site.key} detail answered nothing for ${ref.contentId}');
    }
    final detail = parseSpiderDetail(answer);
    // Episodes carry their play coordinates in ref metadata: the url is the
    // id the spider's playerContent expects, and ContentRef equality ignores
    // metadata, so a refreshed description never turns an episode into a new
    // key.
    return ContentDetail(
      summary: _summary(detail.vod),
      description: detail.description,
      children: <ContentRef>[
        for (final episode in detail.episodes)
          ContentRef(
            sourceId: sourceId,
            contentId: episode.name,
            kind: ContentKind.episode,
            parentId: detail.vod.vodId,
            metadata: <String, Object?>{'flag': episode.flag, 'playUrl': episode.url},
          ),
      ],
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final answer = await _call(
      'searchContent',
      () => _handle.searchContent(query.keyword, false, '${query.page.page}'),
    );
    final spiderPage = parseSpiderPage(answer ?? const <String, Object?>{});
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final vod in spiderPage.vods) _summary(vod)],
      page: query.page.page,
      pageSize: query.page.pageSize,
      hasMore: spiderPage.hasMore,
      total: spiderPage.total,
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final flag = '${ref.metadata['flag'] ?? ''}';
    final playUrl = '${ref.metadata['playUrl'] ?? ''}';
    if (playUrl.isEmpty) {
      throw StateError('tvbox ${site.key} episode ${ref.contentId} carries no play url');
    }
    final answer = await _call('playerContent', () => _handle.playerContent(flag, playUrl, false));
    final play = parseSpiderPlay(answer ?? const <String, Object?>{});
    if (play.playUrl.isEmpty) {
      throw StateError('tvbox ${site.key} returned no play url for ${ref.contentId}');
    }
    return MediaTicket(
      id: '$sourceId/${ref.parentId ?? ref.contentId}/${ref.contentId}',
      uri: Uri.parse(play.playUrl),
      kind: MediaKind.vod,
      protocol: play.playUrl.contains('.m3u8') ? MediaProtocol.hls : MediaProtocol.http,
      createdAt: DateTime.now().toUtc(),
      headers: play.headers,
      // A parse=1 answer is a page for the sniffer, not media: the ticket says
      // so in metadata, and the player wave decides how to sniff. Pretending
      // the page url is a stream would fail worse than saying what it is.
      metadata: MediaPlaybackMetadata(
        isLive: false,
        extra: <String, Object?>{'needsSniff': play.parse, 'jx': play.jx, if (flag.isNotEmpty) 'flag': flag},
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) {
    // A vod url is re-fetched by resolving the episode again; the ticket does
    // not carry enough to short-circuit that, and resolve is cheap.
    throw StateError('tvbox ${site.key}: refresh by re-resolving the episode');
  }

  ContentSummary _summary(SpiderVod vod) {
    return ContentSummary(
      ref: ContentRef(sourceId: sourceId, contentId: vod.vodId, kind: ContentKind.vod),
      title: vod.vodName,
      subtitle: vod.remarks,
      cover: vod.vodPic,
      metadata: ContentMetadata(extra: <String, Object?>{if (vod.typeName != null) 'typeName': vod.typeName!}),
    );
  }

  /// Releases the spider. The host calls this when the plugin unloads.
  Future<void> dispose() => _handle.destroy();
}

// Module: lib/features/home/home_page.dart
// Purpose: The home feed tab: renders the sections the feed aggregator serves.
// Author: liuchuancong
// Created: 2026-10-09
//
// The page consumes the aggregator, never a source: which providers appear is
// whatever the capability registry holds at boot (built-ins and plugins), so a
// newly registered site needs no edit here. Section titles come from the
// registry's source ids because the user-arranged home layout is a later wave.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live_feed/pure_live_feed.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../../app/di.dart';

/// One aggregated feed page. Invalidated by pull-to-refresh, which asks for
/// page 1 again rather than a separate reload path (feed.md's refresh rule).
final feedProvider = FutureProvider.autoDispose<FeedResult>((ref) async {
  final runtime = ref.watch(runtimeProvider);
  return runtime.feed.feed(PageRequest.first);
});

/// Every vod-capable source's home listing, kept per source so one broken
/// source shows as skipped instead of vanishing.
final class VodHomeSection {
  const VodHomeSection({required this.sourceId, this.page, this.error});

  final String sourceId;
  final PageResult<ContentSummary>? page;
  final String? error;
}

final vodHomesProvider = FutureProvider.autoDispose<List<VodHomeSection>>((ref) async {
  final runtime = ref.watch(runtimeProvider);
  final sections = <VodHomeSection>[];
  for (final entry in runtime.capabilities.all) {
    if (!entry.capabilities.supports(CapabilityKind.vod)) {
      continue;
    }
    final provider = entry.provider;
    if (provider is! BrowseCapability) {
      continue;
    }
    try {
      sections.add(VodHomeSection(sourceId: entry.sourceId, page: await provider.browse(const ContentQuery())));
    } catch (error) {
      sections.add(VodHomeSection(sourceId: entry.sourceId, error: '$error'));
    }
  }
  return sections;
});

final class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('纯粹直播'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.search), tooltip: '搜索', onPressed: () => context.push('/search')),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _FeedError(onRetry: () => ref.invalidate(feedProvider)),
        data: (result) => RefreshIndicator(
          onRefresh: () => ref.refresh(feedProvider.future),
          child: result.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    children: <Widget>[SizedBox(height: constraints.maxHeight, child: const _EmptyFeed())],
                  ),
                )
              : _FeedSections(sections: result.sections, vodHomes: ref.watch(vodHomesProvider)),
        ),
      ),
    );
  }
}

final class _FeedSections extends StatelessWidget {
  const _FeedSections({required this.sections, required this.vodHomes});

  final List<FeedSection> sections;
  final AsyncValue<List<VodHomeSection>> vodHomes;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        for (final section in sections) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(section.sourceId, style: Theme.of(context).textTheme.titleMedium),
          ),
          _RoomGrid(items: section.items),
        ],
        ..._vodWidgets(context),
      ],
    );
  }

  List<Widget> _vodWidgets(BuildContext context) {
    final theme = Theme.of(context);
    final homes = vodHomes.value;
    if (homes == null || homes.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text('影视', style: theme.textTheme.titleMedium),
      ),
      for (final home in homes) ...<Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            home.error ?? home.sourceId,
            style: home.error == null
                ? theme.textTheme.labelLarge
                : theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error),
          ),
        ),
        if (home.page != null && home.page!.items.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: home.page!.items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = home.page!.items[index];
                return SizedBox(width: 110, child: _VodCard(item: item));
              },
            ),
          ),
      ],
    ];
  }
}

/// A poster card for vod content; navigates to the vod detail surface.
final class _VodCard extends StatelessWidget {
  const _VodCard({required this.item});

  final ContentSummary item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/vod/${item.ref.sourceId}/${Uri.encodeComponent(item.ref.contentId)}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: item.cover == null
                  ? Container(
                      alignment: Alignment.center,
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: Icon(Icons.movie_outlined, color: theme.colorScheme.outline),
                    )
                  : Image.network(
                      item.cover!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        alignment: Alignment.center,
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(Icons.movie_outlined, color: theme.colorScheme.outline),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid of room cards. Columns per width keep phone (2), tablet (3) and
/// desktop (4) densities without a second layout.
final class _RoomGrid extends StatelessWidget {
  const _RoomGrid({required this.items});

  final List<ContentSummary> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200 ? 4 : (width >= 720 ? 3 : 2);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: <Widget>[for (final item in items) _RoomCard(item: item)],
        );
      },
    );
  }
}

final class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.item});

  final ContentSummary item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/room/${item.ref.contentId}', extra: item.ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: item.cover == null
                  ? Container(
                      alignment: Alignment.center,
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: Icon(Icons.live_tv, size: 32, color: theme.colorScheme.outline),
                    )
                  : Image.network(
                      item.cover!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        alignment: Alignment.center,
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(Icons.live_tv, size: 32, color: theme.colorScheme.outline),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: <Widget>[
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                  Text(
                    item.subtitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: <Widget>[
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          Text('首页加载失败', style: theme.textTheme.titleMedium),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

final class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: <Widget>[
          Icon(Icons.podcasts, size: 64, color: theme.colorScheme.outline),
          Text('还没有内容源', style: theme.textTheme.titleMedium),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '站点插件在后续波次接入,注册后首页会自动列出各站推荐内容',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

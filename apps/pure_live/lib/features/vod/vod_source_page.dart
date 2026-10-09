// Module: lib/features/vod/vod_source_page.dart
// Purpose: Browsing one vod source by category: chips of the source's own
// class table, a paginated grid, load-more at the source's own pace.
// Author: liuchuancong
// Created: 2026-10-09
//
// The category ids come from the source's home listing (the spider contract's
// class table); a source that exposes none degrades to its home listing only,
// which is still a usable grid. One page in flight at a time - load-more
// appends what arrived and re-arms, never stacking duplicate requests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_external_tvbox/pure_live_external_tvbox.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../../app/di.dart';

final class VodSourcePage extends ConsumerStatefulWidget {
  const VodSourcePage({required this.sourceId, super.key});

  final String sourceId;

  @override
  ConsumerState<VodSourcePage> createState() => _VodSourcePageState();
}

final class _VodSourcePageState extends ConsumerState<VodSourcePage> {
  List<SpiderClass> _classes = const <SpiderClass>[];
  String? _selected;
  final List<ContentSummary> _items = <ContentSummary>[];
  int _nextPage = 1;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open(null);
  }

  BrowseCapability? _provider() {
    final runtime = ref.read(runtimeProvider);
    final entry = runtime.capabilities.all
        .where((registration) => registration.sourceId == widget.sourceId)
        .firstOrNull;
    final provider = entry?.provider;
    return provider is BrowseCapability ? provider : null;
  }

  Future<void> _open(String? category) async {
    final provider = _provider();
    if (provider == null) {
      setState(() => _error = '源 ${widget.sourceId} 不提供浏览能力');
      return;
    }
    setState(() {
      _selected = category;
      _items.clear();
      _nextPage = 1;
      _loading = true;
      _error = null;
    });
    await _fetch(provider, replace: true);
    // The class table fills on the first home browse; read it after that call
    // so the chips appear without a second request.
    final runtime = ref.read(runtimeProvider);
    final entry = runtime.capabilities.all
        .where((registration) => registration.sourceId == widget.sourceId)
        .firstOrNull;
    final providerObject = entry?.provider;
    if (providerObject is SpiderVodProvider && mounted) {
      setState(() => _classes = providerObject.classes);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) {
      return;
    }
    final provider = _provider();
    if (provider == null) {
      return;
    }
    await _fetch(provider, replace: false);
  }

  Future<void> _fetch(BrowseCapability provider, {required bool replace}) async {
    setState(() => _loading = true);
    try {
      final result = await provider.browse(
        ContentQuery(
          category: _selected,
          page: PageRequest(page: _nextPage),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (replace) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          final known = _items.map((item) => item.ref.contentId).toSet();
          _items.addAll([
            for (final item in result.items)
              if (!known.contains(item.ref.contentId)) item,
          ]);
        }
        _hasMore = result.hasMore;
        _nextPage++;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.sourceId)),
      body: Column(
        children: <Widget>[
          if (_classes.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: <Widget>[
                  for (final spiderClass in _classes)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(spiderClass.typeName),
                        selected: _selected == spiderClass.typeId,
                        onSelected: (_) => _open(spiderClass.typeId),
                      ),
                    ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                childAspectRatio: 0.62,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              padding: const EdgeInsets.all(12),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  // The sentinel cell triggers the next page on build, which
                  // keeps "load more" automatic without scroll listeners.
                  _loadMore();
                  return const Center(child: CircularProgressIndicator());
                }
                final item = _items[index];
                return _PosterCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.item});

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
            if (item.subtitle != null && item.subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

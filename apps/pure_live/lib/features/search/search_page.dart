// Module: lib/features/search/search_page.dart
// Purpose: Keyword search across every registered source, via the aggregator.
// Author: liuchuancong
// Created: 2026-10-09
//
// The page never names a source: runtime.search fans out to whatever the
// capability registry holds, and each source's outcome keeps its identity so
// a failing source is visible instead of silently missing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_search/pure_live_search.dart';

import '../../app/di.dart';

final class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

final class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Future<SearchAggregate>? _pending;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final runtime = ref.read(runtimeProvider);
    setState(() {
      _pending = runtime.search.search(SearchQuery(keyword: trimmed));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          decoration: const InputDecoration(hintText: '搜索直播间、主播', border: InputBorder.none),
        ),
        actions: <Widget>[IconButton(icon: const Icon(Icons.search), onPressed: () => _submit(_controller.text))],
      ),
      body: _pending == null
          ? const _SearchHint()
          : FutureBuilder<SearchAggregate>(
              future: _pending,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _SearchMessage(icon: Icons.error_outline, text: '搜索失败:${snapshot.error}');
                }
                final aggregate = snapshot.data!;
                if (aggregate.isEmpty) {
                  return const _SearchMessage(icon: Icons.search_off, text: '没有匹配的结果');
                }
                return _SearchResults(aggregate: aggregate);
              },
            ),
    );
  }
}

final class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return const _SearchMessage(icon: Icons.search, text: '输入关键词,回车搜索已注册的站点');
  }
}

final class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: <Widget>[
          Icon(icon, size: 56, color: theme.colorScheme.outline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

final class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.aggregate});

  final SearchAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        for (final outcome in aggregate.answered) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(outcome.sourceId, style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final item in outcome.items)
            ListTile(
              leading: item.cover == null
                  ? const Icon(Icons.live_tv_outlined)
                  : SizedBox(
                      width: 72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item.cover!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.live_tv_outlined),
                        ),
                      ),
                    ),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(item.subtitle ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => context.push('/room/${item.ref.contentId}', extra: item.ref),
            ),
        ],
        for (final problem in aggregate.problems)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${problem.sourceId} 搜索失败:${problem.detail ?? problem.kind.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

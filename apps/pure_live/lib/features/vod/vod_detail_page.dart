// Module: lib/features/vod/vod_detail_page.dart
// Purpose: The vod detail surface: info plus the episode list, each episode
// navigating into the room player with its own ref.
// Author: liuchuancong
// Created: 2026-10-09
//
// The page names no source: it looks up the entry its sourceId points at and
// requires a BrowseCapability. Episodes come back as refs whose metadata
// carries the play coordinates, so the room page can resolve them through the
// same registry lookup it uses for live rooms.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../../app/di.dart';

final class VodDetailPage extends ConsumerStatefulWidget {
  const VodDetailPage({required this.sourceId, required this.vodId, super.key});

  final String sourceId;
  final String vodId;

  @override
  ConsumerState<VodDetailPage> createState() => _VodDetailPageState();
}

final class _VodDetailPageState extends ConsumerState<VodDetailPage> {
  ContentDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final runtime = ref.read(runtimeProvider);
    final entry = runtime.capabilities.all
        .where((registration) => registration.sourceId == widget.sourceId)
        .firstOrNull;
    final provider = entry?.provider;
    if (provider is! BrowseCapability) {
      setState(() => _error = '源 ${widget.sourceId} 不提供详情能力');
      return;
    }
    try {
      final detail = await provider.detail(
        ContentRef(sourceId: widget.sourceId, contentId: widget.vodId, kind: ContentKind.vod),
      );
      if (mounted) {
        setState(() => _detail = detail);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.summary.title ?? widget.vodId)),
      body: detail == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: <Widget>[
                    if (detail.summary.cover != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 120,
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Image.network(
                              detail.summary.cover!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: theme.colorScheme.surfaceContainerHigh),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: <Widget>[
                          if (detail.summary.subtitle != null && detail.summary.subtitle!.isNotEmpty)
                            Text(detail.summary.subtitle!, style: theme.textTheme.bodySmall),
                          if (detail.description != null && detail.description!.isNotEmpty)
                            Text(
                              detail.description!,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (detail.children.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '没有可播放的剧集',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  )
                else
                  for (final episode in detail.children)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(episode.contentId, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => context.push('/room/${episode.contentId}', extra: episode),
                    ),
              ],
            ),
    );
  }
}

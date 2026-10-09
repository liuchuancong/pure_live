// Module: lib/features/home/home_page.dart
// Purpose: The home feed tab: lists what the registered content sources serve.
// Author: liuchuancong
// Created: 2026-10-09
//
// The page reads the capability registry, not a hardcoded source list: with
// zero providers registered it shows an honest empty state, and each provider
// the W4+ waves register appears here without touching this file again.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';

final class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerCount = ref.watch(runtimeProvider).capabilities.length;
    return Scaffold(
      appBar: AppBar(title: const Text('纯粹直播')),
      body: providerCount == 0 ? const _EmptyFeed() : Center(child: Text('已注册 $providerCount 个内容源,首页 Feed 接入在下一波落地')),
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

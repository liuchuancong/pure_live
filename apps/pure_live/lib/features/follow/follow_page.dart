// Module: lib/features/follow/follow_page.dart
// Purpose: The follow tab: followed rooms across all sites.
// Author: liuchuancong
// Created: 2026-10-09
//
// The favorites service exists (packages/services/favorites) but nothing can
// produce a follow yet: following requires a signed-in site identity, which
// the provider waves bring. The page shows the empty state that matches that
// reality instead of wiring a source it does not have.

import 'package:flutter/material.dart';

final class FollowPage extends StatelessWidget {
  const FollowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关注')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: <Widget>[
            Icon(Icons.favorite_outline, size: 64, color: theme.colorScheme.outline),
            Text('暂无关注', style: theme.textTheme.titleMedium),
            Text('站点接入并登录后,关注的直播间会汇总在这里', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

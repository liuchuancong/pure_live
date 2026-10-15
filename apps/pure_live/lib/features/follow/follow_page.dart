import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

/// The followed-rooms branch. The repository (`live_library`'s
/// `FollowRepository`) already exists; this page is wired to it in the
/// user-data wave (design doc §9), so it stays an honest placeholder here.
class FollowPage extends StatelessWidget {
  /// The follow page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colors.bgLayout,
      appBar: AppBar(
        title: const Text('关注'),
        backgroundColor: theme.colors.bgContainer,
        foregroundColor: theme.colors.text,
      ),
      body: const LiveEmpty(title: '还没有关注', message: '关注仓库接入后，这里按分组显示已关注的主播与开播状态。', icon: Icons.favorite_border),
    );
  }
}

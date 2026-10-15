import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

/// The home branch: the live discovery feed. A placeholder until the site
/// registry is wired into the composition root (design doc §9, wave 2), so it
/// states what will be here rather than showing invented content.
class HomePage extends StatelessWidget {
  /// The home page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colors.bgLayout,
      appBar: AppBar(
        title: const Text('首页'),
        backgroundColor: theme.colors.bgContainer,
        foregroundColor: theme.colors.text,
      ),
      body: const LiveEmpty(title: '推荐流待接入', message: '站点注册表接入后，这里显示各平台的推荐与热门直播。', icon: Icons.live_tv_outlined),
    );
  }
}

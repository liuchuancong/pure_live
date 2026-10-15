import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

/// The watch-history branch, backed by `live_library`'s `HistoryRepository`
/// once it is wired in the user-data wave (design doc §9).
class HistoryPage extends StatelessWidget {
  /// The history page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colors.bgLayout,
      appBar: AppBar(
        title: const Text('历史'),
        backgroundColor: theme.colors.bgContainer,
        foregroundColor: theme.colors.text,
      ),
      body: const LiveEmpty(title: '还没有观看记录', message: '看过的直播间会出现在这里。', icon: Icons.history_outlined),
    );
  }
}

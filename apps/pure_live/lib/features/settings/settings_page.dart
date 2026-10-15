import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/router.dart';

/// The settings index: one row per settings area. Appearance is the only area
/// filled in today; the rest arrive with their features (storage/files in the
/// user-data wave, recording in the recording wave — design doc §9), and are
/// listed here so the shell's shape is complete before its contents are.
class SettingsPage extends StatelessWidget {
  /// The settings index.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colors.bgLayout,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.colors.bgContainer,
        foregroundColor: theme.colors.text,
      ),
      body: ListView(
        padding: EdgeInsets.all(theme.card.padding),
        children: [
          _SettingsRow(
            title: '外观',
            subtitle: '设计语言、明暗、强调色、密度、桌面行为',
            icon: Icons.palette_outlined,
            onTap: () => const AppearanceRoute().push<void>(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const new({required this.title, required this.subtitle, required this.icon, this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.card.padding * 0.5),
      child: LiveCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: theme.text.title.fontSize, color: theme.colors.text),
            SizedBox(width: theme.card.padding * 0.75),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.text.title.copyWith(color: theme.colors.text)),
                  SizedBox(height: theme.token.scale.sizes.sm * 0.5),
                  Text(subtitle, style: theme.text.caption.copyWith(color: theme.colors.textTertiary)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: theme.colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

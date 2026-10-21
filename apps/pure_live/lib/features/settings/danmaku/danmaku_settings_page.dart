import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/danmaku/danmaku_settings_content.dart';
import 'package:pure_live/shared/widgets/settings_chrome.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';

/// The danmaku settings page (the reference's `DanmakuSettingsPage`,
/// U.6a c6, F01): the shared `DanmakuSettingsContent` — the very component
/// the room's own tab shows, so the two are two doors to one room — under a
/// global "显示弹幕" switch, with the block list linked below.
final class DanmakuSettingsPage extends ConsumerWidget {
  /// The danmaku settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return SettingsChrome(
      title: t.settings.danmakuTitle,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupDanmaku),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.comment_outlined),
                title: Text(t.settings.danmakuVisible),
                description: Text(t.settings.danmakuVisibleSubtitle),
                initialValue: preferences.danmakuVisible,
                onToggle: (value) => unawaited(update((p) => p.copyWith(danmakuVisible: value))),
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              // The room's danmaku settings, one component for both doors.
              CustomSettingsTile(
                child: DanmakuSettingsContent(preferences: preferences, update: update),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionDanmaku),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.shield_outlined),
                title: Text(t.shield.title),
                description: Text(t.settings.shieldSubtitle),
                onPressed: (_) => unawaited(const ShieldRoute().push<void>(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

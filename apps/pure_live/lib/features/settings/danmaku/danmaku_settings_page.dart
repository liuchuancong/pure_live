import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The danmaku settings page (the reference's `SettingsSection.danmaku`,
/// `danmaku_page.dart`): what the barrage looks like and who gets through.
///
/// The size and opacity are the video surface's defaults — the room's own
/// danmaku-settings tab edits the same stored answers, so the two pages are
/// two doors to one room. Blocking lives on the shield page, linked below.
final class DanmakuSettingsPage extends ConsumerWidget {
  /// The danmaku settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.danmakuTitle),
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
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.text_fields,
                  title: t.room.barrageFontSize,
                  value: preferences.barrageFontSize,
                  min: 10,
                  max: 28,
                  valueLabel: '${preferences.barrageFontSize.round()} px',
                  onChanged: (value) => unawaited(update((p) => p.copyWith(barrageFontSize: value))),
                ),
              ),
              CustomSettingsTile(
                child: SettingsSliderRow(
                  icon: Icons.opacity,
                  title: t.room.barrageOpacity,
                  value: preferences.barrageOpacity,
                  min: 0.2,
                  valueLabel: '${(preferences.barrageOpacity * 100).round()}%',
                  onChanged: (value) => unawaited(update((p) => p.copyWith(barrageOpacity: value))),
                ),
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
          SettingsSection(
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    t.room.barrageSettingsNote,
                    style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

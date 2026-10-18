import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/routing/routes/settings/shield_routes.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The video and danmaku settings (3.x `VideoSettingsPage`, scoped to what this
/// build backs): what a room opens with.
///
/// The answers stored here are the ones the room reads at open: the barrage's
/// default visibility, the per-device volume levels and the global mute — the
/// same three the reference's room volume dialog edits in place — the local
/// interaction switch, and the barrage size and opacity the video surface
/// draws with. They are defaults, not locks: a room's own bar still turns the
/// barrage off, and a volume dragged mid-stream does not rewrite the stored
/// level.
///
/// The reference's other rows on this page have no backing in this build and stay
/// out: the preferred quality per network (a per-platform resolution match the
/// site layer does not expose), background play and ASMR sleep (no audio-focus
/// service), the picture-in-picture geometry (the app declines PiP), the danmaku
/// font (the manager applies the interface font only), and the screen keep-on
/// switch (wakelock is taken by the room itself).
final class VideoSettingsPage extends ConsumerWidget {
  /// The video and danmaku settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return SettingsList(
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
            SettingsTile.navigation(
              leading: const Icon(Icons.shield_outlined),
              title: Text(t.shield.title),
              description: Text(t.settings.shieldSubtitle),
              onPressed: (_) => unawaited(const ShieldRoute().push<void>(context)),
            ),
          ],
        ),
        SettingsSection(
          title: Text(t.settings.groupAudio),
          tiles: [
            SettingsTile.switchTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: Text(t.room.globalMute),
              description: Text(t.room.globalMuteSubtitle),
              initialValue: preferences.volumeMuted,
              onToggle: (value) => unawaited(update((p) => p.copyWith(volumeMuted: value))),
            ),
            CustomSettingsTile(
              child: SettingsSliderRow(
                icon: Icons.phone_android,
                title: t.room.mobileDefaultVolume,
                subtitle: t.settings.defaultVolumeSubtitle,
                value: preferences.defaultMobileVolume,
                valueLabel: '${(preferences.defaultMobileVolume * 100).round()}%',
                onChanged: (value) => unawaited(update((p) => p.copyWith(defaultMobileVolume: value))),
              ),
            ),
            CustomSettingsTile(
              child: SettingsSliderRow(
                icon: Icons.computer,
                title: t.room.desktopDefaultVolume,
                subtitle: t.settings.defaultVolumeSubtitle,
                value: preferences.defaultDesktopVolume,
                valueLabel: '${(preferences.defaultDesktopVolume * 100).round()}%',
                onChanged: (value) => unawaited(update((p) => p.copyWith(defaultDesktopVolume: value))),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: Text(t.settings.groupAppearance),
          tiles: [
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
          title: Text(t.settings.groupLocalInteraction),
          tiles: [
            SettingsTile.switchTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(t.settings.localInteraction),
              description: Text(t.settings.localInteractionSubtitle),
              initialValue: preferences.localInteractionEnabled,
              onToggle: (value) => unawaited(update((p) => p.copyWith(localInteractionEnabled: value))),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.badge_outlined),
              title: Text(t.settings.localInteractionName),
              trailing: Text(
                preferences.localInteractionUserName.trim().isEmpty
                    ? t.room.localMe
                    : preferences.localInteractionUserName,
              ),
              onPressed: (context) => unawaited(_editName(context, ref)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final field = TextEditingController(text: ref.read(appPreferencesProvider).localInteractionUserName);
    final value = await showPureDialog<String>(
      context: context,
      title: context.t.settings.localInteractionName,
      child: Builder(
        builder: (fieldContext) => Focus(
          autofocus: true,
          child: PureTextField(
            controller: field,
            placeholder: context.t.room.localMe,
            onSubmitted: (submitted) => Navigator.of(fieldContext).pop(submitted),
          ),
        ),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        PureButton(label: dialogContext.t.common.confirm, onPressed: () => Navigator.of(dialogContext).pop(field.text)),
      ],
    );
    field.dispose();
    if (value != null) {
      await ref
          .read(appPreferencesProvider.notifier)
          .update((preferences) => preferences.copyWith(localInteractionUserName: value.trim()));
    }
  }
}

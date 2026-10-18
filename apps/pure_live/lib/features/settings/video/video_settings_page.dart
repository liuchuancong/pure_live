import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The video settings (3.x `VideoSettingsPage`, scoped to what this build
/// backs): what a room opens with, on the audio side.
///
/// The answers stored here are the ones the room reads at open: the global
/// mute and the per-device volume levels — the same three the reference's
/// room volume dialog edits in place. They are defaults, not locks: a volume
/// dragged mid-stream does not rewrite the stored level.
///
/// The barrage's own answers moved to the danmaku section (the reference's
/// split), and so did the local interaction identity; both are links here.
///
/// The reference's other rows on this page have no backing in this build and
/// stay out: the preferred quality per network (a per-platform resolution
/// match the site layer does not expose), background play and ASMR sleep (no
/// audio-focus service), the picture-in-picture geometry (the app declines
/// PiP), and the screen keep-on switch (wakelock is taken by the room
/// itself).
final class VideoSettingsPage extends ConsumerWidget {
  /// The video settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.video),
      body: SettingsList(
      sections: [
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
          title: Text(t.settings.sectionVideo),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.subtitles_outlined),
              title: Text(t.settings.danmakuTitle),
              description: Text(t.settings.danmakuDesc),
              onPressed: (_) => unawaited(const DanmakuSettingsRoute().push<void>(context)),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.face_outlined),
              title: Text(t.settings.localInteraction),
              description: Text(t.settings.localInteractionSubtitle),
              onPressed: (_) => unawaited(const LocalInteractionRoute().push<void>(context)),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

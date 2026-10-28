import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:pure_live/features/account/account.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart';

/// The Bilibili station's own settings: the Bilibili account the station
/// reads (and only that account — the live platforms' sign-ins stay in the
/// live module), the quality a video opens with, and the playback page
/// beside them.
final class VodSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → Bilibili video.
  const VodSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final quality = ref.watch(vodQualityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        const AccountPane(siteIds: {SiteIds.bilibili}),
        DsListSection(
          header: Text(t.settings.vodPlayback),
          children: [
            SettingsChoiceRow<VodQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.vodQuality,
              description: t.settings.vodQualityDesc,
              value: quality,
              options: [
                for (final choice in VodQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: ref.read(vodQualityProvider.notifier).select,
            ),
          ],
        ),
        const DsListSection(
          children: [
            SettingsChildEntry(child: SettingsSection.vodPlayback),
            SettingsChildEntry(child: SettingsSection.vodInterface),
          ],
        ),
      ],
    );
  }
}

/// The newBV reference's playback page: the rate a video opens with and what
/// a finished part leads to. The video page reads both where it plays.
final class VodPlaybackPane extends ConsumerWidget {
  /// The pane shown under Settings → Bilibili video → 播放行为.
  const VodPlaybackPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(vodPlaybackSettingsProvider);
    final controller = ref.read(vodPlaybackSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsChoiceRow<VodSpeedChoice>(
              leading: const DsIcon(DsIcons.timer),
              title: t.vod.openingSpeed,
              description: t.vod.openingSpeedDesc,
              value: settings.speed,
              options: [
                for (final choice in VodSpeedChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (choice) => unawaited(controller.setSpeed(choice)),
            ),
            SettingsChoiceRow<VodFinishAction>(
              leading: const DsIcon(DsIcons.skipForward),
              title: t.vod.finishAction,
              description: t.vod.finishActionDesc,
              value: settings.finish,
              options: [
                for (final action in VodFinishAction.values) DsSelectOption(value: action, label: action.label(t)),
              ],
              onChanged: (action) => unawaited(controller.setFinish(action)),
            ),
          ],
        ),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.vod.playbackReset),
              description: Text(t.vod.playbackResetDesc),
              onPressed: () => unawaited(controller.reset()),
            ),
          ],
        ),
      ],
    );
  }
}

/// The reference's interface page: whether the archive's details sit under
/// the picture. The video page reads it where it paints.
final class VodInterfacePane extends ConsumerWidget {
  /// The pane shown under Settings → Bilibili video → 界面设置.
  const VodInterfacePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(vodPlaybackSettingsProvider);
    final controller = ref.read(vodPlaybackSettingsProvider.notifier);
    return DsListSection(
      children: [
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.info),
          title: t.vod.showDetails,
          description: t.vod.showDetailsDesc,
          control: DsSwitch(
            value: settings.showDetails,
            onChanged: (value) => unawaited(controller.setShowDetails(value: value)),
          ),
        ),
      ],
    );
  }
}

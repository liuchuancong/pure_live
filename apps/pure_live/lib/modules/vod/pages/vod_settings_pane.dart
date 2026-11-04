import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:pure_live/features/account/account.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_app_login.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart';
import 'package:pure_live/modules/vod/pages/vod_card_preview_page.dart' show showVodCardPreview;
import 'package:pure_live/modules/vod/widgets/vod_app_login_dialog.dart' show showVodAppLogin;

/// The Bilibili station's own settings: the Bilibili account the station
/// reads (and only that account — the live platforms' sign-ins stay in the
/// live module) and the app's own player pages this station's video page
/// obeys. What a video opens at, and what the player does with it, is the
/// playback group's business — see [VodPlaybackPane].
final class VodSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → Bilibili video.
  const VodSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        const AccountPane(siteIds: {SiteIds.bilibili}),
        DsListSection(
          header: Text(t.settings.vodPlayback),
          children: [
            // The picture's shape, the bar's hide delay and the screen's wake
            // are the app's own player settings, which this page's player
            // reads; the row opens the page carrying them rather than a second
            // copy of each switch here. It names what this module meets there,
            // not the live room's full set of rows on that page.
            SettingsChildEntry(
              child: SettingsSection.picture,
              title: t.settings.sharedPictureEntry,
              description: t.settings.sharedPictureEntryDesc,
            ),
            // The mute pair, the background switch, the seed volume and the
            // wheel step are the app's own, read by this player's handle.
            SettingsChildEntry(
              child: SettingsSection.quality,
              title: t.settings.sharedSoundEntry,
              description: t.settings.sharedSoundEntryDesc,
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.vodPages),
          children: const [
            SettingsChildEntry(child: SettingsSection.vodDownload),
            SettingsChildEntry(child: SettingsSection.vodInterface),
          ],
        ),
      ],
    );
  }
}

/// The newBV reference's playback page: the quality a video opens at, the
/// rate it opens with and what a finished part leads to. The video page
/// reads all three where it plays, so they sit together in the playback
/// group beside the kernel rather than split across the module's own page.
final class VodPlaybackPane extends ConsumerWidget {
  /// The pane shown under Settings → 播放 → 播放行为.
  const VodPlaybackPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(vodPlaybackSettingsProvider);
    final controller = ref.read(vodPlaybackSettingsProvider.notifier);
    final quality = ref.watch(vodQualityProvider);
    final appSession = ref.watch(vodAppSessionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navVodPlayback),
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
            SettingsChoiceRow<VodSpeedChoice>(
              leading: const DsIcon(DsIcons.timer),
              title: t.vod.openingSpeed,
              description: t.vod.openingSpeedDesc,
              value: settings.speed,
              options: [for (final choice in VodSpeedChoice.values) DsSelectOption(value: choice, label: choice.label)],
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
            SettingsChoiceRow<VodApiType>(
              leading: const DsIcon(DsIcons.globe),
              title: t.vod.apiType,
              description: t.vod.apiTypeDesc,
              value: settings.apiType,
              options: [for (final type in VodApiType.values) DsSelectOption(value: type, label: type.label)],
              onChanged: (type) => unawaited(controller.setApiType(type)),
            ),
          ],
        ),
        DsListSection(
          children: [
            DsListRow(
              leading: DsIcon(appSession == null ? DsIcons.qrCode : DsIcons.circleUser),
              title: Text(appSession == null ? t.vod.appLogin : t.vod.appLoggedIn(uid: '${appSession.mid}')),
              description: Text(t.vod.appLoginDesc),
              showChevron: true,
              onPressed: () => unawaited(showVodAppLogin(context)),
            ),
            if (appSession != null)
              DsListRow(
                leading: const DsIcon(DsIcons.logOut),
                title: Text(t.vod.appLogout),
                onPressed: () => unawaited(ref.read(vodAppSessionProvider.notifier).clear()),
              ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.resetGroup),
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
/// the picture, and which pieces an archive card draws. The video page and
/// the three browse grids read these where they paint.
final class VodInterfacePane extends ConsumerWidget {
  /// The pane shown under Settings → Bilibili video → 界面设置.
  const VodInterfacePane({super.key});

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
          header: Text(t.settings.navVodInterface),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.image),
              title: t.vod.showFeedBanner,
              description: t.vod.showFeedBannerDesc,
              control: DsSwitch(
                value: ref.watch(vodFeedBannerProvider),
                onChanged: (value) => unawaited(ref.read(vodFeedBannerProvider.notifier).setShown(value: value)),
              ),
            ),
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
        ),
        DsListSection(
          children: [
            // The row opens the card's own page — the two samples at a feed's
            // width — rather than a list of switches beside the rest, the way
            // the browsing settings hand their room card over.
            DsListRow(
              leading: const DsIcon(DsIcons.idCard),
              title: Text(t.vod.cardElements),
              description: Text(t.settings.roomCardPreviewHint),
              showChevron: true,
              onPressed: () => unawaited(showVodCardPreview(context)),
            ),
          ],
        ),
      ],
    );
  }
}

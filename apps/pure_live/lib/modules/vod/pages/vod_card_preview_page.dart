import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_card_settings.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart';

/// The piece every card of this station can draw, with the icon and the word
/// the switch wears: the table the sample's panel is built from.
List<(VodCardElement, DsIconData, String)> vodCardElements(Translations t) => [
  (VodCardElement.plays, DsIcons.play, t.vod.cardPlays),
  (VodCardElement.danmaku, DsIcons.captions, t.vod.cardDanmaku),
  (VodCardElement.duration, DsIcons.clock, t.vod.cardDuration),
  (VodCardElement.uploader, DsIcons.user, t.vod.cardUploader),
  (VodCardElement.seasonState, DsIcons.info, t.vod.cardSeasonState),
  (VodCardElement.seasonScore, DsIcons.star, t.vod.score),
];

/// Opens the station's card sample full-window and alone, the way the live
/// module opens its own: the video settings' entry to the card, and the only
/// page that tunes it.
Future<void> showVodCardPreview(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(DsPageRoute<void>(fullscreenDialog: true, builder: (context) => const VodCardPreviewPage()));

/// The two cards at a feed's width, full-window: the real widgets, drawn with
/// the appearance this device uses, under the switches that shape them.
///
/// The station's cards have one design, so this page offers no layout choice —
/// each row is one piece of information a card may or may not draw, and both
/// cards are on the stage because the two season pieces have nowhere else to
/// show. The cards read the stored visibility themselves, so a switch moves
/// the sample it belongs to rather than a copy of it.
final class VodCardPreviewPage extends ConsumerWidget {
  /// The page.
  const VodCardPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final visibility = ref.watch(vodCardSettingsProvider);
    final controller = ref.read(vodCardSettingsProvider.notifier);
    return SettingsPreviewPage(
      icon: DsIcons.idCard,
      title: t.settings.roomCardPreview,
      // One action over the whole set, so it rides the bar's top-right rather
      // than the list of switches, and asks before it acts.
      barTrailing: DsTooltip(
        message: t.settings.roomCardResetCurrent,
        child: DsButton.icon(
          variant: DsButtonVariant.ghost,
          icon: const DsIcon(DsIcons.rotateCcw),
          semanticLabel: t.settings.roomCardResetCurrent,
          onPressed: () => unawaited(_confirmReset(context, controller)),
        ),
      ),
      // The card lives on the app's page, not over media: the stage takes the
      // page's colour so a light skin previews a light page.
      stageColor: colors.canvas,
      stage: Center(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.s20),
          // Both samples keep the width a feed gives them and are scaled down
          // whole, so a small stage shrinks them instead of squeezing the
          // information line the switches are about.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s16,
              children: [
                SizedBox(width: 320, child: VodVideoCard(video: _sampleVideo(t))),
                SizedBox(width: 320, child: VodSeasonCard(season: _sampleSeason(t))),
              ],
            ),
          ),
        ),
      ),
      settings: DsListSection(
        header: Text(t.vod.cardElements),
        children: [
          for (final (element, icon, label) in vodCardElements(t))
            SettingsConfigRow(
              leading: DsIcon(icon),
              title: label,
              control: DsSwitch(
                value: visibility.shows(element),
                onChanged: (value) => unawaited(controller.setElement(element, visible: value)),
              ),
            ),
        ],
      ),
    );
  }

  /// Asks before every switch goes back to the designed default, then does it.
  Future<void> _confirmReset(BuildContext context, VodCardSettingsController controller) async {
    final t = context.t;
    final confirmed = await showDsDialog<bool>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.settings.roomCardResetConfirmTitle),
        destructive: true,
        description: Text(t.settings.roomCardResetConfirmBody),
        style: const DsDialogStyle(width: 420),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          DsButton(
            variant: DsButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.settings.roomCardResetCurrent),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.set(VodCardVisibility.standard);
  }
}

/// A stable public sample; every switch has something to show, so turning a
/// piece on and off is visible at a glance.
VodVideo _sampleVideo(Translations t) => VodVideo(
  id: 'preview',
  bvid: 'BVpreview000',
  title: t.vod.cardPreviewTitle,
  coverUrl: 'https://picsum.photos/seed/pure-live-vod/640/360',
  uploader: t.vod.cardPreviewUploader,
  duration: const Duration(minutes: 12, seconds: 34),
  playCount: 1234567,
  danmakuCount: 4321,
);

/// The same subject as a season, which is the only card that draws the update
/// state and the score.
VodSeason _sampleSeason(Translations t) => VodSeason(
  seasonId: 0,
  title: t.vod.cardPreviewTitle,
  subtitle: t.vod.cardPreviewState,
  coverUrl: 'https://picsum.photos/seed/pure-live-vod-season/448/600',
  rating: '9.2',
  playCount: 87654321,
);

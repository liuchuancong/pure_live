import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/surface/settings_preview.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_card_settings.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoSeries;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart';

/// The card and the list row have fixed designs; the preview page draws both with
/// this device's appearance and carries these controls beside them, the way the
/// room card's own page does. The station's interface settings hold one row that
/// opens it, so the sample is where the card is tuned.
final class HongguoCardSettings extends ConsumerWidget {
  /// The controls for the design on the preview's stage: a list row draws no
  /// cover, so [coverPieces] false leaves out the pieces only a cover carries
  /// and keeps the panel to switches that change what the sample shows.
  const HongguoCardSettings({required this.coverPieces, super.key});

  /// Whether the design on the stage has cover corners: true for the poster
  /// card, false for the list row.
  final bool coverPieces;

  /// The pieces drawn only over a cover's corners. A row folds all of them into
  /// its listing line whatever the switches say, so a switch here would move
  /// nothing on the stage.
  static const Set<HongguoCardElement> _coverOnly = {
    HongguoCardElement.rank,
    HongguoCardElement.coverTags,
    HongguoCardElement.today,
    HongguoCardElement.score,
    HongguoCardElement.episodes,
    HongguoCardElement.favorite,
    HongguoCardElement.hot,
    HongguoCardElement.category,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final appearance = ref.watch(hongguoCardSettingsProvider);
    final controller = ref.read(hongguoCardSettingsProvider.notifier);

    void update(HongguoCardElement element, {required bool visible}) =>
        unawaited(controller.setElement(element, visible: visible));

    return DsListSection(
      header: Text(t.settings.hongguoCardVisibleContent),
      children: [
        // Every piece is its own switch: a card never jumps to another layout,
        // only the chosen pieces come and go.
        for (final element in HongguoCardElement.values)
          if (coverPieces || !_coverOnly.contains(element))
            SettingsConfigRow(
              leading: DsIcon(_elementIcon(element)),
              title: _elementLabel(t, element),
              control: DsSwitch(
                value: appearance.shows(element),
                onChanged: (visible) => update(element, visible: visible),
                semanticLabel: _elementLabel(t, element),
              ),
            ),
      ],
    );
  }
}

/// Opens the poster card's sample full-window and alone: the station's own entry
/// to the card, and the only page that tunes it.
Future<void> showHongguoCardPreview(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(fullscreenDialog: true, builder: (context) => const HongguoCardPreviewPage()));
}

/// The poster card and the list row at a feed's size, full-window: the real
/// widgets, drawn with the appearance this device uses, under the controls that
/// shape them. The design switch only changes what the preview shows — the walls
/// keep choosing their own layout.
final class HongguoCardPreviewPage extends ConsumerStatefulWidget {
  /// The page.
  const HongguoCardPreviewPage({super.key});

  @override
  ConsumerState<HongguoCardPreviewPage> createState() => _HongguoCardPreviewPageState();
}

final class _HongguoCardPreviewPageState extends ConsumerState<HongguoCardPreviewPage> {
  /// The sample's own artwork, bundled rather than fetched: the station's
  /// posters are HEIC behind a signature that expires with the listing, and a
  /// settings page has no business asking for one.
  static const AssetImage _poster = AssetImage('assets/preview/banner.png');

  /// The card's width on the stage: the widest share a poster wall ever gives a
  /// tile, so the cover is drawn with all four corners — under
  /// [kHongguoCoverChipFloor] the card folds the viewer's place and the category
  /// into the listing line, and those switches would look dead here.
  static const double _tileWidth = 216;

  /// The row's width on the stage: a feed's own column, the width the row is
  /// read at rather than the tile the grid cuts.
  static const double _rowWidth = 320;

  bool _list = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final series = _sampleSeries(t);
    final design = _list ? t.common.layoutList : t.common.layoutGrid;
    return SettingsPreviewPage(
      icon: _list ? DsIcons.layoutList : DsIcons.layoutGrid,
      title: t.settings.hongguoCardPreview,
      // One action over the whole set, so it rides the bar's top-right rather
      // than the list of switches, and asks before it acts.
      barTrailing: DsTooltip(
        message: t.settings.hongguoCardResetCurrent,
        child: DsButton.icon(
          variant: DsButtonVariant.ghost,
          icon: const DsIcon(DsIcons.rotateCcw),
          semanticLabel: t.settings.hongguoCardResetCurrent,
          onPressed: () => unawaited(_confirmReset(context)),
        ),
      ),
      // The card lives on the app's page, not over media: the stage takes the
      // page's colour so a light skin previews a light page.
      stageColor: colors.canvas,
      stage: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.s20),
                // Both designs are laid out at their own width and scaled down
                // whole, so a small stage shrinks the sample instead of
                // squeezing its information lines.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _list
                      ? SizedBox(
                          width: _rowWidth,
                          height: kHongguoSeriesRowExtent,
                          child: HongguoSeriesRow(series: series, poster: _poster),
                        )
                      : SizedBox(
                          width: _tileWidth,
                          height: hongguoSeriesTileHeight(_tileWidth),
                          child: HongguoSeriesCard(series: series, poster: _poster, favorited: true),
                        ),
                ),
              ),
            ),
          ),
          // The strip under the stage wears the theme's own fill and type: on a
          // page-coloured stage the floating white controls would vanish.
          DecoratedBox(
            decoration: BoxDecoration(
              border: BorderDirectional(top: BorderSide(color: colors.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  SettingsPreviewCircleButton(
                    icon: DsIcons.layoutGrid,
                    semanticLabel: t.common.layoutGrid,
                    selected: !_list,
                    onSurface: true,
                    onPressed: () => setState(() => _list = false),
                  ),
                  SettingsPreviewCircleButton(
                    icon: DsIcons.layoutList,
                    semanticLabel: t.common.layoutList,
                    selected: _list,
                    onSurface: true,
                    onPressed: () => setState(() => _list = true),
                  ),
                  const SizedBox(width: DsSpace.s8),
                  Text(design, style: theme.typography.small.copyWith(color: colors.textMuted)),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
      // The panel follows the design on the stage: a list row has no cover
      // corners, so the pieces only a cover carries are not offered while it
      // shows.
      settings: HongguoCardSettings(coverPieces: !_list),
    );
  }

  /// Asks before every piece goes back to the designed default, then does it.
  Future<void> _confirmReset(BuildContext context) async {
    final t = context.t;
    final confirmed = await showDsDialog<bool>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.settings.hongguoCardResetConfirmTitle),
        destructive: true,
        description: Text(t.settings.hongguoCardResetConfirmBody),
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
            child: Text(t.settings.hongguoCardResetCurrent),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(hongguoCardSettingsProvider.notifier).reset();
  }
}

/// A stable public sample: every piece has something to show, so turning one on
/// and off is visible at a glance. The corner holds one state, and the sample
/// carries all four of its candidates — the viewer's own place is left out,
/// because a settings page cannot say where this device stopped.
HongguoSeries _sampleSeries(Translations t) => HongguoSeries(
  seriesId: 'preview',
  title: t.settings.hongguoCardPreviewTitle,
  episodeCount: 80,
  score: '8.6',
  playCount: 1280000,
  intro: t.settings.hongguoCardPreviewIntro,
  category: t.settings.hongguoCardPreviewCategory,
  hot: t.settings.hongguoCardPreviewHot,
  coverTags: [t.settings.hongguoCardPreviewTag],
  rank: 2,
  today: true,
);

/// The switch's glyph for one card piece, drawn like the piece it stands for.
DsIconData _elementIcon(HongguoCardElement element) => switch (element) {
  HongguoCardElement.rank => DsIcons.trophy,
  HongguoCardElement.coverTags => DsIcons.badge,
  HongguoCardElement.today => DsIcons.calendar,
  HongguoCardElement.score => DsIcons.star,
  HongguoCardElement.episodes => DsIcons.listVideo,
  HongguoCardElement.favorite => DsIcons.heart,
  HongguoCardElement.hot => DsIcons.flame,
  HongguoCardElement.category => DsIcons.tag,
  HongguoCardElement.meta => DsIcons.info,
};

String _elementLabel(Translations t, HongguoCardElement element) => switch (element) {
  HongguoCardElement.rank => t.settings.hongguoCardRank,
  HongguoCardElement.coverTags => t.settings.hongguoCardTags,
  HongguoCardElement.today => t.settings.hongguoCardToday,
  HongguoCardElement.score => t.settings.hongguoCardScore,
  HongguoCardElement.episodes => t.settings.hongguoCardEpisodes,
  HongguoCardElement.favorite => t.settings.hongguoCardFavorite,
  HongguoCardElement.hot => t.settings.hongguoCardHot,
  HongguoCardElement.category => t.settings.hongguoCardCategory,
  HongguoCardElement.meta => t.settings.hongguoCardMeta,
};

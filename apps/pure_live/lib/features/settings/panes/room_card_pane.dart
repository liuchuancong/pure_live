import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAnchor, LiveArea, LiveRoom, LiveStatus, RoomAudience, RoomBroadcast, RoomContent;
import 'package:pure_live/features/settings/room/room_card_settings.dart';
import 'package:pure_live/features/settings/surface/settings_preview.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/popular/room_card.dart';

/// The card and the list row have fixed designs; the preview page draws both
/// with this device's appearance and carries these controls beside them. The
/// browsing settings' room-card row opens that page, so the sample is where
/// the card is tuned.
final class RoomCardSettings extends ConsumerWidget {
  /// The controls for the design on the preview's stage: a list row draws no
  /// cover, so [coverPieces] false leaves out the pieces only a cover carries
  /// and keeps the panel to switches that change what the sample shows.
  const RoomCardSettings({required this.coverPieces, super.key});

  /// Whether the design on the stage has a cover corner: true for the grid
  /// card, false for the list row.
  final bool coverPieces;

  /// The pieces drawn only over a cover's corners.
  static const Set<RoomCardElement> _coverOnly = {RoomCardElement.coverType, RoomCardElement.platformBadge};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final appearance = ref.watch(roomCardSettingsProvider);
    final controller = ref.read(roomCardSettingsProvider.notifier);

    void update(RoomCardAppearance next) => unawaited(controller.set(next));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // Every piece is its own switch: a card never jumps to another
        // layout, only the chosen pieces come and go.
        DsListSection(
          header: Text(t.settings.roomCardVisibleContent),
          children: [
            for (final element in RoomCardElement.values)
              if (coverPieces || !_coverOnly.contains(element))
                SettingsConfigRow(
                  leading: DsIcon(_elementIcon(element)),
                  title: _elementLabel(t, element),
                  control: DsSwitch(
                    value: appearance.visibility.shows(element),
                    onChanged: (visible) => update(appearance.withElement(element, visible: visible)),
                    semanticLabel: _elementLabel(t, element),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

/// Opens the card sample full-window and alone: the browsing settings' entry
/// to the card, and the only page that tunes it.
Future<void> showRoomCardPreview(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(fullscreenDialog: true, builder: (context) => const RoomCardPreviewPage()));
}

/// The card and the list row at a feed's size, full-window: the real widgets,
/// drawn with the appearance this device uses, under the controls that shape
/// them. The design switch only changes what the preview shows — the feed
/// keeps choosing its own layout.
final class RoomCardPreviewPage extends ConsumerStatefulWidget {
  /// The page.
  const RoomCardPreviewPage({super.key});

  @override
  ConsumerState<RoomCardPreviewPage> createState() => _RoomCardPreviewPageState();
}

final class _RoomCardPreviewPageState extends ConsumerState<RoomCardPreviewPage> {
  /// The sample's own artwork: the card shows a picture even when the
  /// network one never arrives, and the picture is the card's — not the
  /// stage's — so the sample reads like a room tile.
  static const AssetImage _cover = AssetImage('assets/preview/banner.png');

  bool _list = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final room = _sampleRoom(t);
    final design = _list ? t.common.layoutList : t.common.layoutGrid;
    final tileHeight = roomCardTileHeight(320);
    return SettingsPreviewPage(
      icon: _list ? DsIcons.layoutList : DsIcons.layoutGrid,
      title: t.settings.roomCardPreview,
      // One action over the whole set, so it rides the bar's top-right
      // rather than the list of switches, and asks before it acts.
      barTrailing: DsTooltip(
        message: t.settings.roomCardResetCurrent,
        child: DsButton.icon(
          variant: DsButtonVariant.ghost,
          icon: const DsIcon(DsIcons.rotateCcw),
          semanticLabel: t.settings.roomCardResetCurrent,
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
                // Both designs are laid out at the card's own width and scaled
                // down whole, so a small stage shrinks them instead of
                // squeezing their information line.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _list
                      ? SizedBox(
                          width: 320,
                          height: kRoomCardListDesignHeight,
                          child: RoomCard(room: room, listRow: true, followable: false),
                        )
                      : SizedBox(
                          width: 320,
                          height: tileHeight,
                          child: RoomCard(room: room, followable: false, cover: _cover),
                        ),
                ),
              ),
            ),
          ),
          // The strip under the stage wears the theme's own fill and type: on
          // a page-coloured stage the floating white controls would vanish.
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
      // corners, so the two cover-only pieces are not offered while it shows.
      settings: RoomCardSettings(coverPieces: !_list),
    );
  }

  /// Asks before every switch goes back to the designed default, then does it.
  Future<void> _confirmReset(BuildContext context) async {
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
    if (confirmed ?? false) await ref.read(roomCardSettingsProvider.notifier).reset();
  }
}

/// A stable public sample; every switch has something to show, so turning a
/// piece on and off is visible at a glance.
LiveRoom _sampleRoom(Translations t) => LiveRoom.normalized(
  platform: 'bilibili',
  roomId: 'preview',
  content: RoomContent.of(
    title: t.settings.roomCardPreviewTitle,
    coverUrl: 'https://picsum.photos/seed/pure-live-room/640/360',
  ),
  audience: RoomAudience.of(popularity: 326000, onlineViewers: 12800),
  // A recording rather than an on-air room: the state pill only marks
  // recordings, so this is the sample that shows it.
  broadcast: RoomBroadcast.of(liveStatus: LiveStatus.replay),
  anchor: LiveAnchor.of(
    platform: 'bilibili',
    anchorId: 'preview',
    name: t.settings.roomCardPreviewAnchor,
    avatarUrl: 'https://picsum.photos/seed/pure-live-anchor/96/96',
  ),
  area: LiveArea.of(platform: 'bilibili', areaId: 'game', areaName: t.settings.roomCardPreviewArea),
);

String _elementLabel(Translations t, RoomCardElement element) => switch (element) {
  RoomCardElement.title => t.settings.roomCardShowTitle,
  RoomCardElement.coverType => t.settings.roomCardShowCoverTitle,
  RoomCardElement.avatar => t.settings.roomCardShowAvatar,
  RoomCardElement.anchorName => t.settings.roomCardShowAnchor,
  RoomCardElement.platformBadge => t.settings.roomCardShowPlatform,
  RoomCardElement.audience => t.settings.roomCardShowAudience,
  RoomCardElement.status => t.settings.roomCardShowStatus,
};

DsIconData _elementIcon(RoomCardElement element) => switch (element) {
  RoomCardElement.title => DsIcons.heading,
  RoomCardElement.coverType => DsIcons.tag,
  RoomCardElement.avatar => DsIcons.userRound,
  RoomCardElement.anchorName => DsIcons.atSign,
  RoomCardElement.platformBadge => DsIcons.badge,
  RoomCardElement.audience => DsIcons.flame,
  RoomCardElement.status => DsIcons.signal,
};

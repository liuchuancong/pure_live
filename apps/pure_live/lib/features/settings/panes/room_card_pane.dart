import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAnchor, LiveArea, LiveRoom, LiveStatus, RoomAudience, RoomBroadcast, RoomContent;
import 'package:pure_live/app/app.dart';
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
  /// The controls.
  const RoomCardSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final viewport = ref.watch(deviceProfileProvider) == DeviceProfile.mobile
        ? RoomCardViewport.mobile
        : RoomCardViewport.desktop;
    final targets = ref.watch(roomCardSettingsProvider);
    final appearance = viewport == RoomCardViewport.mobile ? targets.mobile : targets.desktop;
    final controller = ref.read(roomCardSettingsProvider.notifier);

    void update(RoomCardAppearance next) => unawaited(controller.update(viewport, next));

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
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.settings.roomCardResetCurrent),
              onPressed: () => unawaited(controller.reset(viewport)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
          child: Text(t.settings.roomCardScopeHint, style: theme.typography.small.copyWith(color: colors.textSubtle)),
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
    final room = _sampleRoom(t);
    final design = _list ? t.common.layoutList : t.common.layoutGrid;
    final layout = ref.watch(browseSettingsProvider);
    final tileHeight = roomCardTileHeight(320, cover: layout.coverAspect);
    return SettingsPreviewPage(
      icon: _list ? DsIcons.layoutList : DsIcons.layoutGrid,
      title: t.settings.roomCardPreview,
      stage: Stack(
        fit: StackFit.expand,
        children: [
          Center(
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
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: SettingsPreviewBar(
              children: [
                SettingsPreviewCircleButton(
                  icon: DsIcons.layoutGrid,
                  semanticLabel: t.common.layoutGrid,
                  selected: !_list,
                  onPressed: () => setState(() => _list = false),
                ),
                SettingsPreviewCircleButton(
                  icon: DsIcons.layoutList,
                  semanticLabel: t.common.layoutList,
                  selected: _list,
                  onPressed: () => setState(() => _list = true),
                ),
                const SizedBox(width: DsSpace.s8),
                Text(design, style: theme.typography.small.copyWith(color: const Color(0xCCFFFFFF))),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
      settings: const RoomCardSettings(),
    );
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

import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAnchor, LiveRoom, LiveStatus, RoomAudience, RoomBroadcast, RoomContent;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/room/room_card_settings.dart';
import 'package:pure_live/features/settings/surface/settings_preview.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/popular/room_card.dart';
import 'package:pure_live/shared/shared.dart' show CardGrid;

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
          header: Text(t.settings.roomCardAppearance),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.radius),
              title: t.settings.roomCardCornerRadius,
              detail: Text('${appearance.cornerRadius.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: appearance.cornerRadius,
                max: RoomCardAppearance.maxCornerRadius,
                divisions: (RoomCardAppearance.maxCornerRadius - RoomCardAppearance.minCornerRadius).round(),
                onChanged: (value) => update(appearance.copyWith(cornerRadius: value)),
                semanticLabel: t.settings.roomCardCornerRadius,
                semanticFormatter: (value) => '${value.round()} px',
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
  bool _list = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final room = _sampleRoom(t);
    final design = _list ? t.common.layoutList : t.common.layoutGrid;
    return SettingsPreviewPage(
      icon: _list ? DsIcons.layoutList : DsIcons.layoutGrid,
      title: t.settings.roomCardPreview,
      stage: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(DsSpace.s20),
              // The card is laid out at a feed's comfortable size and scaled
              // down whole, so a small stage shrinks it instead of squeezing
              // its information line.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _list
                    ? SizedBox(
                        width: 480,
                        height: kRoomCardListDesignHeight,
                        child: RoomCard(room: room, listRow: true),
                      )
                    : SizedBox(
                        width: 320,
                        height: 320 / CardGrid.roomCardAspectRatio,
                        child: RoomCard(room: room),
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

/// A stable public sample; offline the card's own fallbacks stand in.
LiveRoom _sampleRoom(Translations t) => LiveRoom.normalized(
  platform: 'bilibili',
  roomId: 'preview',
  content: RoomContent.of(
    title: t.settings.roomCardPreviewTitle,
    coverUrl: 'https://picsum.photos/seed/pure-live-room/640/360',
  ),
  audience: RoomAudience.of(popularity: 326000, onlineViewers: 12800),
  broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
  anchor: LiveAnchor.of(
    platform: 'bilibili',
    anchorId: 'preview',
    name: t.settings.roomCardPreviewAnchor,
    avatarUrl: 'https://picsum.photos/seed/pure-live-anchor/96/96',
  ),
);

String _elementLabel(Translations t, RoomCardElement element) => switch (element) {
  RoomCardElement.title => t.settings.roomCardShowTitle,
  RoomCardElement.coverTitle => t.settings.roomCardShowCoverTitle,
  RoomCardElement.avatar => t.settings.roomCardShowAvatar,
  RoomCardElement.anchorName => t.settings.roomCardShowAnchor,
  RoomCardElement.platformBadge => t.settings.roomCardShowPlatform,
  RoomCardElement.audience => t.settings.roomCardShowAudience,
  RoomCardElement.replayBadge => t.settings.roomCardShowReplay,
  RoomCardElement.status => t.settings.roomCardShowStatus,
};

DsIconData _elementIcon(RoomCardElement element) => switch (element) {
  RoomCardElement.title => DsIcons.heading,
  RoomCardElement.coverTitle => DsIcons.image,
  RoomCardElement.avatar => DsIcons.userRound,
  RoomCardElement.anchorName => DsIcons.atSign,
  RoomCardElement.platformBadge => DsIcons.badge,
  RoomCardElement.audience => DsIcons.flame,
  RoomCardElement.replayBadge => DsIcons.history,
  RoomCardElement.status => DsIcons.signal,
};

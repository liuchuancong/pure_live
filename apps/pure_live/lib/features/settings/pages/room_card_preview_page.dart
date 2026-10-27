import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/features/popular/popular.dart';
import 'package:pure_live/features/settings/room/room_card_settings.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow, SettingsHint;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show CardGrid;

/// Opens the room card's preview: the card drawn by the real feed widget, at
/// the sizes a feed gives it, so the viewer can see where each piece of the
/// room's information lands before deciding what to show.
Future<void> showRoomCardPreview(BuildContext context, RoomCardViewport viewport) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(builder: (context) => RoomCardPreviewPage(viewport: viewport)));
}

/// The preview page.
final class RoomCardPreviewPage extends ConsumerWidget {
  /// The target whose appearance is previewed.
  const RoomCardPreviewPage({required this.viewport, super.key});

  /// Which stored appearance the cards draw with.
  final RoomCardViewport viewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final targets = ref.watch(roomCardSettingsProvider);
    final appearance = viewport == RoomCardViewport.mobile ? targets.mobile : targets.desktop;
    final rooms = _sampleRooms(t);
    final gridRatio = appearance.layout == RoomCardLayout.compact
        ? CardGrid.roomCardCompactAspectRatio
        : CardGrid.roomCardAspectRatio;
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s16, DsSpace.s4),
              child: Row(
                children: [
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const DsIcon(DsIcons.chevronLeft),
                    semanticLabel: t.common.back,
                  ),
                  Expanded(
                    child: Text(
                      t.settings.roomCardPreviewTitle,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                  ),
                  Text(
                    viewport == RoomCardViewport.mobile ? t.settings.roomCardMobile : t.settings.roomCardDesktop,
                    style: theme.typography.small.copyWith(color: colors.textSubtle),
                  ),
                  const SizedBox(width: DsSpace.s12),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(DsSpace.s16, 0, DsSpace.s16, DsSpace.s24),
                children: [
                  Text(
                    t.settings.roomCardPreviewHint,
                    style: theme.typography.small.copyWith(color: colors.textSubtle),
                  ),
                  const SizedBox(height: DsSpace.s16),
                  _PreviewGroup(
                    title: t.settings.roomCardPreviewGrid,
                    // A feed tile is a fixed box: the card fills it with an
                    // `Expanded` text row, so a preview has to give it one
                    // too rather than let it size from its content.
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: DsSpace.s12,
                        crossAxisSpacing: DsSpace.s12,
                        childAspectRatio: gridRatio,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) => RoomCard(room: rooms[index], viewport: viewport),
                    ),
                  ),
                  _PreviewGroup(
                    title: t.settings.roomCardPreviewList,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DsSpace.s8,
                      children: [for (final room in rooms) RoomCard(room: room, compact: true, viewport: viewport)],
                    ),
                  ),
                  _WhereSection(appearance: appearance, viewport: viewport),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The rooms the preview draws: a live one with a long title, a replay, and
  /// an offline one, so the badges and the fallbacks all appear.
  static List<LiveRoom> _sampleRooms(Translations t) => [
    LiveRoom.normalized(
      platform: 'bilibili',
      roomId: 'preview-live',
      content: RoomContent.of(title: '${t.settings.roomCardPreviewRoomTitle} · ${t.settings.roomCardPreviewLongTitle}'),
      anchor: LiveAnchor.of(name: t.settings.roomCardPreviewAnchor),
      audience: RoomAudience.of(popularity: 128000),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
    ),
    LiveRoom.normalized(
      platform: 'douyu',
      roomId: 'preview-replay',
      content: RoomContent.of(title: t.settings.roomCardPreviewReplayTitle),
      anchor: LiveAnchor.of(name: t.settings.roomCardPreviewAnchor),
      audience: RoomAudience.of(popularity: 4200),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.replay),
    ),
    LiveRoom.normalized(
      platform: 'huya',
      roomId: 'preview-offline',
      content: RoomContent.of(title: t.settings.roomCardPreviewOfflineTitle),
      anchor: LiveAnchor.of(name: t.settings.roomCardPreviewAnchor),
      audience: RoomAudience.of(popularity: 0),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
    ),
  ];
}

/// One labelled block of the preview.
final class _PreviewGroup extends StatelessWidget {
  const _PreviewGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(title, style: theme.typography.overline.copyWith(color: colors.textSubtle)),
          child,
        ],
      ),
    );
  }
}

/// Where each piece of the room shows, with the switch that controls it: the
/// point of the page is to answer "if I turn this on, where does it appear".
final class _WhereSection extends ConsumerWidget {
  const _WhereSection({required this.appearance, required this.viewport});

  final RoomCardAppearance appearance;
  final RoomCardViewport viewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.read(roomCardSettingsProvider.notifier);
    void update(RoomCardAppearance next) => controller.update(viewport, next);
    return DsListSection(
      header: Text(t.settings.roomCardPreviewWhere),
      children: [
        _SlotRow(
          title: t.settings.roomCardShowAvatar,
          where: t.settings.roomCardWhereAvatar,
          on: appearance.showAvatar,
          onChanged: (value) => update(appearance.copyWith(showAvatar: value)),
        ),
        _SlotRow(
          title: t.settings.roomCardShowAnchor,
          where: t.settings.roomCardWhereAnchor,
          on: appearance.showAnchorName,
          onChanged: (value) => update(appearance.copyWith(showAnchorName: value)),
        ),
        _SlotRow(
          title: t.settings.roomCardShowAudience,
          where: t.settings.roomCardWhereAudience,
          on: appearance.showAudience,
          onChanged: (value) => update(appearance.copyWith(showAudience: value)),
        ),
        _SlotRow(
          title: t.settings.roomCardShowReplay,
          where: t.settings.roomCardWhereReplay,
          on: appearance.showReplayBadge,
          onChanged: (value) => update(appearance.copyWith(showReplayBadge: value)),
        ),
        _SlotRow(
          title: t.settings.roomCardShowPlatform,
          where: t.settings.roomCardWherePlatform,
          on: appearance.platformBadge != RoomCardPlatformBadgeMode.hidden,
          onChanged: (value) => update(
            appearance.copyWith(
              platformBadge: value ? RoomCardPlatformBadgeMode.automatic : RoomCardPlatformBadgeMode.hidden,
            ),
          ),
        ),
        SettingsHint(t.settings.roomCardPreviewFollowsTheme),
      ],
    );
  }
}

/// One information slot: its name, where it draws, and its switch.
final class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.title, required this.where, required this.on, required this.onChanged});

  final String title;
  final String where;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsConfigRow(
      title: title,
      description: where,
      control: DsSwitch(value: on, onChanged: onChanged, semanticLabel: title),
    );
  }
}

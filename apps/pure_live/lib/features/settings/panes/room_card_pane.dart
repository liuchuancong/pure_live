import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/popular/popular.dart';
import 'package:pure_live/features/settings/pages/room_card_preview_page.dart' show showRoomCardPreview;
import 'package:pure_live/features/settings/room/room_card_settings.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show CardGrid;

/// The room-card settings page (the reference's `room_card_settings_page`):
/// one target at a time (mobile or desktop), a live preview, the three quick
/// presets, the visible-content toggles, the layout and corner radius, and a
/// reset to the standard look. Both targets are stored independently.
final class RoomCardPane extends ConsumerStatefulWidget {
  /// The pane.
  const RoomCardPane({super.key});

  @override
  ConsumerState<RoomCardPane> createState() => _RoomCardPaneState();
}

final class _RoomCardPaneState extends ConsumerState<RoomCardPane> {
  late RoomCardViewport _viewport;

  @override
  void initState() {
    super.initState();
    _viewport = ref.read(deviceProfileProvider) == DeviceProfile.mobile
        ? RoomCardViewport.mobile
        : RoomCardViewport.desktop;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final targets = ref.watch(roomCardSettingsProvider);
    final appearance = _viewport == RoomCardViewport.mobile ? targets.mobile : targets.desktop;
    final controller = ref.read(roomCardSettingsProvider.notifier);
    final preset = appearance.preset;

    void update(RoomCardAppearance next) => unawaited(controller.update(_viewport, next));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsChoiceRow<RoomCardViewport>(
              leading: const DsIcon(DsIcons.monitor),
              title: t.settings.roomCardTarget,
              value: _viewport,
              options: [
                DsSelectOption(value: RoomCardViewport.mobile, label: t.settings.roomCardMobile),
                DsSelectOption(value: RoomCardViewport.desktop, label: t.settings.roomCardDesktop),
              ],
              onChanged: (viewport) => setState(() => _viewport = viewport),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.settings.roomCardResetCurrent),
              onPressed: () => unawaited(controller.reset(_viewport)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.roomCardPreview),
          children: [
            Padding(
              padding: const EdgeInsets.all(DsSpace.s16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  // The card is built for a grid tile: its text row is an
                  // `Expanded`, so the preview has to hand it the tile's
                  // fixed box rather than let it size from its content.
                  child: AspectRatio(
                    aspectRatio: appearance.layout == RoomCardLayout.compact
                        ? CardGrid.roomCardCompactAspectRatio
                        : CardGrid.roomCardAspectRatio,
                    child: RoomCard(room: _previewRoom(t), viewport: _viewport),
                  ),
                ),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.eye),
              title: Text(t.settings.roomCardPreviewTitle),
              description: Text(t.settings.roomCardPreviewHint),
              showChevron: true,
              onPressed: () => unawaited(showRoomCardPreview(context, _viewport)),
            ),
          ],
        ),
        DsListSection(
          children: [
            SettingsChoiceRow<RoomCardPreset>(
              leading: const DsIcon(DsIcons.layoutTemplate),
              title: t.settings.roomCardPresets,
              value: preset == RoomCardPreset.custom ? null : preset,
              placeholder: t.settings.roomCardPresetCustom,
              options: [
                DsSelectOption(value: RoomCardPreset.compact, label: t.settings.roomCardPresetCompact),
                DsSelectOption(value: RoomCardPreset.standard, label: t.settings.roomCardPresetStandard),
                DsSelectOption(value: RoomCardPreset.detailed, label: t.settings.roomCardPresetDetailed),
              ],
              onChanged: (next) => unawaited(controller.applyPreset(_viewport, next)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.roomCardVisibleContent),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.userRound),
              title: t.settings.roomCardShowAvatar,
              description: t.settings.roomCardShowAvatarDesc,
              control: DsSwitch(
                value: appearance.showAvatar,
                onChanged: (value) => update(appearance.copyWith(showAvatar: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.userRound),
              title: t.settings.roomCardShowAnchor,
              description: t.settings.roomCardShowAnchorDesc,
              control: DsSwitch(
                value: appearance.showAnchorName,
                onChanged: (value) => update(appearance.copyWith(showAnchorName: value)),
              ),
            ),
            SettingsChoiceRow<RoomCardPlatformBadgeMode>(
              leading: const DsIcon(DsIcons.layoutGrid),
              title: t.settings.roomCardShowPlatform,
              description: t.settings.roomCardShowPlatformDesc,
              value: appearance.platformBadge,
              options: [
                DsSelectOption(value: RoomCardPlatformBadgeMode.automatic, label: t.settings.roomCardPlatformAutomatic),
                DsSelectOption(value: RoomCardPlatformBadgeMode.always, label: t.settings.roomCardPlatformAlways),
                DsSelectOption(value: RoomCardPlatformBadgeMode.hidden, label: t.settings.roomCardPlatformHidden),
              ],
              onChanged: (value) => update(appearance.copyWith(platformBadge: value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.eye),
              title: t.settings.roomCardShowAudience,
              description: t.settings.roomCardShowAudienceDesc,
              control: DsSwitch(
                value: appearance.showAudience,
                onChanged: (value) => update(appearance.copyWith(showAudience: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.video),
              title: t.settings.roomCardShowReplay,
              description: t.settings.roomCardShowReplayDesc,
              control: DsSwitch(
                value: appearance.showReplayBadge,
                onChanged: (value) => update(appearance.copyWith(showReplayBadge: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.roomCardAppearance),
          children: [
            SettingsChoiceRow<RoomCardLayout>(
              leading: const DsIcon(DsIcons.layoutGrid),
              title: t.settings.roomCardLayout,
              description: t.settings.roomCardLayoutDesc,
              value: appearance.layout,
              options: [
                DsSelectOption(value: RoomCardLayout.cover, label: t.settings.roomCardLayoutCover),
                DsSelectOption(value: RoomCardLayout.compact, label: t.settings.roomCardLayoutCompact),
              ],
              onChanged: (value) => update(appearance.copyWith(layout: value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.scale),
              title: t.settings.roomCardCornerRadius,
              description: t.settings.roomCardCornerRadiusDesc,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
          child: Text(t.settings.roomCardScopeHint, style: theme.typography.small.copyWith(color: colors.textSubtle)),
        ),
      ],
    );
  }

  /// The preview's stand-in room, mirroring the reference's synthetic card.
  static LiveRoom _previewRoom(Translations t) => LiveRoom.normalized(
    platform: 'bilibili',
    roomId: 'room-card-preview',
    content: RoomContent.of(title: 'Pure Live · ${t.settings.roomCardPreviewRoomTitle}'),
    anchor: LiveAnchor.of(name: t.settings.roomCardPreviewAnchor),
    audience: RoomAudience.of(popularity: 12800),
    broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
  );
}

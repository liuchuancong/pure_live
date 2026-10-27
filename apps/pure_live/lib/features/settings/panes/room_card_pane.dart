import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/room/room_card_settings.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow, SettingsSegmentedRow;
import 'package:pure_live/l10n/translations.dart';

/// The room-card settings page. The card and the list row have fixed
/// designs; the switches only decide which pieces of information they draw.
/// The page edits the set for the device it runs on, and the appearance
/// follows the device wherever it is used.
final class RoomCardPane extends ConsumerWidget {
  /// The pane.
  const RoomCardPane({super.key});

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
    final preset = appearance.preset;

    void update(RoomCardAppearance next) => unawaited(controller.update(viewport, next));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
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
            SettingsSegmentedRow<RoomCardPreset?>(
              leading: const DsIcon(DsIcons.layoutTemplate),
              title: t.settings.roomCardPresets,
              // A hand-tuned card matches no preset: the control selects
              // nothing and the badge says why.
              value: preset == RoomCardPreset.custom ? null : preset,
              detail: preset == RoomCardPreset.custom
                  ? DsBadge(label: Text(t.settings.roomCardPresetCustom), dot: false)
                  : null,
              options: [
                (value: RoomCardPreset.standard, label: t.settings.roomCardPresetStandard),
                (value: RoomCardPreset.detailed, label: t.settings.roomCardPresetDetailed),
              ],
              onChanged: (next) {
                if (next != null) unawaited(controller.applyPreset(viewport, next));
              },
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.roomCardAppearance),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.radius),
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

import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/player_surface.dart'
    show RoomStreamPicker, roomStreamPickerAskProvider;
import 'package:pure_live/modules/live/room/page/room_details.dart' show copyRoomLink, openRoomExternally, shareRoom;
import 'package:pure_live/modules/live/room/page/room_shortcuts.dart' show showRoomShortcuts;
import 'package:pure_live/modules/live/room/panels/room_panel.dart' show showRoomDetails, showRoomSleepTimer;
import 'package:pure_live/modules/live/room/player/room_switcher.dart' show showRoomSwitcher;
import 'package:pure_live/shared/shared.dart';

/// Opens the room's more container: the shared players' container — a
/// right-docked glass panel where the window has the room, a bottom glass
/// sheet where it doesn't — carrying the room's own rows and tiles. The
/// container owns the chrome (glass, header, grip, escape); everything here
/// is a verb whose home is not a bar: the share circles, the cast and stats
/// and the room switch, the audio mode, and the settings rows. The bar's own
/// verbs — screenshot, recording, the small window, the danmaku gear — stay
/// on the bars where they live; the container is an index of the homes that
/// have no bar, not a second copy of the ones that do.
Future<void> showRoomMore(BuildContext context) {
  return showPlayerMoreContainer(context, content: (context, {required labeled}) => _RoomMoreContent(labeled: labeled));
}

/// The container's content: the share row, the tools grid and the settings
/// rows — every tile and row a verb that already exists, so the container is
/// an index of homes and not a second copy of any of them. The panel reads
/// the groups from their spacing; the sheet, which the reference draws with
/// the labels on, keeps them.
final class _RoomMoreContent extends ConsumerWidget {
  const _RoomMoreContent({required this.labeled});

  /// Whether the group labels show.
  final bool labeled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    final detail = room.room;
    final settings = ref.watch(playbackSettingsProvider);
    final shortcutsHelp = ref.watch(platformRuntimeProvider).environment.runtime.formFactor != FormFactor.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labeled) playerMoreSectionLabel(context, t.room.share),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: _Circle(
                  color: const Color(0xFF3ECF8E),
                  icon: DsIcons.share,
                  label: t.room.share,
                  onTap: detail == null ? null : () => unawaited(shareRoom(context, detail)),
                ),
              ),
              Expanded(
                child: _Circle(
                  color: const Color(0xFF4F8CFF),
                  icon: DsIcons.link,
                  label: t.room.copyLink,
                  onTap: detail == null ? null : () => unawaited(copyRoomLink(context, detail)),
                ),
              ),
              Expanded(
                child: _Circle(
                  color: const Color(0xFFF5A623),
                  icon: DsIcons.appWindow,
                  label: t.room.openExternal,
                  onTap: detail == null ? null : () => unawaited(openRoomExternally(context, detail)),
                ),
              ),
              Expanded(
                child: _Circle(
                  color: const Color(0xFF8B5CF6),
                  icon: DsIcons.badgeInfo,
                  label: t.room.detailsHint,
                  onTap: () => unawaited(showRoomDetails(context)),
                ),
              ),
            ],
          ),
        ),
        if (labeled) playerMoreSectionLabel(context, t.room.moreTools),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8),
          child: Wrap(
            spacing: DsSpace.s4,
            runSpacing: DsSpace.s8,
            children: [
              PlayerMoreTile(
                icon: DsIcons.cast,
                label: t.room.cast,
                onTap: room.lines.isEmpty
                    ? null
                    : () => unawaited(
                        showCastDialog(
                          context,
                          line: room.lines[room.lineIndex.clamp(0, room.lines.length - 1)],
                          title: detail?.content.title,
                        ),
                      ),
              ),
              // The stream's own figures, over the picture: the verb the
              // keyboard's I used to own alone, now where every hand can
              // reach it.
              PlayerMoreTile(
                icon: DsIcons.gauge,
                label: t.room.stats,
                onTap: room.handle == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        ref.read(playerStatsVisibleProvider.notifier).toggle();
                      },
              ),
              if (detail != null)
                PlayerMoreTile(
                  icon: DsIcons.arrowLeftRight,
                  label: t.room.switchRoom,
                  onTap: () => unawaited(showRoomSwitcher(context, current: detail)),
                ),
              PlayerMoreTile(
                icon: DsIcons.headphones,
                label: room.audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode,
                lit: room.audioOnly,
                onTap: () => unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: !room.audioOnly)),
              ),
            ],
          ),
        ),
        if (labeled) playerMoreSectionLabel(context, t.room.moreSettings),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              // The auto-hide pace, where the bars' own setting lives: the
              // reference's segments — 常显, then the four delays — not a
              // slider, so the value a viewer picks is one the bar's own
              // words name exactly.
              PlayerMoreRow(
                label: t.settings.controlsAutoHide,
                value: null,
                onTap: null,
                trailing: PlayerMoreSeg(
                  values: const [0, 2, 4, 6, 10],
                  labels: [t.settings.controlsAutoHideAlways, '2s', '4s', '6s', '10s'],
                  current: settings.controlsAutoHideSeconds,
                  onPick: (value) =>
                      unawaited(ref.read(playbackSettingsProvider.notifier).setControlsAutoHideSeconds(value)),
                ),
              ),
              PlayerMoreRow(
                label: t.room.quality,
                value: room.quality?.displayLabel ?? t.room.quality,
                onTap: room.qualities.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        ref.read(roomStreamPickerAskProvider.notifier).ask(RoomStreamPicker.quality);
                      },
              ),
              PlayerMoreRow(
                label: t.room.lineLabel,
                value: room.lines.isEmpty ? null : t.room.line(n: room.lineIndex + 1),
                onTap: room.lines.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        ref.read(roomStreamPickerAskProvider.notifier).ask(RoomStreamPicker.line);
                      },
              ),
              PlayerMoreRow(
                label: t.settings.fit,
                value: fitLabels(t)[ref.watch(playbackSettingsProvider).fit.index],
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(roomStreamPickerAskProvider.notifier).ask(RoomStreamPicker.fit);
                },
              ),
              PlayerMoreRow(
                label: t.room.sleep,
                value: t.room.sleepOff,
                onTap: () => unawaited(showRoomSleepTimer(context)),
              ),
              if (shortcutsHelp)
                PlayerMoreRow(
                  label: t.room.shortcutsHelp,
                  value: null,
                  onTap: () => unawaited(showRoomShortcuts(context, const [])),
                ),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.s12),
      ],
    );
  }
}

/// The share row's circle: a fixed hue per verb, the reference's share sheet
/// shape — the hue says which verb without reading.
final class _Circle extends StatelessWidget {
  const _Circle({required this.color, required this.icon, required this.label, required this.onTap});

  final Color color;
  final DsIconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      onPressed: onTap,
      builder: (context, states, _) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: onTap == null ? colors.border : color),
            child: DsIcon(icon, size: 20, color: onTap == null ? colors.textMuted : const Color(0xFFFFFFFF)),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.typography.caption.copyWith(color: onTap == null ? colors.textMuted : colors.text),
          ),
        ],
      ),
    );
  }
}

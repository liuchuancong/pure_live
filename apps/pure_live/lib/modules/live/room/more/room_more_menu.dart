import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/room_details.dart' show copyRoomLink, openRoomExternally, shareRoom;
import 'package:pure_live/modules/live/room/page/room_shortcuts.dart' show RoomShortcutBinding, showRoomShortcuts;
import 'package:pure_live/modules/live/room/panels/room_panel.dart' show showRoomSleepTimer;
import 'package:pure_live/modules/live/room/player/room_switcher.dart' show showRoomSwitcher;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart' show sleepTimerProvider;
import 'package:pure_live/shared/shared.dart';

/// Opens the room's more container: the shared players' container — the
/// component library's own panel — carrying the room's own rows and tiles.
/// The container owns the chrome (header, scroll, escape); everything here
/// is a verb whose home is not a bar: the share circles, the cast and stats
/// and the room switch, the audio mode, and the settings rows. The bar's own
/// verbs — screenshot, recording, the small window, the danmaku gear — stay
/// on the bars where they live; the container is an index of the homes that
/// have no bar, not a second copy of the ones that do.
///
/// [shortcuts] is the page's own live bindings, so the help row opens the
/// same sheet the `?` key does — not an empty one. [cleanScreen] shows the
/// immersive room's clean-screen switch when not null, flipping through
/// [onCleanScreen]; null leaves the row out (the layouts with no overlay to
/// clean have nothing for it to say). [onOpenChat] shows the chat's door —
/// the row that opens the talk's drawer (the immersive room's only door,
/// its send bar having gone away); null leaves the row out.
Future<void> showRoomMore(
  BuildContext context, {
  required List<RoomShortcutBinding> shortcuts,
  bool? cleanScreen,
  ValueChanged<bool>? onCleanScreen,
  VoidCallback? onOpenChat,
}) {
  return showPlayerMoreContainer(
    context,
    content: (context, {required labeled}) => _RoomMoreContent(
      shortcuts: shortcuts,
      cleanScreen: cleanScreen,
      onCleanScreen: onCleanScreen,
      onOpenChat: onOpenChat,
    ),
  );
}

/// The container's content, drawn the reference sheet's way: the share
/// circles over the tools tiles, then the settings as the component library's
/// own list — [DsListSection] holding [DsListRow]s, each row with its icon,
/// value and trailing control, so no row chrome is hand-drawn here.
final class _RoomMoreContent extends ConsumerWidget {
  const _RoomMoreContent({required this.shortcuts, this.cleanScreen, this.onCleanScreen, this.onOpenChat});

  /// The page's live key bindings, for the help row's sheet.
  final List<RoomShortcutBinding> shortcuts;

  /// The immersive room's clean-screen state; null hides the row.
  final bool? cleanScreen;

  /// Flips the clean-screen state.
  final ValueChanged<bool>? onCleanScreen;

  /// Opens the chat's drawer (the immersive room's only door); null hides
  /// the row.
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    final detail = room.room;
    final settings = ref.watch(playbackSettingsProvider);
    final sleepMinutes = ref.watch(sleepTimerProvider).minutes;
    final shortcutsHelp = ref.watch(platformRuntimeProvider).environment.runtime.formFactor != FormFactor.phone;
    // The choice panels' pick closures run after the more panel is gone, so
    // they hold the notifiers, not this widget's ref.
    final roomNotifier = ref.read(roomProvider.notifier);
    final playbackSettingsController = ref.read(playbackSettingsProvider.notifier);
    // The chat door's local: a field's null-promotion does not reach into
    // the row's closure.
    final openChat = onOpenChat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: _Circle(
                  color: const Color(0xFF3ECF8E),
                  icon: DsIcons.share2,
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
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: _Circle(
                  color: const Color(0xFF8B5CF6),
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
              ),
              Expanded(
                child: _Circle(
                  color: const Color(0xFF38BDF8),
                  icon: DsIcons.arrowLeftRight,
                  label: t.room.switchRoom,
                  onTap: detail == null ? null : () => unawaited(showRoomSwitcher(context, current: detail)),
                ),
              ),
              Expanded(
                child: _Circle(
                  color: const Color(0xFFFB7185),
                  icon: DsIcons.headphones,
                  label: room.audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode,
                  lit: room.audioOnly,
                  onTap: () => unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: !room.audioOnly)),
                ),
              ),
            ],
          ),
        ),
        DsListSection(
          children: [
            // The chat's door: the row closes the menu first — the drawer it
            // opens is a page surface, not another sheet on the stack.
            if (openChat != null)
              DsListRow(
                title: Text(t.room.chatTitle),
                leading: const DsIcon(DsIcons.messageCircle),
                onPressed: () {
                  Navigator.of(context).pop();
                  openChat();
                },
              ),
            // The bars' auto-hide pace: the row opens its own choice panel —
            // 常显, then the three delays — where the pick lands like every
            // other choice in the menu.
            DsListRow(
              title: Text(t.settings.controlsAutoHide),
              leading: const DsIcon(DsIcons.clock),
              detail: Text(
                settings.controlsAutoHideSeconds == 0
                    ? t.settings.controlsAutoHideAlways
                    : '${settings.controlsAutoHideSeconds} s',
              ),
              showChevron: true,
              onPressed: () => unawaited(
                showRoomChoicePanel(
                  context,
                  title: t.settings.controlsAutoHide,
                  options: [
                    for (final seconds in const [0, 2, 4, 6])
                      RoomChoiceOption(
                        label: seconds == 0 ? t.settings.controlsAutoHideAlways : '$seconds s',
                        selected: settings.controlsAutoHideSeconds == seconds,
                        onPick: () => unawaited(playbackSettingsController.setControlsAutoHideSeconds(seconds)),
                      ),
                  ],
                ),
              ),
            ),
            // The flying layer's switch, where a strip too narrow to carry
            // the pair still reaches it: the same one read the bar's glyph.
            DsListRow(
              title: Text(t.room.danmakuOn),
              leading: const DsIcon(DsIcons.messageSquare),
              trailing: DsSwitch(
                value: settings.danmakuVisible,
                onChanged: (value) => unawaited(playbackSettingsController.setDanmakuVisible(value: value)),
              ),
            ),
            // The immersive room's clean screen: the overlay chat and the
            // composer bar give way to the picture alone, and a small pill
            // floating at the picture's side takes them back. A layout with
            // no overlay carries no row for it.
            if (cleanScreen case final clean? when onCleanScreen != null)
              DsListRow(
                title: Text(t.room.cleanScreen),
                leading: const DsIcon(DsIcons.eyeOff),
                detail: Text(t.room.cleanScreenDesc, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: DsSwitch(value: clean, onChanged: onCleanScreen),
              ),
            DsListRow(
              title: Text(t.room.quality),
              leading: const DsIcon(DsIcons.monitorPlay),
              detail: room.quality == null ? null : Text(room.quality!.displayLabel),
              showChevron: true,
              onPressed: room.qualities.isEmpty
                  ? null
                  : () => unawaited(
                      showRoomChoicePanel(
                        context,
                        title: t.room.quality,
                        options: [
                          for (final option in room.qualities)
                            RoomChoiceOption(
                              label: option.displayLabel,
                              selected: option == (room.quality ?? room.qualities.first),
                              onPick: () => unawaited(roomNotifier.selectQuality(option)),
                            ),
                        ],
                      ),
                    ),
            ),
            DsListRow(
              title: Text(t.room.lineLabel),
              leading: const DsIcon(DsIcons.route),
              detail: room.lines.isEmpty ? null : Text(t.room.line(n: room.lineIndex + 1)),
              showChevron: true,
              onPressed: room.lines.isEmpty
                  ? null
                  : () => unawaited(
                      showRoomChoicePanel(
                        context,
                        title: t.room.lineLabel,
                        options: [
                          for (final (index, line) in room.lines.indexed)
                            RoomChoiceOption(
                              label: roomLineShortLabel(t, line, index),
                              detail: roomLineDetail(line),
                              selected: index == room.lineIndex,
                              onPick: () => unawaited(roomNotifier.selectLine(index)),
                            ),
                        ],
                      ),
                    ),
            ),
            DsListRow(
              title: Text(t.settings.fit),
              leading: const DsIcon(DsIcons.scaling),
              detail: Text(fitLabels(t)[settings.fit.index]),
              showChevron: true,
              onPressed: () => unawaited(
                showRoomChoicePanel(
                  context,
                  title: t.settings.fit,
                  options: [
                    for (final option in PlaybackFit.values)
                      RoomChoiceOption(
                        label: fitLabels(t)[option.index],
                        selected: option == settings.fit,
                        onPick: () => unawaited(playbackSettingsController.setFit(option)),
                      ),
                  ],
                ),
              ),
            ),
            DsListRow(
              title: Text(t.room.sleep),
              leading: const DsIcon(DsIcons.timer),
              detail: Text(sleepMinutes == null ? t.room.sleepOff : asmrSleepDurationLabel(sleepMinutes)),
              showChevron: true,
              // The timer's panel takes the menu's place: the menu puts
              // itself away first, per the sheet's own traffic.
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(showRoomSleepTimer(context));
              },
            ),
            if (shortcutsHelp)
              DsListRow(
                title: Text(t.room.shortcutsHelp),
                leading: const DsIcon(DsIcons.keyboard),
                showChevron: true,
                onPressed: () => unawaited(showRoomShortcuts(context, shortcuts)),
              ),
          ],
        ),
        const SizedBox(height: DsSpace.s12),
      ],
    );
  }
}

/// The share row's circle: a fixed hue per verb, the reference's share sheet
/// shape — the hue says which verb without reading. [lit] wears the theme's
/// accent instead of the verb's own hue: the on state of a toggle.
final class _Circle extends StatelessWidget {
  const _Circle({required this.color, required this.icon, required this.label, required this.onTap, this.lit = false});

  final Color color;
  final DsIconData icon;
  final String label;
  final VoidCallback? onTap;

  final bool lit;

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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap == null
                  ? colors.border
                  : lit
                  ? colors.accent
                  : color,
            ),
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

/// One choice in a settings panel: its words, whether it is the live one,
/// and the verb that applies it.
final class RoomChoiceOption {
  const RoomChoiceOption({required this.label, required this.selected, required this.onPick, this.detail});

  /// The choice's words.
  final String label;

  /// A muted second line — a line's container and codec, say.
  final String? detail;

  /// Whether this is the current choice; its row carries the check.
  final bool selected;

  /// Applies the choice.
  final VoidCallback onPick;
}

/// Closes the more panel, then opens [title]'s own choice panel: the
/// component library's panel — a side panel on a wide window, a bottom sheet
/// on a narrow one — listing [options] in one list, the live one
/// check-marked. A pick applies itself and puts the panel away.
Future<void> showRoomChoicePanel(
  BuildContext context, {
  required String title,
  required List<RoomChoiceOption> options,
}) {
  Navigator.of(context).pop();
  return showAppPanel<void>(
    context: context,
    builder: (sheetContext) {
      final colors = DsTheme.colorsOf(sheetContext);
      // The live room's lists run at the library's own measure: the app's
      // settings-sized rows and paddings stop at this subtree.
      final theme = DsTheme.of(sheetContext);
      return AppPanel(
        title: Text(title),
        child: DsListRowTheme(
          data: DsListRowThemeData(style: DsListRow.defaultStyle(theme)),
          child: DsListSectionTheme(
            data: DsListSectionThemeData(style: DsListSection.defaultStyle(theme)),
            child: DsListSection(
              children: [
                for (final option in options)
                  DsListRow(
                    title: Text(option.label),
                    detail: option.detail == null ? null : Text(option.detail!),
                    trailing: option.selected ? DsIcon(DsIcons.check, size: 16, color: colors.accent) : null,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      option.onPick();
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The line's words in the choice panel: the platform's own label when it
/// reads as one, the position otherwise (Bilibili labels a line
/// `host|protocol|format|codec`, which never belongs on a row).
String roomLineShortLabel(Translations t, LivePlayLine line, int index) {
  final own = (line.lineLabel ?? '').trim();
  if (own.isEmpty || own.contains('|') || own.length > 14) return t.room.line(n: index + 1);
  return own;
}

/// What a line is, under its name in the panel: the container and the codec,
/// the two facts a viewer compares lines by.
String roomLineDetail(LivePlayLine line) {
  final format = switch (line.format) {
    LiveStreamFormat.mpegts => 'MPEG-TS',
    LiveStreamFormat.webrtc => 'WebRTC',
    _ => line.format.name.toUpperCase(),
  };
  final codec = switch (line.codec) {
    LiveStreamCodec.avc => 'H.264',
    LiveStreamCodec.hevc => 'H.265',
    LiveStreamCodec.av1 => 'AV1',
    LiveStreamCodec.vp9 => 'VP9',
    LiveStreamCodec.unknown || null => '',
  };
  return codec.isEmpty ? format : '$format · $codec';
}

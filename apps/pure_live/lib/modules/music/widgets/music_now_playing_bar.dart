import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart';
import 'package:pure_live/modules/music/widgets/music_actions.dart' show listenPlaybackErrors;
import 'package:pure_live/modules/music/widgets/music_lyric_panel.dart';
import 'package:pure_live/modules/music/widgets/music_quality_pill.dart';
import 'package:pure_live/modules/music/widgets/music_queue_panel.dart' show MusicQueuePanel;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/widgets/app_panel.dart';

/// The bar's own width thresholds. The sidebar takes its share of the window
/// first, so the window width says nothing about how much room the bar has.
const double _regularBarWidth = 720;
const double _expandedBarWidth = 1020;

/// Below this the bar keeps play and next only: the previous button is the
/// first verb a phone's bar gives up.
const double _previousButtonWidth = 460;

/// The bar under every music page while something plays: the song and its
/// favourite at one end, the transport in the middle, and the sound's own
/// controls at the other — the lyric sheet, the effect centre, the quality,
/// the volume, the output device and the queue. The shell mounts it once for
/// the module, so it stays put while the viewer moves between search, the
/// lists, the local library, downloads and the effects page; the full player
/// is its own screen.
/// The strip over the module's views while something plays, drawn in the
/// reference bar's shape: a progress hairline along its top edge, then the
/// three groups. The groups shed their low-frequency verbs as the bar
/// narrows instead of squeezing the title.
final class MusicNowPlayingBar extends ConsumerStatefulWidget {
  /// The bar.
  const MusicNowPlayingBar({super.key});

  @override
  ConsumerState<MusicNowPlayingBar> createState() => MusicNowPlayingBarState();
}

final class MusicNowPlayingBarState extends ConsumerState<MusicNowPlayingBar> {
  /// Sends the sound to [name] and re-reads the devices so the menu's mark
  /// follows the choice.
  Future<void> _selectAudioDevice(String name) async {
    await ref.read(musicPlayerProvider.notifier).selectAudioDevice(name);
    if (!mounted) return;
    ref.invalidate(musicAudioDevicesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(
      musicPlayerProvider.select(
        (state) => (
          track: state.track,
          playing: state.playing,
          position: state.position,
          duration: state.duration,
          mode: state.mode,
          volume: state.volume,
          muted: state.muted,
        ),
      ),
    );
    final controller = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    // A failed song must say so before it skips away — the bar is the one
    // strip alive under every page of the module.
    listenPlaybackErrors(context, ref);
    final track = state.track;
    if (track == null) return const SizedBox.shrink();
    final duration = state.duration.inMilliseconds;
    final shownPosition = state.position.inMilliseconds.clamp(0, duration < 0 ? 0 : duration);
    final progress = duration <= 0 ? 0.0 : shownPosition / duration;
    // Read only to decide whether a picker is worth showing: a single output
    // offers no choice, the same rule the settings row follows.
    final devices = ref.watch(musicAudioDevicesProvider).value ?? const [];
    Widget favouriteButton() => DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      semanticLabel: favourites.contains(track) ? t.music.unfavourite : t.music.favourite,
      onPressed: () => unawaited(favouriteController.toggle(track)),
      icon: DsIcon(DsIcons.heart, color: favourites.contains(track) ? colors.accent : null),
    );
    return DecoratedBox(
      // The bar is the module's bottom strip, docked flush like every other
      // player dock in the app: the theme's surface, one hairline above it.
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The hairline: tap anywhere on it to seek without opening
          // the player page.
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: duration <= 0
                  ? null
                  : (details) => unawaited(
                      controller.seek(
                        Duration(milliseconds: (details.localPosition.dx / constraints.maxWidth * duration).round()),
                      ),
                    ),
              child: SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    Container(color: colors.surface),
                    FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(color: colors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Three groups — the song on the left, the transport in the
          // middle, the sound's own controls on the right — that shed
          // their low-frequency verbs as the bar narrows, never the
          // title.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final regular = width >= _regularBarWidth;
              final expanded = width >= _expandedBarWidth;
              final withPrevious = width >= _previousButtonWidth;
              Widget lyricsButton() => DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.music.lyrics,
                onPressed: () => unawaited(
                  showAppPanel<void>(
                    context: context,
                    builder: (context) => AppPanel(
                      title: Text(context.t.music.lyrics),
                      scrollable: false,
                      child: SizedBox(
                        // Half the window, kept between a readable
                        // minimum and a sheet that leaves the page in
                        // view.
                        height: (MediaQuery.sizeOf(context).height * 0.5).clamp(240.0, 480.0),
                        child: const MusicLyricsPanel(),
                      ),
                    ),
                  ),
                ),
                icon: const DsIcon(DsIcons.captions),
              );
              // The effect centre as its own screen: the bar opens it
              // above the shell, so the page the viewer browsed keeps its
              // place behind it.
              Widget effectsButton() => DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.music.eqCenter,
                onPressed: () => unawaited(context.push(RouteNames.musicEffects)),
                icon: const DsIcon(DsIcons.audioLines),
              );
              // Only a real choice is offered; the entry is absent where
              // the engine reports one output or none.
              Widget outputButton() => DsMenuAnchor(
                semanticLabel: t.music.audioOutput,
                items: [
                  for (final device in devices)
                    DsMenuItem(
                      label: Text(device.description.isEmpty ? device.name : device.description),
                      checked: device.selected,
                      onPressed: () => unawaited(_selectAudioDevice(device.name)),
                    ),
                ],
                builder: (context, menu, _) => DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.music.audioOutput,
                  onPressed: menu.toggle,
                  icon: const DsIcon(DsIcons.speaker),
                ),
              );
              Widget queueButton() => DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.music.queueTitle,
                onPressed: () => unawaited(
                  showAppPanel<void>(
                    context: context,
                    builder: (context) => AppPanel(
                      title: Text(context.t.music.queueTitle),
                      scrollable: false,
                      child: const MusicQueuePanel(),
                    ),
                  ),
                ),
                icon: const DsIcon(DsIcons.listMusic),
              );
              Widget actions() => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  lyricsButton(),
                  if (expanded) effectsButton(),
                  // The tier the song plays at, and the way to change it
                  // without leaving the bar for the settings.
                  const MusicQualityPill(),
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: state.muted ? t.room.unmute : t.room.mute,
                    onPressed: () => unawaited(controller.setMuted(muted: !state.muted)),
                    icon: DsIcon(state.muted ? DsIcons.volumeOff : DsIcons.volume),
                  ),
                  if (expanded)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: SizedBox(
                        width: 96,
                        child: DsSlider(
                          value: state.muted ? 0 : state.volume,
                          semanticLabel: t.music.volume,
                          onChanged: (value) => unawaited(controller.setVolume(value)),
                        ),
                      ),
                    ),
                  if (expanded && devices.length > 1) outputButton(),
                  queueButton(),
                ],
              );
              Widget lead() => Row(
                children: [
                  // One pressable over the cover and its two lines. They
                  // were two doors side by side opening the same page, and
                  // neither answered the pointer — DsPressable draws no
                  // feedback of its own, so the tint here is the same one
                  // every other pressable in the app paints.
                  Expanded(
                    child: DsPressable(
                      semanticLabel: t.music.openPlayer,
                      onPressed: () => unawaited(context.push(RouteNames.musicPlayer)),
                      builder: (context, states, _) {
                        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed);
                        return Container(
                          decoration: BoxDecoration(
                            color: lit ? colors.hover : null,
                            borderRadius: BorderRadius.circular(theme.radii.control(44)),
                          ),
                          child: Row(
                            children: [
                              MusicArtwork(track: track),
                              const SizedBox(width: DsSpace.s8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: DsSpace.s3,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.typography.body.copyWith(
                                        color: colors.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    // Who sang it and off which record — the
                                    // same line the list rows above the bar
                                    // use. A song with neither says where it
                                    // is, not nothing.
                                    Text(
                                      musicTrackCredits(track) ?? t.music.nowPlaying,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: DsSpace.s4),
                  favouriteButton(),
                ],
              );
              Widget transport() => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s3,
                children: [
                  // A phone's bar leaves the mode step to the player
                  // page: the mode is the first verb the bar gives up.
                  if (regular)
                    DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: musicPlayModeLabel(t, state.mode),
                      onPressed: controller.cycleMode,
                      icon: DsIcon(musicPlayModeIcon(state.mode)),
                    ),
                  if (withPrevious)
                    DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: t.music.previous,
                      onPressed: () => unawaited(controller.previous()),
                      icon: const DsIcon(DsIcons.skipBack),
                    ),
                  DsButton.icon(
                    variant: DsButtonVariant.primary,
                    size: DsSize.sm,
                    semanticLabel: state.playing ? t.music.pause : t.music.play,
                    onPressed: () => unawaited(controller.toggle()),
                    icon: DsIcon(state.playing ? DsIcons.pause : DsIcons.play),
                  ),
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.music.next,
                    onPressed: () => unawaited(controller.next()),
                    icon: const DsIcon(DsIcons.skipForward),
                  ),
                ],
              );

              /// The numbers in the bar's own line, as the reference
              /// prints them: elapsed / total on a wide bar, elapsed alone
              /// where the total would squeeze the title.
              Widget timeText({required bool compact}) {
                final elapsed = musicDurationText(Duration(milliseconds: shownPosition));
                return SizedBox(
                  width: compact ? 48 : 96,
                  child: Text(
                    duration <= 0 || compact ? elapsed : '$elapsed / ${musicDurationText(state.duration)}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                  ),
                );
              }

              // A phone keeps the bar to the song, the clock, the tier and
              // the transport; the verbs the wide bar draws as icons move
              // behind one menu rather than falling off the strip.
              Widget moreButton() => DsMenuAnchor(
                semanticLabel: t.common.more,
                align: DsAlign.end,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.listMusic),
                    label: Text(t.music.queueTitle),
                    onPressed: () => unawaited(
                      showAppPanel<void>(
                        context: context,
                        builder: (context) => AppPanel(
                          title: Text(context.t.music.queueTitle),
                          scrollable: false,
                          child: const MusicQueuePanel(),
                        ),
                      ),
                    ),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.captions),
                    label: Text(t.music.lyrics),
                    onPressed: () => unawaited(
                      showAppPanel<void>(
                        context: context,
                        builder: (context) => AppPanel(
                          title: Text(context.t.music.lyrics),
                          scrollable: false,
                          child: SizedBox(
                            height: (MediaQuery.sizeOf(context).height * 0.5).clamp(240.0, 480.0),
                            child: const MusicLyricsPanel(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.audioLines),
                    label: Text(t.music.eqCenter),
                    onPressed: () => unawaited(context.push(RouteNames.musicEffects)),
                  ),
                  DsMenuItem(
                    leading: DsIcon(state.muted ? DsIcons.volumeOff : DsIcons.volume),
                    label: Text(state.muted ? t.room.unmute : t.room.mute),
                    onPressed: () => unawaited(controller.setMuted(muted: !state.muted)),
                  ),
                  DsMenuItem(
                    leading: DsIcon(musicPlayModeIcon(state.mode)),
                    label: Text(musicPlayModeLabel(t, state.mode)),
                    onPressed: controller.cycleMode,
                  ),
                ],
                builder: (context, menu, _) => DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.common.more,
                  onPressed: menu.toggle,
                  icon: const DsIcon(DsIcons.ellipsisVertical),
                ),
              );

              // One line at every width, progress on the strip's top edge
              // — the reference bar's own shape. The wide bar keeps its
              // utility cluster beside the transport; the phone's bar keeps
              // the transport and puts the rest behind 更多.
              final row = regular
                  ? Row(
                      spacing: DsSpace.s8,
                      children: [
                        Expanded(child: lead()),
                        timeText(compact: false),
                        actions(),
                        transport(),
                      ],
                    )
                  : Row(
                      spacing: DsSpace.s8,
                      children: [
                        Expanded(child: lead()),
                        transport(),
                        moreButton(),
                      ],
                    );
              return Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, 0, DsSpace.s12, 0),
                child: SizedBox(height: 60, child: row),
              );
            },
          ),
        ],
      ),
    );
  }
}

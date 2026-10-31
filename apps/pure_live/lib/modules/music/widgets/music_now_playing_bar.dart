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

/// The bar under every music page while something plays: the cover and song
/// at one end, the transport in the middle, and — where it is wide enough —
/// the seek with its clock, the volume, the favourite and the queue toggle at
/// the other. The shell mounts it once for the module, so it stays put while
/// the viewer moves between search, the lists, the local library, downloads
/// and the effects page; the full player is its own screen.
/// The strip over the module's views while something plays, drawn in the
/// reference bar's shape: a progress hairline along its top edge, then the
/// cover and song at one end, the transport at the middle and — where the
/// bar is wide enough — the seek with its clock, the volume and the queue
/// toggle at the other.
final class MusicNowPlayingBar extends ConsumerStatefulWidget {
  /// The bar.
  const MusicNowPlayingBar({super.key});

  @override
  ConsumerState<MusicNowPlayingBar> createState() => MusicNowPlayingBarState();
}

final class MusicNowPlayingBarState extends ConsumerState<MusicNowPlayingBar> {
  /// Where the seek slider sits while the viewer drags it, in milliseconds.
  int? _dragMs;

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
    final shownPosition = _dragMs ?? state.position.inMilliseconds.clamp(0, duration < 0 ? 0 : duration);
    final progress = duration <= 0 ? 0.0 : shownPosition / duration;
    // One more control sits in the wide row now — the lyric sheet — so the
    // width that fits the whole row rose with it; a narrower bar keeps the
    // cover, the title, the transport and the queue.
    final wide = MediaQuery.sizeOf(context).width >= 940;
    Widget favouriteButton() => DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      semanticLabel: favourites.contains(track) ? t.music.unfavourite : t.music.favourite,
      onPressed: () => unawaited(favouriteController.toggle(track)),
      icon: DsIcon(DsIcons.heart, color: favourites.contains(track) ? colors.accent : null),
    );
    // A phone's bar trades the mode step for the heart: the mode lives on the
    // player page, while liking is the bar's most-used verb — the reference's
    // compact bar makes the same trade.
    Widget transport({required bool withMode}) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s3,
      children: [
        if (withMode)
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            semanticLabel: musicPlayModeLabel(t, state.mode),
            onPressed: controller.cycleMode,
            icon: DsIcon(musicPlayModeIcon(state.mode)),
          ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s8),
      child: DsSurface(
        decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.card),
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
                            Duration(
                              milliseconds: (details.localPosition.dx / constraints.maxWidth * duration).round(),
                            ),
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
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s6, DsSpace.s8, DsSpace.s8),
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    DsPressable(
                      semanticLabel: t.music.openPlayer,
                      onPressed: () => unawaited(context.push(RouteNames.musicPlayer)),
                      builder: (context, states, _) => MusicArtwork(track: track),
                    ),
                    Expanded(
                      flex: 3,
                      child: DsPressable(
                        semanticLabel: t.music.openPlayer,
                        onPressed: () => unawaited(context.push(RouteNames.musicPlayer)),
                        builder: (context, states, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: DsSpace.s3,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.body.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              track.artist.isEmpty ? t.music.nowPlaying : track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ],
                        ),
                      ),
                    ),
                    transport(withMode: wide),
                    // The narrow bar carries the heart in the mode step's
                    // place, so the width it had stays the width it has.
                    if (!wide) favouriteButton(),
                    if (wide) ...[
                      // The clock and the seek, the way the full page lays
                      // them; the drag shows itself before it seeks.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s6,
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              musicDurationText(Duration(milliseconds: shownPosition)),
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: colors.textMuted),
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: SizedBox(
                              width: 260,
                              child: DsSlider(
                                value: duration <= 0 ? 0 : shownPosition.toDouble(),
                                max: duration <= 0 ? 1 : duration.toDouble(),
                                semanticLabel: t.music.progress,
                                onChanged: duration <= 0 ? null : (value) => setState(() => _dragMs = value.round()),
                                onChangeEnd: duration <= 0
                                    ? null
                                    : (value) {
                                        setState(() => _dragMs = null);
                                        unawaited(controller.seek(Duration(milliseconds: value.round())));
                                      },
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              musicDurationText(state.duration),
                              textAlign: TextAlign.end,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: colors.textMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s4,
                        children: [
                          // The words, raised over the page: the same lyric
                          // panel the player shows, so a viewer browsing a
                          // list reads the song without leaving it.
                          DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            semanticLabel: t.music.lyrics,
                            onPressed: () => unawaited(
                              showDsPanel<void>(
                                context: context,
                                builder: (context) => DsPanel(
                                  title: Text(context.t.music.lyrics),
                                  scrollable: false,
                                  child: SizedBox(
                                    // Half the window, kept between a readable
                                    // minimum and a sheet that leaves the page
                                    // in view.
                                    height: (MediaQuery.sizeOf(context).height * 0.5).clamp(240.0, 480.0),
                                    child: const MusicLyricsPanel(),
                                  ),
                                ),
                              ),
                            ),
                            icon: const DsIcon(DsIcons.captions),
                          ),
                          // The tier the song plays at, and the way to change
                          // it without leaving the bar for the settings.
                          const MusicQualityPill(),
                          favouriteButton(),
                          DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            semanticLabel: state.muted ? t.room.unmute : t.room.mute,
                            onPressed: () => unawaited(controller.setMuted(muted: !state.muted)),
                            icon: DsIcon(state.muted ? DsIcons.volumeOff : DsIcons.volume),
                          ),
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
                        ],
                      ),
                    ],
                    // The reference's queue opens over the page, so the
                    // viewer keeps their place while reordering.
                    DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: t.music.queueTitle,
                      onPressed: () => unawaited(
                        showDsPanel<void>(
                          context: context,
                          builder: (context) => DsPanel(
                            title: Text(context.t.music.queueTitle),
                            scrollable: false,
                            child: const MusicQueuePanel(),
                          ),
                        ),
                      ),
                      icon: const DsIcon(DsIcons.listMusic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

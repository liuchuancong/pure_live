import 'dart:async' show StreamSubscription, unawaited;
import 'dart:typed_data' show Float32List;
import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:media_core_mpv_audio/media_core_mpv_audio.dart' show FftFrame;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment, musicCommentsProvider;
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_lyric_overrides.dart' show musicLyricOverridesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart'
    show MusicLyricAlignment, MusicSettings, musicSettingsProvider;
import 'package:pure_live/modules/music/controller/music_ui_settings.dart'
    show MusicPlayerMode, MusicUiElement, musicPlayerModeProvider, musicUiSettingsProvider;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_lyric_panel.dart';
import 'package:pure_live/modules/music/widgets/music_quality_pill.dart';
import 'package:pure_live/modules/music/widgets/music_queue_panel.dart' show MusicQueuePanel;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow, cachedImage;

/// The module's player page: the song at listening size, its transport, and
/// the queue behind it — the reference's PlayDetail, with the module's own
/// artwork and controls rather than the video players'.
final class MusicPlayerPage extends ConsumerStatefulWidget {
  /// The player page.
  const MusicPlayerPage({super.key});

  @override
  ConsumerState<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

final class _MusicPlayerPageState extends ConsumerState<MusicPlayerPage> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final ui = ref.watch(musicUiSettingsProvider);
    final track = state.track;
    // The bar hides while this page is up, so the failure toast needs this
    // page's own ear; the shared key keeps the two from double-speaking.
    listenPlaybackErrors(context, ref);
    return CallbackShortcuts(
      bindings: <SingleActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): () => unawaited(controller.toggle()),
        const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.canvas),
            // The song's own cover, blown up and blurred into a backdrop, so
            // the page takes its colour from what is playing; the scrim keeps
            // every word on it readable.
            if (track?.coverUri case final cover?)
              if (ui.shows(MusicUiElement.blurredBackdrop))
                Positioned.fill(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Transform.scale(
                        scale: 1.5,
                        child: Image(image: cachedImage(cover.toString()), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topCenter,
                    end: AlignmentDirectional.bottomCenter,
                    colors: [colors.canvas.withValues(alpha: 0.92), colors.canvas.withValues(alpha: 0.76)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: track == null
                  ? Center(
                      child: DsEmptyState(
                        icon: const DsIcon(DsIcons.music),
                        title: Text(t.music.searchIdleTitle),
                        description: Text(t.music.searchIdleDescription),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 920;
                        // A phone has no room for a stage and a panel side by
                        // side or stacked half each: the song leads, and the
                        // lyrics / queue / comments open from the header, the
                        // way the station's own phone player does.
                        // A short window is the same problem as a narrow
                        // one: two half-height panes leave neither side
                        // usable, so height counts as well as width.
                        final phone = constraints.maxWidth < LiveWindow.sheet || constraints.maxHeight < 520;
                        final header = Row(
                          spacing: DsSpace.s8,
                          children: [
                            DsButton.icon(
                              variant: DsButtonVariant.secondary,
                              size: DsSize.sm,
                              semanticLabel: t.common.close,
                              onPressed: () => context.pop(),
                              icon: const DsIcon(DsIcons.chevronLeft),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: DsSpace.s3,
                                children: [
                                  Text(
                                    t.music.nowPlaying,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.title.copyWith(color: colors.text),
                                  ),
                                  if (state.sleepTimerRemaining case final remaining?)
                                    Text(
                                      t.music.sleepRemaining(value: musicDurationText(remaining)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                                    ),
                                ],
                              ),
                            ),
                            if (phone)
                              DsButton.icon(
                                variant: DsButtonVariant.secondary,
                                size: DsSize.sm,
                                semanticLabel: t.music.stagePanels,
                                onPressed: () => _openStagePanels(context),
                                icon: const DsIcon(DsIcons.listMusic),
                              ),
                            const _PlayerMenu(),
                          ],
                        );
                        final body = wide
                            ? const Row(
                                spacing: DsSpace.s24,
                                children: [
                                  Expanded(flex: 5, child: _Stage()),
                                  Expanded(flex: 6, child: _SidePanel()),
                                ],
                              )
                            : phone
                            ? const _Stage()
                            : const Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: DsSpace.s12,
                                children: [
                                  Expanded(child: _Stage()),
                                  Expanded(child: _SidePanel()),
                                ],
                              );
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s8, DsSpace.s12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: DsSpace.s12,
                            children: [
                              header,
                              Expanded(child: body),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone's panel button: lyrics, comments, the queue and recent songs,
/// each a tab of one sheet. The stage keeps the screen and these lists are
/// summoned — the station's own phone player — because half the screen given
/// to a permanently open panel left neither side enough room.
void _openStagePanels(BuildContext context) {
  final t = context.t;
  unawaited(
    showDsPanel<void>(
      context: context,
      builder: (context) => DsPanel(
        title: Text(t.music.stagePanels),
        scrollable: false,
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.6).clamp(320.0, 560.0),
          child: const _SidePanel(),
        ),
      ),
    ),
  );
}

/// The stage: the song at listening size above its seek and transport.
final class _Stage extends ConsumerStatefulWidget {
  const _Stage();

  @override
  ConsumerState<_Stage> createState() => _StageState();
}

final class _StageState extends ConsumerState<_Stage> {
  /// Where the seek slider is while the viewer drags it, in seconds.
  double? _dragSeconds;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final track = state.track!;
    final duration = state.duration;
    final playerMode = ref.watch(musicPlayerModeProvider);
    final position = _dragSeconds != null ? Duration(milliseconds: (_dragSeconds! * 1000).round()) : state.position;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxHeight >= 560 ? 320 : 216).toDouble();
        final disc = playerMode == MusicPlayerMode.vinyl && constraints.maxWidth >= 640;
        final words = playerMode == MusicPlayerMode.lyrics;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s16,
            children: [
              if (words)
                SizedBox(height: size, child: const MusicLyricsPanel())
              else
                Center(
                  child: disc
                      ? SizedBox(
                          width: size * 1.32,
                          height: size,
                          child: Stack(
                            alignment: AlignmentDirectional.centerStart,
                            clipBehavior: Clip.none,
                            children: [
                              // The record is the stage in this mode — the
                              // sleeve gives way to the disc, its own cover
                              // pressed into the label — and the arm rests on
                              // it, the reference's turntable.
                              PositionedDirectional(
                                start: 0,
                                top: 0,
                                child: _VinylDisc(size: size * 0.92, track: track, playing: state.playing),
                              ),
                              PositionedDirectional(
                                start: size * 0.62,
                                top: -size * 0.02,
                                child: _Tonearm(size: size),
                              ),
                            ],
                          ),
                        )
                      : DecoratedBox(
                          decoration: DsBoxDecoration(
                            borderRadius: BorderRadius.circular(theme.radii.overlay),
                            shadows: [
                              DsShadow(color: colors.overlay, blur: DsSpace.s40, offset: const Offset(0, DsSpace.s16)),
                            ],
                          ),
                          child: _Artwork(track: track, size: size),
                        ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s4,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.typography.heading.copyWith(color: colors.text),
                  ),
                  if (track.artist.isNotEmpty)
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.typography.body.copyWith(color: colors.textMuted),
                    ),
                  if (track.album.isNotEmpty)
                    Text(
                      '${t.music.songDetailAlbum} · ${track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                ],
              ),
              // The reference stage's pill row: the song's own verbs —
              // collecting, saving and reading the comments — sit beside its
              // name, leaving the transport to movement alone.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: DsSpace.s8,
                children: [
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: favourites.contains(track) ? t.music.unfavourite : t.music.favourite,
                    onPressed: () => unawaited(favouriteController.toggle(track)),
                    icon: DsIcon(DsIcons.heart, size: 16, color: favourites.contains(track) ? colors.accent : null),
                  ),
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: t.music.download,
                    onPressed: () => unawaited(downloadTrackWithToast(context, ref, track)),
                    icon: const DsIcon(DsIcons.download, size: 16),
                  ),
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: t.music.comments,
                    onPressed: () => unawaited(
                      showDsDialog<void>(
                        context: context,
                        builder: (context) => _CommentsDialog(track: track),
                      ),
                    ),
                    icon: const DsIcon(DsIcons.messageCircle, size: 16),
                  ),
                  // The song's own tier rides with its verbs: the listener can
                  // see what is playing and ask for another without leaving
                  // the stage.
                  const MusicQualityPill(),
                ],
              ),
              // The engine's own FFT taps, drawn live: nothing until the
              // first frames arrive, so a backend without taps leaves the
              // stage exactly as it was.
              const _Spectrum(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s4,
                children: [
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          musicDurationText(position),
                          style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                        ),
                      ),
                      Expanded(
                        child: DsSlider(
                          value: duration.inMilliseconds <= 0
                              ? 0
                              : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                          max: duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds.toDouble(),
                          semanticLabel: t.music.progress,
                          onChanged: duration.inMilliseconds <= 0
                              ? null
                              : (value) => setState(() => _dragSeconds = value / 1000),
                          onChangeEnd: duration.inMilliseconds <= 0
                              ? null
                              : (value) {
                                  setState(() => _dragSeconds = null);
                                  unawaited(controller.seek(Duration(milliseconds: value.round())));
                                },
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          musicDurationText(duration),
                          textAlign: TextAlign.end,
                          style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: DsSpace.s12,
                    children: [
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.lg,
                        semanticLabel: musicPlayModeLabel(t, state.mode),
                        onPressed: controller.cycleMode,
                        icon: DsIcon(musicPlayModeIcon(state.mode)),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.lg,
                        semanticLabel: t.music.previous,
                        onPressed: () => unawaited(controller.previous()),
                        icon: const DsIcon(DsIcons.skipBack),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.primary,
                        size: DsSize.lg,
                        semanticLabel: state.playing ? t.music.pause : t.music.play,
                        onPressed: () => unawaited(controller.toggle()),
                        icon: DsIcon(state.playing ? DsIcons.pause : DsIcons.play),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.lg,
                        semanticLabel: t.music.next,
                        onPressed: () => unawaited(controller.next()),
                        icon: const DsIcon(DsIcons.skipForward),
                      ),
                    ],
                  ),
                ],
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _Volume(
                    volume: state.volume,
                    muted: state.muted,
                    onVolume: (value) => unawaited(controller.setVolume(value)),
                    onMute: () => unawaited(controller.setMuted(muted: !state.muted)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The live spectrum strip: the mpv_audio engine's smoothed log-spaced
/// bands, one bar each. It appears only when the engine is actually
/// tapping the audio — the honest reading of a null stream is silence,
/// not a faked animation.
final class _Spectrum extends ConsumerStatefulWidget {
  const _Spectrum();

  @override
  ConsumerState<_Spectrum> createState() => _SpectrumState();
}

final class _SpectrumState extends ConsumerState<_Spectrum> {
  Float32List? _bands;
  StreamSubscription<FftFrame>? _subscription;

  @override
  void dispose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(musicUiSettingsProvider).shows(MusicUiElement.spectrum)) return const SizedBox.shrink();
    // Watching the player state re-runs this when the engine comes to be
    // (the first track) or is replaced, which is exactly when the tap
    // stream appears and the subscription has to be made anew.
    final player = ref.watch(musicPlayerProvider);
    final spectrum = ref.read(musicPlayerProvider.notifier).spectrum;
    if (spectrum != null && _subscription == null) {
      _subscription = spectrum.listen(
        (frame) {
          if (mounted) setState(() => _bands = frame.bands);
        },
        onDone: () => _subscription = null,
        onError: (Object _) => _subscription = null,
      );
    }
    final bands = _bands;
    // A paused or failed engine stops sending frames, and the strip would
    // freeze on its last frame — a picture of sound that is not sounding.
    // Only a playing engine earns the bars.
    if (!player.playing || bands == null || bands.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: _SpectrumPainter(bands: bands, color: DsTheme.colorsOf(context).accent),
      ),
    );
  }
}

/// One bar per band, bottom-aligned, rounded caps — the reference
/// visualizer's shape in this theme's dialect.
final class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter({required this.bands, required this.color});

  final Float32List bands;

  /// The bars' colour, the theme's accent from the tree that painted us.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    final count = bands.length;
    final gap = size.width / (count * 4);
    final barWidth = (size.width - gap * (count + 1)) / count;
    for (var i = 0; i < count; i++) {
      final height = (bands[i].clamp(0.0, 1.0)) * size.height;
      if (height < 0.5) continue;
      final left = gap + i * (barWidth + gap);
      canvas.drawLine(
        Offset(left + barWidth / 2, size.height),
        Offset(left + barWidth / 2, size.height - height),
        paint..strokeWidth = barWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) => true;
}

/// The panel beside the stage: lyrics and the queue behind one pair of
/// tabs, so neither pushes the other off the page.
final class _SidePanel extends ConsumerStatefulWidget {
  const _SidePanel();

  @override
  ConsumerState<_SidePanel> createState() => _SidePanelState();
}

final class _SidePanelState extends ConsumerState<_SidePanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Center(
          child: DsTabs<int>(
            value: _tab,
            onChanged: (value) => setState(() => _tab = value),
            tabs: [
              DsTab<int>(value: 0, label: Text(t.music.lyrics)),
              DsTab<int>(value: 1, label: Text(t.music.comments)),
              DsTab<int>(value: 2, label: Text(t.music.queueTitle)),
              DsTab<int>(value: 3, label: Text(t.music.mineRecent)),
            ],
            semanticLabel: t.music.lyrics,
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => const MusicLyricsPanel(),
            1 => const _CommentsTab(),
            2 => const MusicQueuePanel(),
            _ => const _RecentPanel(),
          },
        ),
      ],
    );
  }
}

/// The current song's comments in the panel; nothing when nothing plays.
final class _CommentsTab extends ConsumerWidget {
  const _CommentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(musicPlayerProvider.select((state) => state.track));
    if (track == null) return const SizedBox.shrink();
    return _CommentsPanel(track: track);
  }
}

/// The songs played lately, alone in the panel — the reference stage's
/// 最近播放 tab, each row stepping back into its own play.
final class _RecentPanel extends ConsumerWidget {
  const _RecentPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final recent = ref.watch(musicRecentProvider);
    final recentController = ref.read(musicRecentProvider.notifier);
    final player = ref.read(musicPlayerProvider.notifier);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    return DsSurface(
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s4, DsSpace.s4),
      child: recent.isEmpty
          ? Center(
              child: DsEmptyState(icon: const DsIcon(DsIcons.clock), title: Text(t.music.recentEmpty)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: DsSpace.s8),
                  child: Row(
                    spacing: DsSpace.s4,
                    children: [
                      Expanded(
                        child: Text(
                          '${t.music.mineRecent} · ${t.music.songsCount(count: recent.length)}',
                          style: theme.typography.caption.copyWith(color: colors.textSubtle),
                        ),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        semanticLabel: t.music.clearRecent,
                        onPressed: () => unawaited(recentController.clear()),
                        icon: const DsIcon(DsIcons.trash2, size: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      DsListSection(
                        children: [
                          for (final (index, song) in recent.indexed)
                            DsListRow(
                              leading: MusicArtwork(track: song),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(
                                  color: song.id == playingId ? colors.accent : colors.text,
                                  fontWeight: song.id == playingId ? FontWeight.w600 : null,
                                ),
                              ),
                              description: song.artist.isEmpty
                                  ? null
                                  : Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: DsSpace.s4,
                                children: [
                                  if (song.id == playingId) DsIcon(DsIcons.audioLines, size: 14, color: colors.accent),
                                  if (song.duration case final length?)
                                    Text(
                                      musicDurationText(length),
                                      style: theme.typography.numeric(
                                        theme.typography.caption.copyWith(color: colors.textSubtle),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () => unawaited(player.playAll(recent, index: index)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// The song's cover at listening size, or the module's mark on a plain tile
/// when the platform gave none.
final class _Artwork extends StatelessWidget {
  const _Artwork({required this.track, required this.size});

  final audio.MusicTrack track;

  /// The square's side; the wide layout affords a larger stage.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final cover = track.coverUri;
    final radius = BorderRadius.circular(theme.radii.overlay);
    if (cover == null) {
      return Container(
        width: size,
        height: size,
        decoration: DsBoxDecoration(color: colors.control, borderRadius: radius),
        child: Center(child: DsIcon(DsIcons.music, size: 64, color: colors.textSubtle)),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: DsImage(image: cachedImage(cover.toString()), width: size, height: size, semanticLabel: track.title),
    );
  }
}

/// The record that is the stage in vinyl mode: a dark disc with groove
/// rings, the song's own cover pressed in as its label and a centre hole.
/// It turns slowly while the song plays and stops where it was left when the
/// song pauses, as the reference's turntable does.
final class _VinylDisc extends StatefulWidget {
  const _VinylDisc({required this.size, required this.track, required this.playing});

  /// The disc's diameter.
  final double size;

  /// The song on air; its cover is the label.
  final audio.MusicTrack track;

  /// Whether the record should be turning.
  final bool playing;

  @override
  State<_VinylDisc> createState() => _VinylDiscState();
}

final class _VinylDiscState extends State<_VinylDisc> with SingleTickerProviderStateMixin {
  /// One turn, slow enough to read as a record rather than a spinner.
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _spin.repeat();
  }

  @override
  void didUpdateWidget(_VinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.playing && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final size = widget.size;
    final label = size * 0.42;
    final groove = size * 0.86;
    final cover = widget.track.coverUri;
    return SizedBox(
      width: size,
      height: size,
      child: RotationTransition(
        turns: _spin,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.control,
            border: Border.all(color: colors.border),
            boxShadow: [BoxShadow(color: colors.overlay, blurRadius: DsSpace.s24, offset: const Offset(0, DsSpace.s8))],
          ),
          child: Center(
            child: Container(
              width: groove,
              height: groove,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.border.withValues(alpha: 0.55)),
              ),
              child: Center(
                child: ClipOval(
                  child: SizedBox(
                    width: label,
                    height: label,
                    child: cover == null
                        ? ColoredBox(
                            color: colors.surface,
                            child: Center(
                              child: DsIcon(DsIcons.music, size: label * 0.5, color: colors.textSubtle),
                            ),
                          )
                        : DsImage(
                            image: cachedImage(cover.toString()),
                            width: label,
                            height: label,
                            semanticLabel: widget.track.title,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tonearm resting on the record: a pivot at the top, the arm reaching
/// down onto the disc and the cartridge at its end.
final class _Tonearm extends StatelessWidget {
  const _Tonearm({required this.size});

  /// The disc's side; the arm is drawn in proportion to it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      width: size * 0.5,
      height: size * 0.78,
      child: CustomPaint(painter: _TonearmPainter(colors: colors)),
    );
  }
}

final class _TonearmPainter extends CustomPainter {
  const _TonearmPainter({required this.colors});

  final DsColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.74, size.height * 0.10);
    final needle = Offset(size.width * 0.30, size.height * 0.80);
    final arm = Paint()
      ..color = colors.textMuted
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // A slight elbow, so the arm reads as a mechanism rather than a stick.
    final elbow = Offset(size.width * 0.66, size.height * 0.52);
    canvas
      ..drawLine(pivot, elbow, arm)
      ..drawLine(elbow, needle, arm);
    // The cartridge: a short bar across the needle's end.
    final cartridge = Paint()
      ..color = colors.text
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(needle, needle.translate(size.width * 0.10, -size.height * 0.06), cartridge);
    // The pivot base, ring and cap.
    final base = Paint()..color = colors.control;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colors.border;
    final cap = Paint()..color = colors.textSubtle;
    canvas
      ..drawCircle(pivot, 13, base)
      ..drawCircle(pivot, 13, ring)
      ..drawCircle(pivot, 5, cap);
  }

  @override
  bool shouldRepaint(_TonearmPainter oldDelegate) => oldDelegate.colors != colors;
}

/// The player's more menu: the reference's runtime verbs — rate, sleep timer,
/// lyric delay and secondary tracks, desktop lyrics, download and playlists.
final class _PlayerMenu extends ConsumerStatefulWidget {
  const _PlayerMenu();

  @override
  ConsumerState<_PlayerMenu> createState() => _PlayerMenuState();
}

final class _PlayerMenuState extends ConsumerState<_PlayerMenu> {
  static const List<double> _rates = [0.5, 0.75, 1, 1.25, 1.5, 2];
  static const List<int> _offsets = [-2000, -1500, -1000, -500, 0, 500, 1000, 1500, 2000];
  static const List<int> _sleepMinutes = [15, 30, 45, 60, 90];

  String _rateLabel(double rate) => '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)}x';
  String _offsetLabel(Translations t, int ms) {
    if (ms == 0) return t.music.lyricOffsetReset;
    final seconds = (ms / 1000).toStringAsFixed(1);
    return ms > 0 ? '+${seconds}s' : '${seconds}s';
  }

  /// Moves the lyric delay by [delta] milliseconds, the reference's ±10/±100.
  Future<void> _nudgeOffset(int delta) => ref
      .read(musicPlayerProvider.notifier)
      .setLyricOffset(Duration(milliseconds: ref.read(musicSettingsProvider).lyricOffsetMs + delta));

  /// Steps the lyric size by [delta] points, or back to the default for null.
  Future<void> _setFontScale(int? delta) {
    final controller = ref.read(musicSettingsProvider.notifier);
    final current = ref.read(musicSettingsProvider).lyricFontScale;
    return controller.setLyricFontScale(delta == null ? MusicSettings.standard.lyricFontScale : current + delta);
  }

  Future<void> _exportLyric(audio.MusicTrack track) async {
    final t = context.t;
    try {
      final document = await ref.read(musicPlayerProvider.notifier).loadLyric(force: true);
      if (document.isEmpty) {
        if (mounted) {
          showDsToast(context: context, title: t.music.lyricsEmpty, status: DsStatus.warning);
        }
        return;
      }
      final settings = ref.read(musicSettingsProvider);
      final text = const audio.LyricExporter().build(
        document,
        options: audio.LyricExportOptions(
          includeTranslation: settings.showTranslation,
          includeRomanization: settings.showRomanization,
        ),
      );
      final name = audio.MusicDownloadRequest.sanitizeFileName(
        [track.artist, track.title].where((part) => part.isNotEmpty).join(' - '),
      );
      final directory = ref.read(appPathsProvider).lyrics.path;
      final path = await const audio.LyricFileWriter().write(
        p.join(directory, '${name.isEmpty ? track.id : name}.lrc'),
        text,
      );
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.exportLyricDone(path: path),
          status: DsStatus.success,
        );
      }
    } on Object catch (failure) {
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.exportLyricFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }

  /// Points the current song at a lyric file the viewer picked.
  Future<void> _associateLyric(audio.MusicTrack track) async {
    final t = context.t;
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: t.music.associateLyric,
        type: FileType.custom,
        allowedExtensions: const ['lrc', 'txt'],
      );
      final path = file?.path;
      if (!mounted || path == null) return;
      final ok = await ref.read(musicPlayerProvider.notifier).associateLyricFile(track, path);
      if (!mounted) return;
      showDsToast(
        context: context,
        title: ok ? t.music.associateLyricDone : t.music.associateLyricFailed,
        status: ok ? DsStatus.success : DsStatus.danger,
      );
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.music.associateLyricFailed, status: DsStatus.danger);
      }
    }
  }

  /// Searches the source for another recording and takes its lyric.
  Future<void> _searchLyric(audio.MusicTrack track) async {
    final t = context.t;
    final candidate = await showDsDialog<audio.MusicTrack>(
      context: context,
      builder: (context) => _LyricSearchDialog(track: track),
    );
    if (candidate == null || !mounted) return;
    final ok = await ref.read(musicPlayerProvider.notifier).useLyricFrom(track, candidate);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: ok ? t.music.lyricSearchApplied(title: candidate.title) : t.music.lyricSearchNoLyric,
      status: ok ? DsStatus.success : DsStatus.warning,
    );
  }

  /// Opens the song's comments — the reference's 评论.
  Future<void> _showComments(audio.MusicTrack track) => showDsDialog<void>(
    context: context,
    builder: (context) => _CommentsDialog(track: track),
  );

  Future<void> _toggleDesktopLyrics() async {
    final t = context.t;
    final wasVisible = ref.read(musicSettingsProvider).desktopLyrics;
    final visible = await ref.read(musicPlayerProvider.notifier).toggleDesktopLyric();
    if (!mounted) return;
    showDsToast(
      context: context,
      title: visible
          ? t.music.desktopLyricsOn
          : wasVisible
          ? t.music.desktopLyricsOff
          : t.music.desktopLyricsUnavailable,
      status: visible || wasVisible ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(musicPlayerProvider);
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.track;
    final sleepRemaining = state.sleepTimerRemaining;
    final hasLyricOverride = track != null && ref.watch(musicLyricOverridesProvider).containsKey(musicTrackKey(track));
    return DsMenuAnchor(
      semanticLabel: t.music.moreActions,
      items: [
        if (track != null) ...[
          DsMenuItem(
            leading: const DsIcon(DsIcons.download),
            label: Text(t.music.download),
            onPressed: () => unawaited(downloadTrackWithToast(context, ref, track)),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.listMusic),
            label: Text(t.music.addToPlaylist),
            onPressed: () => unawaited(showAddToPlaylistDialog(context, ref, track)),
          ),
          if (!track.isLocal)
            DsMenuItem(
              leading: const DsIcon(DsIcons.messageCircle),
              label: Text(t.music.comments),
              onPressed: () => unawaited(_showComments(track)),
            ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.fileText),
            label: Text(t.music.exportLyric),
            onPressed: () => unawaited(_exportLyric(track)),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.fileMusic),
            label: Text(t.music.associateLyric),
            onPressed: () => unawaited(_associateLyric(track)),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.search),
            label: Text(t.music.lyricSearch),
            onPressed: () => unawaited(_searchLyric(track)),
          ),
          if (hasLyricOverride)
            DsMenuItem(
              leading: const DsIcon(DsIcons.x),
              label: Text(t.music.lyricOverrideRemove),
              onPressed: () => unawaited(controller.clearLyricOverride(track)),
            ),
          const DsMenuDivider(),
        ],
        DsMenuItem.submenu(
          leading: const DsIcon(DsIcons.timer),
          label: Text('${t.music.playbackRate} · ${_rateLabel(state.rate)}'),
          submenu: [
            for (final rate in _rates)
              DsMenuItem(
                label: Text(_rateLabel(rate)),
                checked: (state.rate - rate).abs() < 0.001,
                onPressed: () => unawaited(controller.setRate(rate)),
              ),
            const DsMenuDivider(),
            DsMenuItem(
              label: Text(t.music.preservesPitch),
              checked: settings.preservesPitch,
              onPressed: () => unawaited(
                ref.read(musicSettingsProvider.notifier).setPreservesPitch(value: !settings.preservesPitch),
              ),
            ),
          ],
        ),
        DsMenuItem.submenu(
          leading: const DsIcon(DsIcons.clock),
          label: Text(
            state.pauseAfterCurrentTrack
                ? '${t.music.sleepTimer} · ${t.music.sleepAfterCurrent}'
                : sleepRemaining == null
                ? t.music.sleepTimer
                : '${t.music.sleepTimer} · ${musicDurationText(sleepRemaining)}',
          ),
          submenu: [
            DsMenuItem(
              label: Text(t.music.sleepOff),
              checked: sleepRemaining == null && !state.pauseAfterCurrentTrack,
              onPressed: () => controller.setSleepTimer(null),
            ),
            for (final minutes in _sleepMinutes)
              DsMenuItem(
                label: Text(t.music.sleepMinutes(count: minutes)),
                onPressed: () => controller.setSleepTimer(Duration(minutes: minutes)),
              ),
            DsMenuItem(
              label: Text(t.music.sleepAfterCurrent),
              checked: state.pauseAfterCurrentTrack,
              onPressed: () => controller.setPauseAfterCurrentTrack(enabled: !state.pauseAfterCurrentTrack),
            ),
          ],
        ),
        DsMenuItem.submenu(
          leading: const DsIcon(DsIcons.hourglass),
          label: Text('${t.music.lyricOffset} · ${_offsetLabel(t, settings.lyricOffsetMs)}'),
          submenu: [
            for (final offset in _offsets)
              DsMenuItem(
                label: Text(_offsetLabel(t, offset)),
                checked: offset == settings.lyricOffsetMs,
                onPressed: () => unawaited(controller.setLyricOffset(Duration(milliseconds: offset))),
              ),
            const DsMenuDivider(),
            DsMenuItem(label: const Text('- 100ms'), onPressed: () => unawaited(_nudgeOffset(-100))),
            DsMenuItem(label: const Text('+ 100ms'), onPressed: () => unawaited(_nudgeOffset(100))),
            DsMenuItem(label: const Text('- 10ms'), onPressed: () => unawaited(_nudgeOffset(-10))),
            DsMenuItem(label: const Text('+ 10ms'), onPressed: () => unawaited(_nudgeOffset(10))),
          ],
        ),
        DsMenuItem.submenu(
          leading: const DsIcon(DsIcons.fontSize),
          label: Text('${t.music.lyricFontScale} · ${settings.lyricFontScale}%'),
          submenu: [
            DsMenuItem(
              label: Text(t.music.lyricFontSmaller),
              onPressed: settings.lyricFontScale <= 100 ? null : () => unawaited(_setFontScale(-10)),
            ),
            DsMenuItem(
              label: Text(t.music.lyricFontLarger),
              onPressed: settings.lyricFontScale >= 200 ? null : () => unawaited(_setFontScale(10)),
            ),
            DsMenuItem(label: Text(t.music.lyricFontReset), onPressed: () => unawaited(_setFontScale(null))),
          ],
        ),
        DsMenuItem.submenu(
          leading: const DsIcon(DsIcons.alignLeft),
          label: Text('${t.music.lyricAlignment} · ${settings.lyricAlignment.label(t)}'),
          submenu: [
            for (final alignment in MusicLyricAlignment.values)
              DsMenuItem(
                label: Text(alignment.label(t)),
                checked: settings.lyricAlignment == alignment,
                onPressed: () => unawaited(ref.read(musicSettingsProvider.notifier).setLyricAlignment(alignment)),
              ),
          ],
        ),
        const DsMenuDivider(),
        DsMenuItem(
          leading: const DsIcon(DsIcons.captions),
          label: Text(t.music.lyricTranslation),
          checked: settings.showTranslation,
          checkRole: DsMenuCheckRole.checkbox,
          onPressed: () =>
              unawaited(ref.read(musicSettingsProvider.notifier).setShowTranslation(value: !settings.showTranslation)),
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.captions),
          label: Text(t.music.lyricRomanization),
          checked: settings.showRomanization,
          checkRole: DsMenuCheckRole.checkbox,
          onPressed: () => unawaited(
            ref.read(musicSettingsProvider.notifier).setShowRomanization(value: !settings.showRomanization),
          ),
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.arrowUpDown),
          label: Text(t.music.lyricSwapSecondary),
          checked: settings.swapLyricSecondary,
          checkRole: DsMenuCheckRole.checkbox,
          onPressed: () => unawaited(
            ref.read(musicSettingsProvider.notifier).setSwapLyricSecondary(value: !settings.swapLyricSecondary),
          ),
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.monitor),
          label: Text(t.music.desktopLyrics),
          checked: settings.desktopLyrics,
          checkRole: DsMenuCheckRole.checkbox,
          onPressed: () => unawaited(_toggleDesktopLyrics()),
        ),
        if (settings.desktopLyrics)
          DsMenuItem(
            leading: const DsIcon(DsIcons.lock),
            label: Text(t.music.desktopLyricLock),
            checked: settings.desktopLyricLocked,
            checkRole: DsMenuCheckRole.checkbox,
            onPressed: () => unawaited(controller.setDesktopLyricLocked(locked: !settings.desktopLyricLocked)),
          ),
        if (state.queueLength > 0) ...[
          const DsMenuDivider(),
          DsMenuItem(
            leading: const DsIcon(DsIcons.trash2),
            label: Text(t.music.clearQueue),
            destructive: true,
            onPressed: () async {
              // The same ask the queue panel makes: an emptied queue cannot
              // be brought back.
              final confirmed = await showDsConfirm(
                context: context,
                title: t.music.clearQueueConfirmTitle,
                description: t.music.clearQueueConfirmBody,
                confirmLabel: t.music.clearQueue,
                cancelLabel: t.common.cancel,
                destructive: true,
                icon: const DsIcon(DsIcons.trash2),
              );
              if (!confirmed || !context.mounted) return;
              unawaited(controller.clearQueue());
            },
          ),
        ],
      ],
      builder: (context, controller, _) => DsButton.icon(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        semanticLabel: t.music.moreActions,
        onPressed: controller.toggle,
        icon: const DsIcon(DsIcons.ellipsisVertical),
      ),
    );
  }
}

/// The lyric search dialog: a keyword, the source's matches, and the one the
/// viewer picks — lx-music's way of fixing a song whose lyric came from the
/// wrong recording.
final class _LyricSearchDialog extends ConsumerStatefulWidget {
  const _LyricSearchDialog({required this.track});

  final audio.MusicTrack track;

  @override
  ConsumerState<_LyricSearchDialog> createState() => _LyricSearchDialogState();
}

final class _LyricSearchDialogState extends ConsumerState<_LyricSearchDialog> {
  late final TextEditingController _field = TextEditingController(
    text: [widget.track.artist, widget.track.title].where((part) => part.isNotEmpty).join(' '),
  );
  List<audio.MusicTrack>? _results;
  String? _failure;
  bool _searching = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _field.text.trim();
    if (query.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _failure = null;
    });
    try {
      final results = await ref.read(musicPlayerProvider.notifier).searchLyricCandidates(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on Object catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = '$failure';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final results = _results;
    return DsDialog(
      title: Text(t.music.lyricSearch),
      icon: const DsIcon(DsIcons.search),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.music.lyricSearchFor(title: widget.track.title)),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsTextField(
                  controller: _field,
                  autofocus: true,
                  clearable: true,
                  placeholder: t.music.lyricSearchHint,
                  semanticLabel: t.music.lyricSearch,
                  onSubmitted: (_) => unawaited(_search()),
                ),
              ),
              DsButton(
                onPressed: _searching ? null : () => unawaited(_search()),
                child: Text(t.music.lyricSearchAction),
              ),
            ],
          ),
          SizedBox(
            height: 280,
            child: _searching
                ? const Center(child: DsSpinner())
                : _failure != null
                ? Center(
                    child: Text(
                      t.music.lyricSearchFailed(error: _failure!),
                      textAlign: TextAlign.center,
                      style: theme.typography.caption.copyWith(color: colors.danger.text),
                    ),
                  )
                : results == null
                ? Center(
                    child: Text(
                      t.music.lyricSearchHint,
                      textAlign: TextAlign.center,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  )
                : results.isEmpty
                ? Center(
                    child: Text(
                      t.music.lyricSearchEmpty,
                      textAlign: TextAlign.center,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  )
                : ListView(
                    children: [
                      DsListSection(
                        children: [
                          for (final song in results)
                            DsListRow(
                              leading: const DsIcon(DsIcons.fileMusic),
                              title: Text(song.title),
                              description: Text(
                                [song.artist, song.album].where((part) => part.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              showChevron: true,
                              onPressed: () => Navigator.of(context).pop(song),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
      ],
    );
  }
}

/// One song's comments, inside the player's side panel: the hot tab first,
/// then the newest, with the paging the reference offers. The panel fills
/// whatever room it is given; the dialog wraps it at a fixed height.
final class _CommentsPanel extends ConsumerStatefulWidget {
  const _CommentsPanel({required this.track});

  final audio.MusicTrack track;

  @override
  ConsumerState<_CommentsPanel> createState() => _CommentsPanelState();
}

final class _CommentsPanelState extends ConsumerState<_CommentsPanel> {
  bool _hot = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: _hot));
    });
  }

  @override
  void didUpdateWidget(_CommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another song on air means another comment thread.
    if (oldWidget.track.id != widget.track.id || oldWidget.track.sourceId != widget.track.sourceId) {
      unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: _hot));
    }
  }

  void _selectTab(bool hot) {
    if (_hot == hot) return;
    setState(() => _hot = hot);
    unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: hot));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicCommentsProvider);
    final comments = state.comments;
    final controller = ref.read(musicCommentsProvider.notifier);
    final hasTail = state.hasMore || state.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          children: [
            DsSegmentedControl<bool>(
              value: _hot,
              onChanged: _selectTab,
              segments: [
                DsSegment(value: true, label: Text(t.music.commentsHot)),
                DsSegment(value: false, label: Text(t.music.commentsNew)),
              ],
            ),
            const Spacer(),
            if (comments.isNotEmpty)
              Text(
                t.music.commentsCount(count: comments.length),
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
          ],
        ),
        Expanded(
          child: state.loading && comments.isEmpty
              ? const Center(child: DsSpinner())
              : state.error != null && comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s8,
                    children: [
                      Text(
                        t.music.commentsFailed(error: state.error!),
                        textAlign: TextAlign.center,
                        style: theme.typography.caption.copyWith(color: colors.danger.text),
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () => unawaited(controller.retry()),
                        child: Text(t.common.retry),
                      ),
                    ],
                  ),
                )
              : comments.isEmpty
              ? Center(
                  child: Text(t.music.commentsEmpty, style: theme.typography.body.copyWith(color: colors.textMuted)),
                )
              : ListView.builder(
                  itemCount: comments.length + (hasTail ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < comments.length) return _CommentTile(comment: comments[index]);
                    if (state.loading) {
                      return const Padding(
                        padding: EdgeInsets.all(DsSpace.s12),
                        child: Center(child: DsSpinner()),
                      );
                    }
                    if (state.error != null) {
                      return Padding(
                        padding: const EdgeInsets.all(DsSpace.s12),
                        child: Center(
                          child: DsButton(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            onPressed: () => unawaited(controller.retry()),
                            child: Text(t.common.retry),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(DsSpace.s12),
                      child: Center(
                        child: DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          onPressed: () => unawaited(controller.loadMore()),
                          child: Text(t.music.loadMore),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// The same thread in a dialog, from the stage's 评论 pill.
final class _CommentsDialog extends StatelessWidget {
  const _CommentsDialog({required this.track});

  final audio.MusicTrack track;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.music.comments),
      icon: const DsIcon(DsIcons.messageCircle),
      description: SizedBox(height: 360, child: _CommentsPanel(track: track)),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }
}

/// A comment's moment, in the local wall clock.
String _commentTime(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// One comment row inside [_CommentsPanel].
final class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final MusicComment comment;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final avatar = comment.avatar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s8, horizontal: DsSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          DsAvatar(
            initials: comment.userName,
            image: avatar == null ? null : cachedImage(avatar),
            size: DsSize.md,
            semanticLabel: comment.userName,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                      ),
                    ),
                    if (comment.likedCount > 0) ...[
                      DsIcon(DsIcons.heart, size: 12, color: colors.textSubtle),
                      Text('${comment.likedCount}', style: theme.typography.caption.copyWith(color: colors.textSubtle)),
                    ],
                  ],
                ),
                Text(
                  comment.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.text),
                ),
                if (comment.replies.isNotEmpty)
                  Text(
                    t.music.commentsReplies(count: comment.replies.length),
                    style: theme.typography.caption.copyWith(color: colors.accent),
                  ),
                if (comment.time != null)
                  Text(_commentTime(comment.time), style: theme.typography.caption.copyWith(color: colors.textSubtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The output row: mute and a volume slider.
final class _Volume extends StatelessWidget {
  const _Volume({required this.volume, required this.muted, required this.onVolume, required this.onMute});

  final double volume;
  final bool muted;
  final ValueChanged<double> onVolume;
  final VoidCallback onMute;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      spacing: DsSpace.s8,
      children: [
        DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          semanticLabel: muted ? t.room.unmute : t.room.mute,
          onPressed: onMute,
          icon: DsIcon(muted ? DsIcons.volumeOff : DsIcons.volume),
        ),
        Expanded(
          child: DsSlider(value: muted ? 0 : volume, onChanged: onVolume, semanticLabel: t.music.volume),
        ),
      ],
    );
  }
}

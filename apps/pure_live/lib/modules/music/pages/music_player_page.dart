import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/providers/settings/download_directory_provider.dart'
    show DownloadDirectoryPaths, downloadDirectoryProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_comments.dart'
    show MusicComment, musicCommentsProvider;
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_lyric_overrides.dart' show musicLyricOverridesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart'
    show MusicLyricAlignment, MusicSettings, musicSettingsProvider;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show cachedImage;

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
    final track = state.track;
    return CallbackShortcuts(
      bindings: <SingleActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): () => unawaited(controller.toggle()),
        const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: colors.canvas,
          child: SafeArea(
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
                      final header = Row(
                        spacing: DsSpace.s8,
                        children: [
                          DsButton.icon(
                            variant: DsButtonVariant.ghost,
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
                          children: [header, Expanded(child: body)],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
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
    final position = _dragSeconds != null ? Duration(milliseconds: (_dragSeconds! * 1000).round()) : state.position;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxHeight >= 560 ? 300 : 208).toDouble();
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s16,
            children: [
              Center(child: _Artwork(track: track, size: size)),
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
                ],
              ),
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
                          style: theme.typography.numeric(
                            theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
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
                          style: theme.typography.numeric(
                            theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
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
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.lg,
                        semanticLabel: favourites.contains(track) ? t.music.unfavourite : t.music.favourite,
                        onPressed: () => unawaited(favouriteController.toggle(track)),
                        icon: DsIcon(DsIcons.heart, color: favourites.contains(track) ? colors.accent : null),
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
              DsTab<int>(value: 1, label: Text(t.music.queueTitle)),
            ],
            semanticLabel: t.music.lyrics,
          ),
        ),
        Expanded(child: _tab == 0 ? const _Lyrics() : const _QueuePanel()),
      ],
    );
  }
}

/// The play queue, alone in the panel.
final class _QueuePanel extends ConsumerWidget {
  const _QueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final track = state.track;
    if (state.queueLength == 0 || track == null) {
      return DsSurface(
        decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: Center(
          child: DsEmptyState(icon: const DsIcon(DsIcons.listMusic), title: Text(t.music.queueEmpty)),
        ),
      );
    }
    return DsSurface(
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s4, DsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: DsSpace.s8),
            child: Text(
              '${t.music.queueTitle} · ${t.music.songsCount(count: state.queueLength)}',
              style: theme.typography.caption.copyWith(color: colors.textSubtle),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                DsListSection(
                  children: [
                    for (final (index, song) in controller.queue.indexed)
                      MusicSongRow(
                        track: song,
                        playing: song == track,
                        favourite: favourites.contains(song),
                        onPlay: () => unawaited(controller.playAt(index)),
                        onFavourite: () => unawaited(favouriteController.toggle(song)),
                        onRemove: () => unawaited(controller.removeAt(index)),
                        onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                        onDownload: () => unawaited(downloadTrackWithToast(context, ref, song)),
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

/// The lyric panel: the current line highlighted, the panel following the
/// song. Unsynchronized lyrics (plain text from the lookup) scroll freely and
/// never highlight, because there is no position to highlight.
final class _Lyrics extends ConsumerStatefulWidget {
  const _Lyrics();

  @override
  ConsumerState<_Lyrics> createState() => _LyricsState();
}

final class _LyricsState extends ConsumerState<_Lyrics> {
  static const double _baseLineHeight = 46;

  final ScrollController _scroll = ScrollController();
  audio.LyricDocument? _document;
  String? _loadedTrack;
  int _loadedOffset = 0;
  int _loadedRevision = 0;
  int _active = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(String trackId) async {
    final document = await ref.read(musicPlayerProvider.notifier).loadLyric();
    if (!mounted || trackId != _loadedTrack) return;
    setState(() => _document = document);
  }

  /// Keeps the active line in view: the panel's own height, not the whole
  /// page, so the page does not jump every verse.
  void _reveal(int index, double lineHeight) {
    if (!_scroll.hasClients || index < 0) return;
    final target = ((index - 2) * lineHeight).clamp(0.0, _scroll.position.maxScrollExtent);
    if ((_scroll.offset - target).abs() < lineHeight) return;
    _scroll.animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider);
    final settings = ref.watch(musicSettingsProvider);
    final trackId = state.track?.id;
    final offset = state.lyricOffset.inMilliseconds;
    final revision = state.lyricRevision;
    final scale = settings.lyricFontScale / 100;
    final lineHeight = _baseLineHeight * scale;
    final (alignment, crossAlignment, textAlign) = switch (settings.lyricAlignment) {
      MusicLyricAlignment.left => (Alignment.centerLeft, CrossAxisAlignment.start, TextAlign.left),
      MusicLyricAlignment.center => (Alignment.center, CrossAxisAlignment.center, TextAlign.center),
      MusicLyricAlignment.right => (Alignment.centerRight, CrossAxisAlignment.end, TextAlign.right),
    };
    if (trackId != _loadedTrack || offset != _loadedOffset || revision != _loadedRevision) {
      _loadedTrack = trackId;
      _loadedOffset = offset;
      _loadedRevision = revision;
      _document = null;
      _active = -1;
      if (trackId != null) unawaited(_load(trackId));
    }
    final document = _document;
    final lines = document?.lines ?? const <audio.LyricLine>[];
    if (document != null && document.isSynchronized && !document.isEmpty) {
      final active = document.indexAt(state.position);
      if (active != _active) {
        _active = active;
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(active, lineHeight));
      }
    }
    return DsSurface(
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      padding: const EdgeInsets.all(DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          if (settings.lyricProgress && state.duration > Duration.zero)
            DsProgressBar(
              value: (state.position.inMilliseconds / state.duration.inMilliseconds).clamp(0.0, 1.0),
              semanticLabel: t.music.lyricProgress,
            ),
          Expanded(
            child: document == null
                ? const Center(child: DsSpinner())
                : document.isEmpty
                ? Center(
                    child: Text(
                      t.music.lyricsEmpty,
                      textAlign: TextAlign.center,
                      style: theme.typography.body.copyWith(color: colors.textMuted),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemExtent: lineHeight,
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      final current = index == _active;
                      final text = line.text.trim();
                      final secondary = line.secondaryTexts(
                        showTranslation: settings.showTranslation,
                        showRomanization: settings.showRomanization,
                        swap: settings.swapLyricSecondary,
                      );
                      final zoom = settings.lyricZoomActive && current ? 1.1 : 1.0;
                      return Align(
                        alignment: alignment,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: crossAlignment,
                          children: [
                            Text(
                              text.isEmpty ? '♪' : text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: textAlign,
                              style: theme.typography.body.copyWith(
                                fontSize: (theme.typography.body.fontSize ?? 14) * scale * zoom,
                                color: current ? colors.text : colors.textMuted,
                                fontWeight: current ? FontWeight.w600 : null,
                              ),
                            ),
                            if (secondary.isNotEmpty)
                              Text(
                                secondary.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: textAlign,
                                style: theme.typography.caption.copyWith(
                                  fontSize: (theme.typography.caption.fontSize ?? 12) * scale,
                                  color: colors.textSubtle,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
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
      final directory = ref.read(downloadDirectoryProvider).effectivePath;
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
          leading: const DsIcon(DsIcons.gauge),
          label: Text('${t.music.playbackRate} · ${_rateLabel(state.rate)}'),
          submenu: [
            for (final rate in _rates)
              DsMenuItem(
                label: Text(_rateLabel(rate)),
                checked: (state.rate - rate).abs() < 0.001,
                onPressed: () => unawaited(controller.setRate(rate)),
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
          leading: const DsIcon(DsIcons.timer),
          label: Text('${t.music.lyricOffset} · ${_offsetLabel(t, settings.lyricOffsetMs)}'),
          submenu: [
            for (final offset in _offsets)
              DsMenuItem(
                label: Text(_offsetLabel(t, offset)),
                checked: offset == settings.lyricOffsetMs,
                onPressed: () => unawaited(controller.setLyricOffset(Duration(milliseconds: offset))),
              ),
            const DsMenuDivider(),
            DsMenuItem(
              label: const Text('- 100ms'),
              onPressed: () => unawaited(_nudgeOffset(-100)),
            ),
            DsMenuItem(
              label: const Text('+ 100ms'),
              onPressed: () => unawaited(_nudgeOffset(100)),
            ),
            DsMenuItem(
              label: const Text('- 10ms'),
              onPressed: () => unawaited(_nudgeOffset(-10)),
            ),
            DsMenuItem(
              label: const Text('+ 10ms'),
              onPressed: () => unawaited(_nudgeOffset(10)),
            ),
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
                onPressed: () =>
                    unawaited(ref.read(musicSettingsProvider.notifier).setLyricAlignment(alignment)),
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
            onPressed: () => unawaited(controller.clearQueue()),
          ),
        ],
      ],
      builder: (context, controller, _) => DsButton.icon(
        variant: DsButtonVariant.ghost,
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

/// One song's comments: the hot tab first, then the newest, with the same
/// paging the reference offers.
final class _CommentsDialog extends ConsumerStatefulWidget {
  const _CommentsDialog({required this.track});

  final audio.MusicTrack track;

  @override
  ConsumerState<_CommentsDialog> createState() => _CommentsDialogState();
}

final class _CommentsDialogState extends ConsumerState<_CommentsDialog> {
  bool _hot = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: _hot));
    });
  }

  void _selectTab(bool hot) {
    if (_hot == hot) return;
    setState(() => _hot = hot);
    unawaited(ref.read(musicCommentsProvider.notifier).load(widget.track, hot: hot));
  }

  static String _time(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
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
    return DsDialog(
      title: Text(t.music.comments),
      icon: const DsIcon(DsIcons.messageCircle),
      description: Column(
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
          SizedBox(
            height: 360,
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
                    child: Text(
                      t.music.commentsEmpty,
                      style: theme.typography.body.copyWith(color: colors.textMuted),
                    ),
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
      ),
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

/// One comment row inside [_CommentsDialog].
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
                      Text(
                        '${comment.likedCount}',
                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                      ),
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
                  Text(
                    _CommentsDialogState._time(comment.time),
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
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

/// A clock in `mm:ss`, or `h:mm:ss` past an hour — the player's two labels.
String musicDurationText(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '${two(minutes)}:${two(seconds)}';
}

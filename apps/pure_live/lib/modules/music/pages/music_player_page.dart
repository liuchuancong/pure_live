import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
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
  /// Where the seek slider is while the viewer drags it, in seconds.
  double? _dragSeconds;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.track;
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final duration = state.duration;
    final position = _dragSeconds != null ? Duration(milliseconds: (_dragSeconds! * 1000).round()) : state.position;
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
                : Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s8, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DsSpace.s12,
                      children: [
                        Row(
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
                              child: Text(
                                t.music.nowPlaying,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.title.copyWith(color: colors.text),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 640),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  spacing: DsSpace.s20,
                                  children: [
                                    Center(child: _Artwork(track: track)),
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
                                                    : position.inMilliseconds
                                                          .clamp(0, duration.inMilliseconds)
                                                          .toDouble(),
                                                max: duration.inMilliseconds <= 0
                                                    ? 1
                                                    : duration.inMilliseconds.toDouble(),
                                                semanticLabel: t.music.progress,
                                                onChanged: duration.inMilliseconds <= 0
                                                    ? null
                                                    : (value) => setState(() => _dragSeconds = value / 1000),
                                                onChangeEnd: duration.inMilliseconds <= 0
                                                    ? null
                                                    : (value) {
                                                        setState(() => _dragSeconds = null);
                                                        unawaited(
                                                          controller.seek(Duration(milliseconds: value.round())),
                                                        );
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
                                              semanticLabel: favourites.contains(track)
                                                  ? t.music.unfavourite
                                                  : t.music.favourite,
                                              onPressed: () => unawaited(favouriteController.toggle(track)),
                                              icon: DsIcon(
                                                DsIcons.heart,
                                                color: favourites.contains(track) ? colors.accent : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    _Volume(
                                      volume: state.volume,
                                      muted: state.muted,
                                      onVolume: (value) => unawaited(controller.setVolume(value)),
                                      onMute: () => unawaited(controller.setMuted(muted: !state.muted)),
                                    ),
                                    const _Lyrics(),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      spacing: DsSpace.s8,
                                      children: [
                                        Text(
                                          '${t.music.queueTitle} · ${t.music.songsCount(count: state.queueLength)}',
                                          style: theme.typography.caption.copyWith(color: colors.textSubtle),
                                        ),
                                        DsListSection(
                                          children: [
                                            for (final (index, song) in controller.queue.indexed)
                                              MusicSongRow(
                                                track: song,
                                                playing: song == track,
                                                favourite: favourites.contains(song),
                                                onPlay: () => unawaited(controller.playAt(index)),
                                                onFavourite: () => unawaited(favouriteController.toggle(song)),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The song's cover at listening size, or the module's mark on a plain tile
/// when the platform gave none.
final class _Artwork extends StatelessWidget {
  const _Artwork({required this.track});

  final audio.MusicTrack track;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final cover = track.coverUri;
    final radius = BorderRadius.circular(theme.radii.overlay);
    if (cover == null) {
      return Container(
        width: 260,
        height: 260,
        decoration: DsBoxDecoration(color: colors.control, borderRadius: radius),
        child: Center(child: DsIcon(DsIcons.music, size: 64, color: colors.textSubtle)),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: DsImage(image: cachedImage(cover.toString()), width: 260, height: 260, semanticLabel: track.title),
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
  static const double _lineHeight = 32;
  static const double _height = 208;

  final ScrollController _scroll = ScrollController();
  audio.LyricDocument? _document;
  String? _loadedTrack;
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
  void _reveal(int index) {
    if (!_scroll.hasClients || index < 0) return;
    final target = ((index - 2) * _lineHeight).clamp(0.0, _scroll.position.maxScrollExtent);
    if ((_scroll.offset - target).abs() < _lineHeight) return;
    _scroll.animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider);
    final trackId = state.track?.id;
    if (trackId != _loadedTrack) {
      _loadedTrack = trackId;
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(active));
      }
    }
    return DsSurface(
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      padding: const EdgeInsets.all(DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(t.music.lyrics, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          SizedBox(
            height: _height,
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
                    itemExtent: _lineHeight,
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      final current = index == _active;
                      final text = line.text.trim();
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          text.isEmpty ? '♪' : text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.copyWith(
                            color: current ? colors.text : colors.textMuted,
                            fontWeight: current ? FontWeight.w600 : null,
                          ),
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

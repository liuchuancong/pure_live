import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/lyric/music_lyric_settings.dart'
    show MusicLyricAlignment, musicLyricsSettingsProvider;
import 'package:pure_live/modules/music/controller/playback/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/widgets/music_widgets.dart' show musicDurationText;

/// The lyric panel: the current line highlighted, the panel following the
/// song. Unsynchronized lyrics (plain text from the lookup) scroll freely and
/// never highlight, because there is no position to highlight.
///
/// The player's stage and side tab draw it in place; the bar raises it in a
/// panel, so the viewer can read the words without leaving the list they are
/// browsing.
final class MusicLyricsPanel extends ConsumerStatefulWidget {
  const MusicLyricsPanel({super.key, this.transparent = false});

  /// Draws without the panel fill: the player's stage already carries the
  /// blurred cover, and a grey card over it dulled the whole mode.
  final bool transparent;

  @override
  ConsumerState<MusicLyricsPanel> createState() => MusicLyricsPanelState();
}

final class MusicLyricsPanelState extends ConsumerState<MusicLyricsPanel> {
  /// Two text lines fit the slot, so a long verse wraps instead of
  /// vanishing behind an ellipsis.
  static const double _baseLineHeight = 72;

  final ScrollController _scroll = ScrollController();
  audio.LyricDocument? _document;
  String? _loadedTrack;
  int _loadedOffset = 0;
  int _loadedRevision = 0;
  int _active = -1;

  /// The read's refusal, shown with a retry instead of a spinner that would
  /// never settle — the loader completes with an error when the lyric
  /// endpoint refuses.
  String? _failure;

  /// Whether the viewer is scrolling the panel: the follow pauses while they
  /// do — the reference's isPauseScroll — and, with 拖拽歌词调整进度 on, a
  /// scrub line answers instead.
  bool _scrubbing = false;

  /// The line the scrub line points at.
  int _scrubLine = 0;

  /// Whether [_reveal]'s animation is in flight; its notifications look like
  /// the viewer's scrolling otherwise.
  bool _animating = false;

  /// The reference's 3 秒回弹: a panel left alone returns to the song.
  Timer? _resume;

  @override
  void dispose() {
    _resume?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(String trackId) async {
    try {
      final document = await ref.read(musicPlayerProvider.notifier).loadLyric();
      if (!mounted || trackId != _loadedTrack) return;
      setState(() {
        _document = document;
        _failure = null;
      });
    } on Object catch (failure) {
      if (!mounted || trackId != _loadedTrack) return;
      setState(() => _failure = '$failure');
    }
  }

  /// Keeps the active line in view: the panel's own height, not the whole
  /// page, so the page does not jump every verse. The viewer's drag wins
  /// while it lasts.
  void _reveal(int index, double lineHeight) {
    if (_scrubbing || !_scroll.hasClients || index < 0) return;
    final target = ((index - 2) * lineHeight).clamp(0.0, _scroll.position.maxScrollExtent);
    if ((_scroll.offset - target).abs() < lineHeight) return;
    _animating = true;
    unawaited(
      _scroll
          .animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic)
          .whenComplete(() => _animating = false),
    );
  }

  /// The reference's drag: the viewer's scrolling stops the follow, and three
  /// seconds after they stop, the panel returns to the song.
  bool _onScroll(ScrollNotification notification, {required bool synced, required double lineHeight}) {
    if (!synced) return false;
    // The follow's own animations announce themselves like a scroll.
    final drag = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails,
      ScrollUpdateNotification(:final dragDetails) => dragDetails,
      ScrollEndNotification(:final dragDetails) => dragDetails,
      _ => null,
    };
    if (_animating && drag == null) return false;

    switch (notification) {
      case ScrollStartNotification():
        _resume?.cancel();
        if (!_scrubbing) setState(() => _scrubbing = true);
      case ScrollUpdateNotification() when _scrubbing:
        _updateScrubLine(notification.metrics, lineHeight);
      case ScrollEndNotification() when _scrubbing:
        _resume = Timer(const Duration(seconds: 3), () => _resumeFollow(lineHeight));
    }
    return false;
  }

  /// Points the scrub line at the row sitting at 40% of the panel — the
  /// reference's offset math.
  void _updateScrubLine(ScrollMetrics metrics, double lineHeight) {
    final count = _document?.lines.length ?? 0;
    if (count == 0 || lineHeight <= 0) return;
    final target = ((metrics.pixels + metrics.viewportDimension * 0.4) / lineHeight).floor().clamp(0, count - 1);
    if (target != _scrubLine) setState(() => _scrubLine = target);
  }

  /// The reference's 3 秒回弹: the indicator hides and the panel returns to
  /// the song when it is playing; a paused song stays where it was left.
  void _resumeFollow(double lineHeight) {
    if (!mounted) return;
    setState(() => _scrubbing = false);
    if (ref.read(musicPlayerProvider).playing) _reveal(_active, lineHeight);
  }

  /// Jumps to the line the scrub line points at — the reference's PlayLine
  /// button.
  Future<void> _seekToScrubLine() async {
    final lines = _document?.lines;
    if (lines == null || lines.isEmpty) return;
    final start = lines[_scrubLine.clamp(0, lines.length - 1)].start;
    _resume?.cancel();
    setState(() => _scrubbing = false);
    await ref.read(musicPlayerProvider.notifier).seek(start);
  }

  /// Jumps the song to the line the viewer picked. Only synchronized lyrics
  /// carry a start worth seeking to, so their rows are the pressable ones;
  /// a pending drag-scrub is dropped first, so the panel returns to the song
  /// instead of holding the scrub line.
  Future<void> _seekToLine(int index) async {
    final lines = _document?.lines;
    if (lines == null || index < 0 || index >= lines.length) return;
    _resume?.cancel();
    if (_scrubbing) setState(() => _scrubbing = false);
    await ref.read(musicPlayerProvider.notifier).seek(lines[index].start);
  }

  /// The scrub line itself: a rule at 40% of the panel with the pointed
  /// line's time and the verb that jumps there.
  Widget _scrubRule(BuildContext context, DsColors colors, DsThemeData theme, List<audio.LyricLine> lines) {
    final t = context.t;
    final time = musicDurationText(lines[_scrubLine.clamp(0, lines.length - 1)].start);
    return Positioned.fill(
      child: Align(
        alignment: const Alignment(0, -0.2),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: DsSpace.s4),
              child: Text(time, style: theme.typography.caption.copyWith(color: colors.accent)),
            ),
            Expanded(child: Container(height: 1, color: colors.accent)),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.music.lyricScrubPlay,
              onPressed: () => unawaited(_seekToScrubLine()),
              icon: const DsIcon(DsIcons.play, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    // The panel rides the track, the offset and the revision only: those
    // decide what is loaded. The position tick reaches in through the
    // listener below (the singing line) and the singing row's own watch
    // (the sweep), so the column rebuilds once per song, not once per tick.
    final (trackId, offset, revision) = ref.watch(
      musicPlayerProvider.select((state) => (state.track?.id, state.lyricOffset.inMilliseconds, state.lyricRevision)),
    );
    final settings = ref.watch(musicLyricsSettingsProvider);
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
      _failure = null;
      _active = -1;
      _resume?.cancel();
      _scrubbing = false;
      if (trackId != null) unawaited(_load(trackId));
    }
    // The singing line moves off the tick without rebuilding the column:
    // this listen fires per tick but only carries the line (and its reveal)
    // forward when the line index changed. The check under it is the
    // catch-up for a freshly loaded document, where no tick has come yet.
    ref.listen(musicPlayerProvider.select((state) => state.position), (previous, next) {
      final loaded = _document;
      if (loaded == null || !loaded.isSynchronized || loaded.isEmpty) return;
      final active = loaded.indexAt(next);
      if (active == _active) return;
      setState(() {
        _active = active;
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(active, lineHeight));
      });
    });
    final document = _document;
    final lines = document?.lines ?? const <audio.LyricLine>[];
    if (document != null && document.isSynchronized && !document.isEmpty) {
      final active = document.indexAt(ref.read(musicPlayerProvider).position);
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
          if (settings.lyricProgress && ref.read(musicPlayerProvider).duration > Duration.zero)
            Consumer(
              builder: (context, ref, _) {
                final (position, duration) = ref.watch(
                  musicPlayerProvider.select((state) => (state.position, state.duration)),
                );
                if (duration <= Duration.zero) return const SizedBox.shrink();
                return DsProgressBar(
                  value: (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
                  semanticLabel: t.music.lyricProgress,
                );
              },
            ),
          Expanded(
            child: document == null
                ? _failure != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: DsSpace.s8,
                            children: [
                              Text(
                                t.music.lyricLoadFailed,
                                textAlign: TextAlign.center,
                                style: theme.typography.caption.copyWith(color: colors.danger.text),
                              ),
                              DsButton(
                                variant: DsButtonVariant.secondary,
                                size: DsSize.sm,
                                onPressed: trackId == null ? null : () => unawaited(_load(trackId)),
                                child: Text(t.common.retry),
                              ),
                            ],
                          ),
                        )
                      : const Center(child: DsSpinner())
                : document.isEmpty
                ? Center(
                    child: Text(
                      t.music.lyricsEmpty,
                      textAlign: TextAlign.center,
                      style: theme.typography.body.copyWith(color: colors.textMuted),
                    ),
                  )
                : Stack(
                    children: [
                      // The column fades out at both edges, so lines walk
                      // in and out of view instead of being cut by the box.
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                          stops: [0.0, 0.07, 0.93, 1.0],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) =>
                              _onScroll(notification, synced: document.isSynchronized, lineHeight: lineHeight),
                          child: ListView.builder(
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
                              final lineText = Text(
                                text.isEmpty ? '♪' : text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: textAlign,
                                style: theme.typography.body.copyWith(
                                  fontSize: (theme.typography.body.fontSize ?? 14) * scale,
                                  height: 1.3,
                                  color: colors.text,
                                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                                ),
                              );
                              final secondaryText = secondary.isEmpty
                                  ? null
                                  : Text(
                                      secondary.join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: textAlign,
                                      style: theme.typography.caption.copyWith(
                                        fontSize: (theme.typography.caption.fontSize ?? 12) * scale,
                                        color: colors.textSubtle,
                                      ),
                                    );
                              // Which line is singing is the one thing the
                              // words alone cannot say: the current line
                              // carries selected in the semantics.
                              // The sung part rides ahead of the unsung one
                              // across the active line — the sweep the word-
                              // level timeline affords, read off the line's
                              // own progress so plain LRC sweeps too.
                              Widget contentOf(double? sweep) => Semantics(
                                selected: current,
                                child: AnimatedOpacity(
                                  opacity: current ? 1.0 : 0.52,
                                  duration: const Duration(milliseconds: 260),
                                  child: AnimatedScale(
                                    scale: zoom,
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                    alignment: alignment,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: crossAlignment,
                                      children: [
                                        if (sweep == null)
                                          lineText
                                        else
                                          ShaderMask(
                                            shaderCallback: (bounds) => LinearGradient(
                                              begin: AlignmentDirectional.centerStart,
                                              end: AlignmentDirectional.centerEnd,
                                              colors: const [Colors.white, Colors.white, Colors.black, Colors.black],
                                              stops: [0.0, sweep, sweep, 1.0],
                                            ).createShader(bounds),
                                            blendMode: BlendMode.dstIn,
                                            child: lineText,
                                          ),
                                        ?secondaryText,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              // Only the singing line follows the word sweep,
                              // so only it watches the position tick; every
                              // other row stays off it.
                              final Widget content;
                              if (!current || !document.isSynchronized) {
                                content = contentOf(null);
                              } else {
                                content = Consumer(
                                  builder: (context, rowRef, _) {
                                    final position = rowRef.watch(
                                      musicPlayerProvider.select((state) => state.position),
                                    );
                                    final progress = document.positionAt(position).lineProgress;
                                    return contentOf(progress > 0.02 && progress < 0.98 ? progress : null);
                                  },
                                );
                              }
                              // A synchronized line is a seek target: pressing
                              // it plays from there. Unsynced words have no
                              // time to jump to, so they stay plain text.
                              if (!document.isSynchronized) {
                                return Align(alignment: alignment, child: content);
                              }
                              return DsPressable(
                                onPressed: () => unawaited(_seekToLine(index)),
                                builder: (context, states, child) {
                                  final lit =
                                      states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                                  return DsFocusRing(
                                    focused: states.contains(WidgetState.focused),
                                    borderRadius: BorderRadius.circular(theme.radii.card),
                                    child: Container(
                                      alignment: alignment,
                                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
                                      decoration: DsBoxDecoration(
                                        color: lit ? colors.hover : null,
                                        borderRadius: BorderRadius.circular(theme.radii.card),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: content,
                              );
                            },
                          ),
                        ),
                      ),
                      if (_scrubbing && settings.lyricDragSeek) _scrubRule(context, colors, theme, document.lines),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

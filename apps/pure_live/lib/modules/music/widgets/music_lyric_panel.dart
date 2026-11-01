import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_lyric_settings.dart'
    show MusicLyricAlignment, musicLyricsSettingsProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/widgets/music_widgets.dart' show musicDurationText;

/// The lyric panel: the current line highlighted, the panel following the
/// song. Unsynchronized lyrics (plain text from the lookup) scroll freely and
/// never highlight, because there is no position to highlight.
///
/// The player's stage and side tab draw it in place; the bar raises it in a
/// panel, so the viewer can read the words without leaving the list they are
/// browsing.
final class MusicLyricsPanel extends ConsumerStatefulWidget {
  const MusicLyricsPanel({super.key});

  @override
  ConsumerState<MusicLyricsPanel> createState() => MusicLyricsPanelState();
}

final class MusicLyricsPanelState extends ConsumerState<MusicLyricsPanel> {
  static const double _baseLineHeight = 46;

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
    final state = ref.watch(musicPlayerProvider);
    final settings = ref.watch(musicLyricsSettingsProvider);
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
      _failure = null;
      _active = -1;
      _resume?.cancel();
      _scrubbing = false;
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
                      NotificationListener<ScrollNotification>(
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
                            final content = Column(
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
                            );
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
                      if (_scrubbing && settings.lyricDragSeek) _scrubRule(context, colors, theme, document.lines),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

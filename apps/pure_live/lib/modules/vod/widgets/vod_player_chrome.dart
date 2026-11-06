import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_vod/live_vod.dart' show VodChapter, VodSeekPreview;
import 'package:media_core/media_core.dart' show BufferRange;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show vodDurationText;
import 'package:pure_live/shared/player/on_video_colors.dart';
import 'package:pure_live/shared/shared.dart';

/// What a gesture on the picture is doing, named by the chip it answers with.
///
/// A drag on the picture has no slider under the finger, so the picture answers
/// in words instead: which figure moved, where it reached, and — for a seek —
/// how far it went. A seek chip stands on the side the gesture happened on, so
/// a viewer who taps the picture's left edge learns that edge goes backwards
/// without reading anything first.
enum VodGestureKind {
  /// A seek that went backwards, shown at the picture's start.
  seekBack(DsIcons.chevronsLeft, AlignmentDirectional.centerStart),

  /// A seek that went forwards, shown at the picture's end.
  seekForward(DsIcons.chevronsRight, AlignmentDirectional.centerEnd),

  /// A seek the viewer watched move, shown over the middle.
  seek(DsIcons.timer, AlignmentDirectional.center),

  /// The sound a drag or a wheel set.
  volume(DsIcons.volume2, AlignmentDirectional.center),

  /// The screen's brightness the other half adjusts.
  brightness(DsIcons.sun, AlignmentDirectional.center),

  /// The rate a held picture is running at.
  speed(DsIcons.gauge, AlignmentDirectional.center);

  VodGestureKind(this.icon, this.alignment);

  /// The glyph that names the figure.
  final DsIconData icon;

  /// Where the chip stands over the picture.
  final AlignmentDirectional alignment;
}

/// The chip a picture gesture answers with: the figure's glyph, where the
/// gesture reached, and one short line about what it moved by.
final class VodGestureTip extends StatelessWidget {
  /// A tip naming [kind], reading [value] with [note] under it.
  const VodGestureTip({required this.kind, required this.value, this.note, super.key});

  /// Which figure moved.
  final VodGestureKind kind;

  /// The figure in words: a time, a percentage, a rate.
  final String value;

  /// The step the gesture took, e.g. `+10`; null leaves the line out.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return IgnorePointer(
      child: Align(
        alignment: kind.alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20, vertical: DsSpace.s12),
            decoration: DsBoxDecoration(
              color: OnVideoColors.scrimDeep,
              borderRadius: BorderRadius.circular(theme.radii.card),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s3,
              children: [
                DsIcon(kind.icon, size: 22, color: OnVideoColors.foreground),
                Text(
                  value,
                  style: theme.typography.numeric(
                    theme.typography.title.copyWith(color: OnVideoColors.foreground, fontWeight: FontWeight.w600),
                  ),
                ),
                if (note != null && note!.isNotEmpty)
                  Text(note!, style: theme.typography.caption.copyWith(color: OnVideoColors.inkSubtle)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The archive's seek line: what has been watched, what the engine already
/// holds, where the station marked a moment, and — under the pointer — where
/// the picture would go.
///
/// A live stream has no such line; this is the shape a video is read by, and it
/// is drawn rather than handed to a slider because the figures it carries are
/// three different claims — played, buffered, marked — that one value cannot
/// make. The bubble says the target time in the same words the bar's ends use,
/// and shows a frame for it when the station sent a filmstrip or a chapter
/// picture; with neither it stays a time, which is still the answer the pointer
/// asked for.
final class VodSeekBar extends StatefulWidget {
  /// The line for [position] of [duration]; [onSeek] commits seconds, and
  /// [semanticLabel] names the control to a reader.
  const VodSeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.semanticLabel,
    this.onScrub,
    this.buffered = const <BufferRange>[],
    this.chapters = const <VodChapter>[],
    this.preview,
    this.coverUrl,
    this.showPreview = true,
    super.key,
  });

  /// Where the part stands.
  final Duration position;

  /// How long the part is.
  final Duration duration;

  /// Commits a seek to the seconds the viewer chose.
  final ValueChanged<double> onSeek;

  /// The line's accessible name; the time it stands on is read beside it.
  final String? semanticLabel;

  /// Follows a drag while it is still moving, and says null when it let go;
  /// the caller shows the figure without committing it.
  final ValueChanged<double?>? onScrub;

  /// What the engine reports as already held.
  final List<BufferRange> buffered;

  /// The station's marked moments, ticked on the line.
  final List<VodChapter> chapters;

  /// The source's scrub filmstrip; null leaves the bubble to the cover.
  final VodSeekPreview? preview;

  /// The archive's own picture, for a bubble with no filmstrip.
  final String? coverUrl;

  /// Whether the bubble shows a picture at all.
  final bool showPreview;

  @override
  State<VodSeekBar> createState() => _VodSeekBarState();
}

final class _VodSeekBarState extends State<VodSeekBar> {
  /// The line at rest, and the taller one it takes while a pointer is on it.
  static const double _restThickness = 4;
  static const double _hoverThickness = 6;

  /// The height the line is given to be hit in: a 4 px rule is not a target.
  static const double _hitHeight = 18;

  /// The bubble's picture box, near the frame the station's own sheets cut.
  static const double _frameWidth = 168;
  static const double _frameHeight = 94;

  double? _hoverSeconds;
  double? _dragSeconds;
  bool _hovering = false;

  double get _total => widget.duration.inMilliseconds.toDouble();

  bool get _enabled => _total > 0;

  double _secondsAt(double x, double width) {
    if (width <= 0 || !_enabled) return 0;
    return (x / width).clamp(0.0, 1.0) * _total / 1000;
  }

  double? get _shown => _dragSeconds ?? _hoverSeconds;

  /// The station's own name for the moment the pointer stands on: the last
  /// mark at or before it.
  VodChapter? _chapterAt(double seconds) {
    VodChapter? found;
    for (final chapter in widget.chapters) {
      if (chapter.at.inMilliseconds / 1000 <= seconds) found = chapter;
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    if (!_enabled) {
      return const SizedBox(height: _hitHeight, child: SizedBox.expand());
    }
    final shown = _shown;
    final thickness = _hovering ? _hoverThickness : _restThickness;
    return Semantics(
      label: widget.semanticLabel,
      value: '${vodDurationText(widget.position)} / ${vodDurationText(widget.duration)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
          final bubble = _hovering && shown != null
              ? PositionedDirectional(
                  bottom: _hitHeight,
                  start: (shown / (_total / 1000) * width - _frameWidth / 2).clamp(
                    0.0,
                    (width - _frameWidth).clamp(0.0, width),
                  ),
                  child: _bubble(context, shown),
                )
              : const SizedBox.shrink();
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() {
              _hovering = false;
              _hoverSeconds = null;
            }),
            onHover: (event) => setState(() => _hoverSeconds = _secondsAt(event.localPosition.dx, width)),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // The tap commits when the finger leaves: a press that turns
              // into a drag must not also jump the picture to where it began.
              onTapUp: (tap) => widget.onSeek(_secondsAt(tap.localPosition.dx, width)),
              onHorizontalDragStart: (start) {
                final seconds = _secondsAt(start.localPosition.dx, width);
                setState(() => _dragSeconds = seconds);
                widget.onScrub?.call(seconds);
              },
              onHorizontalDragUpdate: (move) {
                final seconds = _secondsAt(move.localPosition.dx, width);
                setState(() => _dragSeconds = seconds);
                widget.onScrub?.call(seconds);
              },
              onHorizontalDragEnd: (_) {
                final seconds = _dragSeconds;
                setState(() => _dragSeconds = null);
                widget.onScrub?.call(null);
                if (seconds != null) widget.onSeek(seconds);
              },
              onHorizontalDragCancel: () {
                setState(() => _dragSeconds = null);
                widget.onScrub?.call(null);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: _hitHeight,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _SeekLinePainter(
                        played: widget.position.inMilliseconds / _total,
                        scrub: _dragSeconds == null ? null : _dragSeconds! * 1000 / _total,
                        buffered: [
                          for (final range in widget.buffered)
                            (start: range.start.inMilliseconds / _total, end: range.end.inMilliseconds / _total),
                        ],
                        marks: [for (final chapter in widget.chapters) chapter.at.inMilliseconds / _total],
                        thickness: thickness,
                        track: colors.channel,
                        held: const Color(0x59FFFFFF),
                        playedColor: colors.indicator,
                        markColor: const Color(0x8CFFFFFF),
                      ),
                    ),
                  ),
                  bubble,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bubble(BuildContext context, double seconds) {
    final theme = DsTheme.of(context);
    final chapter = _chapterAt(seconds);
    final frame = widget.preview?.urlAt(Duration(seconds: seconds.round()));
    final cover = widget.coverUrl;
    final picture = frame ?? (cover == null || cover.isEmpty ? null : cover);
    final time = vodDurationText(Duration(seconds: seconds.round()));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPreview && picture != null)
          Container(
            width: _frameWidth,
            height: _frameHeight,
            decoration: DsBoxDecoration(
              color: OnVideoColors.scrimDeep,
              borderRadius: BorderRadius.circular(theme.radii.control(8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image(
              image: cachedImage(
                picture,
                policy: ImageCachePolicies.videoCover,
                width: frame == null ? _frameWidth.round() : null,
              ),
              fit: BoxFit.cover,
              width: _frameWidth,
              height: _frameHeight,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.s4),
          child: Text(
            chapter == null || chapter.title.isEmpty ? time : '$time · ${chapter.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.typography.numeric(theme.typography.caption.copyWith(color: OnVideoColors.foreground)),
          ),
        ),
      ],
    );
  }
}

/// The seek line's three claims in one paint: what was watched, what is held,
/// and where the station marked a moment.
final class _SeekLinePainter extends CustomPainter {
  const _SeekLinePainter({
    required this.played,
    required this.scrub,
    required this.buffered,
    required this.marks,
    required this.thickness,
    required this.track,
    required this.held,
    required this.playedColor,
    required this.markColor,
  });

  /// The watched share, 0–1.
  final double played;

  /// The drag's share while a drag is moving; null at rest.
  final double? scrub;

  /// The held stretches, as shares of the whole.
  final List<({double start, double end})> buffered;

  /// The marked moments, as shares of the whole.
  final List<double> marks;

  /// The line's height right now.
  final double thickness;

  /// The three colours, in the theme's own words.
  final Color track;
  final Color held;
  final Color playedColor;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(thickness / 2);
    final rect = Rect.fromLTRB(0, (size.height - thickness) / 2, size.width, (size.height + thickness) / 2);
    canvas.drawRRect(
      RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius),
      Paint()..color = track,
    );
    for (final range in buffered) {
      if (range.end <= range.start) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            rect.left + range.start.clamp(0.0, 1.0) * size.width,
            rect.top,
            rect.left + range.end.clamp(0.0, 1.0) * size.width,
            rect.bottom,
          ),
          radius,
        ),
        Paint()..color = held,
      );
    }
    final share = (scrub ?? played).clamp(0.0, 1.0);
    if (share > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(rect.left, rect.top, rect.left + share * size.width, rect.bottom),
          radius,
        ),
        Paint()..color = playedColor,
      );
    }
    if (scrub == null && share < 1) {
      // The head the finger sits on, only while the line is not being dragged.
      canvas.drawCircle(
        Offset(rect.left + share * size.width, rect.center.dy),
        thickness,
        Paint()..color = playedColor,
      );
    }
    for (final mark in marks) {
      if (mark <= 0 || mark >= 1) continue;
      final x = rect.left + mark * size.width;
      canvas.drawRect(Rect.fromLTRB(x - 0.75, rect.top - 2, x + 0.75, rect.bottom + 2), Paint()..color = markColor);
    }
  }

  @override
  bool shouldRepaint(_SeekLinePainter previous) =>
      previous.played != played ||
      previous.scrub != scrub ||
      previous.thickness != thickness ||
      previous.buffered.length != buffered.length ||
      previous.marks.length != marks.length ||
      previous.track != track ||
      previous.playedColor != playedColor;
}

/// The archive's subtitle line, under the flying danmaku and above the bar.
///
/// One line rather than a scrolling block: the words the station sends are
/// timed to the picture, and a second line would cover what the viewer is
/// watching for. The shadow is the danmaku's own trick — the picture behind
/// the ink is nobody's choice.
final class VodSubtitleLayer extends StatelessWidget {
  /// Shows [text]; null or empty draws nothing.
  const VodSubtitleLayer({required this.text, this.bottomInset = 0, super.key});

  /// The words.
  final String? text;

  /// How far the line stands off the picture's bottom edge — the bar's height,
  /// so the two never sit on each other.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final words = text;
    if (words == null || words.isEmpty) return const SizedBox.shrink();
    final theme = DsTheme.of(context);
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(DsSpace.s24, 0, DsSpace.s24, DsSpace.s12 + bottomInset),
        child: Align(
          alignment: AlignmentDirectional.bottomCenter,
          child: Text(
            words,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(
              color: OnVideoColors.foreground,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: OnVideoColors.scrim, blurRadius: 6, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line the picture offers an action on: the end of a part counting down
/// to the next, a position the player jumped back to, the opening the viewer
/// can step over. A pill over the picture, because the bar is the watching
/// verbs' and these are one-time offers that leave when taken.
final class VodPictureNotice extends StatelessWidget {
  /// A notice reading [text], with one verb when [actionLabel] names it.
  const VodPictureNotice({required this.text, this.icon, this.actionLabel, this.onAction, super.key});

  /// What the picture says.
  final String text;

  /// The notice's own glyph; null leaves it out.
  final DsIconData? icon;

  /// The verb's word; null leaves the verb out.
  final String? actionLabel;

  /// Takes the verb.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return PlayerGlassPill(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s6, DsSpace.s6, DsSpace.s6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s8,
          children: [
            if (icon != null) DsIcon(icon!, size: theme.sizes.iconSm, color: OnVideoColors.foreground),
            Text(text, style: theme.typography.caption.copyWith(color: OnVideoColors.foreground)),
            if (actionLabel != null && onAction != null)
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.xs,
                onPressed: onAction,
                style: const DsButtonStyle(foreground: OnVideoColors.foreground, background: Color(0x00000000)),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

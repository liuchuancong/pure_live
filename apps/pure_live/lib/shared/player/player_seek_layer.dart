import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart' show BufferRange;

import 'package:pure_live/shared/player/on_video_colors.dart';

/// The clock a seek layer speaks: minutes and seconds under an hour, hours
/// prefixed past it.
String playerClockText(Duration time) {
  final total = time.inSeconds.clamp(0, 1 << 31);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${m < 10 ? '0' : ''}$m:${two(s)}';
}

/// The control bar's first layer: the picture's whole width given to
/// progress. A replay draws the seek line — its track, the buffer ahead of
/// it and the clocks at its ends — and a live broadcast draws the red badge
/// instead, the one word television cannot scrub, with the way back beside
/// it when the viewer has wandered behind.
final class PlayerSeekLayer extends StatelessWidget {
  /// The layer a live channel shows: the badge, and — when the picture is
  /// a replay wearing live's clothes — the door back to the broadcast,
  /// named by the caller's own word.
  const PlayerSeekLayer.live({this.onBackToLive, this.backToLiveLabel, super.key})
    : position = Duration.zero,
      duration = Duration.zero,
      buffered = const [],
      onSeek = null,
      onScrub = null,
      seekBar = null;

  /// The layer a replay shows: the clocks and the seek line, or a caller's
  /// own richer line (a scrub preview, chapters) drawn in the slot instead.
  const PlayerSeekLayer.replay({
    required this.position,
    required this.duration,
    this.buffered = const [],
    this.onSeek,
    this.onScrub,
    this.seekBar,
    super.key,
  }) : onBackToLive = null,
       backToLiveLabel = null;

  /// Where the line stands.
  final Duration position;

  /// How long the line runs.
  final Duration duration;

  /// What stands downloaded ahead of the position.
  final List<BufferRange> buffered;

  /// Fired with the second the line should jump to.
  final ValueChanged<double>? onSeek;

  /// Fired while the thumb is dragged, null when it lets go.
  final ValueChanged<double?>? onScrub;

  /// A caller's own seek line drawn between the clocks; null draws the
  /// layer's own.
  final Widget? seekBar;

  /// The door back to the live broadcast.
  final VoidCallback? onBackToLive;

  /// The door's word (`回到直播`), the caller's slang.
  final String? backToLiveLabel;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final clock = theme.typography.numeric(theme.typography.caption.copyWith(color: OnVideoColors.inkMuted));
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s4),
      child: onSeek == null && seekBar == null
          ? _liveRow(theme)
          : Row(
              spacing: DsSpace.s8,
              children: [
                SizedBox(width: 46, child: Text(playerClockText(position), style: clock)),
                Expanded(
                  child:
                      seekBar ??
                      _SeekLine(
                        position: position,
                        duration: duration,
                        buffered: buffered,
                        onSeek: (seconds) => onSeek?.call(seconds),
                        onScrub: onScrub,
                      ),
                ),
                SizedBox(
                  width: 46,
                  child: Text(playerClockText(duration), textAlign: TextAlign.end, style: clock),
                ),
              ],
            ),
    );
  }

  Widget _liveRow(DsThemeData theme) {
    return Row(
      spacing: DsSpace.s8,
      children: [
        const PlayerLiveBadge(),
        if (onBackToLive != null && backToLiveLabel != null)
          DsPressable(
            semanticLabel: backToLiveLabel,
            onPressed: onBackToLive,
            builder: (context, states, _) {
              final lit = states.contains(WidgetState.hovered);
              return Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(theme.radii.control(22)),
                  color: lit ? OnVideoColors.inkHover : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s4,
                  children: [
                    const DsIcon(DsIcons.radio, size: 12, color: OnVideoColors.foreground),
                    Text(
                      backToLiveLabel!,
                      style: theme.typography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: OnVideoColors.foreground,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// The red word a live channel wears in the bar's first layer. The badge
/// stands still — the recording indicator is the piece that breathes.
final class PlayerLiveBadge extends StatelessWidget {
  /// Draws the badge.
  const PlayerLiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radii.control(22)),
        border: Border.all(color: OnVideoColors.signal.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: OnVideoColors.signal, shape: BoxShape.circle),
          ),
          Text(
            'LIVE',
            style: theme.typography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OnVideoColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The seek line itself: a hair that thickens under the pointer, the buffer
/// standing faintly ahead of the fill, and a thumb that only shows when a
/// hand is on it — the picture keeps its clean edge the rest of the time.
final class _SeekLine extends StatefulWidget {
  const _SeekLine({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
    this.onScrub,
  });

  final Duration position;
  final Duration duration;
  final List<BufferRange> buffered;
  final ValueChanged<double> onSeek;
  final ValueChanged<double?>? onScrub;

  @override
  State<_SeekLine> createState() => _SeekLineState();
}

class _SeekLineState extends State<_SeekLine> {
  bool _handOn = false;
  bool _dragging = false;
  double? _dragSeconds;

  double get _fraction {
    if (_dragSeconds case final seconds?) return seconds;
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double _secondsOf(double fraction) => fraction * widget.duration.inMilliseconds / 1000;

  @override
  Widget build(BuildContext context) {
    final on = _handOn || _dragging;
    final trackHeight = on ? 6.0 : 4.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _handOn = true),
      onExit: (_) => setState(() => _handOn = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => widget.onSeek(_secondsOf(_fractionAt(details.localPosition))),
        onHorizontalDragStart: (details) {
          setState(() {
            _dragging = true;
            _dragSeconds = _secondsOf(_fractionAt(details.localPosition));
          });
          widget.onScrub?.call(_dragSeconds);
        },
        onHorizontalDragUpdate: (details) {
          setState(() => _dragSeconds = _secondsOf(_fractionAt(details.localPosition)));
          widget.onScrub?.call(_dragSeconds);
        },
        onHorizontalDragEnd: (_) {
          final seconds = _dragSeconds;
          setState(() {
            _dragging = false;
            _dragSeconds = null;
          });
          widget.onScrub?.call(null);
          if (seconds != null) widget.onSeek(seconds);
        },
        child: SizedBox(
          height: 24,
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final fraction = _fraction;
                final total = widget.duration.inMilliseconds <= 0 ? 1 : widget.duration.inMilliseconds;
                return Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [
                    Container(
                      height: trackHeight,
                      width: width,
                      decoration: BoxDecoration(
                        color: OnVideoColors.track,
                        borderRadius: BorderRadius.circular(DsRadii.pill),
                      ),
                    ),
                    for (final range in widget.buffered)
                      PositionedDirectional(
                        start: range.start.inMilliseconds / total * width,
                        width: (range.end.inMilliseconds - range.start.inMilliseconds) / total * width,
                        child: Container(
                          height: trackHeight,
                          decoration: BoxDecoration(
                            color: OnVideoColors.foreground.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(DsRadii.pill),
                          ),
                        ),
                      ),
                    Container(
                      height: trackHeight,
                      width: fraction * width,
                      decoration: BoxDecoration(
                        color: OnVideoColors.foreground,
                        borderRadius: BorderRadius.circular(DsRadii.pill),
                      ),
                    ),
                    if (on)
                      PositionedDirectional(
                        start: (fraction * width - 6).clamp(0.0, math.max(0.0, width - 12)).toDouble(),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(color: OnVideoColors.foreground, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _fractionAt(Offset local) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || widget.duration.inMilliseconds <= 0) return 0;
    return (local.dx / box.size.width).clamp(0.0, 1.0);
  }
}

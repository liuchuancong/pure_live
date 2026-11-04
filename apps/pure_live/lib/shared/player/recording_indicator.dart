import 'dart:async' show Timer;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/player_overlay.dart' show playerInk, playerSignal;

/// The recording state over a player: a red dot that breathes while a capture
/// runs and, where the surface has room for it, the elapsed time beside it.
///
/// It is the control and the status at once: with [onStop] the whole pill stops
/// the recording, which is why no second red button sits beside it; left null it
/// is a read-only status for a surface that carries the verb elsewhere (the
/// picture-in-picture strip).
///
/// The count is derived from [startedAt] on every tick rather than accumulated,
/// so a recording that began in an earlier visit, a window that was hidden, or a
/// dropped tick all read the same truth the task store holds.
final class RecordingIndicator extends StatefulWidget {
  /// Shows the running state of a capture that began at [startedAt].
  const RecordingIndicator({
    required this.startedAt,
    this.onStop,
    this.showTimer = true,
    this.figures,
    this.word,
    this.label,
    this.tv = false,
    super.key,
  });

  /// When the capture started. Null with no [word] draws nothing: a breathing
  /// dot without a running task behind it would be a lie.
  final DateTime? startedAt;

  /// Stops the recording. Null renders the status without a press.
  final VoidCallback? onStop;

  /// Whether the elapsed time rides beside the dot. A narrow strip keeps the
  /// dot alone — there the fact that something is recording is the whole news.
  final bool showTimer;

  /// The take's own state in the viewer's words, for the states that are not
  /// writing: a room armed and waiting for its streamer, a capture whose
  /// segments are still being joined, a take that ended in failure. Without it
  /// those three leave the bar saying nothing, and the button beside the picture
  /// reads "nothing is happening here" while a take is queued or unfinished.
  final String? word;

  /// What the take has written so far, in the viewer's own units — a size, said
  /// once the clock is there to read it against. Null leaves the strip with the
  /// dot and the time alone, which is right where the surface has no room for
  /// both, and in the small window, where the picture is what is being traded
  /// for text.
  final String? figures;

  /// What a screen reader says, and the tooltip's words.
  final String? label;

  /// The TV tier: the room's bars grow their controls for a viewer across the
  /// room (§10.5), and the indicator is one of them — a 8 px dot and a caption
  /// would vanish next to 48 px buttons.
  final bool tv;

  /// `mm:ss` under the hour and `h:mm:ss` past it: three hours of recording
  /// must not read as 180 minutes.
  ///
  /// Public because the room's own recording panel counts the same take with
  /// the same words; one clock format, two surfaces.
  static String formatElapsed(Duration since) {
    String two(int value) => value.toString().padLeft(2, '0');
    final hours = since.inHours;
    final minutes = two(since.inMinutes % 60);
    final seconds = two(since.inSeconds % 60);
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

final class _RecordingIndicatorState extends State<RecordingIndicator> with SingleTickerProviderStateMixin {
  /// One way of the breath, so a round trip is 1.6 s: slow enough to read as a
  /// status rather than an alarm, quick enough to catch from the corner of an
  /// eye while the viewer is looking at the picture.
  static const Duration _halfCycle = Duration(milliseconds: 800);

  late final AnimationController _pulse = AnimationController(vsync: this, duration: _halfCycle);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(RecordingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) _restart();
  }

  /// (Re)starts the breath and the one-second repaint. Both stop with the
  /// capture: no running task means no clock and no animation on the picture.
  void _restart() {
    _tick?.cancel();
    _pulse.stop();
    if (widget.startedAt == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final startedAt = widget.startedAt;
    final word = widget.word;
    if (startedAt == null && word == null) return const SizedBox.shrink();
    final theme = DsTheme.of(context);
    // The system's own "remove animations", a player whose tickers are paused
    // (a kept-alive tab off screen) and a status with nothing to press all keep
    // the dot lit rather than breathing — as does a take that is not writing at
    // all: a queued or joining capture is waiting, not recording.
    final still = startedAt == null || MediaQuery.disableAnimationsOf(context) || !TickerMode.valuesOf(context).enabled;
    final alpha = still ? 1.0 : 0.35 + 0.65 * Curves.easeInOut.transform(_pulse.value);
    final dotSize = widget.tv ? 12.0 : 8.0;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.tv ? DsSpace.s12 : DsSpace.s8, vertical: DsSpace.s3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          // The dot means *writing*, so it only appears with a clock behind it:
          // a red disc next to "等待开播" or "处理中" would say the opposite of
          // the words beside it.
          if (startedAt != null)
            SizedBox(
              width: dotSize,
              height: dotSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: playerSignal.withValues(alpha: alpha),
                ),
              ),
            ),
          if (widget.showTimer && startedAt != null)
            Text(
              RecordingIndicator.formatElapsed(DateTime.now().difference(startedAt)),
              style: theme.typography.numeric(
                (widget.tv ? theme.typography.label : theme.typography.caption).copyWith(
                  color: playerInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // The clock leads and the size follows it, dimmer: "how long" is the
          // fact a viewer checks a running capture for, and the bytes are the
          // proof that it is still writing.
          if (widget.figures case final String written when widget.showTimer)
            Text(
              written,
              style: theme.typography.numeric(
                (widget.tv ? theme.typography.label : theme.typography.caption).copyWith(
                  color: playerInk.withValues(alpha: 0.72),
                ),
              ),
            ),
          if (word case final String state)
            Text(
              state,
              style: (widget.tv ? theme.typography.label : theme.typography.caption).copyWith(
                color: playerInk,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
    final onStop = widget.onStop;
    if (onStop == null) return content;
    final label = widget.label;
    return DsTooltip(
      message: label ?? '',
      child: DsPressable(
        semanticLabel: label,
        // The dot alone is 8 px; a press needs the app's desktop floor of 24,
        // or the only way to stop a recording from the small window is to miss.
        builder: (context, states, _) => ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          child: ColoredBox(
            color: states.contains(WidgetState.hovered) ? const Color(0x24FFFFFF) : const Color(0x00000000),
            child: Align(child: content),
          ),
        ),
        onPressed: onStop,
      ),
    );
  }
}

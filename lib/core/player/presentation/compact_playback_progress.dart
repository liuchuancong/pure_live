import 'package:flutter/material.dart';

/// The position, seek bar and duration row a compact playback window shows.
///
/// A recording shrunk to a small window gives no clue where the viewer stands
/// in a fifteen-minute file, and a time label alone cannot be moved: the whole
/// point of the compact window is that the viewer operates it without going
/// back to the page. So the bar is the primary element and the two times are
/// its ends.
///
/// Nothing is painted while the engine has not reported a duration. `0:00 /
/// 0:00` with a dead slider is a claim about a file that is still being
/// probed, and live streams have no duration at all.
class CompactPlaybackProgress extends StatelessWidget {
  const CompactPlaybackProgress({super.key, required this.position, required this.duration, this.onSeek});

  /// Where playback is.
  final Duration position;

  /// How long the media is, or [Duration.zero] while the engine has not said.
  final Duration duration;

  /// Seeks playback when the viewer releases the bar. Null leaves the bar as
  /// a read-only progress line.
  final ValueChanged<Duration>? onSeek;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    if (total <= 0) return const SizedBox.shrink();

    final clamped = position.inMilliseconds.clamp(0, total).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text(formatPlaybackTime(position), style: _timeStyle),
          Expanded(
            child: onSeek == null
                ? LinearProgressIndicator(value: clamped / total, minHeight: 14)
                : SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: clamped,
                      max: total.toDouble(),
                      onChanged: (value) {},
                      onChangeEnd: (value) => onSeek?.call(Duration(milliseconds: value.round())),
                    ),
                  ),
          ),
          Text(formatPlaybackTime(duration), style: _timeStyle),
        ],
      ),
    );
  }

  static const TextStyle _timeStyle = TextStyle(color: Colors.white, fontSize: 11, height: 1.2);
}

/// `m:ss`, widened to `h:mm:ss` once the media passes an hour.
String formatPlaybackTime(Duration time) {
  final total = time.isNegative ? Duration.zero : time;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final ss = seconds.toString().padLeft(2, '0');

  if (hours <= 0) return '$minutes:$ss';

  return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
}

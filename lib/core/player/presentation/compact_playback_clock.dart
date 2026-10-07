import 'package:flutter/material.dart';

/// The position/duration readout a compact playback window shows.
///
/// A recording shrunk to a small window gives no clue where the viewer stands
/// in a fifteen-minute file — the corner controls cannot say it either. Live
/// streams have no duration, so this widget paints nothing until the engine
/// reports one: `0:00 / 0:00` would be a claim about a file that is still
/// being probed, not information.
class CompactPlaybackClock extends StatelessWidget {
  const CompactPlaybackClock({super.key, required this.position, required this.duration});

  /// Where playback is.
  final Duration position;

  /// How long the media is, or [Duration.zero] while the engine has not said.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (duration <= Duration.zero) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '${formatPlaybackTime(position)} / ${formatPlaybackTime(duration)}',
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
      ),
    );
  }
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

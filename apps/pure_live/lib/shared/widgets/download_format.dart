/// The one way this app prints a download's size.
///
/// Three surfaces each carried their own copy of the same loop and a fourth —
/// the music queue — stopped at MB, so a 1.5 GB album printed as `1536.0 MB`
/// beside the video pages' `1.5 GB` of the same bytes. One function now, so the
/// queue, its summary line, the recording library and the player's list all say
/// a size the same way.
library;

/// A byte count as a person reads it: the largest unit that stays whole, one
/// decimal from KB up. Zero and negatives read as `0 B` rather than as a unit
/// the viewer has to interpret.
String formatDownloadBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '${value.round()} B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// The same figure as a rate: what a running capture moves per second. A rate
/// of zero is not "0 B/s" but nothing to say — a paused row has no speed, and a
/// row that claims one invents a fact the engine never measured.
String? formatDownloadRate(int bytesPerSecond) =>
    bytesPerSecond <= 0 ? null : '${formatDownloadBytes(bytesPerSecond)}/s';

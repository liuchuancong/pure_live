import 'dart:math' as math;

/// The least amount of a recording the viewer has to have watched before it is
/// worth putting them back into.
const Duration recordingResumeFloor = Duration(seconds: 5);

/// The tail of a recording that counts as "already finished".
const Duration recordingResumeTail = Duration(seconds: 10);

/// Where a reopened recording resumes, or null when it should start over.
///
/// Two refusals. The first seconds are not a position worth restoring — the
/// viewer barely saw anything. And the tail is not either: dropping someone
/// two seconds before the end is a stub, not a continuation.
///
/// The tail margin used to be a flat ten seconds, which on a sixteen-second
/// test recording swallowed everything past the six-second mark: expanding the
/// small window restarted the file from zero even though the position had been
/// saved correctly. A margin that is a tenth of the media at most keeps the
/// long-movie behaviour (ten seconds) and stops short recordings from being
/// treated as finished when they are nowhere near it.
Duration? recordingResumeTarget({required Duration? saved, required Duration duration}) {
  if (saved == null || duration <= Duration.zero) return null;
  if (saved <= recordingResumeFloor) return null;

  final tail = math.min(recordingResumeTail.inMilliseconds, duration.inMilliseconds ~/ 10);

  return duration - saved > Duration(milliseconds: tail) ? saved : null;
}

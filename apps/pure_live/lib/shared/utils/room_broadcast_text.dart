import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/translations.dart';

/// How a room's broadcast reads on a card: how long a live room has been on
/// air, "just started", a recording, or nothing (an offline room the tabs
/// already group).
String? roomBroadcastText(Translations t, LiveRoom room) {
  final broadcast = room.broadcast;
  if (broadcast.isLiveNow) {
    final started = broadcast.startedAt;
    if (started == null) return t.favorites.statusLive;
    final elapsed = DateTime.now().difference(started);
    if (elapsed.isNegative) return t.favorites.statusLive;
    if (elapsed.inMinutes < 1) return t.favorites.justStarted;
    return t.favorites.liveFor(duration: roomDurationText(t, elapsed));
  }
  if (broadcast.followGroup == LiveFollowGroup.replay) return t.favorites.statusReplay;
  return null;
}

/// A broadcast's length in the viewer's words: hours and minutes, minutes
/// alone, or days and hours.
String roomDurationText(Translations t, Duration elapsed) {
  final minutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;
  if (minutes < 60) return t.favorites.durationMinutes(m: '$minutes');
  if (minutes < Duration.minutesPerDay) {
    return t.favorites.durationHours(h: '${minutes ~/ 60}', m: '${minutes % 60}');
  }
  return t.favorites.durationDays(
    d: '${minutes ~/ Duration.minutesPerDay}',
    h: '${minutes % Duration.minutesPerDay ~/ 60}',
  );
}

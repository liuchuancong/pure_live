import 'package:live_sites/live_sites.dart' show LiveRestriction, LiveRoom, LiveStatus;

/// Whether [room] cannot be played here — the reference's discovery rule:
///
/// - a carousel (the streamer is off and the platform loops past content)
///   never plays;
/// - a restriction this client cannot pass (payment, members-only, private,
///   app-only, region, password, or an unspecified block) always hides;
/// - a login or age check hides only while [signedIn] is false — with the
///   platform's cookie the room is playable.
///
/// Discovery pages hide such rooms unless the viewer asked to see them
/// (`showUnplayableInDiscover`).
bool cannotPlayHere(LiveRoom room, {required bool signedIn}) {
  if (room.broadcast.effectiveLiveStatus == LiveStatus.carousel) {
    return true;
  }
  return switch (room.broadcast.effectiveRestriction) {
    LiveRestriction.none => false,
    LiveRestriction.needsLogin || LiveRestriction.adult => !signedIn,
    _ => true,
  };
}

import 'package:live_sites/src/capabilities/live_site_capability.dart';

/// The events of a stored login the platform refused.
///
/// Only the platforms that drop a refused cookie and carry on anonymously
/// implement this (twitch): the site keeps working without the session, so no
/// call returns the refusal as an error and this feed is how the app learns
/// the cookie expired and should be filled in again.
abstract interface class LiveCookieRefusalFeed implements LiveSiteCapability {
  /// One event each time a stored cookie is refused for the first time; a
  /// refused cookie is not sent again until it changes, so each cookie is
  /// reported once. A broadcast stream that never closes; the cookie is not in
  /// the event.
  Stream<void> get cookieRefusals;
}

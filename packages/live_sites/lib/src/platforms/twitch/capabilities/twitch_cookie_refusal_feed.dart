import 'package:live_sites/src/capabilities/live_cookie_refusal_feed.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

/// Twitch's refusal feed: an event when the playback access token ask refuses
/// the stored cookie and falls back to an anonymous one. The chat reports the
/// same refusal in its own notice.
final class TwitchCookieRefusalFeed implements LiveCookieRefusalFeed {
  /// Serves [site].
  const new({required this.site});

  /// The adapter whose session refusals this feed reports.
  final TwitchSite site;

  @override
  Stream<void> get cookieRefusals => site.cookieRefusals;
}

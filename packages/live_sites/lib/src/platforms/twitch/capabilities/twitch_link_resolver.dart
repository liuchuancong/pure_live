import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a Twitch link to its canonical `https://www.twitch.tv/<login>`
/// channel page.
///
/// A channel is the first path segment of `twitch.tv` (`www`, `m`, `go`), the
/// second of a pop-out chat (`/popout/<login>/chat`), or `player.twitch.tv`'s
/// `?channel=` parameter; the login keeps the case it was written in. Twitch's
/// own pages (`/drops`, `/prime`, …) name no channel. No request is made:
/// Twitch's links are already canonical, so a foreign host is left as
/// [LiveSiteUnsupported] and a Twitch page without a channel as
/// [LiveSiteNotFound].
final class TwitchLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its endpoint constants and identity).
  TwitchLinkResolver({required this.site});

  /// The site whose links this resolver reads.
  final TwitchSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    final owned = host == 'player.twitch.tv' || TwitchEndpoints.channelHosts.contains(host);
    if (!owned) {
      return left(LiveSiteError.unsupported(siteId: 'twitch', message: 'not a twitch link: $uri'));
    }
    final login = TwitchSite.loginFromUrl(uri);
    if (login == null) {
      return left(LiveSiteError.notFound(siteId: 'twitch', message: 'no channel in twitch link: $uri'));
    }
    return right(Uri.parse(TwitchEndpoints.roomPageUrl(login)));
  }
}

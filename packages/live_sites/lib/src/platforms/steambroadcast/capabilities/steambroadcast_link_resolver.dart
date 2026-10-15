import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart' show siteId;
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Steam Broadcast's links: a watch link
/// `steamcommunity.com/broadcast/watch/<id>` or a profile link
/// `steamcommunity.com/profiles/<id>` canonicalized to the watch page
/// without a request; a custom address `steamcommunity.com/id/<name>`
/// resolved to its account with one request for the profile XML.
///
/// A link of another site is unsupported; a page of this site that names no
/// account is not-found.
final class SteambroadcastLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  SteambroadcastLinkResolver({required this.site});

  /// The site this capability serves.
  final SteambroadcastSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final raw = '$uri';
    final steamId = SteambroadcastEndpoints.steamIdOf(raw);
    if (steamId != null) return right(Uri.parse(SteambroadcastEndpoints.link(steamId)));
    final vanity = SteambroadcastEndpoints.vanityOf(raw);
    if (vanity == null) {
      return left(LiveSiteError.unsupported(siteId: siteId, message: '"$uri" is not a Steam broadcast link'));
    }
    final String? resolved;
    try {
      resolved = await site.resolveVanity(vanity);
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(siteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: siteId, message: '$error', cause: error));
    }
    if (resolved == null) {
      return left(LiveSiteError.notFound(siteId: siteId, message: 'no Steam account at "$uri"'));
    }
    return right(Uri.parse(SteambroadcastEndpoints.link(resolved)));
  }
}

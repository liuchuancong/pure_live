import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/kick_manifest.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a kick.com link to its canonical `https://kick.com/<slug>`
/// channel page.
///
/// A channel is the single path segment of `kick.com` (`www` and `m` too):
/// trimmed, lower-cased and shaped `[a-z0-9_-]{1,100}`, and not one of
/// Kick's own pages (`/search`, `/clips`, …). A multi-segment path names no
/// channel. No request is made — the slug is already the room id the channel
/// API answers for (`/api/v2/channels/<slug>`), so a foreign link is
/// [LiveSiteUnsupported] and a Kick page without a channel is
/// [LiveSiteNotFound].
final class KickLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its endpoint constants and identity).
  KickLinkResolver({required this.site});

  /// The site whose links this resolver reads.
  final KickSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (!KickRoomParser.isKickHost(host)) {
      return left(LiveSiteError.unsupported(siteId: kickSiteId, message: 'not a kick link: $uri'));
    }
    final slug = KickRoomParser.slugFromUrl(uri);
    if (slug == null) {
      return left(LiveSiteError.notFound(siteId: kickSiteId, message: 'no channel in kick link: $uri'));
    }
    return right(KickEndpoints.roomPage(slug));
  }
}

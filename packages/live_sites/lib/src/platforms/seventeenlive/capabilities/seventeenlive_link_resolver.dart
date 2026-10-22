import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_room_parser.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a 17LIVE link to its canonical `https://17.live/en/live/<roomId>`.
///
/// 17LIVE has no short link to follow, so this is pure reading: http(s) on
/// `17.live` or `www.17.live` exactly (any case, any port) without user info, and
/// a path of `/live/<id>`, `/<locale>/live/<id>`, `/profile/r/<id>` or
/// `/<locale>/profile/r/<id>` (the locale two letters with an optional `-`
/// suffix, the words in any case, empty segments ignored). A host the platform
/// does not own is [LiveSiteUnsupported] — the resolver hands the caller a link
/// that is not this site's, never a guess; a page of its own hosts with no room
/// in it is [LiveSiteNotFound].
final class SeventeenLiveLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its endpoint constants and identity).
  SeventeenLiveLinkResolver({required this.site});

  /// The site whose links this resolver recognizes.
  final SeventeenLiveSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (!SeventeenLiveEndpoints.webHosts.contains(host)) {
      return left(LiveSiteError.unsupported(siteId: seventeenliveSiteId, message: 'not a 17LIVE link: $uri'));
    }
    final roomId = SeventeenLiveRoomParser.roomIdFromUrl('$uri');
    if (roomId == null) {
      return left(LiveSiteError.notFound(siteId: seventeenliveSiteId, message: 'no room in 17LIVE link: $uri'));
    }
    return right(Uri.parse(SeventeenLiveRoomParser.roomUrl(roomId)));
  }
}

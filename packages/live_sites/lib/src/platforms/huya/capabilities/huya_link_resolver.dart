import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/huya/huya_manifest.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a huya room link — a bare numeric rid (`/660000`) or a letter
/// alias (`/lpl`) — to the canonical `https://www.huya.com/<rid>` page,
/// mapping an alias through its room page (`TT_ROOM_DATA.profileRoom`) like
/// the rest of the adapter (a repeat is served from the site's rid cache).
final class HuyaLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its rid cache and room-page fetch).
  HuyaLinkResolver({required this.site});

  /// The site whose rid mapping this resolver drives.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host != 'huya.com' && !host.endsWith('.huya.com')) {
      return left(LiveSiteError.unsupported(siteId: huyaSiteId, message: 'not a huya link: $uri'));
    }
    final first = uri.pathSegments.where((segment) => segment.isNotEmpty).firstOrNull;
    if (first == null) {
      return left(LiveSiteError.notFound(siteId: huyaSiteId, message: 'no room in huya link: $uri'));
    }
    // A numeric path is already canonical; `profileRoom` refuses a letter
    // alias, so the alias page resolves it to a number.
    final numeric = HuyaRoomParser.roomIdAt(uri);
    if (numeric != null) return right(Uri.https('www.huya.com', '/$numeric'));
    final alias = HuyaRoomParser.aliasAt(uri);
    if (alias == null) {
      return left(LiveSiteError.notFound(siteId: huyaSiteId, message: 'no room in huya link: $uri'));
    }
    try {
      final rid = await site.ridFor(alias);
      if (rid == null) {
        return left(LiveSiteError.notFound(siteId: huyaSiteId, message: 'huya link resolves to no room: $alias'));
      }
      site.rememberRid(alias, rid);
      return right(Uri.https('www.huya.com', '/$rid'));
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }
}

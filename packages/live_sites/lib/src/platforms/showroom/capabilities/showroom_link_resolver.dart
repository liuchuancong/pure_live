import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SHOWROOM's links: a room page canonicalized to the room's own profile
/// page without a request; a key page (`/r/{key}`, `/{key}`) resolved to its
/// room with one `room/status` — including a key made of digits only, which
/// would otherwise be read as a room id.
///
/// A link of another site is unsupported; a page of this site that names no
/// room is not-found.
final class ShowroomLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  ShowroomLinkResolver({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final link = ShowroomParser.link(uri);
    if (link == null) {
      final ours = ShowroomEndpoints.isSiteHost(uri.host.toLowerCase());
      return left(
        ours
            ? LiveSiteError.notFound(siteId: 'showroom', message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: 'showroom', message: '"$uri" is not a SHOWROOM link'),
      );
    }
    final String roomId;
    try {
      final id = link.roomId;
      final key = link.key;
      roomId = id ?? '${await site.resolveRoomKey(key!)}';
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError('showroom'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'showroom', message: '$error', cause: error));
    }
    final page = ShowroomEndpoints.roomUrl(roomId);
    if (page == null) {
      return left(LiveSiteError.notFound(siteId: 'showroom', message: '"$uri" names no room'));
    }
    return right(Uri.parse(page));
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_endpoints.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Six Rooms' links: a room page of `v.6.cn` or `m.6.cn` canonicalized to
/// the room's own page, without a request. A room number is a link too.
///
/// A link of another site is unsupported; a page of this site that is no
/// room page is not-found.
final class SixroomLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  SixroomLinkResolver({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final roomId = SixroomEndpoints.roomIdOf('$uri');
    if (roomId != null) return right(Uri.parse(SixroomEndpoints.link(roomId)));
    final host = uri.host.toLowerCase();
    final ours = host == 'v.6.cn' || host == 'm.6.cn' || host.endsWith('.6.cn') || host.endsWith('.6rooms.com');
    return left(
      ours
          ? const LiveSiteError.notFound(siteId: sixroomSiteId, message: 'the page names no Six Rooms room')
          : LiveSiteError.unsupported(siteId: sixroomSiteId, message: '"$uri" is not a Six Rooms link'),
    );
  }
}

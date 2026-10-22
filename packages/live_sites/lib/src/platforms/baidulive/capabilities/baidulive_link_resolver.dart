import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_endpoints.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Baidu Live's links: a room page, the PC player or a share page on
/// `live.baidu.com`, canonicalized to the room's own page, without a request.
///
/// Baidu Live has no short links, so nothing is followed. A link of another
/// site is unsupported; a Baidu Live link that names no room is not-found.
final class BaiduliveLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  BaiduliveLinkResolver({required this.site});

  /// The site this capability serves.
  final BaiduliveSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final roomId = BaiduliveEndpoints.roomIdFromUrl('$uri');
    if (roomId == null) {
      final host = uri.host.toLowerCase();
      final ours = host == 'live.baidu.com' || host.endsWith('.live.baidu.com');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: baiduliveSiteId, message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: baiduliveSiteId, message: '"$uri" is not a Baidu Live link'),
      );
    }
    return right(Uri.parse(BaiduliveEndpoints.roomUrl(roomId)));
  }
}

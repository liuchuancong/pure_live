import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC's links: a room of `cc.163.com/{ccid}` (3.x), and the two forms the
/// site now shares — the mobile page `h5.cc.163.com/cc/{ccid}` and the
/// Dashen player `ds.163.com/glive/?ccid=` — canonicalized to the room's
/// `cc.163.com/{ccid}/` page, offline (no request: the id is all there is).
///
/// A link of another site is unsupported; a page of this site that names no
/// room (a category page, a word path) is not-found — only numeric ids are
/// rooms, 3.x's manual-link rule that took any word being dropped.
final class CcLinkResolver implements LiveLinkResolver {
  /// Serves [site] (its identity decides what this resolver accepts).
  CcLinkResolver({required this.site});

  /// The site this capability serves.
  final CcSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final roomId = CcEndpoints.roomIdFromUrl('$uri');
    if (roomId == null) {
      final host = uri.host.toLowerCase();
      final ours =
          const {'cc.163.com', 'h5.cc.163.com', 'ds.163.com'}.contains(host) ||
          host.endsWith('.cc.163.com') ||
          host.endsWith('.ds.163.com');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: ccSiteId, message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: ccSiteId, message: '"$uri" is not a NetEase CC link'),
      );
    }
    return right(Uri.parse(CcEndpoints.roomUrl(roomId)));
  }
}

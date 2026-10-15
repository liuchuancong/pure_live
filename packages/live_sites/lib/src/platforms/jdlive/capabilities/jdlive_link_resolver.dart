import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// JD Live's links: a room page of `lives.jd.com` canonicalized to its
/// broadcast's `#/<liveId>` page, offline (no request: the page routes by
/// fragment, so the id is all there is).
///
/// A link of another site is unsupported; a page of this site that names no
/// broadcast (a tab, the shop) is not-found.
final class JdliveLinkResolver implements LiveLinkResolver {
  /// Serves [site] (its identity decides what this resolver accepts).
  JdliveLinkResolver({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final liveId = JdliveEndpoints.liveIdFromUrl('$uri');
    if (liveId == null) {
      final ours = uri.host.toLowerCase() == 'lives.jd.com' || uri.host.toLowerCase().endsWith('.lives.jd.com');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: 'jdlive', message: '"$uri" names no broadcast')
            : LiveSiteError.unsupported(siteId: 'jdlive', message: '"$uri" is not a JD Live link'),
      );
    }
    return right(Uri.parse(JdliveEndpoints.link(liveId)));
  }
}

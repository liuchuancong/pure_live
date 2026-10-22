import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/inke/api/inke_endpoints.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's links: a web room page or an app share link canonicalized to the
/// room's own web page, without a request.
///
/// A link of another site is unsupported; a page of this site that names no
/// room is not-found.
final class InkeLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  InkeLinkResolver({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final canonical = site.canonicalRoomUrl(uri);
    if (canonical != null) return right(canonical);
    final ours = InkeEndpoints.isOurHost(uri.host.toLowerCase());
    return left(
      ours
          ? LiveSiteError.notFound(siteId: inkeSiteId, message: '"$uri" names no room')
          : LiveSiteError.unsupported(siteId: inkeSiteId, message: '"$uri" is not an Inke link'),
    );
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_link.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC's links: a room page of any of the site's three forms canonicalized to
/// `cc.163.com/{ccid}/` without a request.
///
/// A link of another site is unsupported; a page of this site that names no
/// room is not-found.
final class CcLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  CcLinkResolver({required this.site});

  /// The site this capability serves.
  final CcSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final ccid = CcLink.ccidOf(uri);
    if (ccid != null) return right(Uri.parse(CcEndpoints.roomUrl(ccid)));
    final ours = CcLink.hosts.contains(uri.host.toLowerCase());
    return left(
      ours
          ? LiveSiteError.notFound(siteId: 'cc', message: '"$uri" names no room')
          : LiveSiteError.unsupported(siteId: 'cc', message: '"$uri" is not a CC link'),
    );
  }
}

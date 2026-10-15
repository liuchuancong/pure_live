import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_link.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// PandaTV's links: a live or channel page canonicalized to the website's
/// current live page `/play/<id>`, without a request. PandaTV has no short
/// links.
///
/// A link of another site is unsupported; a page of this site that names no
/// broadcaster is not-found.
final class PandaliveLinkResolver implements LiveLinkResolver {
  /// Serves [site] (unused: resolving asks nothing).
  PandaliveLinkResolver({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final id = PandaliveLink.roomIdFromUrl('$uri');
    if (id == null) {
      final host = uri.host.toLowerCase();
      final ours = PandaliveEndpoints.roomHosts.contains(host) || host.endsWith('.pandalive.co.kr');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: 'pandalive', message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: 'pandalive', message: '"$uri" is not a PandaTV link'),
      );
    }
    return right(Uri.parse(PandaliveEndpoints.roomUrl(id)));
  }
}

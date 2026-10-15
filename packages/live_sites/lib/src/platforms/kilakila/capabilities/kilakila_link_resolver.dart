import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_link.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// KilaKila's links: an anchor page canonicalized to the anchor's own page
/// without a request; a broadcast page (a share link, possibly the
/// website's encrypted form) resolved to its anchor with one `getRoomInfo`.
///
/// A link of another site is unsupported; a page of this site that names no
/// broadcast or anchor is not-found.
final class KilakilaLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  KilakilaLinkResolver({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final link = KilakilaLink.parse('$uri');
    if (link == null) {
      final host = uri.host.toLowerCase();
      final ours =
          KilakilaEndpoints.roomHosts.contains(host) ||
          host == KilakilaEndpoints.ownerHost ||
          host.endsWith('.kilakila.cn') ||
          host.endsWith('.hongrenshuo.com.cn');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: 'kilakila', message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: 'kilakila', message: '"$uri" is not a KilaKila link'),
      );
    }
    final String uid;
    try {
      uid = switch (link.kind) {
        KilakilaLinkKind.owner => link.id,
        KilakilaLinkKind.broadcast => await site.resolveBroadcast(link.id),
      };
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError('kilakila'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kilakila', message: '$error', cause: error));
    }
    return right(Uri.parse(KilakilaEndpoints.ownerUrl(uid)));
  }
}

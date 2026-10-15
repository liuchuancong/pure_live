import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Missevan's links: a room page canonicalized to that room's own page
/// without a request ([MissevanEndpoints.roomIdFromUri]; the site has no
/// short links).
///
/// A link of another site is unsupported; a page of this site that names no
/// room is not-found.
final class MissevanLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  MissevanLinkResolver({required this.site});

  /// The site this capability serves.
  final MissevanSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final roomId = MissevanEndpoints.roomIdFromUri(uri);
    if (roomId != null) return right(Uri.parse(MissevanEndpoints.roomUrl(roomId)));
    final host = uri.host.toLowerCase();
    final ours = host == 'missevan.com' || host.endsWith('.missevan.com');
    return left(
      ours
          ? LiveSiteError.notFound(siteId: 'missevan', message: '"$uri" names no room')
          : LiveSiteError.unsupported(siteId: 'missevan', message: '"$uri" is not a Missevan link'),
    );
  }
}

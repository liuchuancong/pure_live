import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Picarto's links: a channel page canonicalized to the channel's own page,
/// without a request.
///
/// A link of another site is unsupported; a page of this site that names no
/// channel is not-found.
final class PicartoLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  PicartoLinkResolver({required this.site});

  /// The site this capability serves.
  final PicartoSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final canonical = site.canonicalRoomUrl(uri);
    if (canonical != null) return right(canonical);
    return left(
      PicartoSite.ownsHost(uri)
          ? LiveSiteError.notFound(siteId: 'picarto', message: '"$uri" names no room')
          : LiveSiteError.unsupported(siteId: 'picarto', message: '"$uri" is not a Picarto link'),
    );
  }
}

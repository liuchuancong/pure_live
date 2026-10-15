import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's links: a room page of `look.163.com` canonicalized to its
/// room's own page, without a request.
///
/// A link of another site is unsupported; a room page of this site that
/// names no room is not-found.
final class LookliveLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  LookliveLinkResolver({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final roomId = LookliveEndpoints.roomIdFromUrl('$uri');
    if (roomId == null) {
      final ours = uri.host.toLowerCase() == 'look.163.com' || uri.host.toLowerCase().endsWith('.look.163.com');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: 'looklive', message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: 'looklive', message: '"$uri" is not a LOOK Live link'),
      );
    }
    return right(Uri.parse(LookliveEndpoints.link(roomId)));
  }
}

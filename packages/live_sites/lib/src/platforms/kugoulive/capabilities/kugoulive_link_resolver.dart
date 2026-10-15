import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugou Live's links: a room page canonicalized to its `/<roomId>` page,
/// without a request. Kugou Live has no short links.
///
/// A link of another site is unsupported; a page of this site that names no
/// room is not-found.
final class KugouliveLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  KugouliveLinkResolver({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) {
    final roomId = KugouliveEndpoints.roomIdFromUrl('$uri');
    if (roomId != null) {
      return Future.value(right(Uri.parse(KugouliveEndpoints.roomUrl(roomId))));
    }
    final host = uri.host.toLowerCase();
    final ours = host == 'fanxing.kugou.com' || host == 'mfanxing.kugou.com' || host.endsWith('.kugou.com');
    return Future.value(
      left(
        ours
            ? LiveSiteError.notFound(siteId: 'kugoulive', message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: 'kugoulive', message: '"$uri" is not a Kugou Live link'),
      ),
    );
  }
}

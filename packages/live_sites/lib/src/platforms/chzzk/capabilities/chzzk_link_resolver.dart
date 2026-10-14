import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a CHZZK link to its canonical `https://chzzk.naver.com/live/<id>`.
///
/// Chzzk has no short link to follow: the channel id is written in the page's
/// own path, as the live page `/live/<id>` or as the channel page `/<id>` with
/// at most one tab after it (`/<id>/videos`, `/<id>/clips`). The id is accepted
/// in any case and canonicalized to the lower case the platform writes. A host
/// that is not `chzzk.naver.com` — its own mobile host included — is
/// [LiveSiteUnsupported] (the resolver hands the caller an unsupported link,
/// never a guess); a page of that host with no channel id in it is
/// [LiveSiteNotFound].
final class ChzzkLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its endpoint constants and identity).
  ChzzkLinkResolver({required this.site});

  /// The site whose links this resolver recognizes.
  final ChzzkSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    if (uri.host.toLowerCase() != 'chzzk.naver.com') {
      return left(LiveSiteError.unsupported(siteId: 'chzzk', message: 'not a chzzk link: $uri'));
    }
    final id = ChzzkRoomParser.roomIdFromUrl('$uri');
    if (id == null) {
      return left(LiveSiteError.notFound(siteId: 'chzzk', message: 'no channel in chzzk link: $uri'));
    }
    return right(Uri.parse(ChzzkEndpoints.roomUrl(id)));
  }
}

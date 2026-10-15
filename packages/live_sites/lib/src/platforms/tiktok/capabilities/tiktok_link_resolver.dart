import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_endpoints.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_link.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TikTok's links: a user link (`tiktok.com/@<user>`, `/@<user>/live`)
/// canonicalized to the room's own page without a request; a
/// `share/live/<LIVE room id>` link resolved to its owner with one
/// `room/info`; a share short link followed by the transport and read off
/// the page it lands on.
///
/// A link of another site is unsupported; a page of this site that names no
/// LIVE room is not-found.
final class TiktokLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  TiktokLinkResolver({required this.site});

  /// The site this capability serves.
  final TiktokSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final raw = '$uri';
    if (TiktokLink.shortLink(raw) case final short?) {
      try {
        final username = await site.shortLinkUsername(short);
        return username == null
            ? left(LiveSiteError.notFound(siteId: 'tiktok', message: '"$uri" leads to no LIVE room'))
            : right(Uri.parse(TiktokEndpoints.roomUrl(username)));
      } on TiktokFailure catch (failure) {
        return left(failure.toLiveSiteError('tiktok'));
      } on Object catch (error) {
        return left(LiveSiteError.unexpected(siteId: 'tiktok', message: '$error', cause: error));
      }
    }
    final link = TiktokLink.parse(raw);
    if (link == null) {
      return left(
        TiktokLink.ownsHost(uri.host)
            ? LiveSiteError.notFound(siteId: 'tiktok', message: '"$uri" names no LIVE room')
            : LiveSiteError.unsupported(siteId: 'tiktok', message: '"$uri" is not a TikTok link'),
      );
    }
    if (link.kind == TiktokLinkKind.username) {
      return right(Uri.parse(TiktokEndpoints.roomUrl(link.id)));
    }
    try {
      final username = await site.owner(link.id);
      return right(Uri.parse(TiktokEndpoints.roomUrl(username)));
    } on TiktokFailure catch (failure) {
      return left(failure.toLiveSiteError('tiktok'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'tiktok', message: '$error', cause: error));
    }
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_endpoints.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Weibo's links: a watch page or media-centre link canonicalized to the
/// broadcast's own web page without a request; a `t.cn` short link is asked
/// where it leads (one request, its target not fetched further).
///
/// A link of another site is unsupported; a page of this site that names no
/// room is not-found. The reference handed a redirect to another platform
/// back to the app for other adapters to try; the v2 resolver answers for
/// this site only, so any target that is no Weibo room is not-found here.
final class WeiboLinkResolver implements LiveLinkResolver {
  /// Serves [site] (its short-link requests).
  WeiboLinkResolver({required this.site});

  /// The site this capability serves.
  final WeiboSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final text = '$uri';
    final id = WeiboEndpoints.liveIdFromUrl(text);
    if (id != null) return right(Uri.parse(WeiboEndpoints.roomUrl(id)));
    if (site.isShortLink(uri)) {
      try {
        final followed = await site.shortLinkRoom(text);
        if (followed != null) return right(Uri.parse(WeiboEndpoints.roomUrl(followed)));
      } on WeiboFailure catch (failure) {
        return left(failure.toLiveSiteError(weiboSiteId));
      } on Object catch (error) {
        return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
      }
      return left(LiveSiteError.notFound(siteId: weiboSiteId, message: '"$uri" leads to no room'));
    }
    final ours = WeiboEndpoints.isOurHost(uri.host);
    return left(
      ours
          ? LiveSiteError.notFound(siteId: weiboSiteId, message: '"$uri" names no room')
          : LiveSiteError.unsupported(siteId: weiboSiteId, message: '"$uri" is not a Weibo Live link'),
    );
  }
}

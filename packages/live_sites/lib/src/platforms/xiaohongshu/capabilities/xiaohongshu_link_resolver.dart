import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_link.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Xiaohongshu's links: a share page canonicalized to the room's own page
/// without a request; an app deep link (`xhsdiscover://live_audience`) read
/// from its `room_id` without a request; and a `xhslink.com` short link
/// followed to the room page it lands on (the transport follows the
/// redirect chain; 3.x followed it hop by hop within `xhslink.com`).
///
/// A link of another site is unsupported; a link of this site that names no
/// room is not-found.
final class XiaohongshuLinkResolver implements LiveLinkResolver {
  /// Serves [site] (its short-link requests).
  XiaohongshuLinkResolver({required this.site});

  /// The site this capability serves.
  final XiaohongshuSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final text = '$uri';
    final deep = XiaohongshuLink.deepLinkRoomId(text);
    if (deep != null) return right(XiaohongshuEndpoints.roomUrl(deep));
    final roomId = XiaohongshuLink.webRoomId(text);
    if (roomId != null) return right(XiaohongshuEndpoints.roomUrl(roomId));
    if (XiaohongshuLink.shortLink(text) != null) {
      try {
        final followed = await site.shortLinkRoom(text);
        if (followed != null) return right(XiaohongshuEndpoints.roomUrl(followed));
      } on XiaohongshuFailure catch (failure) {
        return left(failure.toLiveSiteError(xiaohongshuSiteId));
      } on Object catch (error) {
        return left(LiveSiteError.unexpected(siteId: xiaohongshuSiteId, message: '$error', cause: error));
      }
      return left(LiveSiteError.notFound(siteId: xiaohongshuSiteId, message: '"$uri" leads to no room'));
    }
    final host = uri.host.toLowerCase();
    final ours =
        uri.scheme.toLowerCase() == 'xhsdiscover' ||
        host == 'www.xiaohongshu.com' ||
        host == 'xiaohongshu.com' ||
        host.endsWith('.xiaohongshu.com') ||
        host == 'xhslink.com' ||
        host.endsWith('.xhslink.com');
    return left(
      ours
          ? LiveSiteError.notFound(siteId: xiaohongshuSiteId, message: '"$uri" names no room')
          : LiveSiteError.unsupported(siteId: xiaohongshuSiteId, message: '"$uri" is not a Xiaohongshu link'),
    );
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YY's links: a channel page on `yy.com` or a subdomain
/// (`www.yy.com/{sid}`, `www.yy.com/{sid}/{ssid}`) and the mobile page
/// `wap.yy.com/mobileweb/{sid}/{ssid}`, canonicalized to
/// `https://www.yy.com/{sid}` without a request.
///
/// A link of another site is unsupported; a `yy.com` page that names no
/// channel (`/music/`, the root) is not-found.
final class YyLinkResolver implements LiveLinkResolver {
  /// Creates the resolver.
  const YyLinkResolver();

  static const String _siteId = 'yy';

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final id = roomIdFromUrl(uri);
    if (id == null) {
      final host = uri.host.toLowerCase();
      const domain = 'yy.com';
      final ours = host == domain || host.endsWith('.$domain');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: _siteId, message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: _siteId, message: '"$uri" is not a YY link'),
      );
    }
    return right(YyEndpoints.roomLink(id));
  }

  /// The channel number [uri] names: the first path segment of a `yy.com`
  /// page, after `mobileweb` on the mobile host, when it is a channel
  /// number.
  static String? roomIdFromUrl(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
    final host = uri.host.toLowerCase();
    const domain = 'yy.com';
    if (host != domain && !host.endsWith('.$domain')) return null;
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final id = (segments.first == 'mobileweb' && segments.length > 1 ? segments[1] : segments.first).trim();
    return YyEndpoints.isChannel(id) ? id : null;
  }
}

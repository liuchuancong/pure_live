import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves an AcFun link to its canonical `https://live.acfun.cn/live/<id>`
/// room page.
///
/// The live page (`live.acfun.cn/live/{id}`), the mobile live page
/// (`m.acfun.cn/live/detail/{id}`), the author profile (`www.acfun.cn/u/{id}`,
/// `acfun.cn/u/{id}`, also with the legacy `.aspx` suffix the site still
/// redirects) and the mobile `upPage` all name a room: the author id *is* the
/// room id. Nothing is fetched — the id is in the path. A foreign host is
/// [LiveSiteUnsupported], a host of this site with no author in it is
/// [LiveSiteNotFound].
final class AcfunLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its identity and endpoint rules).
  AcfunLinkResolver({required this.site});

  /// The site whose links this resolver reads.
  final AcfunSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final id = authorIdOf(uri);
    if (id != null) return right(Uri.parse(AcfunEndpoints.roomPageUrl(id)));
    final host = uri.host.toLowerCase();
    final owned = const {'live.acfun.cn', 'm.acfun.cn', 'www.acfun.cn', 'acfun.cn'}.contains(host);
    return owned
        ? left(LiveSiteError.notFound(siteId: acfunSiteId, message: 'no author in acfun link: $uri'))
        : left(LiveSiteError.unsupported(siteId: acfunSiteId, message: 'not an acfun link: $uri'));
  }

  /// The author id a link names, or null when it names none.
  static String? authorIdOf(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    final id = switch (segments) {
      ['live', final value] when host == 'live.acfun.cn' => value,
      ['live', 'detail', final value] when host == 'm.acfun.cn' => value,
      ['u', final value] when host == 'www.acfun.cn' || host == 'acfun.cn' => _withoutAspx(value),
      ['upPage', final value] when host == 'm.acfun.cn' => value,
      _ => null,
    };
    if (id == null) return null;
    final trimmed = id.trim();
    return AcfunEndpoints.isAuthorId(trimmed) ? trimmed : null;
  }

  static String _withoutAspx(String value) =>
      value.endsWith('.aspx') ? value.substring(0, value.length - '.aspx'.length) : value;
}

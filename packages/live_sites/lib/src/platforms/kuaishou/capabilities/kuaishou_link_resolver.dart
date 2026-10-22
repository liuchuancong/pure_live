import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

final RegExp _roomIdPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

/// Resolves a Kuaishou room link to its canonical `https://live.kuaishou.com/
/// u/{id}` page.
///
/// Only a room page `/u/{id}` on `live.kuaishou.com` or `live.kuaishou.cn`
/// names a room; other pages there (search, categories) are not rooms
/// (not-found). Share links (`v.kuaishou.com`) and mobile pages are not
/// supported by the desktop client, so a foreign host is left as
/// [LiveSiteUnsupported] (the resolver hands the caller an unsupported link,
/// never a guess).
final class KuaishouLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its endpoint constants and identity).
  KuaishouLinkResolver({required this.site});

  /// The site whose requests this resolver could drive.
  final KuaishouSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host != KuaishouEndpoints.host && host != 'live.kuaishou.cn') {
      return left(LiveSiteError.unsupported(siteId: kuaishouSiteId, message: 'not a kuaishou link: $uri'));
    }
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    final id = roomIdOf(segments);
    if (id == null) {
      return left(LiveSiteError.notFound(siteId: kuaishouSiteId, message: 'no room in kuaishou link: $uri'));
    }
    return right(Uri.parse(KuaishouEndpoints.roomPageUrl(id)));
  }

  /// The streamer id a room page path names: `/u/{id}` with an id of letters,
  /// digits, `_` or `-` (the generated `3d/3x…` forms included); null for
  /// anything else.
  static String? roomIdOf(List<String> segments) {
    if (segments.length < 2 || segments.first.toLowerCase() != 'u') return null;
    final id = segments[1].trim();
    return _roomIdPattern.hasMatch(id) ? id : null;
  }
}

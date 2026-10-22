import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a douyu room link — a bare rid (`/9999`), a 靓号, an alias
/// (`/lpl`) or a share page (`/room/share/9999`) — to the canonical
/// `https://www.douyu.com/<rid>` page, mapping an alias or 靓号 through the
/// room page like the rest of the adapter (a share page names the rid in its
/// third segment; the site's rid cache makes a repeat free).
final class DouyuLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its rid cache and room-page fetch).
  DouyuLinkResolver({required this.site});

  /// The site whose rid mapping this resolver drives.
  final DouyuSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host != 'douyu.com' && !host.endsWith('.douyu.com')) {
      return left(LiveSiteError.unsupported(siteId: douyuSiteId, message: 'not a douyu link: $uri'));
    }
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) {
      return left(LiveSiteError.notFound(siteId: douyuSiteId, message: 'no room in douyu link: $uri'));
    }
    // A share page (`/room/share/<number>`) names the room in its third part.
    final share = segments.length == 3 && segments[0] == 'room' && segments[1] == 'share';
    final key = share ? segments[2] : segments[0];
    if (!DouyuRoomParser.isRoomKey(key)) {
      return left(LiveSiteError.notFound(siteId: douyuSiteId, message: 'no room in douyu link: $uri'));
    }
    try {
      final rid = await site.ridFor(key);
      if (rid == null) {
        return left(LiveSiteError.notFound(siteId: douyuSiteId, message: 'douyu link resolves to no room: $key'));
      }
      return right(Uri.https('www.douyu.com', '/$rid'));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError(douyuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyuSiteId, message: '$error', cause: error));
    }
  }
}

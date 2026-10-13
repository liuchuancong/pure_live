import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a Bilibili room link to its canonical `https://live.bilibili.com/
/// {room_id}` page:
///
/// - `live.bilibili.com/{id}`, `/h5/{id}` and `/blanc/{id}`, and the old
///   `www.bilibili.com/{id}` alias name the room in the address itself;
/// - a `b23.tv` short link is followed once (a browser UA) and the room read
///   from where it lands — its `Location`, or the room id the landing page
///   carries;
/// - any other host is not a room of this platform (`space.bilibili.com/{uid}`
///   is a profile, not a room).
final class BilibiliLinkResolver implements LiveLinkResolver {
  /// Resolves through [site]'s transport.
  BilibiliLinkResolver({required this.site});

  /// The site whose requests this resolver drives.
  final BilibiliSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    final direct = BilibiliSite.roomIdFromUrl('$uri');
    if (direct != null) return right(Uri.https(BilibiliEndpoints.liveHost, '/$direct'));
    if (!_owns(host)) {
      return left(LiveSiteError.unsupported(siteId: 'bilibili', message: 'not a bilibili link: $uri'));
    }
    // A short link: the transport lands on the room page (another b23.tv hop
    // included), which names its room in the Location or in its own text.
    try {
      final response = await site.httpGet(uri, headers: BilibiliEndpoints.shortLinkHeaders);
      final target = BilibiliHttp.header(response.headers, 'location');
      final fromLocation = target == null ? null : BilibiliSite.roomIdFromUrl(target);
      final id = fromLocation ?? _roomInPage(response);
      if (id == null) {
        return left(LiveSiteError.notFound(siteId: 'bilibili', message: 'bilibili link resolves to no room: $uri'));
      }
      return right(Uri.https(BilibiliEndpoints.liveHost, '/$id'));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError('bilibili'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'bilibili', message: '$error', cause: error));
    }
  }

  /// The room a landing page names: a `live.bilibili.com/{id}` address in its
  /// text, else the `"room_id":123` its state carries.
  static String? _roomInPage(BilibiliResponse response) {
    if (response.status < 200 || response.status >= 300) return null;
    for (final pattern in [RegExp(r'live\.bilibili\.com/(\d{1,18})'), RegExp(r'"room_id":\s*(\d{1,18})')]) {
      for (final match in pattern.allMatches(response.text)) {
        final id = BilibiliSite.roomNumber(match.group(1) ?? '');
        if (id != null) return id;
      }
    }
    return null;
  }

  /// Whether [host] is one of Bilibili's: the live and www pages and the
  /// short-link host.
  static bool _owns(String host) =>
      host == BilibiliEndpoints.liveHost ||
      host == 'bilibili.com' ||
      host == 'www.bilibili.com' ||
      host == BilibiliEndpoints.shortLinkHost ||
      host.endsWith('.${BilibiliEndpoints.shortLinkHost}');
}

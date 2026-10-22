import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_http.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a douyin room link to its canonical `https://live.douyin.com/
/// {web_rid}` page:
///
/// - `live.douyin.com/{digits}` (one segment) and `www.douyin.com/{1–20
///   digits}` name the room in the address itself — a video, a search page or
///   the bare site are not rooms;
/// - a `webcast.amemv.com/…/reflow/{room_id}` link is a broadcast, so the
///   reflow request turns it into the owner's web_rid (and the room_id stands
///   when that answer is refused);
/// - a `v.douyin.com` share link is followed and the room read out of the
///   answer it lands on (its `Location`, a reflow body, or the room page's
///   own state).
final class DouyinLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its transports and reflow request).
  DouyinLinkResolver({required this.site});

  /// The site whose requests this resolver drives.
  final DouyinSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    // The webcast fallback host (reflow links) belongs to Douyin too.
    if (!_owns(host)) {
      return left(LiveSiteError.unsupported(siteId: douyinSiteId, message: 'not a douyin link: $uri'));
    }
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) {
      return left(LiveSiteError.notFound(siteId: douyinSiteId, message: 'no room in douyin link: $uri'));
    }
    final direct = _roomIdOf(host, segments);
    if (direct != null) return right(Uri.https(DouyinEndpoints.liveHost, '/$direct'));
    final broadcast = DouyinRoomParser.broadcastIdInPath(uri.path);
    if (broadcast != null) {
      final webRid = await site.reflowWebRid(broadcast) ?? broadcast;
      return right(Uri.https(DouyinEndpoints.liveHost, '/$webRid'));
    }
    if (host != 'v.douyin.com' && host != DouyinEndpoints.webHost && host != DouyinEndpoints.amemvHost) {
      return left(LiveSiteError.notFound(siteId: douyinSiteId, message: 'no room in douyin link: $uri'));
    }
    try {
      // The transport follows the share link itself, so the room is read out
      // of the answer it lands on.
      final response = await site.httpGet(uri, headers: DouyinSite.shareHeaders);
      final location = DouyinHttp.header(response.headers, 'location');
      final target = location == null ? null : Uri.tryParse(location);
      final fromLocation = target == null
          ? null
          : _roomIdOf(target.host.toLowerCase(), [
              for (final s in target.pathSegments)
                if (s.isNotEmpty) s,
            ]);
      final found =
          fromLocation ?? DouyinRoomParser.reflowWebRid(response.text) ?? DouyinRoomParser.roomIdInPage(response.text);
      if (found == null) {
        return left(LiveSiteError.notFound(siteId: douyinSiteId, message: 'douyin link resolves to no room: $uri'));
      }
      return right(Uri.https(DouyinEndpoints.liveHost, '/$found'));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
    }
  }

  /// The room a path names on [host]: one numeric segment on the live host
  /// (any length) or on www (1–20 digits, the web client's rule).
  static String? _roomIdOf(String host, List<String> segments) {
    if (segments.length != 1) return null;
    final single = segments.single;
    return switch (host) {
      DouyinEndpoints.liveHost => RegExp(r'^\d+$').hasMatch(single) ? single : null,
      DouyinEndpoints.webHost => RegExp(r'^\d{1,20}$').hasMatch(single) ? single : null,
      _ => null,
    };
  }

  /// Whether [host] is one of Douyin's: the web, live and share domains, and
  /// the webcast fallback domain the reflow links live on.
  static bool _owns(String host) =>
      host == 'douyin.com' || host.endsWith('.douyin.com') || host == 'amemv.com' || host.endsWith('.amemv.com');
}

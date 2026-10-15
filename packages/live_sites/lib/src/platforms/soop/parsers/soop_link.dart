import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';

/// The streamer a SOOP page link names, or null.
///
/// A streamer page on a SOOP host carries the id as its first path segment
/// (`play.sooplive.co.kr/{id}/{broadcast}`, `ch.sooplive.co.kr/{id}`,
/// `www.sooplive.com/{id}`, and on the former domain `afreecatv.com/{id}`,
/// `play.afreecatv.com/{id}`), or as the segment after `station`
/// (`www.sooplive.co.kr/station/{id}`). Ids are lower case, as the platform
/// writes them. Search, VOD and other pages are not rooms.
abstract final class SoopLink {
  /// The streamer id [uri] names (lower case), or null: another host, a
  /// page of a SOOP host that is no streamer page, or a segment that is not
  /// a streamer id.
  static String? roomIdFromUrl(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
    final host = uri.host.toLowerCase();
    if (!SoopEndpoints.linkHosts.any((root) => host == root || host.endsWith('.$root'))) return null;
    var segments = uri.pathSegments.where((segment) => segment.trim().isNotEmpty).toList(growable: false);
    if (segments.isNotEmpty && segments.first.toLowerCase() == 'station') {
      segments = segments.sublist(1);
    }
    if (segments.isEmpty) return null;
    final id = segments.first.trim().toLowerCase();
    if (id.isEmpty ||
        SoopEndpoints.reservedSegments.contains(id) ||
        SoopEndpoints.pageSegments.contains(id) ||
        id == 'station' ||
        !SoopEndpoints.roomIdPattern.hasMatch(id)) {
      return null;
    }
    return id;
  }

  /// Whether [host] is one of SOOP's (a subdomain of a [SoopEndpoints
  /// .linkHosts] root), so a link there that names no room is this site's.
  static bool isOwnHost(String host) => SoopEndpoints.linkHosts.any((root) => host == root || host.endsWith('.$root'));
}

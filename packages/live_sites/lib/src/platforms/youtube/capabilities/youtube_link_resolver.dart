import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_endpoints.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A channel a link names: either its `UC…` browse id (a canonical live URL can
/// be built at once), or the page URL that must be resolved to the current
/// broadcast through `navigation/resolve_url`.
typedef YoutubeChannel = ({String? browseId, String? resolveUrl});

/// Resolves a YouTube link to its canonical room URL.
///
/// A video address (`watch?v=`, `live/`, `embed/`, `v/`, `youtu.be/`) becomes
/// `https://www.youtube.com/watch?v={id}`; a channel address (a `UC…` id, an
/// `embed/live_stream?channel=` id) becomes `https://www.youtube.com/
/// channel/{id}/live`; a handle, `c/` or `user/` channel is resolved through
/// `navigation/resolve_url` to its current live broadcast. Hosts outside
/// `youtube.com` (and its `m.`/`www.`/subdomains), `youtube-nocookie.com` and
/// `youtu.be` are not YouTube links at all (unsupported); a YouTube page that
/// names no room is not-found.
final class YoutubeLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (whose `resolve_url` turns a handle into a live
  /// broadcast).
  YoutubeLinkResolver({required this.site});

  /// The site whose `resolve_url` request this resolver drives.
  final YoutubeSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (!isYoutubeHost(host)) {
      return left(LiveSiteError.unsupported(siteId: 'youtube', message: 'not a youtube link: $uri'));
    }
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    final video = videoIdOf(host, segments, uri.queryParameters);
    if (video != null) return right(YoutubeEndpoints.watchUri(video));
    final channel = channelOf(segments, uri.queryParameters);
    if (channel == null) {
      return left(LiveSiteError.notFound(siteId: 'youtube', message: 'no room in youtube link: $uri'));
    }
    final browseId = channel.browseId;
    if (browseId != null) return right(Uri.parse('${YoutubeEndpoints.origin}/channel/$browseId/live'));
    final url = channel.resolveUrl;
    if (url == null) {
      return left(LiveSiteError.notFound(siteId: 'youtube', message: 'no room in youtube link: $uri'));
    }
    try {
      final resolved = await site.resolveUrl(url);
      final videoId = resolved.videoId;
      if (videoId != null) return right(YoutubeEndpoints.watchUri(videoId));
      final id = resolved.browseId;
      if (id != null) return right(Uri.parse('${YoutubeEndpoints.origin}/channel/$id/live'));
      return left(LiveSiteError.notFound(siteId: 'youtube', message: 'youtube link resolves to no room: $uri'));
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError('youtube'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'youtube', message: '$error', cause: error));
    }
  }

  /// Whether [host] is a YouTube host: `youtu.be`, `youtube.com` or
  /// `youtube-nocookie.com` (with or without a subdomain such as `www.`).
  static bool isYoutubeHost(String host) {
    final lower = host.toLowerCase();
    if (lower == 'youtu.be') return true;
    return lower == 'youtube.com' ||
        lower.endsWith('.youtube.com') ||
        lower == 'youtube-nocookie.com' ||
        lower.endsWith('.youtube-nocookie.com');
  }

  /// The video id a [host]/[segments]/[query] address names directly (a valid
  /// 11-character id), or null: `youtu.be/{id}`, `watch?v={id}`, and
  /// `live|embed|v|shorts/{id}`.
  static String? videoIdOf(String host, List<String> segments, Map<String, String> query) {
    if (host == 'youtu.be' && segments.isNotEmpty) {
      return _video(segments.first);
    }
    final fromQuery = _video(query['v']);
    if (fromQuery != null && segments.isNotEmpty && segments.first == 'watch') return fromQuery;
    if (segments.length >= 2 && const {'live', 'embed', 'v', 'shorts'}.contains(segments.first.toLowerCase())) {
      return _video(segments[1]);
    }
    return null;
  }

  /// The channel a [segments]/[query] address names: a `UC…` browse id
  /// (`channel/UC…`, `embed/live_stream?channel=UC…`), else the live URL of a
  /// handle / `c` / `user` channel to resolve. Null when the address names no
  /// channel.
  static YoutubeChannel? channelOf(List<String> segments, Map<String, String> query) {
    if (segments.length >= 2 && segments.first.toLowerCase() == 'embed' && segments[1].toLowerCase() == 'live_stream') {
      final id = _channel(query['channel']);
      if (id != null) return (browseId: id, resolveUrl: null);
    }
    if (segments.length >= 2 && segments.first.toLowerCase() == 'channel') {
      final id = _channel(segments[1]);
      if (id != null) return (browseId: id, resolveUrl: null);
      return (browseId: null, resolveUrl: _channelLiveUrl(segments));
    }
    final head = segments.isEmpty ? '' : segments.first;
    if (head.startsWith('@') || (segments.length >= 2 && const {'c', 'user'}.contains(segments.first.toLowerCase()))) {
      return (browseId: null, resolveUrl: _channelLiveUrl(segments));
    }
    return null;
  }

  /// The live URL of a channel path ([segments]) — the handle or `c`/`user`
  /// page with `/live` appended. A leading `@` handle keeps its sigil (only its
  /// body is percent-encoded).
  static String _channelLiveUrl(List<String> segments) {
    final path = [for (final (index, segment) in segments.indexed) _encodeSegment(segment, index)].join('/');
    final lower = path.toLowerCase();
    final trimmed = lower.endsWith('/live') ? path.substring(0, path.length - '/live'.length) : path;
    return '${YoutubeEndpoints.origin}/$trimmed/live';
  }

  static String _encodeSegment(String segment, int index) {
    if (index == 0 && segment.startsWith('@')) return '@${Uri.encodeComponent(segment.substring(1))}';
    return Uri.encodeComponent(segment);
  }

  static String? _video(Object? value) {
    final id = value?.toString().trim() ?? '';
    return YoutubeEndpoints.videoIdPattern.hasMatch(id) ? id : null;
  }

  static String? _channel(Object? value) {
    final id = value?.toString().trim() ?? '';
    return YoutubeEndpoints.channelIdPattern.hasMatch(id) ? id : null;
  }
}

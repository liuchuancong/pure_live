import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/youtube_manifest.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YouTube's `search`: live videos for a keyword, the "Live" filter sent as the
/// hard-coded InnerTube `params` token on the first page and a continuation
/// token on every later one.
///
/// Continuation paging is stateful on the server (a page is asked with the
/// token the previous page returned), so a request for page N walks pages 1..N
/// from a fresh first page and answers with the last one. `hasMore` is the
/// presence of a continuation token.
final class YoutubeSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  YoutubeSearchProvider({required this.site});

  /// The site this capability serves.
  final YoutubeSite site;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      return left(
        LiveSiteError.unsupported(siteId: youtubeSiteId, message: 'search target ${request.target.name} not supported'),
      );
    }
    final text = request.query.trim();
    if (text.isEmpty) return right(LivePage.of(items: []));
    try {
      final page = request.page < 1 ? 1 : request.page;
      final size = request.pageSize < 1 ? 0 : request.pageSize;
      final result = await _page(text, page);
      final items = [for (final room in result.rooms.take(size)) LiveSearchResult.room(room)];
      return right(LivePage.of(items: items, hasMore: result.hasMore));
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError(youtubeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: youtubeSiteId, message: '$error', cause: error));
    }
  }

  Future<({List<LiveRoom> rooms, bool hasMore})> _page(String query, int page) async {
    var rooms = const <LiveRoom>[];
    var continuation = '';
    var hasMore = false;
    for (var number = 1; number <= page; number++) {
      final result = await site.searchPage(query, continuation: number == 1 ? null : continuation);
      rooms = result.rooms;
      continuation = result.continuation ?? '';
      hasMore = continuation.isNotEmpty;
    }
    return (rooms: rooms, hasMore: hasMore);
  }
}

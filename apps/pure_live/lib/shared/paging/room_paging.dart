import 'dart:math' as math;

import 'package:fpdart/fpdart.dart' show Either, right;
import 'package:live_sites/live_sites.dart';

/// The rooms one recommendations request asks [platform] for.
///
/// The reference tuned these to the platforms' own windows (3.x's
/// `popularWindowSizes`): Douyu's `allpage` answers 40 whatever is asked,
/// Huya's list ~120, SOOP 60, TwitCasting a 60-room window, Twitch and CC
/// 100, Douyin 20. The rest are asked the adapters' default 30. The request
/// size stays constant for a whole walk — it is never the viewer's display
/// page size, so changing that size cannot slide the server's page
/// boundaries under an open feed.
int roomFeedRequestSize(String platform) => switch (platform) {
  SiteIds.douyu => 40,
  SiteIds.huya => 120,
  SiteIds.soop => 60,
  SiteIds.twitcasting => 60,
  SiteIds.twitch => 100,
  SiteIds.cc => 100,
  SiteIds.douyin => 20,
  _ => 30,
};

/// The rooms one area request asks [platform] for (the reference's
/// `areaRoomPageSize`): SOOP and TwitCasting take 60, the rest 30.
int areaRequestSize(String platform) => switch (platform) {
  SiteIds.soop || SiteIds.twitcasting => 60,
  _ => 30,
};

/// The rooms one search request asks every platform for. Search pages stay
/// server pages — there is no local slicing to price a viewer-chosen size
/// against — so the request window is fixed (30, the adapters' default).
const int searchRequestSize = 30;

/// One room feed's walk through a platform: the source page and cursor it
/// asks next, whether the end was reached, and how many pages in a row
/// brought no new room.
///
/// The walk owns the platform-specific part the callers must not repeat:
/// a cursor is passed back while it moves (a cursor that does not move
/// would ask the same page forever), rooms are deduped against the seen
/// set by identity, and two unchanged pages end the walk even when the platform
/// keeps claiming more — the reference's `RoomFeed` rule. The request
/// [pageSize] is fixed for the walk's life.
final class RoomWalk {
  /// Starts at the platform's first page with [pageSize] rooms per request.
  RoomWalk({required this.fetch, required this.pageSize});

  /// Asks one page; the caller's capability call.
  final Future<Either<LiveSiteError, LivePage<LiveRoom>>> Function(LivePageRequest request) fetch;

  /// Rooms per request; never the viewer's display page size.
  final int pageSize;

  int _page = 1;
  String? _cursor;
  bool _ended = false;
  int _stagnant = 0;

  /// Whether the platform may still have rooms.
  bool get hasMore => !_ended;

  /// The page the next request asks.
  int get nextPage => _page;

  /// The cursor the next request carries, when the platform gave one.
  String? get cursor => _cursor;

  /// Asks the next page and answers the rooms [seen] had not held.
  ///
  /// A failure leaves the walk where it was, so a retry asks the same page
  /// again; [seen] is only written when the page arrived.
  Future<Either<LiveSiteError, List<LiveRoom>>> next(Set<String> seen) async {
    if (_ended) return right(const []);
    final answer = await fetch(LivePageRequest.of(page: _page, pageSize: pageSize, cursor: _cursor));
    return answer.map((page) {
      _page++;
      final next = page.nextCursor;
      if (next != null) {
        if (next == _cursor) {
          // A cursor that stayed put would refetch this page forever.
          _ended = true;
        } else {
          _cursor = next;
        }
      }
      final fresh = <LiveRoom>[];
      for (final room in page.items) {
        if (seen.add(room.identityKey)) fresh.add(room);
      }
      _stagnant = fresh.isEmpty ? _stagnant + 1 : 0;
      final more = page.hasMore ?? page.items.isNotEmpty;
      if (!more || _stagnant >= 2) _ended = true;
      return fresh;
    });
  }
}

/// Fetches from [walk] into [rooms] until it holds [target] rooms, the walk
/// ends, or [maxRequests] pages were asked.
///
/// Answers the failure that stopped the walk; [rooms] keeps what arrived
/// before it. [seen] dedupes across calls, so it must be the set [rooms]
/// was built from.
Future<LiveSiteError?> fillRoomFeed({
  required RoomWalk walk,
  required List<LiveRoom> rooms,
  required Set<String> seen,
  required int target,
  int maxRequests = 20,
  void Function()? onProgress,
}) async {
  var requests = 0;
  while (rooms.length < target && walk.hasMore && requests < maxRequests) {
    final answer = await walk.next(seen);
    final failure = answer.fold<LiveSiteError?>((error) => error, (fresh) {
      rooms.addAll(fresh);
      return null;
    });
    if (failure != null) return failure;
    // Each page is handed over before the next is asked, so a later
    // failure never strands rooms the walk has already moved past.
    onProgress?.call();
    requests++;
  }
  return null;
}

/// The last page of pageSize rooms an accumulated list can show.
int roomLastPage(int roomCount, int pageSize) =>
    roomCount <= 0 ? 1 : math.max(1, (roomCount + pageSize - 1) ~/ pageSize);

/// Page [page] (1-based) of pageSize rooms sliced from [rooms].
///
/// A page past the end is empty — callers clamp against roomLastPage
/// first when they need the last real page instead.
List<LiveRoom> roomPageOf(List<LiveRoom> rooms, int page, int pageSize) {
  if (page < 1 || pageSize < 1) return const [];
  final start = (page - 1) * pageSize;
  if (start >= rooms.length) return const [];
  return rooms.sublist(start, math.min(start + pageSize, rooms.length));
}

/// The numeric page count a pager should offer: every locally available
/// page, plus one more when the platform may still have rooms.
int roomPageCount({required int page, required int roomCount, required int pageSize, required bool hasMore}) {
  final known = roomLastPage(roomCount, pageSize);
  return hasMore ? math.max(page + 1, known) : known;
}

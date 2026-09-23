import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_room.dart';

import 'live_site.dart';

/// Optional search transport cancellation. Implementations forward the token
/// without closing a shared client. Legacy adapters keep their existing API.
abstract interface class LiveCancellableSearch {
  Future<List<LiveRoom>> searchRoomsCancellable(String keyword, {int page = 1, int pageSize = 30, CancelToken? cancel});
}

/// Optional per-query pagination rule for adapters that combine exact lookup
/// (one result) with a paged keyword source.
abstract interface class LiveSearchPaginationPolicy {
  bool supportsSearchPaginationFor(String keyword);
}

extension LiveSiteSearch on LiveSite {
  Future<List<LiveRoom>> searchRoomsWithCancellation(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) async {
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    final site = this;
    final rooms = site is LiveCancellableSearch
        ? await (site as LiveCancellableSearch).searchRoomsCancellable(
            keyword,
            page: page,
            pageSize: pageSize,
            cancel: cancel,
          )
        : await searchRooms(keyword, page: page, pageSize: pageSize);
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    return rooms;
  }
}

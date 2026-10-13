import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyin's API search.
///
/// Rooms take three paths, each tried when the one before failed or found
/// nothing: the live search, the general search (both need a signed-in
/// cookie — an anonymous request answers 2483), then the rooms of the first
/// [matchedPartitions] partitions whose name matches the keyword. The failure
/// of the last path is reported rather than an empty page.
final class DouyinSearchProvider implements LiveSearchProvider {
  /// Serves [site].
  DouyinSearchProvider({required this.site});

  /// The site this capability serves.
  final DouyinSite site;

  /// Partitions a keyword-matched area search asks for rooms.
  static const int matchedPartitions = 3;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms, LiveSearchTarget.areas};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    if (!supportedTargets.contains(request.target)) {
      // The contract promises `unsupported` for a target this site does not
      // search, whatever the keyword is — so it is checked before the blank
      // keyword short-circuit below.
      return left(
        LiveSiteError.unsupported(siteId: 'douyin', message: 'search target ${request.target.name} not supported'),
      );
    }
    final text = request.query.trim();
    if (text.isEmpty) {
      // The platform answers a blank keyword with an error; the caller gets
      // a successful empty page instead of a round trip.
      return right(const LivePage(items: []));
    }
    try {
      final items = request.target == LiveSearchTarget.rooms
          ? await _rooms(request, text)
          : [for (final area in await matchedAreas(text)) LiveSearchResult.area(area)];
      return right(LivePage(items: items));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError('douyin'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyin', message: '$error', cause: error));
    }
  }

  Future<List<LiveSearchResult>> _rooms(LiveSearchRequest request, String text) async {
    final count = request.pageSize.clamp(1, 50);
    final offset = count * ((request.page < 1 ? 1 : request.page) - 1);
    final cookie = await site.cookie();
    final headers = site.searchHeaders(text, cookie);
    for (final uri in [
      DouyinEndpoints.liveSearch(text, count: count, offset: offset),
      DouyinEndpoints.generalSearch(text, count: count, offset: offset),
    ]) {
      try {
        final response = await site.httpGet(uri, headers: headers);
        final rooms = DouyinRoomParser.searchRooms(response.text, status: response.status, headers: response.headers);
        if (rooms.isNotEmpty) return [for (final item in rooms) LiveSearchResult.room(item.room)];
      } on DouyinFailure {
        // The next path, then the partition fallback.
      }
    }
    return await _byPartition(text, count: count, offset: offset, cookie: cookie);
  }

  Future<List<LiveSearchResult>> _byPartition(
    String text, {
    required int count,
    required int offset,
    required String cookie,
  }) async {
    final areas = await matchedAreas(text);
    final merged = <LiveSearchResult>[];
    final seen = <String>{};
    DouyinFailure? last;
    var answered = false;
    for (final area in areas.take(matchedPartitions)) {
      final List<LiveSearchItem> rooms;
      try {
        rooms = await _partitionRooms(area, count: count, offset: offset, cookie: cookie);
      } on DouyinFailure catch (failure) {
        last ??= failure;
        continue;
      }
      answered = true;
      for (final room in rooms) {
        if (!seen.add(room.room.roomId)) continue;
        merged.add(LiveSearchResult.room(room.room));
        if (merged.length >= count) return merged;
      }
    }
    if (!answered && last != null) throw last;
    return merged;
  }

  Future<List<LiveSearchItem>> _partitionRooms(
    LiveArea area, {
    required int count,
    required int offset,
    required String cookie,
  }) async {
    final partition = DouyinRoomParser.partition(area.areaId);
    try {
      final response = await site.httpGet(
        site.signer.signedUrl(
          DouyinEndpoints.partitionRooms(),
          DouyinEndpoints.partitionParams(partition, count: count, offset: offset),
        ),
        headers: site.searchHeaders('', cookie),
      );
      final rooms = DouyinRoomParser.partitionRooms(
        response.text,
        offset: offset,
        status: response.status,
        headers: response.headers,
      );
      if (rooms.rooms.isNotEmpty) return [for (final room in rooms.rooms) (room: room, roomId: room.roomId)];
    } on DouyinFailure {
      // The unsigned host below serves the same list.
    }
    final unsigned = await site.httpGet(
      DouyinEndpoints.amemvPartitionRooms(
        DouyinEndpoints.partitionParams(
          partition,
          count: count,
          offset: offset,
          browserName: 'Chrome',
          browserVersion: '120.0.0.0',
          screenWidth: 1920,
        ),
      ),
      headers: site.searchHeaders('', cookie),
    );
    final result = DouyinRoomParser.partitionRooms(
      unsigned.text,
      offset: offset,
      areaName: area.areaName,
      status: unsigned.status,
      headers: unsigned.headers,
    );
    return [for (final room in result.rooms) (room: room, roomId: room.roomId)];
  }

  /// The partitions whose name matches [text] (an anonymous request works):
  /// the areas a keyword search offers, with ids `id_str,type`.
  Future<List<LiveArea>> matchedAreas(String text) async {
    final cookie = await site.cookie();
    final response = await site.httpGet(
      DouyinEndpoints.partitionSearch(text),
      headers: site.searchHeaders(text, cookie),
    );
    return DouyinRoomParser.partitionSearch(response.text, status: response.status, headers: response.headers);
  }
}

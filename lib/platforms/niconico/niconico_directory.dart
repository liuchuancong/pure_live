import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_directory.dart';

import 'niconico_api.dart';
import 'niconico_watch.dart';

/// Observed recent tabs; `live` is the game category, not an all-live flag.
class NiconicoDirectory {
  NiconicoDirectory({NiconicoApi? api}) : _api = api ?? NiconicoApi();
  final NiconicoApi _api;
  static const categories = ['common', 'try', 'live', 'req', 'face', 'totu', 'vtuber'];
  static const recentSize = 70;
  static const searchSize = 40;

  static void validatePage(int page) {
    // Local resource bound, not a claim about the upstream search page limit.
    if (page < 1 || page > 10000) throw const NiconicoException(NiconicoFailure.schema);
  }

  Future<LiveDirectoryPage> recent({int page = 1, String tab = 'common', CancelToken? cancel}) async {
    validatePage(page);
    if (!categories.contains(tab)) throw const NiconicoException(NiconicoFailure.schema);
    final body = await _api.listing(
      path: '/front/api/pages/recent/v1/programs',
      query: {'tab': tab, 'offset': '${page - 1}', 'sortOrder': 'recentDesc'},
      cancel: cancel,
    );
    return parse(body, page: page, search: false);
  }

  Future<LiveDirectoryPage> search(String keyword, {int page = 1, CancelToken? cancel}) async {
    validatePage(page);
    if (keyword.length > 500) throw const NiconicoException(NiconicoFailure.schema);
    final term = keyword.trim();
    if (term.isEmpty) return LiveDirectoryPage(rooms: const [], page: page, hasMore: false);
    final body = await _api.listing(
      path: '/front/api/pages/search/v1/programs',
      query: {'keyword': term, 'column': 'main', 'status': 'onair', 'page': '$page', 'disableGrouping': 'true'},
      cancel: cancel,
    );
    return parse(body, page: page, search: true);
  }

  static LiveDirectoryPage parse(String body, {required int page, required bool search}) {
    validatePage(page);
    if (body.length > NiconicoWatch.responseLimit || utf8.encode(body).length > NiconicoWatch.responseLimit) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    try {
      final root = _object(jsonDecode(body));
      final meta = _object(root['meta']);
      if (meta['statusCode'] != 200 || meta['errorCode'] != 'OK') {
        throw const NiconicoException(NiconicoFailure.service);
      }
      final data = search ? _object(root['data']) : meta;
      final total = _count(data['totalCount']);
      final rows = search ? data['programs'] : root['data'];
      final size = search ? searchSize : recentSize;
      if (rows is! List || rows.length > size || total == null || total < rows.length) {
        throw const NiconicoException(NiconicoFailure.schema);
      }
      final identities = <String>{};
      final rooms = <LiveRoom>[];
      for (final row in rows) {
        final room = _room(_object(row), search: search);
        if (!identities.add(room.roomId!)) throw const NiconicoException(NiconicoFailure.identity);
        rooms.add(room);
      }
      // Use totalCount rather than a short row count. No shared mutable cursor,
      // account state, watch bootstrap or seat is allocated by directory reads.
      return LiveDirectoryPage(rooms: rooms, page: page, hasMore: total > page * size);
    } on FormatException {
      throw const NiconicoException(NiconicoFailure.schema);
    }
  }

  static LiveRoom _room(Map<String, dynamic> row, {required bool search}) {
    final id = NiconicoWatch.validateProgramId(_text(row[search ? 'nicoliveProgramId' : 'id']));
    if (NiconicoWatch.parseInput(_text(row['watchPageUrl'])) != id) {
      throw const NiconicoException(NiconicoFailure.identity);
    }
    if (row[search ? 'status' : 'liveCycle'] != 'ON_AIR') {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    if (!const {'community', 'channel', 'official'}.contains(row['providerType'])) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    final provider = search ? row['supplier'] : row['programProvider'];
    final social = row['socialGroup'];
    final name = provider is Map ? provider['name'] : null;
    final nick = name ?? (social is Map ? social['name'] : null);
    Object? icon;
    if (provider is Map) {
      final icons = provider['icons'];
      icon = search ? (icons is Map ? icons['uri150x150'] : null) : provider['icon'];
    }
    icon ??= social is Map ? social['thumbnailUrl'] : null;
    final count = _count(_object(row['statistics'])['watchCount']);
    return LiveRoom(
      platform: 'niconico',
      roomId: id,
      title: _text(row['title']),
      nick: _text(nick),
      avatar: NiconicoWatch.publicImage(icon) ?? '',
      cover:
          NiconicoWatch.publicImage(row['flippedListingThumbnail']) ??
          NiconicoWatch.publicImage(row['listingThumbnail']) ??
          '',
      link: '${NiconicoApi.origin}/watch/$id',
      liveStatus: LiveStatus.live,
      totalViewers: count?.toString(),
      audienceMetricType: AudienceMetricType.totalViewers,
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw const NiconicoException(NiconicoFailure.schema);
    return value;
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    return value;
  }

  static int? _count(Object? value) {
    if (value == null) return null;
    if (value is! int || value < 0 || value > 9007199254740991) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    return value;
  }
}

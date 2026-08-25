import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/douyin/douyin_audience.dart';

class DouyinSearch {
  static const String host = 'https://live.douyin.com';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const Map<String, dynamic> defaultHeaders = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };

  static String _cookie = '';
  static Future<String>? _cookieRequest;
  static String _configuredCookieSnapshot = '';

  static Future<String> _getCookie() async {
    if (_cookie.isNotEmpty) {
      return _cookie;
    }

    final configuredCookie = SettingsService.to.cookieManager.douyinCookie.v.trim();

    if (configuredCookie.isNotEmpty) {
      _configuredCookieSnapshot = configuredCookie;
      _cookie = configuredCookie;
      return _cookie;
    }

    // A user may clear or replace the account cookie while the process stays
    // alive. Do not keep searching with the old authenticated session.
    if (_configuredCookieSnapshot.isNotEmpty) {
      _configuredCookieSnapshot = '';
      _cookie = '';
    }

    try {
      final cookie = await (_cookieRequest ??= _fetchCookie());
      _cookieRequest = null;

      if (cookie.isNotEmpty) {
        _cookie = cookie;
      }

      return _cookie;
    } catch (e) {
      _cookieRequest = null;
      CoreLog.error(e);
      return '';
    }
  }

  static Future<String> _fetchCookie() async {
    try {
      final response = await HttpClient.instance.get(
        host,
        queryParameters: const {'from_nav': '1'},
        header: defaultHeaders,
      );

      final setCookieValues = response.headers.map['set-cookie'] ?? const <String>[];

      final cookies = <String>[];

      for (final value in setCookieValues) {
        final cookie = value.split(';').first.trim();

        if (cookie.startsWith('ttwid=') || cookie.startsWith('UIFID_TEMP=')) {
          cookies.add(cookie);
        }
      }

      return cookies.join('; ');
    } catch (e) {
      CoreLog.error(e);
      return '';
    }
  }

  static Future<Map<String, dynamic>> _getHeaders(String keyword) async {
    final cookie = await _getCookie();

    return {
      ...defaultHeaders,
      'Referer': 'https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?source=switch_tab&type=live',
      'Origin': 'https://www.douyin.com',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
      if (cookie.isNotEmpty) 'Cookie': cookie,
    };
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static dynamic _mapValue(dynamic value, String key) {
    final map = _asMap(value);
    return map?[key];
  }

  static Map<String, dynamic>? _parseRawLiveData(dynamic item) {
    final itemMap = _asMap(item);

    if (itemMap == null) {
      return null;
    }

    final candidates = <dynamic>[
      _mapValue(_mapValue(itemMap, 'lives'), 'rawdata'),
      _mapValue(_mapValue(itemMap, 'lives'), 'raw_data'),
      _mapValue(_mapValue(itemMap, 'live'), 'rawdata'),
      _mapValue(_mapValue(itemMap, 'live_info'), 'rawdata'),
      _mapValue(_mapValue(_mapValue(itemMap, 'aweme_info'), 'live_info'), 'rawdata'),
      _mapValue(_mapValue(itemMap, 'data'), 'rawdata'),
      itemMap['rawdata'],
      itemMap['lives'],
      itemMap['live'],
      itemMap['live_info'],
      _mapValue(_mapValue(itemMap, 'aweme_info'), 'live_info'),
      itemMap['aweme_info'],
      itemMap['data'],
      itemMap,
    ];

    for (final candidate in candidates) {
      if (candidate is String) {
        try {
          final decoded = jsonDecode(candidate);

          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      } else {
        final map = _asMap(candidate);

        if (map != null) {
          return map;
        }
      }
    }

    return null;
  }

  static LiveRoom? _normalizeSearchItem(Map<String, dynamic>? raw, {Map<String, dynamic>? fallback}) {
    if (raw == null) {
      return null;
    }

    fallback ??= {};

    final room = _asMap(raw['room']) ?? {};
    final owner = _asMap(raw['owner']) ?? {};
    final roomOwner = _asMap(room['owner']) ?? {};

    final roomId = _firstNonEmpty([
      raw['id_str'],
      raw['room_id_str'],
      room['id_str'],
      room['id'],
      raw['room_id'],
      raw['roomId'],
    ]);

    if (roomId.isEmpty) {
      return null;
    }

    final webRid = _firstNonEmpty([owner['web_rid'], raw['web_rid'], roomOwner['web_rid']]);

    final nickname = _firstNonEmpty([owner['nickname'], raw['nickname'], roomOwner['nickname'], fallback['nickname']]);

    final title = _firstNonEmpty([raw['title'], room['title'], fallback['title'], nickname]);

    final cover = _asMap(raw['cover']);
    final roomCover = _asMap(room['cover']);
    final avatarLarge = _asMap(owner['avatar_large']);
    final avatarThumb = _asMap(owner['avatar_thumb']);

    final coverList = roomCover?['url_list'];
    final rawCoverList = cover?['url_list'];
    final avatarList = avatarLarge?['url_list'];
    final avatarThumbList = avatarThumb?['url_list'];

    String getFirstUrl(dynamic value) {
      if (value is List && value.isNotEmpty) {
        return value.first?.toString() ?? '';
      }

      return '';
    }

    final pic = _firstNonEmpty([
      getFirstUrl(avatarList),
      getFirstUrl(rawCoverList),
      getFirstUrl(coverList),
      raw['cover_url'],
    ]);

    final roomOnline = douyinOnlineViewers(room);
    final onlineViewers = roomOnline.isNotEmpty ? roomOnline : douyinOnlineViewers(raw);
    final roomTotal = douyinTotalViewers(room);
    final totalViewers = roomTotal.isNotEmpty ? roomTotal : douyinTotalViewers(raw);
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

    String? tagText;

    final partitionRoadMap = room['partition_road_map'];

    if (partitionRoadMap is List && partitionRoadMap.isNotEmpty) {
      final firstPartition = _asMap(partitionRoadMap.first);

      tagText = firstPartition?['title']?.toString();
    }

    tagText = _firstNonEmpty([raw['video_feed_tag'], tagText, _mapValue(raw['partition'], 'title'), fallback['tag']]);

    final status =
        (raw['status'] is num ? (raw['status'] as num).toInt() : int.tryParse(raw['status']?.toString() ?? '') ?? 0) ==
        2;

    // Keep a deterministic identity. A millisecond timestamp produced invalid
    // room links, changed between refreshes and could collide for adjacent
    // results. The internal room id is a stable fallback when web_rid is absent.
    final realWebRid = webRid.isNotEmpty ? webRid : roomId;

    final avatar = _firstNonEmpty([getFirstUrl(avatarThumbList), getFirstUrl(avatarList)]);

    return LiveRoom(
      roomId: realWebRid,
      title: title,
      cover: pic,
      nick: nickname.isNotEmpty ? nickname : '抖音直播',
      avatar: avatar,
      platform: Sites.douyinSite,
      area: tagText,
      status: status,
      liveStatus: status ? LiveStatus.live : LiveStatus.offline,
      watching: nativeAudience,
      totalViewers: totalViewers,
      onlineViewers: onlineViewers,
      audienceMetricType: totalViewers.isNotEmpty ? AudienceMetricType.totalViewers : AudienceMetricType.onlineViewers,
      link: 'https://live.douyin.com/$realWebRid',
    );
  }

  static List<LiveRoom> _extractSearchVideos(dynamic payload) {
    if (payload is! List) {
      return [];
    }

    final result = <LiveRoom>[];
    final seen = <String>{};

    for (final item in payload) {
      final raw = _parseRawLiveData(item);

      final itemMap = _asMap(item) ?? {};

      final room = _normalizeSearchItem(
        raw,
        fallback: {
          'nickname': itemMap['nickname'],
          'title': itemMap['title'] ?? itemMap['desc'],
          'tag': itemMap['search_keyword'],
        },
      );

      if (room == null) {
        continue;
      }

      if (seen.contains(room.roomId)) {
        continue;
      }

      seen.add(room.roomId!);
      result.add(room);
    }

    return result;
  }

  @visibleForTesting
  static List<LiveRoom> parseSearchPayloadForTesting(dynamic payload) => _extractSearchVideos(payload);

  static Future<List<LiveRoom>> _searchByLiveApi(String keyword, int page, int pageSize) async {
    final count = pageSize.clamp(1, 50).toInt();
    final offset = count * (page - 1);

    final headers = await _getHeaders(keyword);

    final params = {
      'device_platform': 'webapp',
      'aid': '6383',
      'channel': 'channel_pc_web',
      'search_channel': 'aweme_live',
      'search_source': 'switch_tab',
      'query_correct_type': '1',
      'need_filter_settings': '1',
      'list_type': 'single',
      'keyword': keyword,
      'offset': offset.toString(),
      'count': count.toString(),
      'os_version': '10',
    };

    final result = await HttpClient.instance.getJson(
      'https://www.douyin.com/aweme/v1/web/live/search/',
      queryParameters: params,
      header: headers,
    );

    if (result['status_code'] != 0) return [];
    return _extractSearchVideos(result['data']);
  }

  static Future<List<LiveRoom>> _searchByGeneralApi(String keyword, int page, int pageSize) async {
    final count = pageSize.clamp(1, 50).toInt();
    final offset = count * (page - 1);

    final headers = await _getHeaders(keyword);

    final params = {
      'device_platform': 'webapp',
      'aid': '6383',
      'channel': 'channel_pc_web',
      'search_channel': 'aweme_live',
      'keyword': keyword,
      'offset': offset.toString(),
      'count': count.toString(),
      'os_version': '10',
    };

    final result = await HttpClient.instance.getJson(
      'https://www.douyin.com/aweme/v1/web/general/search/stream/',
      queryParameters: params,
      header: headers,
    );

    if (result['status_code'] != 0) return [];
    return _extractSearchVideos(result['data']);
  }

  static Future<List<LiveRoom>> _searchByPartition(String keyword, int page, int pageSize) async {
    final headers = await _getHeaders(keyword);

    final result = await HttpClient.instance.getJson(
      'https://live.douyin.com/webcast/web/partition/search/',
      queryParameters: {'keyword': keyword, 'aid': '6383'},
      header: headers,
    );

    final data = _asMap(result['data']);

    final partitions = data?['SearchResult'];

    if (partitions is! List || partitions.isEmpty) {
      return [];
    }

    final merged = <LiveRoom>[];
    final seen = <String>{};

    for (var i = 0; i < partitions.length && i < 3; i++) {
      final partitionItem = _asMap(partitions[i]);

      if (partitionItem == null) {
        continue;
      }

      final partition = _asMap(partitionItem['partition']);

      if (partition == null) {
        continue;
      }

      final partitionId = partition['id_str']?.toString();
      final partitionType = partition['type'];

      if (partitionId == null || partitionId.isEmpty || partitionType == null) {
        continue;
      }

      try {
        final rooms = await _getPartitionRooms(partitionId, partitionType.toString(), page: page, pageSize: pageSize);

        for (final room in rooms) {
          if (seen.contains(room.roomId)) {
            continue;
          }

          seen.add(room.roomId!);

          if (room.area == null || room.area!.isEmpty) {
            merged.add(room.copyWith(area: partition['title']?.toString() ?? keyword));
          } else {
            merged.add(room);
          }

          if (merged.length >= pageSize) {
            return merged;
          }
        }
      } catch (e) {
        CoreLog.error(e);
      }
    }

    return merged;
  }

  static Future<List<LiveRoom>> _getPartitionRooms(
    String partition,
    String partitionType, {
    required int page,
    required int pageSize,
  }) async {
    final count = pageSize.clamp(1, 50).toInt();
    final params = {
      'aid': '6383',
      'app_name': 'douyin_web',
      'live_id': '1',
      'device_platform': 'web',
      'language': 'zh-CN',
      'browser_language': 'zh-CN',
      'browser_platform': 'Win32',
      'browser_name': 'Chrome',
      'browser_version': '120.0.0.0',
      'partition': partition,
      'partition_type': partitionType,
      'count': count.toString(),
      'offset': ((page - 1) * count).toString(),
      'cookie_enabled': 'true',
      'screen_width': '1920',
      'screen_height': '1080',
    };

    final headers = await _getHeaders('');

    final urls = [
      'https://live.douyin.com/webcast/web/partition/detail/room/v2/',
      'https://webcast.amemv.com/webcast/web/partition/detail/room/v2/',
    ];

    for (final url in urls) {
      try {
        final result = await HttpClient.instance.getJson(url, queryParameters: params, header: headers);

        if (result['status_code'] != 0) {
          continue;
        }

        final data = _asMap(result['data']);
        final list = data?['data'];

        if (list is! List || list.isEmpty) {
          continue;
        }

        final rooms = <LiveRoom>[];

        for (final item in list) {
          final itemMap = _asMap(item);

          if (itemMap == null) {
            continue;
          }

          final room = _asMap(itemMap['room']);

          if (room == null) {
            continue;
          }

          final owner = _asMap(room['owner']) ?? {};
          final cover = _asMap(room['cover']) ?? {};
          final avatar = _asMap(owner['avatar_thumb']) ?? {};
          final coverList = cover['url_list'];
          final avatarList = avatar['url_list'];

          final coverUrl = coverList is List && coverList.isNotEmpty ? coverList.first.toString() : '';

          final avatarUrl = avatarList is List && avatarList.isNotEmpty ? avatarList.first.toString() : '';

          final webRid = _firstNonEmpty([itemMap['web_rid'], owner['web_rid']]);

          final roomId = room['id_str']?.toString();

          if (roomId == null || roomId.isEmpty) {
            continue;
          }

          final rid = webRid.isNotEmpty ? webRid : roomId;

          final totalViewers = douyinTotalViewers(room);
          final onlineViewers = douyinOnlineViewers(room);
          final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

          rooms.add(
            LiveRoom(
              roomId: rid,
              title: room['title']?.toString() ?? '',
              cover: coverUrl,
              nick: owner['nickname']?.toString() ?? '',
              avatar: avatarUrl,
              platform: Sites.douyinSite,
              area: itemMap['tag_name']?.toString() ?? '',
              status: true,
              liveStatus: LiveStatus.live,
              watching: nativeAudience,
              totalViewers: totalViewers,
              onlineViewers: onlineViewers,
              audienceMetricType: totalViewers.isNotEmpty
                  ? AudienceMetricType.totalViewers
                  : AudienceMetricType.onlineViewers,
              link: 'https://live.douyin.com/$rid',
            ),
          );
        }

        return rooms;
      } catch (e) {
        CoreLog.error(e);
      }
    }

    return [];
  }

  static Future<List<LiveRoom>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final kw = keyword.trim();
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedPageSize = pageSize.clamp(1, 50).toInt();

    if (kw.isEmpty) {
      return [];
    }

    try {
      try {
        final result = await _searchByLiveApi(kw, normalizedPage, normalizedPageSize);

        if (result.isNotEmpty) {
          return result;
        }
      } catch (e) {
        CoreLog.error(e);
      }

      try {
        final result = await _searchByGeneralApi(kw, normalizedPage, normalizedPageSize);

        if (result.isNotEmpty) {
          return result;
        }
      } catch (e) {
        CoreLog.error(e);
      }

      return await _searchByPartition(kw, normalizedPage, normalizedPageSize);
    } catch (e) {
      CoreLog.error(e);
      return [];
    }
  }
}

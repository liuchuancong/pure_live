import 'dart:convert';
import 'dart:math';

import 'package:pure_live/core/common/http_client.dart';

typedef AcfunRequest = Future<Object?> Function(
  String method,
  String url, {
  Map<String, dynamic>? query,
  Map<String, dynamic>? body,
  Map<String, dynamic>? headers,
});

enum AcfunFailureKind { transport, service, schema, qualityUnavailable, paginationExpired }

/// Safe to log: never retains the response body, visitor credential or URL.
class AcfunApiException implements Exception {
  const AcfunApiException(this.kind, {this.result});

  final AcfunFailureKind kind;
  final int? result;

  @override
  String toString() => 'AcFun ${kind.name}${result == null ? '' : ' (result=$result)'}';
}

class AcfunDirectoryPage {
  const AcfunDirectoryPage(this.rooms, this.nextCursor, {this.categories = const []});
  final List<Map<String, dynamic>> rooms;
  final String? nextCursor;
  final List<AcfunCategoryFilter> categories;
}

class AcfunCategoryFilter {
  const AcfunCategoryFilter({required this.type, required this.id, required this.name, this.cover = ''});
  final int type;
  final int id;
  final String name;
  final String cover;

  String get query => encode(type, id);

  static String encode(int type, int id) {
    if (type < 0 || id < 0) throw const AcfunApiException(AcfunFailureKind.schema);
    return jsonEncode([
      {'filterType': type, 'filterId': id},
    ]);
  }
}

class AcfunStreamQuality {
  const AcfunStreamQuality({required this.id, required this.label, required this.rank, required this.urls});
  final String id;
  final String label;
  final int rank;
  final List<String> urls;
}

class AcfunPlayback {
  const AcfunPlayback({required this.liveId, required this.qualities});
  final String liveId;
  final List<AcfunStreamQuality> qualities;
}

class _VisitorSession {
  const _VisitorSession(this.did, this.userId, this.token, this.expiresAt);
  final String did;
  final String userId;
  final String token;
  final DateTime expiresAt;
}

/// Public, anonymous AcFun protocol. Directory/refresh reads never log in;
/// playback uses one short-lived, single-flight visitor session in memory.
class AcfunApi {
  AcfunApi({AcfunRequest? request, DateTime Function()? clock})
    : _request = request ?? _defaultRequest,
      _clock = clock ?? DateTime.now;

  static const origin = 'https://live.acfun.cn';
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const playHeaders = <String, String>{'User-Agent': userAgent, 'Referer': '$origin/'};
  final AcfunRequest _request;
  final DateTime Function() _clock;
  _VisitorSession? _visitor;
  Future<_VisitorSession>? _visitorInFlight;

  static Future<Object?> _defaultRequest(
    String method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
  }) => method == 'POST'
      ? HttpClient.instance.postJson(url, queryParameters: query, data: body, header: headers, formUrlEncoded: true)
      : HttpClient.instance.getJson(url, queryParameters: query, header: headers);

  Future<Map<String, dynamic>> _json(
    String method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
  }) async {
    Object? result;
    try {
      result = await _request(method, url, query: query, body: body, headers: headers ?? playHeaders);
    } catch (_) {
      throw const AcfunApiException(AcfunFailureKind.transport);
    }
    return object(result);
  }

  static Map<String, dynamic> object(Object? raw) {
    if (raw is String) {
      if (raw.length > 1024 * 1024) throw const AcfunApiException(AcfunFailureKind.schema);
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        throw const AcfunApiException(AcfunFailureKind.schema);
      }
    }
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const AcfunApiException(AcfunFailureKind.schema);
    }
    return Map<String, dynamic>.from(raw);
  }

  static int? integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) return value.toInt();
    return value is String ? int.tryParse(value.trim()) : null;
  }

  static String text(Object? value) => value is String ? value.trim() : (value is num ? value.toString() : '');

  static String imageUrl(Object? value) {
    var raw = text(value);
    if (raw.startsWith('//')) raw = 'https:$raw';
    final uri = Uri.tryParse(raw);
    return uri != null && {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? raw
        : '';
  }

  static void _success(Map<String, dynamic> data, int expected) {
    final code = integer(data['result']);
    if (code == null) throw const AcfunApiException(AcfunFailureKind.schema);
    if (code != expected) throw AcfunApiException(AcfunFailureKind.service, result: code);
  }

  static String normalizeAuthorId(String value) {
    final result = value.trim();
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(result)) {
      throw const AcfunApiException(AcfunFailureKind.schema);
    }
    return result;
  }

  Future<AcfunDirectoryPage> directory({String cursor = '', int count = 30, String? filters}) async {
    final response = await _json(
      'GET',
      '$origin/api/channel/list',
      query: {'count': count.clamp(1, 60), 'pcursor': cursor, 'filters': ?filters},
    );
    return parseDirectory(response);
  }

  static AcfunDirectoryPage parseDirectory(Object? raw) {
    final wrapper = object(raw);
    final data = object(wrapper['channelListData'] ?? wrapper);
    _success(data, 0);
    final list = data['liveList'];
    if (list is! List || !data.containsKey('pcursor')) throw const AcfunApiException(AcfunFailureKind.schema);
    if (data['pcursor'] is! String && data['pcursor'] is! int) {
      throw const AcfunApiException(AcfunFailureKind.schema);
    }
    final cursor = text(data['pcursor']);
    return AcfunDirectoryPage(
      List.unmodifiable(list.map(object)),
      cursor.isEmpty || cursor == 'no_more' ? null : cursor,
      categories: wrapper.containsKey('channelFilters') ? parseCategories(wrapper['channelFilters']) : const [],
    );
  }

  static List<AcfunCategoryFilter> parseCategories(Object? raw) {
    final groups = object(raw)['liveChannelDisplayFilters'];
    if (groups is! List) throw const AcfunApiException(AcfunFailureKind.schema);
    final result = <(int, int), AcfunCategoryFilter>{};
    for (final group in groups) {
      final filters = object(group)['displayFilters'];
      if (filters is! List) throw const AcfunApiException(AcfunFailureKind.schema);
      for (final rawFilter in filters) {
        final filter = object(rawFilter);
        final type = integer(filter['filterType']);
        final id = integer(filter['filterId']);
        final name = text(filter['name']);
        if (type == null || type < 0 || id == null || id < 0 || name.isEmpty) {
          throw const AcfunApiException(AcfunFailureKind.schema);
        }
        result.putIfAbsent((
          type,
          id,
        ), () => AcfunCategoryFilter(type: type, id: id, name: name, cover: imageUrl(filter['cover'])));
      }
    }
    return List.unmodifiable(result.values);
  }

  Future<Map<String, dynamic>> roomInfo(String authorId) async {
    final id = normalizeAuthorId(authorId);
    final data = await _json('GET', '$origin/api/live/info', query: {'authorId': id});
    validateRoomInfo(data, id);
    return data;
  }

  /// A successful, identity-complete user envelope with no liveId is the
  /// official offline response. Empty/mismatched/failed responses are errors.
  static bool validateRoomInfo(Map<String, dynamic> data, String authorId) {
    _success(data, 0);
    final user = object(data['user']);
    if (text(data['authorId']) != authorId || text(user['id']) != authorId || text(user['name']).isEmpty) {
      throw const AcfunApiException(AcfunFailureKind.schema);
    }
    final liveId = text(data['liveId']);
    final stream = text(data['streamName']);
    if (liveId.isEmpty != stream.isEmpty) throw const AcfunApiException(AcfunFailureKind.schema);
    return liveId.isNotEmpty;
  }

  Future<_VisitorSession> _session() async {
    final cached = _visitor;
    if (cached != null && _clock().isBefore(cached.expiresAt)) return cached;
    final operation = _visitorInFlight ??= _login();
    try {
      return await operation;
    } finally {
      if (identical(_visitorInFlight, operation)) _visitorInFlight = null;
    }
  }

  Future<_VisitorSession> _login() async {
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final did = 'web_${List.generate(16, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
    final data = await _json(
      'POST',
      'https://id.app.acfun.cn/rest/app/visitor/login',
      body: {'sid': 'acfun.api.visitor'},
      headers: {...playHeaders, 'Cookie': '_did=$did;'},
    );
    _success(data, 0);
    final userId = normalizeAuthorId(text(data['userId']));
    final token = text(data['acfun.api.visitor_st']);
    if (token.isEmpty) throw const AcfunApiException(AcfunFailureKind.schema);
    final session = _VisitorSession(did, userId, token, _clock().add(const Duration(minutes: 5)));
    _visitor = session;
    return session;
  }

  Future<AcfunPlayback> playback(String authorId) async {
    final id = normalizeAuthorId(authorId);
    final session = await _session();
    final data = await _json(
      'POST',
      'https://api.kuaishouzt.com/rest/zt/live/web/startPlay',
      query: {
        'subBiz': 'mainApp',
        'kpn': 'ACFUN_APP',
        'kpf': 'PC_WEB',
        'userId': session.userId,
        'did': session.did,
        'acfun.api.visitor_st': session.token,
      },
      body: {'authorId': id, 'pullStreamType': 'FLV'},
    );
    try {
      _success(data, 1);
    } on AcfunApiException {
      if (identical(_visitor, session)) _visitor = null;
      rethrow;
    }
    final payload = object(data['data']);
    final liveId = text(payload['liveId']);
    if (liveId.isEmpty) throw const AcfunApiException(AcfunFailureKind.schema);
    return AcfunPlayback(liveId: liveId, qualities: parseQualities(payload['videoPlayRes']));
  }

  static List<AcfunStreamQuality> parseQualities(Object? raw) {
    final manifests = object(raw)['liveAdaptiveManifest'];
    if (manifests is! List) throw const AcfunApiException(AcfunFailureKind.schema);
    final qualities = <String, AcfunStreamQuality>{};
    for (final manifest in manifests) {
      final representations = object(object(manifest)['adaptationSet'])['representation'];
      if (representations is! List) throw const AcfunApiException(AcfunFailureKind.schema);
      for (final representation in representations) {
        final item = object(representation);
        if (item['hidden'] == true) continue;
        final url = text(item['url']);
        final uri = Uri.tryParse(url);
        if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
          continue;
        }
        final type = text(item['qualityType']);
        final id = type.isNotEmpty ? type : (integer(item['id']) == null ? '' : 'id:${integer(item['id'])}');
        if (id.isEmpty) throw const AcfunApiException(AcfunFailureKind.schema);
        final name = text(item['name']);
        final label = name.isNotEmpty
            ? name
            : switch (type) {
                'STANDARD' => '高清',
                'HIGH' => '超清',
                'SUPER' => '蓝光',
                'BLUE_RAY' => '高码率',
                _ => '画质 $id',
              };
        // Server quality levels and bitrate are different scales. Known levels
        // sort ahead of unknown levels; bitrate only orders that unknown group.
        final level = integer(item['level']);
        final rank = level != null && level >= 0
            ? 1000000 + level.clamp(0, 999999)
            : (integer(item['bitrate']) ?? 0).clamp(0, 999999);
        final previous = qualities[id];
        qualities[id] = AcfunStreamQuality(
          id: id,
          label: previous?.label ?? label,
          rank: max(rank, previous?.rank ?? rank),
          urls: List.unmodifiable({...?previous?.urls, url}),
        );
      }
    }
    if (qualities.isEmpty) throw const AcfunApiException(AcfunFailureKind.schema);
    final result = qualities.values.toList()
      ..sort((a, b) {
        final rank = b.rank.compareTo(a.rank);
        return rank != 0 ? rank : a.id.compareTo(b.id);
      });
    return List.unmodifiable(result);
  }
}

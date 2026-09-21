import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'taobao_live_link.dart';

enum TaobaoLiveFailure {
  transport,
  access,
  credential,
  missing,
  rateLimited,
  service,
  schema,
  identity,
  cancelled,
  notLive,
  mediaUnavailable,
}

final class TaobaoLiveException implements Exception {
  const TaobaoLiveException(this.kind);

  final TaobaoLiveFailure kind;

  @override
  String toString() => 'Taobao Live ${kind.name}';
}

enum TaobaoLiveState { live, offline, replay, restricted, unknown }

final class TaobaoLiveVariant {
  const TaobaoLiveVariant({required this.id, required this.label, required this.hls, required this.flv});

  final String id;
  final String label;
  final Uri? hls;
  final Uri? flv;
}

final class TaobaoLiveRoom {
  TaobaoLiveRoom({
    required this.identity,
    required this.liveId,
    required this.creatorId,
    required this.nick,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.totalViews,
    required this.followers,
    required this.state,
    required Iterable<TaobaoLiveVariant> variants,
  }) : variants = List.unmodifiable(variants);

  final TaobaoLiveIdentity identity;
  final String liveId;
  final String creatorId;
  final String nick;
  final String title;
  final String avatar;
  final String cover;
  final int? totalViews;
  final int? followers;
  final TaobaoLiveState state;
  final List<TaobaoLiveVariant> variants;
}

final class TaobaoLiveHttpResponse {
  const TaobaoLiveHttpResponse({required this.status, required this.body, this.setCookies = const [], this.location});

  final int status;
  final String body;
  final List<String> setCookies;
  final String? location;
}

typedef TaobaoLiveRequest = Future<TaobaoLiveHttpResponse> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

typedef TaobaoLiveCookieProvider = String Function();
typedef TaobaoLiveClock = int Function();

class TaobaoLiveApi {
  TaobaoLiveApi({
    TaobaoLiveRequest? request,
    TaobaoLiveCookieProvider? cookieProvider,
    TaobaoLiveClock? clock,
    this.deadline = const Duration(seconds: 20),
  }) : _request = request ?? _defaultRequest,
       _cookieProvider = cookieProvider ?? (() => ''),
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const String apiOrigin = 'https://h5api.m.taobao.com';
  static const String webOrigin = 'https://h5.m.taobao.com';
  static const String appKey = '12574478';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  final TaobaoLiveRequest _request;
  final TaobaoLiveCookieProvider _cookieProvider;
  final TaobaoLiveClock _clock;
  final Duration deadline;
  String _configuredCookie = '';
  Map<String, String> _sessionCookies = {};

  static Map<String, String> mediaHeaders(TaobaoLiveIdentity identity) => {
    'User-Agent': userAgent,
    'Origin': webOrigin,
    'Referer': TaobaoLiveLink.watchUrl(identity),
  };

  static Future<TaobaoLiveHttpResponse> _defaultRequest(
    Uri uri,
    Map<String, String> headers,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: headers,
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    return TaobaoLiveHttpResponse(
      status: response.statusCode ?? 0,
      body: await _readBody(body.stream),
      setCookies: List.unmodifiable(response.headers.map['set-cookie'] ?? const []),
      location: _singleHeader(response.headers.map['location']),
    );
  }

  static String? _singleHeader(List<String>? values) {
    if (values == null || values.length != 1) return null;
    final value = values.single.trim();
    return value.isEmpty || value.length > 8192 ? null : value;
  }

  static Future<String> _readBody(Stream<Uint8List> source) async {
    final iterator = StreamIterator<List<int>>(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const TaobaoLiveException(TaobaoLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const TaobaoLiveException(TaobaoLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const TaobaoLiveException(TaobaoLiveFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const TaobaoLiveException(TaobaoLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const TaobaoLiveException(TaobaoLiveFailure.cancelled);
          }
          if (error is TaobaoLiveException) rethrow;
          throw const TaobaoLiveException(TaobaoLiveFailure.transport);
        }
      });

  Future<TaobaoLiveIdentity> resolveReference(String raw, {CancelToken? cancel}) async {
    final direct = TaobaoLiveLink.parse(raw);
    if (direct != null) return direct;
    final short = TaobaoLiveLink.shortUri(raw);
    if (short == null) throw const TaobaoLiveException(TaobaoLiveFailure.identity);
    return _scope(cancel, (token) async {
      var current = short;
      for (var hop = 0; hop < 5; hop++) {
        if (!_referenceHost(current.host)) throw const TaobaoLiveException(TaobaoLiveFailure.identity);
        final response = await _request(current, const {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml',
        }, token);
        if ({301, 302, 303, 307, 308}.contains(response.status)) {
          final location = response.location;
          if (location == null) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
          final next = current.resolve(location);
          final identity = TaobaoLiveLink.parse(next.toString());
          if (identity != null) return identity;
          if (!_referenceHost(next.host)) throw const TaobaoLiveException(TaobaoLiveFailure.identity);
          current = next;
          continue;
        }
        _throwStatus(response.status);
        final identity = TaobaoLiveLink.parseLandingPage(response.body);
        if (identity == null) throw const TaobaoLiveException(TaobaoLiveFailure.missing);
        return identity;
      }
      throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    });
  }

  static bool _referenceHost(String host) {
    final value = host.toLowerCase();
    return value == 'm.tb.cn' ||
        value == 'h5.m.taobao.com' ||
        value == 'huodong.m.taobao.com' ||
        value == 'tbzb.taobao.com';
  }

  Future<TaobaoLiveRoom> room(TaobaoLiveIdentity identity, {bool includeMedia = false, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final configured = _cookieProvider().trim();
        var cookies = _cookiesFor(configured);
        final data = jsonEncode(
          identity.kind == TaobaoLiveIdentityKind.live
              ? <String, Object?>{'liveId': identity.id, 'creatorId': null}
              : <String, Object?>{'creatorId': identity.id},
        );
        if (_token(cookies) == null) {
          final bootstrap = await _mtop(data: data, cookies: cookies, sign: '', token: token);
          _applySetCookies(cookies, bootstrap.setCookies);
          if (_token(cookies) == null) throw const TaobaoLiveException(TaobaoLiveFailure.credential);
        }
        for (var attempt = 0; attempt < 2; attempt++) {
          final timestamp = _clock();
          final sessionToken = _token(cookies);
          if (sessionToken == null) throw const TaobaoLiveException(TaobaoLiveFailure.credential);
          final sign = md5.convert(utf8.encode('$sessionToken&$timestamp&$appKey&$data')).toString();
          final response = await _mtop(data: data, cookies: cookies, sign: sign, timestamp: timestamp, token: token);
          _applySetCookies(cookies, response.setCookies);
          final decoded = _decode(response.body);
          final ret = _ret(decoded);
          if (_success(ret)) {
            _remember(configured, cookies);
            final room = parseRoomJson(decoded, identity: identity);
            if (includeMedia && room.state == TaobaoLiveState.live) {
              final hls = room.variants.where((variant) => variant.hls != null).firstOrNull?.hls;
              if (hls == null) throw const TaobaoLiveException(TaobaoLiveFailure.mediaUnavailable);
              final media = await _request(hls, mediaHeaders(identity), token);
              _throwStatus(media.status);
              validatePlaylist(media.body, expected: hls);
            }
            return room;
          }
          if (attempt == 0 && _tokenFailure(ret)) {
            if (_token(cookies) == sessionToken) {
              cookies.remove('_m_h5_tk');
              cookies.remove('_m_h5_tk_enc');
              final bootstrap = await _mtop(data: data, cookies: cookies, sign: '', token: token);
              _applySetCookies(cookies, bootstrap.setCookies);
            }
            continue;
          }
          _throwRet(ret);
        }
        throw const TaobaoLiveException(TaobaoLiveFailure.service);
      });

  Future<TaobaoLiveHttpResponse> _mtop({
    required String data,
    required Map<String, String> cookies,
    required String sign,
    required CancelToken token,
    int? timestamp,
  }) async {
    final now = timestamp ?? _clock();
    if (now < 1) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    final uri = Uri.parse('$apiOrigin/h5/mtop.mediaplatform.live.livedetail/4.0/').replace(
      queryParameters: {
        'jsv': '2.7.0',
        'appKey': appKey,
        't': '$now',
        'sign': sign,
        'AntiFlood': 'true',
        'AntiCreep': 'true',
        'api': 'mtop.mediaplatform.live.livedetail',
        'v': '4.0',
        'preventFallback': 'true',
        'type': 'originaljson',
        'dataType': 'json',
        'data': data,
      },
    );
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept': 'application/json, text/plain, */*',
      'Origin': webOrigin,
      'Referer': '$webOrigin/taolive/video.html',
      if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
    };
    final response = await _request(uri, headers, token);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    return response;
  }

  Map<String, String> _cookiesFor(String configured) {
    if (configured == _configuredCookie && _sessionCookies.isNotEmpty) {
      return Map.of(_sessionCookies);
    }
    return _parseCookieHeader(configured);
  }

  void _remember(String configured, Map<String, String> cookies) {
    if (_cookieProvider().trim() != configured) return;
    _configuredCookie = configured;
    _sessionCookies = Map.unmodifiable(cookies);
  }

  static Map<String, String> _parseCookieHeader(String source) {
    if (source.length > 32768 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(source)) {
      throw const TaobaoLiveException(TaobaoLiveFailure.credential);
    }
    final result = <String, String>{};
    for (final rawPart in source.split(';')) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      final separator = part.indexOf('=');
      if (separator < 1) throw const TaobaoLiveException(TaobaoLiveFailure.credential);
      final name = part.substring(0, separator).trim();
      final value = part.substring(separator + 1).trim();
      if (!RegExp(r"^[!#\$%&'*+.^_`|~0-9A-Za-z-]{1,128}$").hasMatch(name) || value.length > 4096) {
        throw const TaobaoLiveException(TaobaoLiveFailure.credential);
      }
      result[name] = value;
      if (result.length > 64) throw const TaobaoLiveException(TaobaoLiveFailure.credential);
    }
    return result;
  }

  static void _applySetCookies(Map<String, String> cookies, List<String> values) {
    for (final value in values.take(64)) {
      final pair = value.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator < 1) continue;
      final name = pair.substring(0, separator).trim();
      final cookieValue = pair.substring(separator + 1).trim();
      if (!RegExp(r"^[!#\$%&'*+.^_`|~0-9A-Za-z-]{1,128}$").hasMatch(name) || cookieValue.length > 4096) {
        continue;
      }
      if (cookieValue.isEmpty) {
        cookies.remove(name);
      } else {
        cookies[name] = cookieValue;
      }
    }
  }

  static String _cookieHeader(Map<String, String> cookies) =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  static String? _token(Map<String, String> cookies) {
    final value = cookies['_m_h5_tk'];
    if (value == null) return null;
    final token = value.split('_').first;
    return RegExp(r'^[A-Fa-f0-9]{16,64}$').hasMatch(token) ? token : null;
  }

  static Map<String, dynamic> _decode(String source) {
    try {
      final value = jsonDecode(source);
      return _object(value);
    } on FormatException {
      throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    }
  }

  static List<String> _ret(Map<String, dynamic> root) {
    final value = root['ret'];
    if (value is! List || value.isEmpty || value.length > 16 || value.any((entry) => entry is! String)) {
      throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    }
    return value.cast<String>();
  }

  static bool _success(List<String> ret) => ret.any((value) => value.startsWith('SUCCESS::'));

  static bool _tokenFailure(List<String> ret) =>
      ret.any((value) => value.startsWith('FAIL_SYS_TOKEN_') || value.startsWith('FAIL_SYS_ILLEGAL_ACCESS'));

  static void _throwRet(List<String> ret) {
    final text = ret.join('|').toUpperCase();
    if (text.contains('SESSION_EXPIRED') || text.contains('USER_VALIDATE') || text.contains('RGV587')) {
      throw const TaobaoLiveException(TaobaoLiveFailure.access);
    }
    if (text.contains('TRAFFIC') || text.contains('FREQUENCY') || text.contains('LIMIT')) {
      throw const TaobaoLiveException(TaobaoLiveFailure.rateLimited);
    }
    if (text.contains('NOT_EXIST') || text.contains('EMPTY_RESULT')) {
      throw const TaobaoLiveException(TaobaoLiveFailure.missing);
    }
    if (_tokenFailure(ret)) throw const TaobaoLiveException(TaobaoLiveFailure.credential);
    throw const TaobaoLiveException(TaobaoLiveFailure.service);
  }

  static TaobaoLiveRoom parseRoomJson(Object? value, {required TaobaoLiveIdentity identity}) {
    final root = _object(value);
    final ret = _ret(root);
    if (!_success(ret)) _throwRet(ret);
    final data = _object(root['data']);
    final liveId = _id(data['liveId'] ?? data['id']);
    final broadcaster = _object(data['broadCaster']);
    final creatorId = _id(data['accountId'] ?? broadcaster['accountId']);
    if (identity.kind == TaobaoLiveIdentityKind.live && liveId != identity.id) {
      throw const TaobaoLiveException(TaobaoLiveFailure.identity);
    }
    if (identity.kind == TaobaoLiveIdentityKind.creator && creatorId != identity.id) {
      throw const TaobaoLiveException(TaobaoLiveFailure.identity);
    }
    final streamStatus = _int(data['streamStatus']);
    final roomStatus = _int(data['roomStatus']);
    final appOnly = _bool(data['taobaoLiveOnly']) ?? false;
    final route = _optionalText(data['nativeFeedDetailUrl'], limit: 16384);
    final state = appOnly && streamStatus == 1
        ? TaobaoLiveState.restricted
        : streamStatus == 1
        ? TaobaoLiveState.live
        : roomStatus == 2 || route.toLowerCase().contains('livetype=replay')
        ? TaobaoLiveState.replay
        : streamStatus == 0
        ? TaobaoLiveState.offline
        : TaobaoLiveState.unknown;
    final variants = state == TaobaoLiveState.live ? _variants(data) : const <TaobaoLiveVariant>[];
    final title = _optionalText(data['title'], fallback: 'Taobao Live');
    final nick = _optionalText(broadcaster['accountName'], fallback: 'Taobao Live');
    return TaobaoLiveRoom(
      identity: identity,
      liveId: liveId,
      creatorId: creatorId,
      nick: nick,
      title: title,
      avatar: _image(broadcaster['headImg']),
      cover: _image(data['coverImg'] ?? data['backgroundImageURL']),
      totalViews: _nonNegativeInt(data['viewCount']),
      followers: _nonNegativeInt(broadcaster['fansNum']),
      state: state,
      variants: variants,
    );
  }

  static List<TaobaoLiveVariant> _variants(Map<String, dynamic> data) {
    final rows = data['liveUrlList'];
    final candidates = <TaobaoLiveVariant>[];
    if (rows != null) {
      if (rows is! List || rows.length > 32) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
      for (final value in rows) {
        final row = _object(value);
        final id = _qualityId(row['newDefinition']) ?? _qualityId(row['definition']);
        if (id == null) continue;
        final hls = _media(row['hlsUrl'], extension: '.m3u8');
        final flv = _media(row['flvUrl'], extension: '.flv');
        if (hls == null && flv == null) continue;
        if (hls != null && flv != null && _streamKey(hls) != _streamKey(flv)) {
          throw const TaobaoLiveException(TaobaoLiveFailure.schema);
        }
        candidates.add(
          TaobaoLiveVariant(
            id: id,
            label: _optionalText(row['newName'] ?? row['name'], fallback: _qualityLabel(id), limit: 128),
            hls: hls,
            flv: flv,
          ),
        );
      }
    }
    if (candidates.isEmpty) {
      final hls = _media(data['liveUrlHls'], extension: '.m3u8');
      final flv = _media(data['liveUrl'], extension: '.flv');
      if (hls != null || flv != null) {
        if (hls != null && flv != null && _streamKey(hls) != _streamKey(flv)) {
          throw const TaobaoLiveException(TaobaoLiveFailure.schema);
        }
        candidates.add(TaobaoLiveVariant(id: 'auto', label: _qualityLabel('auto'), hls: hls, flv: flv));
      }
    }
    final unique = <String, TaobaoLiveVariant>{};
    for (final variant in candidates) {
      final key = '${variant.hls}|${variant.flv}';
      final existing = unique[key];
      if (existing == null || _qualityRank(variant.id) > _qualityRank(existing.id)) unique[key] = variant;
    }
    final result = unique.values.toList()
      ..sort((a, b) {
        final rank = _qualityRank(b.id).compareTo(_qualityRank(a.id));
        return rank == 0 ? a.id.compareTo(b.id) : rank;
      });
    return List.unmodifiable(result);
  }

  static String? _qualityId(Object? value) {
    final text = value is String ? value.trim().toLowerCase() : '';
    return RegExp(r'^[a-z0-9_-]{1,32}$').hasMatch(text) ? text : null;
  }

  static int _qualityRank(String id) => switch (id) {
    'ud' => 6,
    'hd' => 5,
    'md' => 4,
    'ld' => 3,
    'lld' => 2,
    'auto' => 1,
    _ => 0,
  };

  static String _qualityLabel(String id) => switch (id) {
    'ud' => 'Original',
    'hd' => 'Ultra HD',
    'md' => 'HD',
    'ld' => 'Smooth',
    'lld' => 'Data saver',
    _ => 'Adaptive',
  };

  static Uri? _media(Object? value, {required String extension}) {
    final raw = value is String ? value.trim() : '';
    if (raw.isEmpty || raw.length > 16384 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !RegExp(r'^live[a-z0-9-]*\.alicdn\.com$').hasMatch(host) ||
        !(uri.path.startsWith('/liveplatform/') || uri.path.startsWith('/mediaplatform/')) ||
        !uri.path.toLowerCase().endsWith(extension)) {
      return null;
    }
    final auth = uri.queryParametersAll['auth_key'];
    if (auth == null || auth.length != 1 || auth.single.isEmpty || auth.single.length > 1024) return null;
    return uri;
  }

  static String _streamKey(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return name.replaceFirst(RegExp(r'\.(?:m3u8|flv)$', caseSensitive: false), '');
  }

  static void validatePlaylist(String source, {required Uri expected}) {
    if (source.length > 1024 * 1024 || !source.trimLeft().startsWith('#EXTM3U')) {
      throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    }
    final stem = _streamKey(expected);
    var references = 0;
    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        for (final match in RegExp(r'URI="([^"]+)"').allMatches(line)) {
          if (!_validChild(expected, match.group(1)!, stem)) {
            throw const TaobaoLiveException(TaobaoLiveFailure.schema);
          }
          references++;
        }
        continue;
      }
      if (!_validChild(expected, line, stem)) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
      references++;
      if (references > 1000) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    }
    if (references < 1) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
  }

  static bool _validChild(Uri expected, String raw, String stem) {
    final child = expected.resolve(raw);
    final name = child.pathSegments.isEmpty ? '' : child.pathSegments.last;
    return child.scheme == expected.scheme &&
        child.userInfo.isEmpty &&
        !child.hasFragment &&
        child.host.toLowerCase() == expected.host.toLowerCase() &&
        child.port == expected.port &&
        (child.path.startsWith('/liveplatform/') || child.path.startsWith('/mediaplatform/')) &&
        name.contains(stem) &&
        (name.endsWith('.ts') || name.endsWith('.m4s') || name.endsWith('.aac') || name.endsWith('.key'));
  }

  static DateTime? mediaInvalidAt(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final values = uri.queryParametersAll['auth_key'];
    if (values == null || values.length != 1) return null;
    final parts = values.single.split('-');
    final seconds = parts.isEmpty ? null : int.tryParse(parts.first);
    if (seconds == null || seconds < 946684800 || seconds > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static DateTime? mediaRefreshAt(String url, {DateTime? now}) {
    final invalidAt = mediaInvalidAt(url);
    if (invalidAt == null) return null;
    final current = (now ?? DateTime.now()).toUtc();
    final refreshAt = invalidAt.subtract(const Duration(minutes: 5));
    return refreshAt.isAfter(current) ? refreshAt : current;
  }

  static String _image(Object? value) {
    var raw = value is String ? value.trim() : '';
    if (raw.startsWith('//')) raw = 'https:$raw';
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'alicdn.com' ||
            host.endsWith('.alicdn.com') ||
            host == 'taobaocdn.com' ||
            host.endsWith('.taobaocdn.com') ||
            host.endsWith('.tbcdn.cn'))) {
      return '';
    }
    return uri.toString();
  }

  static String _id(Object? value) {
    try {
      return TaobaoLiveLink.requireId(value);
    } on FormatException {
      throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    }
  }

  static int? _int(Object? value) => switch (value) {
    int number => number,
    num number when number.isFinite && number == number.toInt() => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };

  static int? _nonNegativeInt(Object? value) {
    final result = _int(value);
    return result != null && result >= 0 ? result : null;
  }

  static bool? _bool(Object? value) => switch (value) {
    bool flag => flag,
    0 || '0' || 'false' => false,
    1 || '1' || 'true' => true,
    _ => null,
  };

  static String _optionalText(Object? value, {String fallback = '', int limit = 65536}) {
    if (value == null) return fallback;
    if (value is! String || value.length > limit) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    final result = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return result.isEmpty ? fallback : result;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const TaobaoLiveException(TaobaoLiveFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      >= 200 && < 300 => null,
      400 || 422 => TaobaoLiveFailure.schema,
      401 || 403 => TaobaoLiveFailure.access,
      404 => TaobaoLiveFailure.missing,
      429 => TaobaoLiveFailure.rateLimited,
      >= 500 => TaobaoLiveFailure.service,
      _ => TaobaoLiveFailure.transport,
    };
    if (failure != null) throw TaobaoLiveException(failure);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

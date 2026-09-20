import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_api.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_player_layout.dart';

enum ZhanqiMediaMethod { get, postMultipart }

class ZhanqiMediaRequest {
  ZhanqiMediaRequest({
    required this.method,
    required this.uri,
    Map<String, String> headers = const {},
    Map<String, String>? formFields,
  }) : headers = Map.unmodifiable(headers),
       formFields = formFields == null ? null : Map.unmodifiable(formFields);

  final ZhanqiMediaMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, String>? formFields;
}

class ZhanqiMediaResponse {
  ZhanqiMediaResponse({required this.status, required this.body, Map<String, List<String>> headers = const {}})
    : headers = Map.unmodifiable(headers.map((key, value) => MapEntry(key, List<String>.unmodifiable(value))));

  final int status;
  final String body;
  final Map<String, List<String>> headers;

  List<String> headerValues(String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return const [];
  }
}

typedef ZhanqiMediaTransport = Future<ZhanqiMediaResponse> Function(ZhanqiMediaRequest request, CancelToken cancel);

enum ZhanqiRouteState { notRequired, resolved, partial, unavailable }

/// A single signed media identity. Multiple logical lines can share it, so
/// their original indices are retained without publishing duplicate URLs.
class ZhanqiMediaSource {
  ZhanqiMediaSource({
    required this.cdnKey,
    required this.suffix,
    required Iterable<int> lineIndices,
    required Iterable<int> qualityIndices,
    required this.directUrl,
    required Iterable<Uri> routedUrls,
    required Map<String, String> headers,
  }) : lineIndices = List.unmodifiable(lineIndices),
       qualityIndices = List.unmodifiable(qualityIndices),
       routedUrls = List.unmodifiable(routedUrls),
       headers = Map.unmodifiable(headers);

  final int cdnKey;
  final String suffix;
  final List<int> lineIndices;
  final List<int> qualityIndices;
  final Uri directUrl;
  final List<Uri> routedUrls;
  final Map<String, String> headers;

  /// The official player prefers resolved nodes and keeps the declared domain
  /// as a fallback. Consumers can preserve that ordering directly.
  List<Uri> get candidates => List.unmodifiable(<Uri>[...routedUrls, directUrl]);
}

class ZhanqiMediaResolution {
  ZhanqiMediaResolution({
    required this.roomId,
    required this.videoId,
    required this.routeState,
    required Iterable<ZhanqiMediaSource> sources,
  }) : sources = List.unmodifiable(sources);

  final String roomId;
  final String videoId;
  final ZhanqiRouteState routeState;
  final List<ZhanqiMediaSource> sources;
}

class _ZhanqiViewer {
  const _ZhanqiViewer({required this.gid, required this.clientIp, required this.cookie});

  final int gid;
  final String clientIp;
  final String cookie;
}

class _ZhanqiTemplate {
  const _ZhanqiTemplate(this.host, this.path);

  final String host;
  final String Function(String videoId, String suffix) path;
}

/// Current public H5 signer and Ali CDN-routing contract. This remains a data
/// layer until a returned candidate has passed bounded media validation.
class ZhanqiMediaApi {
  ZhanqiMediaApi({
    ZhanqiMediaTransport? transport,
    DateTime Function()? now,
    this.deadline = const Duration(seconds: 30),
  }) : _transport = transport ?? _defaultTransport,
       _now = now ?? DateTime.now;

  static const _aliResolver = 'umc.danuoyi.alicdn.com';
  static const _platform = '128';
  static const _maxSources = 64;
  static const _templates = <int, _ZhanqiTemplate>{
    12: _ZhanqiTemplate('dlhdl-cdn.zhanqi.tv', _flvPath),
    13: _ZhanqiTemplate('dlhls-cdn.zhanqi.tv', _dlHlsPath),
    42: _ZhanqiTemplate('wshdl-cdn.zhanqi.tv', _flvPath),
    43: _ZhanqiTemplate('wshls-cdn.zhanqi.tv', _wsHlsPath),
    72: _ZhanqiTemplate('yfhdl-p2p-cdn.zhanqi.tv', _flvPath),
    172: _ZhanqiTemplate('yfhdl-cdn.zhanqi.tv', _flvPath),
    173: _ZhanqiTemplate('yfhls-cdn.zhanqi.tv', _yfHlsPath),
    192: _ZhanqiTemplate('txhdl-cdn.zhanqi.tv', _flvPath),
    202: _ZhanqiTemplate('alhdl-cdn.zhanqi.tv', _flvPath),
    203: _ZhanqiTemplate('alhls-cdn.zhanqi.tv', _alHlsPath),
    232: _ZhanqiTemplate('txkcardhdl-cdn.zhanqi.tv', _flvPath),
    242: _ZhanqiTemplate('alhdl-cdn.zhanqi.tv', _flvPath),
  };

  final ZhanqiMediaTransport _transport;
  final DateTime Function() _now;
  final Duration deadline;

  static String _flvPath(String videoId, String suffix) => '/zqlive/$videoId$suffix.flv';

  static String _dlHlsPath(String videoId, String suffix) =>
      suffix.isEmpty ? '/zqlive/$videoId.m3u8' : '/zqlive/$videoId$suffix/index.m3u8';

  static String _wsHlsPath(String videoId, String suffix) => '/zqlive/$videoId$suffix/playlist.m3u8';

  static String _yfHlsPath(String videoId, String suffix) => '/zqlive/$videoId$suffix/online.m3u8';

  static String _alHlsPath(String videoId, String _) => '/zqlive/$videoId.m3u8';

  static Future<ZhanqiMediaResponse> _defaultTransport(ZhanqiMediaRequest request, CancelToken cancel) async {
    final response = await HttpClient.instance.dio.request<ResponseBody>(
      request.uri.toString(),
      data: request.formFields == null ? null : FormData.fromMap(request.formFields!),
      cancelToken: cancel,
      options: Options(
        method: request.method == ZhanqiMediaMethod.get ? 'GET' : 'POST',
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: request.headers,
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const ZhanqiException(ZhanqiFailure.schema);
    final status = response.statusCode ?? 0;
    if (status != 200) {
      await body.stream.listen((_) {}).cancel();
      return ZhanqiMediaResponse(status: status, body: '', headers: response.headers.map);
    }
    return ZhanqiMediaResponse(
      status: status,
      body: await ZhanqiApi.readBody(body.stream),
      headers: response.headers.map,
    );
  }

  Future<ZhanqiMediaResolution> resolve(ZhanqiRoomSnapshot room, {CancelToken? cancel}) => withRequestCancellation(
    cancel,
    (transport) async {
      if (transport.isCancelled) throw const ZhanqiException(ZhanqiFailure.cancelled);
      try {
        return await Future.any<ZhanqiMediaResolution>([
          _resolve(room, transport),
          transport.whenCancel.then<ZhanqiMediaResolution>((_) => throw const ZhanqiException(ZhanqiFailure.cancelled)),
        ]).timeout(deadline);
      } on TimeoutException {
        throw const ZhanqiException(ZhanqiFailure.transport);
      } catch (error) {
        if (cancel?.isCancelled == true) throw const ZhanqiException(ZhanqiFailure.cancelled);
        if (error is ZhanqiException) rethrow;
        throw const ZhanqiException(ZhanqiFailure.transport);
      }
    },
  );

  Future<ZhanqiMediaResolution> _resolve(ZhanqiRoomSnapshot room, CancelToken cancel) async {
    if (room.reportedLive != true) throw const ZhanqiException(ZhanqiFailure.notLive);
    final layout = room.playerLayout;
    if (layout == null || layout.cells.isEmpty) throw const ZhanqiException(ZhanqiFailure.mediaUnavailable);
    if (!layout.videoId.startsWith('${room.roomId}_')) throw const ZhanqiException(ZhanqiFailure.identity);

    final groups = layout.sourceGroups.entries.where((entry) => _templates.containsKey(entry.key.$1)).toList();
    if (groups.isEmpty || groups.length > _maxSources) {
      throw const ZhanqiException(ZhanqiFailure.mediaUnavailable);
    }
    groups.sort((left, right) {
      final leftDefault = left.value.any((cell) => cell.qualityIndex == layout.defaultQualityIndex);
      final rightDefault = right.value.any((cell) => cell.qualityIndex == layout.defaultQualityIndex);
      if (leftDefault != rightDefault) return leftDefault ? -1 : 1;
      final quality = _minimum(left.value.map((cell) => cell.qualityIndex))
          .compareTo(_minimum(right.value.map((cell) => cell.qualityIndex)));
      if (quality != 0) return quality;
      return _minimum(left.value.map((cell) => cell.lineIndex))
          .compareTo(_minimum(right.value.map((cell) => cell.lineIndex)));
    });

    final viewer = await _viewer(cancel);
    final now = _now();
    final playNum = (now.millisecondsSinceEpoch % 100000000) * 1000 + now.microsecondsSinceEpoch % 1000;
    var routeAttempts = 0;
    var routeSuccesses = 0;
    final sources = <ZhanqiMediaSource>[];

    for (final group in groups) {
      final cdnKey = group.key.$1;
      final suffix = group.key.$2;
      final template = _templates[cdnKey]!;
      final unsigned = Uri(scheme: 'https', host: template.host, path: template.path(layout.videoId, suffix));
      final signature = await _signature(unsigned.pathSegments.last, cdnKey, viewer.cookie, cancel);
      final direct = _signedUrl(unsigned, signature, playNum: playNum, gid: viewer.gid, routed: false);
      var routed = const <Uri>[];
      if (cdnKey == 202) {
        routeAttempts++;
        try {
          final domains = await _aliRoutes(
            videoId: layout.videoId,
            pullDomain: template.host,
            playNum: playNum,
            gid: viewer.gid,
            clientIp: viewer.clientIp,
            cancel: cancel,
          );
          routed = domains
              .map(
                (domain) => _signedUrl(
                  Uri(scheme: 'https', host: domain, path: '/${template.host}${unsigned.path}'),
                  signature,
                  playNum: playNum,
                  gid: viewer.gid,
                  routed: true,
                ),
              )
              .toList(growable: false);
          if (routed.isNotEmpty) routeSuccesses++;
        } on ZhanqiException catch (error) {
          if (error.kind == ZhanqiFailure.cancelled) rethrow;
        }
      }
      sources.add(
        ZhanqiMediaSource(
          cdnKey: cdnKey,
          suffix: suffix,
          lineIndices: group.value.map((cell) => cell.lineIndex).toSet().toList()..sort(),
          qualityIndices: group.value.map((cell) => cell.qualityIndex).toSet().toList()..sort(),
          directUrl: direct,
          routedUrls: routed,
          headers: ZhanqiApi.headers,
        ),
      );
    }
    final routeState = switch ((routeAttempts, routeSuccesses)) {
      (0, _) => ZhanqiRouteState.notRequired,
      (final attempts, final successes) when attempts == successes => ZhanqiRouteState.resolved,
      (_, 0) => ZhanqiRouteState.unavailable,
      _ => ZhanqiRouteState.partial,
    };
    return ZhanqiMediaResolution(
      roomId: room.roomId,
      videoId: layout.videoId,
      routeState: routeState,
      sources: sources,
    );
  }

  Future<_ZhanqiViewer> _viewer(CancelToken cancel) async {
    final response = await _send(
      ZhanqiMediaRequest(
        method: ZhanqiMediaMethod.get,
        uri: Uri.parse('${ZhanqiApi.origin}/api/public/room.viewer'),
        headers: ZhanqiApi.headers,
      ),
      cancel,
    );
    final data = _success(response.body);
    final uid = data['uid'];
    final gid = data['gid'];
    final rawIp = data['clientIp'];
    if (uid is! int || uid < 0 || gid is! int || gid <= 0 || rawIp is! int || rawIp < 0 || rawIp > 0xffffffff) {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
    final cookies = _cookies(response.headerValues('set-cookie'));
    if (cookies.isEmpty) throw const ZhanqiException(ZhanqiFailure.schema);
    final cookieGid = cookies['gid'];
    if (cookieGid != null && cookieGid != '$gid') throw const ZhanqiException(ZhanqiFailure.identity);
    return _ZhanqiViewer(
      gid: gid,
      clientIp: '${(rawIp >> 24) & 255}.${(rawIp >> 16) & 255}.${(rawIp >> 8) & 255}.${rawIp & 255}',
      cookie: cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
    );
  }

  Future<String> _signature(String filename, int cdnKey, String cookie, CancelToken cancel) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,96}\.(?:flv|m3u8)$').hasMatch(filename)) {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
    final response = await _send(
      ZhanqiMediaRequest(
        method: ZhanqiMediaMethod.postMultipart,
        uri: Uri.parse('${ZhanqiApi.origin}/api/public/burglar/chain'),
        headers: {...ZhanqiApi.headers, 'Origin': ZhanqiApi.origin, 'Cookie': cookie},
        formFields: {'stream': filename, 'cdnKey': '$cdnKey', 'platform': _platform},
      ),
      cancel,
    );
    final data = _success(response.body);
    final key = data['key'];
    if (key is! String || !RegExp(r'^k=[0-9a-fA-F]{16,128}&t=[0-9a-fA-F]{1,32}$').hasMatch(key)) {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
    return key;
  }

  Future<List<String>> _aliRoutes({
    required String videoId,
    required String pullDomain,
    required int playNum,
    required int gid,
    required String clientIp,
    required CancelToken cancel,
  }) async {
    final response = await _send(
      ZhanqiMediaRequest(
        method: ZhanqiMediaMethod.get,
        uri: Uri.https(_aliResolver, '/dns_resolve_https', {
          'app': 'zqlive',
          'host_key': pullDomain,
          'stream': videoId,
          'playNum': '$playNum',
          'protocol': 'hdl',
          'client_ip': clientIp,
          'gId': '$gid',
          'platform': _platform,
        }),
        headers: {...ZhanqiApi.headers, 'Origin': ZhanqiApi.origin},
      ),
      cancel,
    );
    final root = _object(response.body);
    final ttl = root['ttl'];
    final rawDomains = root['redirect_domain'];
    if (ttl is! int || ttl < 1 || ttl > 3600 || rawDomains is! List || rawDomains.length > 16) {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
    final domains = <String>{};
    for (final value in rawDomains) {
      if (value is! String ||
          value.length > 253 ||
          !RegExp(r'^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$').hasMatch(value) ||
          !value.endsWith('.tbcache.com')) {
        throw const ZhanqiException(ZhanqiFailure.schema);
      }
      domains.add(value);
    }
    return List.unmodifiable(domains);
  }

  Future<ZhanqiMediaResponse> _send(ZhanqiMediaRequest request, CancelToken cancel) async {
    if (cancel.isCancelled) throw const ZhanqiException(ZhanqiFailure.cancelled);
    late final ZhanqiMediaResponse response;
    try {
      response = await _transport(request, cancel);
    } catch (error) {
      if (cancel.isCancelled || (error is DioException && CancelToken.isCancel(error))) {
        throw const ZhanqiException(ZhanqiFailure.cancelled);
      }
      if (error is ZhanqiException) rethrow;
      throw const ZhanqiException(ZhanqiFailure.transport);
    }
    if (cancel.isCancelled) throw const ZhanqiException(ZhanqiFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => ZhanqiFailure.access,
      404 => ZhanqiFailure.missing,
      429 => ZhanqiFailure.rateLimited,
      >= 500 => ZhanqiFailure.service,
      _ => ZhanqiFailure.transport,
    };
    if (failure != null) throw ZhanqiException(failure);
    if (response.body.length > ZhanqiApi.responseLimit || utf8.encode(response.body).length > ZhanqiApi.responseLimit) {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
    return response;
  }

  static Map<String, dynamic> _success(String body) {
    final root = _object(body);
    if (root['code'] is! int) throw const ZhanqiException(ZhanqiFailure.schema);
    if (root['code'] != 0) throw const ZhanqiException(ZhanqiFailure.api);
    final data = root['data'];
    if (data is! Map<String, dynamic>) throw const ZhanqiException(ZhanqiFailure.schema);
    return data;
  }

  static Map<String, dynamic> _object(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic>) throw const ZhanqiException(ZhanqiFailure.schema);
      return value;
    } on FormatException {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
  }

  static Map<String, String> _cookies(Iterable<String> headers) {
    final result = <String, String>{};
    for (final header in headers) {
      final pair = header.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator);
      final value = pair.substring(separator + 1);
      if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,64}$").hasMatch(name) ||
          value.length > 4096 ||
          value.contains(RegExp(r'[\x00-\x20;,\x7f]'))) {
        continue;
      }
      result[name] = value;
    }
    return result;
  }

  static Uri _signedUrl(Uri base, String signature, {required int playNum, required int gid, required bool routed}) {
    final signatureValues = Uri.splitQueryString(signature);
    return base.replace(
      queryParameters: {
        ...signatureValues,
        'playNum': '$playNum',
        'gId': '$gid',
        'ipFrom': routed ? '1' : '0',
        'clientIp': '',
        'fhost': 'h5',
        'platform': _platform,
      },
    );
  }

  static int _minimum(Iterable<int> values) => values.reduce((left, right) => left < right ? left : right);
}

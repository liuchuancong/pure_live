import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'nimotv_link.dart';

enum NimoTvFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  schema,
  identity,
  cancelled,
  unknownState,
  mediaUnavailable,
}

class NimoTvException implements Exception {
  const NimoTvException(this.kind);

  final NimoTvFailure kind;

  @override
  String toString() => 'NimoTV ${kind.name}';
}

enum NimoTvState { live, offline, unknown }

final class NimoTvQuality {
  const NimoTvQuality({required this.id, required this.label, required this.sort, required this.url});

  final String id;
  final String label;
  final int sort;
  final Uri url;
}

final class NimoTvRoom {
  NimoTvRoom({
    required this.roomId,
    required this.anchorId,
    required this.nickname,
    required this.avatar,
    required this.cover,
    required this.title,
    required this.category,
    required this.viewerCount,
    required this.state,
    required Iterable<NimoTvQuality> qualities,
  }) : qualities = List.unmodifiable(qualities);

  final String roomId;
  final String anchorId;
  final String nickname;
  final String avatar;
  final String cover;
  final String title;
  final String category;
  final int? viewerCount;
  final NimoTvState state;
  final List<NimoTvQuality> qualities;
}

typedef NimoTvRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

class NimoTvApi {
  NimoTvApi({NimoTvRequest? request, this.deadline = const Duration(seconds: 35)})
    : _request = request ?? _defaultRequest;

  static const int responseLimit = 4 * 1024 * 1024;
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  final NimoTvRequest _request;
  final Duration deadline;

  static Map<String, String> pageHeaders() => const {
    'User-Agent': mobileUserAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.8',
  };

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': desktopUserAgent,
    'Origin': 'https://www.nimo.tv',
    'Referer': NimoTvLink.url(roomId),
  };

  static Future<({int status, String body})> _defaultRequest(
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
        receiveTimeout: const Duration(seconds: 25),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const NimoTvException(NimoTvFailure.schema);
    final content = await _readBody(body.stream);
    return (status: response.statusCode ?? 0, body: content);
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const NimoTvException(NimoTvFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const NimoTvException(NimoTvFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const NimoTvException(NimoTvFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const NimoTvException(NimoTvFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const NimoTvException(NimoTvFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const NimoTvException(NimoTvFailure.cancelled);
          }
          if (error is NimoTvException) rethrow;
          throw const NimoTvException(NimoTvFailure.transport);
        }
      });

  Future<NimoTvRoom> room(String rawKey, {bool resolveMedia = true, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final key = NimoTvLink.parseKey(rawKey);
        if (key == null) throw const NimoTvException(NimoTvFailure.identity);
        final uri = Uri.parse(NimoTvLink.mobileUrl(key));
        final response = await _request(uri, pageHeaders(), token);
        _throwStatus(response.status);
        return parseRoom(response.body, resolveMedia: resolveMedia);
      });

  static NimoTvRoom parseRoom(String html, {required bool resolveMedia}) {
    if (html.length > responseLimit) throw const NimoTvException(NimoTvFailure.schema);
    final match = RegExp(
      r'<script>\s*var\s+G_roomBaseInfo\s*=\s*(\{.*?\});\s*</script>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) throw const NimoTvException(NimoTvFailure.missing);
    final Map<String, dynamic> data;
    try {
      data = _object(jsonDecode(match.group(1)!));
    } on FormatException {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    final roomId = _id(data['roomId']);
    final status = _int(data['liveStreamStatus']);
    final state = switch (status) {
      0 => NimoTvState.offline,
      1 => NimoTvState.live,
      _ => NimoTvState.unknown,
    };
    final screenshots = _nullableList(data['roomScreenshots'], max: 20);
    var cover = '';
    for (final value in screenshots) {
      final item = _object(value);
      final candidate = _image(item['url']);
      if (candidate.isNotEmpty) {
        cover = candidate;
        if (_optionalInt(item['key']) == 2) break;
      }
    }
    final qualities = resolveMedia && state == NimoTvState.live
        ? parseStreamPackage(_text(data['mStreamPkg']))
        : const <NimoTvQuality>[];
    return NimoTvRoom(
      roomId: roomId,
      anchorId: _id(data['anchorId'] ?? data['auId']),
      nickname: _text(data['nickname']),
      avatar: _image(data['avatarUrl'] ?? data['head_img']),
      cover: cover,
      title: _firstText([data['title'], data['nickname']]),
      category: _optionalText(data['game']),
      viewerCount: state == NimoTvState.live ? _optionalNonNegativeInt(data['viewerNum']) : null,
      state: state,
      qualities: qualities,
    );
  }

  static List<NimoTvQuality> parseStreamPackage(String rawHex) {
    if (rawHex.isEmpty || rawHex.length.isOdd || rawHex.length > 32768 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(rawHex)) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    final bytes = <int>[];
    for (var offset = 0; offset < rawHex.length; offset += 2) {
      bytes.add(int.parse(rawHex.substring(offset, offset + 2), radix: 16));
    }
    final payload = String.fromCharCodes(bytes);
    final appId = _capture(payload, r'appid=(\d+)');
    final hlsDomain = _capture(payload, r'(https?://[A-Za-z]{2,3}\.hls[A-Za-z./]+)(?:V|&)');
    final streamId = _capture(payload, r'\|id=([^|\\\x00-\x1f&]+)');
    final timestamp = _capture(payload, r'tp=(\d+)');
    final secret = _capture(payload, r'wsSecret=(\w+)');
    final expires = _capture(payload, r'wsTime=(\w+)');
    final flvBase =
        '${hlsDomain.replaceFirst('http://', 'https://').replaceFirst('hls.nimo.tv', 'flv.nimo.tv')}$streamId.flv';
    final base = Uri.tryParse(flvBase);
    if (base == null ||
        base.scheme != 'https' ||
        !RegExp(r'^[a-z]{2,3}\.flv\.nimo\.tv$').hasMatch(base.host.toLowerCase())) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    const definitions = [
      (ratio: 6000, label: '1080p', sort: 6000, needWatermark: false, sphd: false),
      (ratio: 2500, label: '720p', sort: 2500, needWatermark: true, sphd: true),
      (ratio: 1000, label: '480p', sort: 1000, needWatermark: true, sphd: true),
      (ratio: 500, label: '360p', sort: 500, needWatermark: true, sphd: true),
      (ratio: 250, label: '240p', sort: 250, needWatermark: true, sphd: false),
    ];
    return List.unmodifiable(
      definitions.map((definition) {
        final params = <String, String>{
          'appid': appId,
          'id': streamId,
          'tp': timestamp,
          'wsSecret': secret,
          'wsTime': expires,
          'u': '0',
          't': '100',
          'needwm': definition.needWatermark ? '1' : '0',
          'ratio': '${definition.ratio}',
          if (definition.sphd) 'sphd': '1',
        };
        return NimoTvQuality(
          id: 'flv:${definition.ratio}',
          label: '${definition.label} · FLV',
          sort: definition.sort,
          url: base.replace(queryParameters: params),
        );
      }),
    );
  }

  static DateTime? mediaInvalidAt(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    final raw = uri?.queryParameters['wsTime'];
    if (raw == null || !RegExp(r'^[0-9a-fA-F]{6,16}$').hasMatch(raw)) return null;
    final seconds = int.tryParse(raw, radix: 16);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).subtract(const Duration(seconds: 10));
  }

  static DateTime? mediaRefreshAt(String rawUrl) => mediaInvalidAt(rawUrl)?.subtract(const Duration(minutes: 5));

  static String _capture(String value, String pattern) {
    final result = RegExp(pattern).firstMatch(value)?.group(1)?.trim() ?? '';
    if (result.isEmpty || result.length > 4096) throw const NimoTvException(NimoTvFailure.schema);
    return result;
  }

  static String _id(Object? value) {
    final text = value is int
        ? value.toString()
        : value is String
        ? value.trim()
        : '';
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(text)) throw const NimoTvException(NimoTvFailure.schema);
    return text;
  }

  static String _text(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) throw const NimoTvException(NimoTvFailure.schema);
    return text;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const NimoTvException(NimoTvFailure.schema);
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const NimoTvException(NimoTvFailure.schema);
    final text = value.trim();
    if (text.length > 8192) throw const NimoTvException(NimoTvFailure.schema);
    return text;
  }

  static String _image(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasFragment || !const {'http', 'https'}.contains(uri.scheme)) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    final host = uri.host.toLowerCase();
    if (!(host == 'img.nimo.tv' || host.endsWith('.nimo.tv') || host.endsWith('.nimostatic.tv'))) {
      throw const NimoTvException(NimoTvFailure.schema);
    }
    return uri.replace(scheme: 'https', port: null).toString();
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? (throw const NimoTvException(NimoTvFailure.schema));
  }

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    return _int(value);
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null) return null;
    final result = _int(value);
    if (result < 0) throw const NimoTvException(NimoTvFailure.schema);
    return result;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const NimoTvException(NimoTvFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _nullableList(Object? value, {required int max}) {
    if (value == null || value == ' ') return const [];
    if (value is! List || value.length > max) throw const NimoTvException(NimoTvFailure.schema);
    return value;
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 => NimoTvFailure.schema,
      401 || 403 => NimoTvFailure.access,
      404 => NimoTvFailure.missing,
      429 => NimoTvFailure.rateLimited,
      >= 500 => NimoTvFailure.service,
      _ => NimoTvFailure.transport,
    };
    if (failure != null) throw NimoTvException(failure);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'shopeelive_browser.dart';
import 'shopeelive_link.dart';

enum ShopeeLiveFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  api,
  schema,
  identity,
  cancelled,
  unknownState,
  mediaUnavailable,
}

class ShopeeLiveException implements Exception {
  const ShopeeLiveException(this.kind);

  final ShopeeLiveFailure kind;

  @override
  String toString() => 'Shopee Live ${kind.name}';
}

enum ShopeeLiveState { live, offline, unknown }

final class ShopeeLiveCard {
  const ShopeeLiveCard({
    required this.sessionId,
    required this.title,
    required this.cover,
    required this.viewerCount,
    required this.shopId,
    required this.userId,
    required this.roomId,
  });

  final String sessionId;
  final String title;
  final String cover;
  final int? viewerCount;
  final String shopId;
  final String userId;
  final String roomId;

  String get storageKey => 'id:$sessionId';
}

final class ShopeeLiveDirectoryPage {
  ShopeeLiveDirectoryPage({required Iterable<ShopeeLiveCard> rooms}) : rooms = List.unmodifiable(rooms);

  final List<ShopeeLiveCard> rooms;
}

final class ShopeeLiveQuality {
  ShopeeLiveQuality({required this.id, required this.label, required this.sort, required Iterable<Uri> urls})
    : urls = List.unmodifiable(urls);

  final String id;
  final String label;
  final int sort;
  final List<Uri> urls;
}

final class ShopeeLiveRoom {
  ShopeeLiveRoom({
    required this.sessionId,
    required this.roomId,
    required this.userId,
    required this.shopId,
    required this.username,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.viewerCount,
    required this.state,
    required Iterable<ShopeeLiveQuality> qualities,
  }) : qualities = List.unmodifiable(qualities);

  final String sessionId;
  final String roomId;
  final String userId;
  final String shopId;
  final String username;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final int? viewerCount;
  final ShopeeLiveState state;
  final List<ShopeeLiveQuality> qualities;

  String get storageKey => 'id:$sessionId';
}

typedef ShopeeLiveRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

/// Current public Shopee Indonesia live-directory and session contract.
///
/// The homepage feed is a finite recommendation snapshot. Session requests
/// first use the ordinary endpoint, then enter the official web application
/// context when Shopee asks for browser-generated fingerprint/SAP headers.
class ShopeeLiveApi {
  ShopeeLiveApi({
    ShopeeLiveRequest? request,
    ShopeeLiveSessionResolver? sessionResolver,
    this.deadline = const Duration(seconds: 45),
    this.sessionDeadline = const Duration(seconds: 80),
  }) : _request = request ?? _defaultRequest,
       _sessionResolver = sessionResolver ?? ShopeeLiveBrowserSessionResolver();

  static const String marketplaceOrigin = 'https://shopee.co.id';
  static const String liveOrigin = 'https://live.shopee.co.id';
  static const int responseLimit = 4 * 1024 * 1024;

  /// Playback CDNs: third-party edges (`cdnID=TXCLOUD`/`HUAWEI`) and Shopee's
  /// own (`play-spe.livestream`, `cdnID=SHOPEE`). All serve codec-id-12 HEVC FLV.
  static const Set<String> mediaHostSuffixes = {'.livetech.shopee.co.id', '.livestream.shopee.co.id'};
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  static Uri get directoryUri => Uri.parse('$marketplaceOrigin/api/v4/homepage/get_homepage_live_info');

  static Uri sessionUri(String sessionId) => Uri.parse('$liveOrigin/api/v1/session/$sessionId');

  static Map<String, String> directoryHeaders() => const {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'id-ID,id;q=0.9,en;q=0.8',
    'Referer': '$marketplaceOrigin/',
  };

  static Map<String, String> sessionHeaders() => const {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'id-ID,id;q=0.9,en;q=0.8',
    'Client-Info': 'os=2;platform=9',
    'X-Livestreaming-Source': 'shopee',
    'Origin': liveOrigin,
    'Referer': '$liveOrigin/',
  };

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Origin': liveOrigin,
    'Referer': ShopeeLiveLink.url(roomId),
  };

  final ShopeeLiveRequest _request;
  final ShopeeLiveSessionResolver _sessionResolver;
  final Duration deadline;

  /// Session lookups usually fall back to a headless WebView, whose cold start
  /// (engine, page and module loading) alone can take over 45 seconds. The
  /// resolver's own stages are bounded at 12 + 20 + 35 seconds.
  final Duration sessionDeadline;

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
    if (body == null) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    final content = await _readBody(body.stream);
    return (status: response.statusCode ?? 0, body: content);
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const ShopeeLiveException(ShopeeLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work, {Duration? timeout}) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const ShopeeLiveException(ShopeeLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const ShopeeLiveException(ShopeeLiveFailure.cancelled)),
          ]).timeout(timeout ?? deadline);
        } on TimeoutException {
          throw const ShopeeLiveException(ShopeeLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const ShopeeLiveException(ShopeeLiveFailure.cancelled);
          }
          if (error is ShopeeLiveException) rethrow;
          throw const ShopeeLiveException(ShopeeLiveFailure.transport);
        }
      });

  Future<ShopeeLiveDirectoryPage> directory({CancelToken? cancel}) => _scope(cancel, (token) async {
    final response = await _request(directoryUri, directoryHeaders(), token);
    _throwStatus(response.status);
    final root = _decodeObject(response.body);
    if (root['error'] != null) throw const ShopeeLiveException(ShopeeLiveFailure.api);
    final data = _object(root['data']);
    final sessions = _list(data['sessions'], max: 80);
    return ShopeeLiveDirectoryPage(rooms: sessions.map((item) => parseDirectoryCard(_object(item))));
  });

  Future<ShopeeLiveRoom> session(String rawRoomId, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final key = ShopeeLiveLink.parseKey(rawRoomId);
    if (key == null) throw const ShopeeLiveException(ShopeeLiveFailure.identity);
    final response = await _request(sessionUri(key.sessionId), sessionHeaders(), token);
    Map<String, dynamic> payload;
    if (response.status == 200) {
      payload = _sessionPayload(_decodeObject(response.body));
    } else if (response.status == 401 || response.status == 403) {
      try {
        payload = await _sessionResolver.resolve(key.sessionId);
      } catch (_) {
        if (token.isCancelled) throw const ShopeeLiveException(ShopeeLiveFailure.cancelled);
        throw const ShopeeLiveException(ShopeeLiveFailure.access);
      }
    } else {
      _throwStatus(response.status);
      throw const ShopeeLiveException(ShopeeLiveFailure.transport);
    }
    if (token.isCancelled) throw const ShopeeLiveException(ShopeeLiveFailure.cancelled);
    return parseSession(payload, expectedSessionId: key.sessionId);
  }, timeout: sessionDeadline);

  Future<ShopeeLiveRoom> refresh(String rawRoomId, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final key = ShopeeLiveLink.parseKey(rawRoomId);
    if (key == null) throw const ShopeeLiveException(ShopeeLiveFailure.identity);
    final result = await directory(cancel: token);
    for (final card in result.rooms) {
      if (card.sessionId == key.sessionId) return roomFromCard(card);
    }
    return session(key.storageKey, cancel: token);
  });

  static ShopeeLiveCard parseDirectoryCard(Map<String, dynamic> data) {
    final sessionId = _id(data['session_id']);
    final status = _int(data['status']);
    if (status != 1) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return ShopeeLiveCard(
      sessionId: sessionId,
      title: _text(data['title']),
      cover: _image(data['cover']),
      viewerCount: _optionalNonNegativeInt(data['view_count']),
      shopId: _optionalId(data['shop_id']),
      userId: _optionalId(data['user_id']),
      roomId: _optionalId(data['room_id']),
    );
  }

  static ShopeeLiveRoom roomFromCard(ShopeeLiveCard card) => ShopeeLiveRoom(
    sessionId: card.sessionId,
    roomId: card.roomId,
    userId: card.userId,
    shopId: card.shopId,
    username: '',
    nickname: '',
    title: card.title,
    avatar: '',
    cover: card.cover,
    viewerCount: card.viewerCount,
    state: ShopeeLiveState.live,
    qualities: const [],
  );

  static ShopeeLiveRoom parseSession(Map<String, dynamic> data, {required String expectedSessionId}) {
    final session = _object(data['session']);
    final sessionId = _id(session['session_id']);
    if (sessionId != expectedSessionId) throw const ShopeeLiveException(ShopeeLiveFailure.identity);
    final terminated = _bool(session['is_terminate']);
    final status = _int(session['status']);
    final state = terminated || status == 2 || status == 3
        ? ShopeeLiveState.offline
        : status == 1
        ? ShopeeLiveState.live
        : ShopeeLiveState.unknown;
    final qualities = state == ShopeeLiveState.live ? _parseQualities(data, session) : const <ShopeeLiveQuality>[];
    return ShopeeLiveRoom(
      sessionId: sessionId,
      roomId: _optionalId(session['room_id']),
      userId: _optionalId(session['uid']),
      shopId: _optionalId(session['shop_id']),
      username: _optionalText(session['username']),
      nickname: _optionalText(session['nickname']),
      title: _firstText([session['title'], session['nickname'], session['username']]),
      avatar: _image(session['avatar']),
      cover: _image(session['cover_pic']),
      viewerCount: _optionalNonNegativeInt(session['viewer_count']),
      state: state,
      qualities: qualities,
    );
  }

  static List<ShopeeLiveQuality> _parseQualities(Map<String, dynamic> data, Map<String, dynamic> session) {
    final candidates = <Object?>[..._nullableList(data['play_urls'], max: 20), session['play_url']];
    final grouped = <String, List<Uri>>{};
    final labels = <String, String>{};
    final sorts = <String, int>{};
    final seen = <String>{};
    for (final candidate in candidates) {
      final uri = _media(candidate);
      if (uri == null || !seen.add(uri.toString())) continue;
      final dimensions = RegExp(r'^(\d{2,5})x(\d{2,5})$').firstMatch(uri.queryParameters['resolution'] ?? '');
      final width = int.tryParse(dimensions?.group(1) ?? '') ?? 0;
      final height = int.tryParse(dimensions?.group(2) ?? '') ?? 0;
      final edge = width == 0 || height == 0 ? 0 : (width < height ? width : height);
      final id = dimensions == null ? 'source' : '${width}x$height';
      final format = uri.path.toLowerCase().endsWith('.m3u8') ? 'HLS' : 'FLV';
      labels[id] = edge > 0 ? '${edge}p · $format' : 'Original · $format';
      sorts[id] = edge;
      grouped.putIfAbsent(id, () => <Uri>[]).add(uri);
    }
    final result =
        grouped.entries
            .map(
              (entry) => ShopeeLiveQuality(
                id: entry.key,
                label: labels[entry.key]!,
                sort: sorts[entry.key]!,
                urls: entry.value,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => right.sort.compareTo(left.sort));
    return List.unmodifiable(result);
  }

  static DateTime? mediaInvalidAt(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    final seconds = int.tryParse(uri?.queryParameters['expire_ts'] ?? '');
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).subtract(const Duration(seconds: 10));
  }

  static DateTime? mediaRefreshAt(String rawUrl) {
    final invalid = mediaInvalidAt(rawUrl);
    return invalid?.subtract(const Duration(minutes: 2));
  }

  static Map<String, dynamic> _sessionPayload(Map<String, dynamic> root) {
    if (root['session'] is Map) return root;
    final data = root['data'];
    if (data is Map && data['session'] is Map) return data.map((key, value) => MapEntry(key.toString(), value));
    throw const ShopeeLiveException(ShopeeLiveFailure.schema);
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 => ShopeeLiveFailure.schema,
      401 || 403 => ShopeeLiveFailure.access,
      404 => ShopeeLiveFailure.missing,
      429 => ShopeeLiveFailure.rateLimited,
      >= 500 => ShopeeLiveFailure.service,
      _ => ShopeeLiveFailure.transport,
    };
    if (failure != null) throw ShopeeLiveException(failure);
  }

  static Map<String, dynamic> _decodeObject(String body) {
    if (body.length > responseLimit) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    try {
      return _object(jsonDecode(body));
    } on FormatException {
      throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return value;
  }

  static List<Object?> _nullableList(Object? value, {required int max}) {
    if (value == null) return const [];
    return _list(value, max: max);
  }

  static String _text(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return text;
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    final text = value.trim();
    if (text.length > 4096) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return text;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const ShopeeLiveException(ShopeeLiveFailure.schema);
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? (throw const ShopeeLiveException(ShopeeLiveFailure.schema));
    }
    throw const ShopeeLiveException(ShopeeLiveFailure.schema);
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null) return null;
    final result = _int(value);
    if (result < 0) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return result;
  }

  static String _id(Object? value) {
    final id = _optionalId(value);
    if (id.isEmpty) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return id;
  }

  static String _optionalId(Object? value) {
    if (value == null) return '';
    final text = value is int
        ? value.toString()
        : value is String
        ? value.trim()
        : '';
    if (text.isEmpty) return '';
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(text)) throw const ShopeeLiveException(ShopeeLiveFailure.schema);
    return text;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value == 0) return false;
    if (value == 1) return true;
    throw const ShopeeLiveException(ShopeeLiveFailure.schema);
  }

  static String _image(Object? value) {
    final raw = _optionalText(value);
    if (raw.isEmpty) return '';
    if (RegExp(r'^[A-Za-z0-9_-]{8,160}$').hasMatch(raw)) {
      return 'https://down-ws-id.img.susercontent.com/file/$raw';
    }
    // Artwork is cosmetic: an unrecognised value shows the placeholder
    // instead of failing the whole room or directory.
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) return '';
    final host = uri.host.toLowerCase();
    if (host != 'cf.shopee.co.id' && !host.endsWith('.img.susercontent.com')) return '';
    return uri.toString();
  }

  /// A session lists several candidates; one from an unrecognised CDN or
  /// scheme is skipped rather than failing the room. A live room with no
  /// usable candidate left is reported as media-unavailable by the site.
  static Uri? _media(Object? value) {
    final raw = value is String ? value.trim() : '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !mediaHostSuffixes.any(uri.host.toLowerCase().endsWith) ||
        (!uri.path.toLowerCase().endsWith('.flv') && !uri.path.toLowerCase().endsWith('.m3u8'))) {
      return null;
    }
    return uri;
  }
}

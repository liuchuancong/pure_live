// The station's local decrypting proxy: the player talks to a loopback URL,
// the proxy range-fetches the CDN's CENC-encrypted file (with the vendor
// headers the CDN insists on), decrypts the samples on the fly and serves
// the plain mp4 — the Dart answer to the reference's player DataSource.
import 'dart:async' show Completer, unawaited;
import 'dart:io' show ContentType, HttpRequest, HttpServer, InternetAddress;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;

import 'package:pure_live/modules/hongguo/official/hongguo_media_crypto.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition;
import 'package:pure_live/modules/hongguo/official/hongguo_vendor.dart' show HongguoVendor;

/// The most the proxy puts behind one response — the reference's own
/// per-request cap. A wider ask is answered honestly: the `Content-Range`
/// names the bytes actually delivered, and the player keeps from there.
const int _kChunk = 8 * 1024 * 1024;
const int _kProbe = 256 * 1024;

final class _Entry {
  _Entry(this.rendition);

  final HongguoRendition rendition;
  int total = -1;
  HongguoPrepared? prepared;
  Future<void>? preparing;
}

/// Serves registered renditions at `http://127.0.0.1:<port>/<token>/e.mp4`.
final class HongguoStreamProxy {
  /// Creates the proxy over the shared transport.
  HongguoStreamProxy({required this._http});

  final LiveHttp _http;
  final Map<String, _Entry> _entries = {};
  HttpServer? _server;

  /// Registers [rendition] and answers the local URL the player opens.
  Future<String> register(HongguoRendition rendition) async {
    final server = await _ensureServer();
    final token = _token();
    _entries[token] = _Entry(rendition);
    return 'http://127.0.0.1:${server.port}/$token/e.mp4';
  }

  /// Forgets every registered stream (the player page closed).
  void clear() => _entries.clear();

  /// Stops the server.
  Future<void> close() async {
    clear();
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  static String _token() {
    final random = math.Random.secure();
    return List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  Future<HttpServer> _ensureServer() async {
    final existing = _server;
    if (existing != null) return existing;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object _) {
        // A failed accept must not take the process down.
      },
    );
    _server = server;
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final token = request.uri.pathSegments.isEmpty ? '' : request.uri.pathSegments.first;
      final entry = _entries[token];
      if (entry == null) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      await _prepare(entry);
      final total = entry.total;
      final response = request.response..bufferOutput = false;
      final range = _rangeOf(request.headers.value('range'), total);
      final start = range?.$1 ?? 0;
      var end = range?.$2 ?? total - 1;
      if (end - start + 1 > _kChunk) end = start + _kChunk - 1;
      if (start >= total || end >= total || start > end) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */$total');
        await response.close();
        return;
      }
      final bytes = await _slice(entry, start, end + 1);
      response.statusCode = range == null && start == 0 && end == total - 1 ? 200 : 206;
      response.headers.set('Accept-Ranges', 'bytes');
      response.headers.set('Content-Length', '${bytes.length}');
      response.headers.contentType = ContentType.binary;
      if (response.statusCode == 206) {
        response.headers.set('Content-Range', 'bytes $start-${start + bytes.length - 1}/$total');
      }
      response.add(bytes);
      await response.flush();
      await response.close();
    } on Object {
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } on Object {
        // The player already hung up.
      }
    }
  }

  (int, int)? _rangeOf(String? header, int total) {
    if (header == null) return null;
    final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(header);
    if (match == null) return null;
    final rawStart = match.group(1) ?? '';
    final rawEnd = match.group(2) ?? '';
    if (rawStart.isEmpty && rawEnd.isEmpty) return null;
    if (rawStart.isEmpty) {
      final suffix = int.parse(rawEnd);
      return (total - suffix, total - 1);
    }
    final start = int.parse(rawStart);
    final end = rawEnd.isEmpty ? total - 1 : math.min(int.parse(rawEnd), total - 1);
    return (start, end);
  }

  /// The header's map and the file's length, fetched once per stream.
  Future<void> _prepare(_Entry entry) async {
    if (entry.prepared != null) return;
    final pending = entry.preparing;
    if (pending != null) {
      await pending;
      return;
    }
    final completer = Completer<void>();
    entry.preparing = completer.future;
    try {
      final first = await _fetch(entry, 0, _kProbe - 1);
      final total = _totalOf(first);
      entry.total = total;
      final headerEnd = HongguoMediaCrypto.headerEnd(first.bytes, total);
      Uint8List header;
      if (headerEnd > first.bytes.length) {
        final rest = await _fetch(entry, first.bytes.length, headerEnd - 1);
        header = Uint8List.fromList([...first.bytes, ...rest.bytes]);
      } else {
        header = Uint8List.fromList(first.bytes.sublist(0, headerEnd));
      }
      entry.prepared = HongguoMediaCrypto.prepare(header, entry.rendition.key);
      completer.complete();
    } on Object catch (error) {
      entry.preparing = null;
      completer.completeError(error);
      rethrow;
    }
  }

  int _totalOf(_Fetched fetched) {
    if (fetched.total > 0) return fetched.total;
    if (fetched.bytes.length < _kProbe) return fetched.bytes.length;
    throw const HongguoProxyFailure('视频服务器没有报告资源大小');
  }

  Future<Uint8List> _slice(_Entry entry, int start, int endExclusive) async {
    await _prepare(entry);
    final fetched = await _fetch(entry, start, endExclusive - 1);
    return HongguoMediaCrypto.decrypt(fetched.bytes, start, entry.rendition.key, entry.prepared!);
  }

  Future<_Fetched> _fetch(_Entry entry, int start, int end) async {
    final response = await _http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.parse(entry.rendition.url),
        headers: {
          'User-Agent': HongguoVendor.videoUa,
          'Referer': 'https://novel.snssdk.com/',
          'Range': 'bytes=$start-$end',
          'Accept-Encoding': 'identity',
        },
        timeout: const Duration(seconds: 30),
      ),
    );
    if (response.statusCode != 206) {
      throw HongguoProxyFailure('视频服务器不支持分段读取（HTTP ${response.statusCode}）');
    }
    final contentRange = response.headers['content-range'] ?? '';
    final match = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
    if (match == null) {
      throw const HongguoProxyFailure('视频分段响应异常');
    }
    final begin = int.parse(match.group(1)!);
    final finish = int.parse(match.group(2)!);
    final total = int.parse(match.group(3)!);
    // Decryption is by absolute offset, so a segment that does not start
    // where the request said it would is worse than no segment at all.
    final bytes = response.bodyBytes;
    if (begin != start || finish > end || bytes.length != finish - begin + 1) {
      throw const HongguoProxyFailure('视频分段响应与请求不符');
    }
    return _Fetched(bytes, total);
  }
}

final class _Fetched {
  const _Fetched(this.bytes, this.total);

  final Uint8List bytes;
  final int total;
}

/// The proxy could not serve the stream.
final class HongguoProxyFailure implements Exception {
  /// Creates the failure.
  const HongguoProxyFailure(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}

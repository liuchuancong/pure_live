import 'dart:typed_data';

import 'package:live_cache/src/image/image_request.dart';
import 'package:live_cache/src/models/cache_entry.dart';
import 'package:live_cache/src/models/cache_failure.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_net/live_net.dart';

/// One network answer for an image.
final class ImageFetchResult {
  /// Creates a result; [bytes] is null on a 304 answer.
  const new({required this.bytes, required this.headers, required this.notModified});

  /// The image bytes, or null when the server confirmed the copy is fresh.
  final Uint8List? bytes;

  /// Lower-cased response headers.
  final Map<String, String> headers;

  /// Whether the server answered 304.
  final bool notModified;
}

/// Fetches image bytes through the project's network kernel.
///
/// Every request walks the app's proxy policy because the `LiveHttp` is the
/// one the network factory builds per profile; the loader itself owns only
/// the conditional headers and the size ceiling.
final class ImageCacheLoader {
  /// Creates a loader over [http].
  new({required this.http, required this.timeout, this.log});

  /// The transport, normally `ClientProfile.media` from the host.
  final LiveHttp http;

  /// Per-phase timeout for one image.
  final Duration timeout;

  /// Optional diagnostics target.
  final LiveLog? log;

  /// Fetches [request], sending the validators in [entry] when present.
  ///
  /// [maxBytes] caps both the declared content length and the received
  /// stream. A body beyond it is refused before it can fill the disk. An
  /// address with no host is refused at this door: such a GET only ends
  /// as the transport's `No host specified in URI`.
  Future<ImageFetchResult> fetch({required ImageCacheRequest request, required int maxBytes, CacheEntry? entry}) async {
    final uri = request.url;
    if (uri.host.isEmpty) {
      throw const CacheFailure(CacheFailureKind.empty, message: 'image url has no host');
    }
    final headers = <String, String>{...request.headers};
    if (entry?.etag != null) {
      headers['if-none-match'] = entry!.etag!;
    }
    if (entry?.lastModified != null) {
      headers['if-modified-since'] = entry!.lastModified!;
    }
    LiveStreamedResponse response;
    try {
      response = await http.open(LiveRequest.get(uri, headers: headers, timeout: timeout));
    } on TransportFailure catch (failure) {
      throw _mapTransport(failure);
    }
    final status = response.statusCode;
    if (status == 304) {
      await response.close();
      return ImageFetchResult(bytes: null, headers: response.headers, notModified: true);
    }
    if (status < 200 || status >= 300) {
      await response.close();
      throw CacheFailure(CacheFailureKind.http, statusCode: status, message: 'HTTP $status');
    }
    final declared = int.tryParse(response.headers['content-length'] ?? '');
    if (declared != null && declared > maxBytes) {
      await response.close();
      throw CacheFailure(CacheFailureKind.tooLarge, message: 'declared $declared bytes exceeds $maxBytes');
    }
    final builder = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.stream) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          await response.close();
          throw CacheFailure(CacheFailureKind.tooLarge, message: 'body exceeds $maxBytes bytes');
        }
      }
    } on CacheFailure {
      rethrow;
    } on TransportFailure catch (failure) {
      throw _mapTransport(failure);
    } on Object catch (error) {
      await response.close();
      throw CacheFailure(CacheFailureKind.unknown, message: 'image stream failed', cause: error);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw const CacheFailure(CacheFailureKind.empty, message: 'the server sent an empty body');
    }
    return ImageFetchResult(bytes: bytes, headers: response.headers, notModified: false);
  }

  CacheFailure _mapTransport(TransportFailure failure) => switch (failure) {
    TimeoutFailure() => CacheFailure(CacheFailureKind.timeout, message: failure.description, cause: failure),
    ConnectFailure() ||
    TlsFailure() => CacheFailure(CacheFailureKind.offline, message: failure.description, cause: failure),
    CancelledFailure() => CacheFailure(CacheFailureKind.unknown, message: failure.description, cause: failure),
    ProtocolFailure() => CacheFailure(CacheFailureKind.unknown, message: failure.description, cause: failure),
  };
}

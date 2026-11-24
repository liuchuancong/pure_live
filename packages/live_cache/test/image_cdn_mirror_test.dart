import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_cache/live_cache.dart';
import 'package:live_net/live_net.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// A transport that breaks for the named hosts and serves bytes for the
/// rest, remembering every host it was asked for in order.
final class _SelectiveHttp implements LiveHttp {
  new({this.deadHosts = const {}, this.timedOutHosts = const {}, this.statusCode = 200});

  final Set<String> deadHosts;
  final Set<String> timedOutHosts;
  int statusCode;
  int requests = 0;
  final List<String> asked = <String>[];

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    requests++;
    asked.add(request.url.host);
    if (deadHosts.contains(request.url.host)) {
      throw const ConnectFailure('connection failed: 信号灯超时时间已到 (errno 121)');
    }
    if (timedOutHosts.contains(request.url.host)) {
      throw const TimeoutFailure('request timed out');
    }
    return _StreamedResponse(
      statusCode: statusCode,
      headers: const {},
      chunks: statusCode >= 200 && statusCode < 300 ? [_png] : const [],
    );
  }

  @override
  Future<LiveResponse> send(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

final class _StreamedResponse implements LiveStreamedResponse {
  new({required this.statusCode, required this.headers, required this.chunks});

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  final List<Uint8List> chunks;

  @override
  Stream<Uint8List> get stream => Stream<Uint8List>.fromIterable(chunks);

  @override
  Future<void> close() async {}
}

ImageCacheLoader _loader(LiveHttp http) => ImageCacheLoader(http: http, timeout: const Duration(seconds: 1));

ImageCacheRequest _request(String host) => ImageCacheRequest(
  url: Uri.parse(
    'https://$host/webcast-cover/7706062195716655907~tplv-qz53dukwul-common-resize:640:0.webp?x-signature=abc',
  ),
  policy: ImageCachePolicies.general,
);

void main() {
  group('the image loader mirrors a dead CDN node', () {
    test('a broken connection hands the fetch to a sibling node', () async {
      // A real outage shape: the signed-webcast pool dies wholesale
      // (errno 121 at the OS), the plain pool answers right away.
      final http = _SelectiveHttp(deadHosts: {'p11-webcast-sign.douyinpic.com'});
      final result = await _loader(http).fetch(request: _request('p11-webcast-sign.douyinpic.com'), maxBytes: 1 << 20);

      expect(result.bytes, _png);
      expect(http.asked, contains('p11-webcast-sign.douyinpic.com'));
      expect(http.asked.length, greaterThan(1), reason: 'at least one sibling was tried');
      expect(http.asked.first, 'p11-webcast-sign.douyinpic.com', reason: 'the original node goes first');
    });

    test('a timed-out node also finds a sibling', () async {
      final http = _SelectiveHttp(timedOutHosts: {'p3.douyinpic.com'});
      final result = await _loader(http).fetch(request: _request('p3.douyinpic.com'), maxBytes: 1 << 20);

      expect(result.bytes, _png);
      expect(http.requests, greaterThan(1));
    });

    test('an HTTP refusal stops the family walk after one attempt', () async {
      // A signature refused at one node is refused at every node: the
      // mirror family has nothing to add, so the answer comes back after
      // exactly one attempt.
      final http = _SelectiveHttp(statusCode: 403);
      await expectLater(
        _loader(http).fetch(request: _request('p11-webcast.douyinpic.com'), maxBytes: 1 << 20),
        throwsA(
          isA<CacheFailure>()
              .having((f) => f.kind, 'kind', CacheFailureKind.http)
              .having((f) => f.statusCode, 'status', 403),
        ),
      );
      expect(http.requests, 1, reason: 'no mirror is asked for an HTTP-level refusal');
    });

    test('a host outside every family gets no mirror to try', () async {
      final http = _SelectiveHttp(deadHosts: {'images.example.test'});
      await expectLater(
        _loader(http).fetch(
          request: ImageCacheRequest(
            url: Uri.parse('https://images.example.test/a.png'),
            policy: ImageCachePolicies.general,
          ),
          maxBytes: 1 << 20,
        ),
        throwsA(isA<CacheFailure>().having((f) => f.kind, 'kind', CacheFailureKind.offline)),
      );
      expect(http.requests, 1);
    });

    test('every failure in the family still answers the last transport failure', () async {
      final http = _SelectiveHttp(
        deadHosts: {
          'p11-webcast-sign.douyinpic.com',
          'p3.douyinpic.com',
          'p6.douyinpic.com',
          'p9.douyinpic.com',
          'p26.douyinpic.com',
          'p3-webcast.douyinpic.com',
          'p9-webcast.douyinpic.com',
          'p11-webcast.douyinpic.com',
          'p3-webcast-sign.douyinpic.com',
          'p9-webcast-sign.douyinpic.com',
        },
      );
      await expectLater(
        _loader(http).fetch(request: _request('p11-webcast-sign.douyinpic.com'), maxBytes: 1 << 20),
        throwsA(isA<CacheFailure>().having((f) => f.kind, 'kind', CacheFailureKind.offline)),
      );
      expect(http.requests, 10, reason: 'the original plus all nine siblings had their turn');
    });
  });

  group('mirrorsFor', () {
    test('a douyinpic host answers its whole family, itself excluded', () {
      final mirrors = mirrorsFor(Uri.parse('https://p11-webcast-sign.douyinpic.com/a.webp?x-signature=abc'));

      expect(mirrors, hasLength(9));
      expect(mirrors.map((uri) => uri.host), isNot(contains('p11-webcast-sign.douyinpic.com')));
      expect(mirrors.map((uri) => uri.host), contains('p3.douyinpic.com'));
      expect(mirrors.first.path, '/a.webp', reason: 'the asset path rides along');
      expect(mirrors.first.query, 'x-signature=abc', reason: 'the signature query rides along');
    });

    test('a stranger answers nothing', () {
      expect(mirrorsFor(Uri.parse('https://images.example.test/a.png')), isEmpty);
      expect(
        mirrorsFor(Uri.parse('https://example.douyinpic.com.evil.test/a.png')),
        isEmpty,
        reason: 'a suffix lookalike is not family',
      );
    });
  });
}

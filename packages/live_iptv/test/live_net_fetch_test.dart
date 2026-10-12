import 'dart:convert';
import 'dart:typed_data';

import 'package:live_iptv/src/import/live_net_fetch.dart';
import 'package:live_net/live_net.dart';
import 'package:test/test.dart';

/// The transport the fetchers are tried against: one canned answer per URL,
/// and a record of what was asked, so the import rules can be tested without
/// a socket.
final class _StubHttp implements LiveHttp {
  new({this.status = 200, this.contentType = 'application/octet-stream', this.chunks = const [], this.body});

  final int status;
  final String contentType;
  final List<List<int>> chunks;
  final String? body;
  final List<LiveRequest> asked = [];
  _StubResponse? opened;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request);
    return LiveResponse(
      statusCode: status,
      headers: {'content-type': contentType},
      bodyBytes: Uint8List.fromList(utf8.encode(body ?? '')),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    asked.add(request);
    final response = _StubResponse(statusCode: status, contentType: contentType, chunks: chunks);
    opened = response;
    return response;
  }

  @override
  void close() {}
}

/// One canned streamed answer, recording whether the reader closed it.
final class _StubResponse implements LiveStreamedResponse {
  new({required this.statusCode, required this.contentType, required this.chunks});

  @override
  final int statusCode;
  final String contentType;
  final List<List<int>> chunks;
  bool closed = false;

  @override
  Map<String, String> get headers => {'content-type': contentType};

  @override
  Stream<Uint8List> get stream => Stream.fromIterable([for (final chunk in chunks) Uint8List.fromList(chunk)]);

  @override
  Future<void> close() async => closed = true;
}

void main() {
  group('iptvFetcherFor', () {
    test('returns the body as text', () async {
      final http = _StubHttp(body: '#EXTM3U\nhttp://a/1.m3u8\n');

      expect(await iptvFetcherFor(http)(Uri.parse('http://list.example/a.m3u8')), contains('#EXTM3U'));
    });

    test('a refused address is an error, not empty text', () async {
      final http = _StubHttp(status: 404, body: 'not found');

      await expectLater(iptvFetcherFor(http)(Uri.parse('http://list.example/gone')), throwsA(isA<HttpStatusFailure>()));
    });

    test('the probe user agent is a default, not an override', () async {
      final http = _StubHttp(body: 'x');
      final fetch = iptvFetcherFor(http, userAgent: 'PureLive/1');

      await fetch(Uri.parse('http://list.example/a'), headers: {'user-agent': 'the caller wins'});
      await fetch(Uri.parse('http://list.example/b'));

      expect(http.asked.first.headers['user-agent'], 'the caller wins');
      expect(http.asked.last.headers['user-agent'], 'PureLive/1');
    });
  });

  group('iptvBytesFetcherFor', () {
    test('gathers the chunks and closes the response', () async {
      final http = _StubHttp(
        contentType: 'application/gzip',
        chunks: [
          [0x1f, 0x8b],
          [0x08, 0x00],
        ],
      );

      final bytes = await iptvBytesFetcherFor(http)(Uri.parse('http://guide.example/epg.xml.gz'));

      expect(bytes, [0x1f, 0x8b, 0x08, 0x00]);
      expect(http.opened!.closed, isTrue);
    });

    test('refuses a body past the limit instead of buffering it', () async {
      final http = _StubHttp(chunks: [List<int>.filled(4096, 7), List<int>.filled(4096, 7)]);

      await expectLater(
        iptvBytesFetcherFor(http, limit: 6000)(Uri.parse('http://guide.example/huge')),
        throwsA(isA<FormatException>()),
      );
      // The abort has to stop the transfer too: the answer is refused, not
      // left draining into a list nobody reads.
      expect(http.opened!.closed, isTrue);
    });

    test('a refused guide is an error and the socket is dropped', () async {
      final http = _StubHttp(status: 503, chunks: [utf8.encode('service unavailable')]);

      await expectLater(
        iptvBytesFetcherFor(http)(Uri.parse('http://guide.example/epg.xml')),
        throwsA(isA<HttpStatusFailure>()),
      );
      expect(http.opened!.closed, isTrue);
    });

    test('the timeout travels with the request', () async {
      final http = _StubHttp();

      await iptvBytesFetcherFor(http, timeout: const Duration(seconds: 3))(Uri.parse('http://guide.example/x'));

      expect(http.asked.single.timeout, const Duration(seconds: 3));
    });
  });
}

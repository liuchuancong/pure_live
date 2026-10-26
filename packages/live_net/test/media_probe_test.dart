import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_net/src/http/dio_http.dart';
import 'package:test/test.dart';

import 'support/test_server.dart';

/// One 188-byte MPEG transport-stream packet.
Uint8List tsPacket([int seed = 0]) {
  final packet = Uint8List(188)..fillRange(0, 188, 0xAA);
  packet[0] = 0x47;
  packet[1] = seed & 0x1f;
  return packet;
}

/// Two packets, which is what the sync test needs to see.
List<int> tsHead() => [tsPacket(1), tsPacket(2)].expand((packet) => packet).toList();

Future<TestServer> startServer(FutureOr<void> Function(HttpRequest request) handler) async {
  final server = await TestServer.start(handler);
  addTearDown(server.close);
  return server;
}

void main() {
  group('sniffMediaContainer', () {
    test('reads the FLV signature', () {
      expect(sniffMediaContainer([0x46, 0x4c, 0x56, 0x09, 0, 0, 0, 9]), MediaContainer.flv);
    });

    test('reads the transport-stream sync bytes 188 apart', () {
      expect(sniffMediaContainer(tsHead()), MediaContainer.mpegTs);
    });

    test('accepts a single sync packet when that is all it was given', () {
      expect(sniffMediaContainer(tsPacket(3)), MediaContainer.mpegTs);
    });

    test('reads an HLS master playlist', () {
      expect(
        sniffMediaContainer(utf8.encode('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n/low.m3u8\n')),
        MediaContainer.hlsPlaylist,
      );
    });

    test('reads an HLS playlist that arrives behind a byte-order mark', () {
      expect(sniffMediaContainer([0xef, 0xbb, 0xbf, ...utf8.encode('#EXTM3U\n')]), MediaContainer.hlsPlaylist);
    });

    test('reads a DASH manifest', () {
      expect(sniffMediaContainer(utf8.encode('<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">')), MediaContainer.dash);
    });

    test('reads an mp4 or fragmented-mp4 box', () {
      expect(
        sniffMediaContainer([0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d]),
        MediaContainer.isoBmff,
      );
      expect(sniffMediaContainer([0, 0, 0, 0x10, 0x73, 0x74, 0x79, 0x70, 0, 0, 0, 0]), MediaContainer.isoBmff);
    });

    test('reads a Matroska or WebM EBML header', () {
      expect(sniffMediaContainer([0x1a, 0x45, 0xdf, 0xa3, 0x01, 0x02]), MediaContainer.matroska);
    });

    test('reads an ID3 tag as MPEG audio', () {
      expect(sniffMediaContainer([0x49, 0x44, 0x33, 0x04, 0x00]), MediaContainer.mpegAudio);
    });

    test('reads an ADTS frame header as raw AAC', () {
      expect(sniffMediaContainer([0xff, 0xf1, 0x4c, 0x80]), MediaContainer.adts);
    });

    test('an HTML error page is no container', () {
      expect(sniffMediaContainer(utf8.encode('<html><body>404</body></html>')), MediaContainer.unknown);
      expect(sniffMediaContainer(const []), MediaContainer.unknown);
    });

    test('a lone 0xff stream marker is not mistaken for ADTS', () {
      // ADTS needs the 0xff 0xX0 pattern with the layer bits clear; a random
      // byte stream that starts 0xff 0x00 must not be called audio.
      expect(sniffMediaContainer([0xff, 0x00, 0x00, 0x00]), isNot(MediaContainer.adts));
    });
  });

  group('MediaProbe.checkUri', () {
    late DioLiveHttp http;
    late MediaProbe probe;

    setUp(() {
      http = DioLiveHttp();
      probe = MediaProbe(http: http, timeout: const Duration(seconds: 2));
      addTearDown(http.close);
    });

    test('a live FLV mirror is playable and the probe stops reading', () async {
      final server = await startServer((request) async {
        request.response.headers.contentType = ContentType.parse('video/x-flv');
        // An endless stream: the probe has to cut it off rather than
        // download it, which is the whole point of reading a head only.
        final chunk = Uint8List(1024)..[0] = 0x46;
        chunk[1] = 0x4c;
        chunk[2] = 0x56;
        var written = 0;
        while (written < 400000) {
          request.response.add(chunk);
          written += chunk.length;
          await request.response.flush();
        }
        await request.response.close();
      });

      final result = await probe.checkUri(server.url, headers: {'range': 'bytes=0-'});

      expect(result.playable, isTrue);
      expect(result.container, MediaContainer.flv);
      expect(result.statusCode, 200);
      expect(result.bytes, greaterThanOrEqualTo(64 * 1024));
      // The cap is met with at most one chunk of slack, and the rest of the
      // 400 KB the server was ready to send never left the socket: that is
      // the whole difference between probing a live stream and downloading it.
      expect(result.bytes, lessThan(2 * 64 * 1024));
      expect(result.latency, isNot(Duration.zero));
    });

    test('an HLS playlist answers with its container', () async {
      final server = await startServer((request) async {
        request.response.headers.contentType = ContentType.parse('application/vnd.apple.mpegurl');
        request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:10\n#EXTINF:10,\n/seg.ts\n');
        await request.response.close();
      });

      final result = await probe.checkUri(server.url);

      expect(result.playable, isTrue);
      expect(result.container, MediaContainer.hlsPlaylist);
    });

    test('a transport stream is recognised from its sync packets', () async {
      final server = await startServer((request) async {
        request.response.headers.contentType = ContentType.parse('application/octet-stream');
        request.response.add(tsPacket(1));
        request.response.add(tsPacket(2));
        request.response.add(tsPacket(3));
        await request.response.close();
      });

      final result = await probe.checkUri(server.url);

      expect(result.container, MediaContainer.mpegTs);
      expect(result.playable, isTrue);
    });

    test('a 200 that carries a web page is not a stream', () async {
      final server = await startServer((request) async {
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html><body>频道不存在</body></html>');
        await request.response.close();
      });

      final result = await probe.checkUri(server.url);

      expect(result.playable, isFalse);
      expect(result.inconclusive, isFalse);
      expect(result.message, contains('web page'));
    });

    test('a 200 with no body at all is a dead stream', () async {
      final server = await startServer((request) async {
        await request.response.close();
      });

      final result = await probe.checkUri(server.url);

      expect(result.playable, isFalse);
      expect(result.message, contains('no body'));
    });

    test('a refused address reports the status it was given', () async {
      final server = await startServer((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final result = await probe.checkUri(server.url);

      expect(result.playable, isFalse);
      expect(result.statusCode, 404);
      expect(result.message, contains('404'));
    });

    test('bytes with no known signature still count as something to play', () async {
      final server = await startServer((request) async {
        request.response.headers.contentType = ContentType.parse('application/octet-stream');
        request.response.add(Uint8List.fromList([0x10, 0x20, 0x30, 0x40, 0x50, 0x60]));
        await request.response.close();
      });

      final result = await probe.checkUri(server.url);

      // The player can sniff what it cannot name; saying "dead" here would
      // drop a working exotic source, and the container field says honestly
      // that the verdict came from "bytes arrived".
      expect(result.playable, isTrue);
      expect(result.container, MediaContainer.unknown);
      expect(result.container.isMedia, isFalse);
    });

    test('a host that answers no bytes at all is timed out, not left hanging', () async {
      final server = await startServer((request) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        request.response.write('#EXTM3U\n');
        await request.response.close();
      });

      final result = await probe.checkUri(server.url);

      expect(result.playable, isFalse);
      expect(result.inconclusive, isFalse);
      expect(result.statusCode, isNull);
    });

    test('the request carries the probe user agent and the caller may override it', () async {
      final seen = <String?>[];
      final server = await startServer((request) async {
        seen.add(request.headers.value('user-agent'));
        request.response.write('#EXTM3U\n');
        await request.response.close();
      });
      final withAgent = MediaProbe(http: http, userAgent: 'lua-probe/1.0');

      await withAgent.checkUri(server.url);
      await withAgent.checkUri(server.url, headers: {'user-agent': 'the callers own'});

      expect(seen, ['lua-probe/1.0', 'the callers own']);
    });

    test('a non-HTTP address is an abstention, not a failure', () async {
      final result = await probe.check('rtmp://live.example.com/live/cctv1');

      expect(result.playable, isFalse);
      expect(result.inconclusive, isTrue);
      expect(result.message, contains('rtmp'));
    });

    test('an address that is not a URL says so', () async {
      final result = await probe.check('CCTV1 中央一台');

      expect(result.playable, isFalse);
      expect(result.inconclusive, isFalse);
      expect(result.message, contains('not a URL'));
    });
  });

  group('MediaProbe over a stub transport', () {
    test('the head is capped at firstBytes and the response is closed', () async {
      final http = _StubHttp(
        chunks: [List<int>.filled(1024, 0x46), List<int>.filled(1024, 0), List<int>.filled(1024, 0)],
      );
      final probe = MediaProbe(http: http, firstBytes: 1500);

      final result = await probe.checkUri(Uri.parse('http://a/live.m3u8'));

      expect(result.bytes, 2048);
      expect(http.response!.closed, isTrue);
    });

    test('a transport that throws on open is reported as not media', () async {
      final http = _StubHttp(failure: const ConnectFailure('connection failed: refused'));
      final probe = MediaProbe(http: http);

      final result = await probe.checkUri(Uri.parse('http://a/1.m3u8'));

      expect(result.playable, isFalse);
      expect(result.message, contains('connect'));
    });
  });
}

/// A [LiveHttp] that answers [open] with canned chunks, so the byte-reading
/// rules can be checked without a socket.
final class _StubHttp implements LiveHttp {
  new({this.chunks = const [], this.failure});

  final List<List<int>> chunks;
  final Object? failure;
  _StubStreamedResponse? response;

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) {
    final raised = failure;
    if (raised != null) {
      return Future.error(raised);
    }
    final opened = _StubStreamedResponse(chunks: chunks);
    response = opened;
    return Future.value(opened);
  }

  @override
  Future<LiveResponse> send(LiveRequest request) => throw UnimplementedError('the probe never buffers a whole body');

  @override
  void close() {}
}

/// The canned streamed response, recording whether the probe closed it.
final class _StubStreamedResponse implements LiveStreamedResponse {
  new({required this.chunks});

  final List<List<int>> chunks;
  bool closed = false;

  @override
  int get statusCode => 200;

  @override
  Map<String, String> get headers => const {'content-type': 'application/octet-stream'};

  @override
  Stream<Uint8List> get stream => Stream.fromIterable([for (final chunk in chunks) Uint8List.fromList(chunk)]);

  @override
  Future<void> close() async => closed = true;
}

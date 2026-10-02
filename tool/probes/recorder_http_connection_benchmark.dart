import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pure_live/domains/recorder/data/services/cancellable_http_connections.dart';

// Local throughput comparison, not Android energy/performance acceptance.
// Certificate trust is restricted to the committed localhost test fixture.
Future<void> main() async {
  if (Platform.environment['PURELIVE_HTTP_CONNECTION_BENCHMARK'] != '1') {
    throw StateError('Set PURELIVE_HTTP_CONNECTION_BENCHMARK=1 to run the local benchmark');
  }
  final context = SecurityContext()
    ..useCertificateChain('test/fixtures/tls/localhost-cert.pem')
    ..usePrivateKey('test/fixtures/tls/localhost-key.pem');
  final trusted = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificates('test/fixtures/tls/localhost-cert.pem');
  final block = Uint8List.fromList(List.generate(64 * 1024, (i) => i % 251));
  const total = 64 * 1024 * 1024;
  final server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
  final sub = server.listen((request) async {
    try {
      request.response.contentLength = total;
      request.response.bufferOutput = false;
      for (var offset = 0; offset < total; offset += block.length) {
        request.response.add(block);
        await request.response.flush();
      }
      await request.response.close();
    } on Object {
      // Failure is detected by the receiving length/exception, never counted.
    }
  });
  final rows = <Map<String, Object>>[];
  try {
    for (var round = 0; round < 3; round++) {
      for (final bridge in round.isEven ? [false, true] : [true, false]) {
        final owner = bridge ? CancellableHttpConnections(securityContext: trusted) : null;
        final client = HttpClient(context: trusted)..findProxy = (_) => 'DIRECT';
        if (owner != null) client.connectionFactory = owner.connect;
        var length = 0;
        final rssBefore = ProcessInfo.currentRss;
        final watch = Stopwatch()..start();
        try {
          final response = await (await client.getUrl(Uri.parse('https://localhost:${server.port}/body'))).close();
          if (response.statusCode != 200) throw StateError('Unexpected HTTP response');
          await for (final bytes in response) {
            if (bytes.isEmpty) continue;
            if (bytes.first != (length % block.length) % 251 ||
                bytes.last != ((length + bytes.length - 1) % block.length) % 251) {
              throw StateError('Payload boundary sample differs');
            }
            length += bytes.length;
          }
          watch.stop();
          if (length != total) throw StateError('Incomplete benchmark response: $length');
          rows.add({
            'round': round,
            'mode': bridge ? 'owned-bridge' : 'default-http-client',
            'bytes': length,
            'elapsedMs': watch.elapsedMicroseconds / 1000,
            'mebibytesPerSecond': 64 / (watch.elapsedMicroseconds / 1000000),
            'rssBefore': rssBefore,
            'rssAfter': ProcessInfo.currentRss,
          });
        } finally {
          client.close(force: true);
          owner?.cancel();
          await owner?.settled.timeout(const Duration(seconds: 3));
          if (owner != null && owner.activeConnectionCount != 0) throw StateError('Owned connection leaked');
        }
      }
    }
  } finally {
    await server.close(force: true);
    await sub.cancel();
  }
  // ignore: avoid_print
  print(jsonEncode({'bytesPerResponse': total, 'rounds': rows}));
}

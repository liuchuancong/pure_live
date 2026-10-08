import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/stream/playback_manifest_probe.dart';

/// A provider that lists its children however it likes.
final class _ManifestServer {
  _ManifestServer._(this._server, this._body, this._status);

  static Future<_ManifestServer> start({required String body, int status = 200}) async {
    final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    final _ManifestServer result = _ManifestServer._(server, body, status);
    server.listen((HttpRequest request) async {
      request.response.statusCode = result._status;
      if (result._status == 200) request.response.write(result._body);
      await request.response.close();
    });
    return result;
  }

  final HttpServer _server;
  final String _body;
  final int _status;
  int requests = 0;

  Uri get url =>
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: _server.port, path: '/live/media.m3u8');

  Future<void> close() => _server.close(force: true);
}

void main() {
  late Dio dio;

  setUp(() => dio = Dio());
  tearDown(() => dio.close(force: true));

  test('bare child names are reported as needing a rewrite', () async {
    final _ManifestServer server = await _ManifestServer.start(
      body: '#EXTM3U\n#EXTINF:2.0,\nmedia.95.mp4\n#EXTINF:2.0,\nmedia.96.mp4\n#EXT-X-ENDLIST\n',
    );
    addTearDown(server.close);

    final PlaybackManifestProbe? probe = await probePlaybackManifest(server.url.toString(), client: dio);

    expect(probe, isNotNull);
    expect(probe!.kind.requiresRewrite, isTrue);
    expect(probe.kind.relativeChildren, 2);
    // The body is returned so the relay does not read the manifest twice.
    expect(probe.body, startsWith('#EXTM3U'));
  });

  test('absolute children are left to the player', () async {
    final _ManifestServer server = await _ManifestServer.start(
      body: '#EXTM3U\n#EXTINF:2.0,\nhttps://cdn.example.com/seg1.ts\n#EXT-X-ENDLIST\n',
    );
    addTearDown(server.close);

    final PlaybackManifestProbe? probe = await probePlaybackManifest(server.url.toString(), client: dio);

    expect(probe?.kind.requiresRewrite, isFalse);
    expect(probe?.kind.absoluteChildren, 1);
  });

  test('a manifest that cannot be read leaves the decision to the caller', () async {
    final _ManifestServer server = await _ManifestServer.start(body: 'no', status: HttpStatus.forbidden);
    addTearDown(server.close);

    expect(await probePlaybackManifest(server.url.toString(), client: dio), isNull);
  });

  test('a non-manifest body is not classified', () async {
    final _ManifestServer server = await _ManifestServer.start(body: '<html>login required</html>');
    addTearDown(server.close);

    expect(await probePlaybackManifest(server.url.toString(), client: dio), isNull);
  });

  test('an unreachable host returns null instead of throwing', () async {
    expect(
      await probePlaybackManifest(
        'http://127.0.0.1:1/live/media.m3u8',
        client: dio,
        timeout: const Duration(milliseconds: 300),
      ),
      isNull,
    );
  });
}

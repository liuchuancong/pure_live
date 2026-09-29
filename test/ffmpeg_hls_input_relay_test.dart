import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/recorder/services/ffmpeg_hls_input_relay.dart';

void main() {
  test('suffix-less FC2 master and variant playlists are relayed as HLS (2026-09 format)', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      final path = request.uri.path;
      if (path == '/a/stream/1/0/master_playlist') {
        request.response.headers.contentType = ContentType('application', 'x-mpegURL');
        request.response.write('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n/a/stream/1/30/playlist?c=x\n');
      } else if (path == '/a/stream/1/30/playlist') {
        request.response.headers.contentType = ContentType('application', 'x-mpegURL');
        request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:0.5,\n/a/stream/v1/1/30/data/7.ts?hash=y\n');
      } else if (path == '/a/stream/v1/1/30/data/7.ts') {
        request.response.add(List<int>.filled(188, 0x47));
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final relay = await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/a/stream/1/0/master_playlist?targets=30',
    ], force: true);
    expect(relay, isNotNull, reason: 'the FC2 master URL has no .m3u8 suffix');
    final client = HttpClient();
    try {
      final master = await _readText(client, relay!.inputUri);
      final variant = master.split('\n').firstWhere((line) => line.isNotEmpty && !line.startsWith('#'));
      expect(variant, endsWith('.m3u8'), reason: 'FFmpeg must open the child as a playlist');
      final playlist = await _readText(client, relay.inputUri.resolve(variant));
      final segment = playlist.split('\n').firstWhere((line) => line.isNotEmpty && !line.startsWith('#'));
      expect(segment, endsWith('.ts'));
      final bytes = await _readBytes(client, relay.inputUri.resolve(segment));
      expect(bytes, hasLength(188));
    } finally {
      client.close(force: true);
      await relay?.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  test('stop replaces a stalled refresh body with the last complete playlist', () async {
    var requests = 0;
    final partial = Completer<void>();
    final release = Completer<void>();
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      try {
        if (++requests == 1) {
          request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nmedia.m4s\n');
        } else {
          request.response.bufferOutput = false;
          request.response.write('#EXTM3U\n');
          await request.response.flush();
          partial.complete();
          await release.future;
        }
        await request.response.close();
      } on Object {
        /* Intentionally interrupted response. */
      }
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], drainOnStop: true))!;
    final client = HttpClient();
    try {
      final first = await _readText(client, relay.inputUri);
      final refresh = _readText(client, relay.inputUri);
      await partial.future.timeout(const Duration(seconds: 2));
      await relay.finish();
      expect(await refresh.timeout(const Duration(seconds: 3)), '$first#EXT-X-ENDLIST\n');
      expect(relay.inputTailDiscarded, false, reason: 'a manifest refresh is not a retired media input');
    } finally {
      release.complete();
      client.close(force: true);
      await relay.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  for (final phase in ['headers', 'body']) {
    test('stop retires an unpublished $phase response without exposing a partial fragment', () async {
      final accepted = Completer<void>();
      final release = Completer<void>();
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = origin.listen((request) async {
        try {
          if (request.uri.path == '/live.m3u8') {
            request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nmedia.m4s\n');
          } else {
            request.response.contentLength = 8;
            if (phase == 'body') {
              request.response.bufferOutput = false;
              request.response.add([1, 2, 3, 4]);
              await request.response.flush();
            }
            if (!accepted.isCompleted) accepted.complete();
            await release.future;
          }
          await request.response.close();
        } on Object {
          /* The intentionally incomplete fixture is closed by stop. */
        }
      });
      final relay = (await FFmpegHlsInputRelay.startForArguments([
        '-i',
        'http://127.0.0.1:${origin.port}/live.m3u8',
      ], drainOnStop: true))!;
      final client = HttpClient();
      try {
        final media = Uri.parse(_mediaLines(await _readText(client, relay.inputUri)).single);
        var published = false;
        final responseFuture = (await client.getUrl(media)).close().then((response) {
          published = true;
          return response;
        });
        await accepted.future.timeout(const Duration(seconds: 2));
        expect(published, false);
        expect(relay.inputTailDiscarded, false);
        await relay.finish();
        final response = await responseFuture.timeout(const Duration(seconds: 3));
        expect(response.statusCode, HttpStatus.gone);
        expect(await response.fold<int>(0, (count, bytes) => count + bytes.length), 0);
        expect(await _readText(client, relay.inputUri), contains('#EXT-X-ENDLIST'));
        expect(relay.inputTailDiscarded, true);
        await relay.close();
        expect(relay.inputTailDiscarded, true, reason: 'cleanup must retain the terminal verdict');
      } finally {
        if (!release.isCompleted) release.complete();
        client.close(force: true);
        await relay.close();
        await origin.close(force: true);
        await subscription.cancel();
      }
    });
  }

  test('truncated upstream body fails before any successful response bytes reach the reader', () async {
    Get.put<LogController>(_QuietLogController());
    addTearDown(() => Get.delete<LogController>(force: true));
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      if (request.uri.path == '/live.m3u8') {
        request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nmedia.m4s\n');
        await request.response.close();
      } else {
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.add(utf8.encode('HTTP/1.1 200 OK\r\nContent-Length: 8\r\nConnection: close\r\n\r\n1234'));
        await socket.close();
      }
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], drainOnStop: true))!;
    final client = HttpClient();
    try {
      final media = Uri.parse(_mediaLines(await _readText(client, relay.inputUri)).single);
      final response = await (await client.getUrl(media)).close();
      expect(response.statusCode, HttpStatus.badGateway);
      expect(await response.fold<int>(0, (count, bytes) => count + bytes.length), 0);
      expect(relay.inputTailDiscarded, false, reason: 'upstream failure is not a stop-time retirement');
    } finally {
      client.close(force: true);
      await relay.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  test('staging validates decompressed media using its actual byte length', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      if (request.uri.path == '/live.m3u8') {
        request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nmedia.ts\n');
      } else {
        final body = gzip.encode([1, 2, 3, 4]);
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        request.response.contentLength = body.length;
        request.response.add(body);
      }
      await request.response.close();
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], drainOnStop: true))!;
    final client = HttpClient();
    try {
      final media = Uri.parse(_mediaLines(await _readText(client, relay.inputUri)).single);
      expect(await _readBytes(client, media), [1, 2, 3, 4]);
    } finally {
      client.close(force: true);
      await relay.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  test('playlist session cookies reach init and media without reaching the local reader', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    origin.listen((request) async {
      if (request.uri.path == '/live/root.m3u8') {
        request.response.headers.add(HttpHeaders.setCookieHeader, 'session=fixture; Path=/live/; HttpOnly');
        request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:2,\nmedia.m4s\n');
      } else if (request.headers.value(HttpHeaders.cookieHeader) == 'session=fixture') {
        request.response.write('media');
      } else {
        request.response.statusCode = HttpStatus.unauthorized;
      }
      await request.response.close();
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live/root.m3u8',
    ], force: true))!;
    addTearDown(relay.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final response = await (await client.getUrl(relay.inputUri)).close();
    expect(response.headers[HttpHeaders.setCookieHeader], isNull);
    final manifest = await utf8.decoder.bind(response).join();
    final init = Uri.parse(RegExp(r'URI="([^"]+)"').firstMatch(manifest)!.group(1)!);
    expect(await _readText(client, init), 'media');
    expect(await _readText(client, Uri.parse(_mediaLines(manifest).single)), 'media');
  });

  test('redirect cookies rotate and caller credentials stay on their original origin', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    addTearDown(() => other.close(force: true));
    other.listen((request) async {
      expect(request.headers.value(HttpHeaders.cookieHeader), isNull);
      expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
      expect(request.headers.value(HttpHeaders.userAgentHeader), 'RelayFixture');
      request.response.write('other media');
      await request.response.close();
    });
    origin.listen((request) async {
      expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer fixture');
      if (request.uri.path == '/root.m3u8') {
        expect(request.headers.value(HttpHeaders.cookieHeader), 'session=stale; caller=keep');
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '/nested/live.m3u8');
        request.response.headers.add(HttpHeaders.setCookieHeader, 'session=first; Path=/');
      } else if (request.uri.path == '/nested/live.m3u8') {
        expect(request.headers.value(HttpHeaders.cookieHeader), 'session=first; caller=keep');
        request.response.headers.add(HttpHeaders.setCookieHeader, 'session=second; Path=/');
        request.response.write(
          '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2,\nseg.ts\n'
          '#EXTINF:2,\nhttp://127.0.0.1:${other.port}/other.ts\n',
        );
      } else {
        expect(request.uri.path, '/nested/seg.ts');
        expect(request.headers.value(HttpHeaders.cookieHeader), 'session=second; caller=keep');
        request.response.statusCode = HttpStatus.temporaryRedirect;
        request.response.headers.set(HttpHeaders.locationHeader, 'http://127.0.0.1:${other.port}/redirect.ts');
      }
      await request.response.close();
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments([
      '-headers',
      'Cookie: session=stale; caller=keep\r\nAuthorization: Bearer fixture\r\n',
      '-user_agent',
      'RelayFixture',
      '-i',
      'http://127.0.0.1:${origin.port}/root.m3u8',
    ], force: true))!;
    addTearDown(relay.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final manifest = await _readText(client, relay.inputUri);
    for (final resource in _mediaLines(manifest)) {
      expect(await _readText(client, Uri.parse(resource)), 'other media');
    }
  });

  test('relay sessions remain independent and close drops cookies with resources', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    var sessions = 0;
    origin.listen((request) async {
      if (request.uri.path == '/root.m3u8') {
        expect(request.headers.value(HttpHeaders.cookieHeader), isNull);
        final id = ++sessions;
        request.response.headers.add(HttpHeaders.setCookieHeader, 'session=$id; Path=/');
        request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2,\n$id.ts\n');
      } else {
        expect(
          request.headers.value(HttpHeaders.cookieHeader),
          'session=${request.uri.path.substring(1).split('.').first}',
        );
        request.response.write('media');
      }
      await request.response.close();
    });
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final relays = <FFmpegHlsInputRelay>[];
    addTearDown(() async {
      for (final relay in relays) {
        await relay.close();
      }
    });
    for (var i = 0; i < 2; i++) {
      relays.add(
        (await FFmpegHlsInputRelay.startForArguments([
          '-i',
          'http://127.0.0.1:${origin.port}/root.m3u8',
        ], force: true))!,
      );
    }
    final manifests = await Future.wait(relays.map((relay) => _readText(client, relay.inputUri)));
    for (var i = 0; i < 2; i++) {
      expect(await _readText(client, Uri.parse(_mediaLines(manifests[i]).single)), 'media');
      expect(relays[i].sessionCookieCount, 1);
      await relays[i].close();
      expect(relays[i].sessionCookieCount, 0);
      expect(relays[i].resourceCount, 0);
    }
  });

  test('redirect loops stop after five hops', () async {
    Get.put<LogController>(_QuietLogController());
    addTearDown(() => Get.delete<LogController>(force: true));
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    var requests = 0;
    origin.listen((request) async {
      requests++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, '/root.m3u8');
      await request.response.close();
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/root.m3u8',
    ], force: true))!;
    addTearDown(relay.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final response = await (await client.getUrl(relay.inputUri)).close();
    expect(response.statusCode, HttpStatus.badGateway);
    await response.drain<void>();
    expect(requests, 6);
  });

  test('manifest range requests still rewrite child URLs before serving FFmpeg', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    origin.listen((request) async {
      if (request.uri.path == '/live.m3u8') {
        const manifest = '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nsegment.ts\n#EXT-X-ENDLIST\n';
        if (request.headers.value(HttpHeaders.rangeHeader) != null) {
          request.response.statusCode = HttpStatus.partialContent;
          final length = utf8.encode(manifest).length;
          request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-${length - 1}/$length');
        }
        request.response.write(manifest);
      } else if (request.uri.path == '/segment.ts') {
        request.response.write('media');
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], force: true))!;
    addTearDown(relay.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.getUrl(relay.inputUri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
    final response = await request.close();
    final manifest = await utf8.decoder.bind(response).join();
    final segment = manifest.split('\n').firstWhere((line) => line.isNotEmpty && !line.startsWith('#'));
    final media = await (await client.getUrl(relay.inputUri.resolve(segment))).close();
    expect(media.statusCode, HttpStatus.ok);
    expect(await utf8.decoder.bind(media).join(), 'media');
  });

  test('relay rewrites nested HLS resources and preserves input headers', () async {
    final seenUserAgents = <String?>[];
    final seenReferers = <String?>[];
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final originSubscription = origin.listen((request) async {
      seenUserAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
      seenReferers.add(request.headers.value('referer'));
      switch (request.uri.path) {
        case '/master.m3u8':
          request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
          request.response.write('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nvariant/live.m3u8\n');
        case '/variant/live.m3u8':
          request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
          request.response.write(
            '#EXTM3U\n'
            '#EXT-X-KEY:METHOD=AES-128,URI="../key.bin"\n'
            '#EXTINF:2.0,\n'
            'seg.ts?token=one\n',
          );
        case '/key.bin':
          request.response.add(List<int>.generate(16, (index) => index));
        case '/variant/seg.ts':
          expect(request.uri.queryParameters['token'], 'one');
          request.response.add(const <int>[1, 2, 3, 4]);
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final upstream = Uri.parse('http://${origin.address.address}:${origin.port}/master.m3u8');
    final relay = await FFmpegHlsInputRelay.startForArguments(<String>[
      '-user_agent',
      'PureLiveRelayTest/1.0',
      '-headers',
      'Referer: https://platform.example/live\r\nHost: ignored.example\r\n',
      '-i',
      upstream.toString(),
      '-c',
      'copy',
    ], force: true);
    expect(relay, isNotNull);

    final client = HttpClient();
    try {
      final rootManifest = await _readText(client, relay!.inputUri);
      expect(rootManifest, startsWith('#EXTM3U'));
      expect(rootManifest, isNot(contains('variant/live.m3u8')));
      final variantUri = Uri.parse(_mediaLines(rootManifest).single);
      expect(variantUri.host, InternetAddress.loopbackIPv4.address);
      expect(variantUri.port, relay.inputUri.port);

      final variantManifest = await _readText(client, variantUri);
      final keyUri = Uri.parse(RegExp(r'URI="([^"]+)"').firstMatch(variantManifest)!.group(1)!);
      final segmentUri = Uri.parse(_mediaLines(variantManifest).single);
      expect(keyUri.host, InternetAddress.loopbackIPv4.address);
      expect(segmentUri.host, InternetAddress.loopbackIPv4.address);
      expect(keyUri.path, endsWith('.ts'));
      expect(segmentUri.path, endsWith('.ts'));
      expect(await _readBytes(client, keyUri), List<int>.generate(16, (index) => index));
      expect(await _readBytes(client, segmentUri), const <int>[1, 2, 3, 4]);

      expect(seenUserAgents, everyElement('PureLiveRelayTest/1.0'));
      expect(seenReferers, everyElement('https://platform.example/live'));
    } finally {
      client.close(force: true);
      await relay?.close();
      await originSubscription.cancel();
      await origin.close(force: true);
    }
  });

  test('relay leaves missing and non-HLS inputs untouched', () async {
    expect(await FFmpegHlsInputRelay.startForArguments(const <String>['-c', 'copy'], force: true), isNull);
    expect(
      await FFmpegHlsInputRelay.startForArguments(const <String>[
        '-i',
        'https://example.invalid/live.flv',
      ], force: true),
      isNull,
    );
  });

  test('live recording opts into HLS drain on desktop without changing other HTTP inputs', () async {
    final arguments = ['-i', 'http://127.0.0.1:1/live.m3u8'];
    final relay = await FFmpegHlsInputRelay.startForArguments(arguments, drainOnStop: true);
    try {
      expect(relay, isNotNull);
      expect(relay!.drainOnStop, true);
      expect(relay.drainTimeout, const Duration(seconds: 4));
    } finally {
      await relay?.close();
    }
    expect(await FFmpegHlsInputRelay.startForArguments(arguments), isNull);
  });

  test('stop freezes nested playlists without ending master or breaking segment ranges', () async {
    var variantRequests = 0;
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      switch (request.uri.path) {
        case '/master.m3u8':
          request.response.write('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nvariant.m3u8\n');
        case '/variant.m3u8':
          variantRequests++;
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXT-X-MEDIA-SEQUENCE:3\n'
            '#EXT-X-MAP:URI="init.mp4"\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
            '#EXTINF:6,\n#EXT-X-BYTERANGE:2@1\nmedia.m4s\n',
          );
        case '/media.m4s':
          expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=1-2');
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 1-2/4');
          request.response.add([2, 3]);
        default:
          request.response.add([0, 1, 2, 3]);
      }
      await request.response.close();
    });
    final relay = await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/master.m3u8',
    ], drainOnStop: true);
    final client = HttpClient();
    try {
      final master = await _readText(client, relay!.inputUri);
      final variant = Uri.parse(_mediaLines(master).single);
      final live = await _readText(client, variant);
      expect(live, isNot(contains('#EXT-X-ENDLIST')));
      expect(relay.drainTimeout, const Duration(seconds: 14));
      await Future.wait([relay.finish(), relay.finish()]);
      expect(await _readText(client, relay.inputUri), master);
      final ended = await _readText(client, variant);
      expect(ended, '$live#EXT-X-ENDLIST\n');
      expect(await _readText(client, variant), ended);
      expect(variantRequests, 1);
      final request = await client.getUrl(Uri.parse(_mediaLines(ended).single));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=1-2');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.headers.value(HttpHeaders.contentRangeHeader), 'bytes 1-2/4');
      expect(await response.fold<List<int>>([], (all, bytes) => all..addAll(bytes)), [2, 3]);
      final resources = RegExp(r'URI="([^"]+)"').allMatches(ended);
      for (final resource in resources) {
        expect(await _readBytes(client, Uri.parse(resource.group(1)!)), [0, 1, 2, 3]);
      }
    } finally {
      client.close(force: true);
      await relay?.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  test('an in-flight refresh cannot publish new segments after stop', () async {
    final pending = Completer<void>();
    final release = Completer<void>();
    var requests = 0;
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      final number = ++requests;
      if (number == 2) {
        pending.complete();
        await release.future;
      }
      request.response.write(
        '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:$number\n'
        '#EXTINF:2,\nsegment$number.ts\n',
      );
      await request.response.close();
    });
    final relay = await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], drainOnStop: true);
    final client = HttpClient();
    try {
      final first = await _readText(client, relay!.inputUri);
      final refreshing = _readText(client, relay.inputUri);
      await pending.future;
      await relay.finish();
      release.complete();
      expect(await refreshing, '$first#EXT-X-ENDLIST\n');
      expect(await _readText(client, relay.inputUri), '$first#EXT-X-ENDLIST\n');
      expect(requests, 2);
    } finally {
      if (!release.isCompleted) release.complete();
      client.close(force: true);
      await relay?.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  test('rolling playlists retain two generations instead of lifetime segment addresses', () async {
    var sequence = 0;
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      if (request.uri.path == '/live.m3u8') {
        request.response.write(
          '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:$sequence\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="key$sequence.bin"\n'
          '#EXTINF:2,\nsegment$sequence.ts\n',
        );
        sequence++;
      } else {
        request.response.add([1, 2, 3]);
      }
      await request.response.close();
    });
    final relay = await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], force: true);
    final client = HttpClient();
    try {
      Uri? first;
      Uri? previous;
      Uri? latest;
      for (var i = 0; i < 200; i++) {
        previous = latest;
        final text = await _readText(client, relay!.inputUri);
        latest = Uri.parse(_mediaLines(text).single);
        first ??= latest;
        expect(relay.resourceCount, lessThanOrEqualTo(5));
      }
      expect(await _readBytes(client, previous!), [1, 2, 3]);
      expect(await _readBytes(client, latest!), [1, 2, 3]);
      final old = await (await client.getUrl(first!)).close();
      expect(old.statusCode, HttpStatus.notFound);
      await old.drain<void>();
      await Future.wait([relay!.close(), relay.close()]);
      expect(relay.resourceCount, 0);
    } finally {
      client.close(force: true);
      await relay?.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  test('stop before the first playlist avoids opening upstream', () async {
    final relay = await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:1/live.m3u8',
    ], drainOnStop: true);
    final client = HttpClient();
    try {
      await relay!.finish();
      expect(await _readText(client, relay.inputUri), contains('#EXT-X-ENDLIST'));
    } finally {
      client.close(force: true);
      await relay?.close();
    }
  });

  test('an active old segment survives playlist pruning and then releases its address', () async {
    var sequence = 0;
    final release = Completer<void>();
    final partial = Completer<void>();
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) async {
      if (request.uri.path == '/live.m3u8') {
        request.response.write(
          '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:$sequence\n'
          '#EXTINF:2,\nsegment${sequence++}.ts\n',
        );
        await request.response.close();
      } else {
        request.response.bufferOutput = false;
        request.response.add([1, 2]);
        await request.response.flush();
        if (!partial.isCompleted) partial.complete();
        await release.future;
        request.response.add([3, 4]);
        await request.response.close();
      }
    });
    final relay = await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], drainOnStop: true);
    final client = HttpClient();
    try {
      final first = Uri.parse(_mediaLines(await _readText(client, relay!.inputUri)).single);
      var published = false;
      final received = (await client.getUrl(first)).close().then((response) {
        published = true;
        return response.fold<List<int>>([], (all, bytes) => all..addAll(bytes));
      });
      await partial.future.timeout(const Duration(seconds: 2));
      expect(published, false); // No partial body has crossed the native boundary.
      for (var i = 0; i < 5; i++) {
        await _readText(client, relay.inputUri);
      }
      expect(relay.resourceCount, 4); // root + two generations + active old segment
      await relay.finish();
      release.complete();
      expect(await received, [1, 2, 3, 4]);
      expect(relay.inputTailDiscarded, false, reason: 'a body completed inside the stop window is preserved');
      // A further request runs only after the old response has finished.
      await _readText(client, relay.inputUri);
      expect(relay.resourceCount, 3);
    } finally {
      if (!release.isCompleted) release.complete();
      client.close(force: true);
      await relay?.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });

  test('close while waiting for headers settles and does not resurrect resources', () async {
    final accepted = Completer<void>();
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = origin.listen((request) => accepted.complete());
    final relay = await FFmpegHlsInputRelay.startForArguments([
      '-i',
      'http://127.0.0.1:${origin.port}/live.m3u8',
    ], drainOnStop: true);
    final client = HttpClient();
    try {
      final request = await client.getUrl(relay!.inputUri);
      final response = request.close().then<void>((response) => response.drain<void>(), onError: (Object _) {});
      await accepted.future.timeout(const Duration(seconds: 2));
      await Future.wait([relay.close(), relay.close()]).timeout(const Duration(seconds: 2));
      await response.timeout(const Duration(seconds: 2));
      expect(relay.resourceCount, 0);
      expect(relay.inputTailDiscarded, false, reason: 'cleanup alone is not a user input stop');
    } finally {
      client.close(force: true);
      await relay?.close();
      await origin.close(force: true);
      await subscription.cancel();
    }
  });
}

Iterable<String> _mediaLines(String manifest) => const LineSplitter()
    .convert(manifest)
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty && !line.startsWith('#'));

Future<String> _readText(HttpClient client, Uri uri) async => utf8.decode(await _readBytes(client, uri));

Future<List<int>> _readBytes(HttpClient client, Uri uri) async {
  final response = await (await client.getUrl(uri)).close();
  expect(response.statusCode, HttpStatus.ok);
  return response.fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
}

class _QuietLogController extends GetxController implements LogController {
  // HTTP-only fixture: no frame scheduling or Hive-backed log controller.
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}

  @override
  bool get enableLog => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

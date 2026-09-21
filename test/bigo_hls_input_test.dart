import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/bigo/bigo_hls_protection.dart';
import 'package:pure_live/recorder/services/ffmpeg_hls_input_relay.dart';

void main() {
  for (final staged in [false, true]) {
    test('Bigo manifest transform restores split TS prefix${staged ? ' through recording staging' : ''}', () async {
      const seed = 1234567890;
      final plain = Uint8List.fromList(List<int>.generate(752, (index) => index & 0xff))
        ..[0] = 0x47
        ..[188] = 0x47;
      final protected = BigoHlsProtection.transformSegment(plain, seed);
      final key = Uint8List.fromList(List<int>.generate(16, (index) => index));
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => origin.close(force: true));
      origin.listen((request) async {
        if (request.uri.path == '/live.m3u8') {
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:2\n'
            '#EXT-X-BIGO-WEB-PROTECTION:SEED=$seed\n'
            '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
            '#EXTINF:2,\nsegment.ts\n',
          );
        } else if (request.uri.path == '/key.bin') {
          request.response.add(key);
        } else if (request.uri.path == '/segment.ts') {
          request.response.bufferOutput = false;
          request.response.add(protected.sublist(0, 100));
          await request.response.flush();
          request.response.add(protected.sublist(100, 300));
          await request.response.flush();
          request.response.add(protected.sublist(300));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
      final relay = (await FFmpegHlsInputRelay.startForArguments(
        ['-i', 'http://127.0.0.1:${origin.port}/live.m3u8'],
        force: true,
        drainOnStop: staged,
        manifestMediaTransform: _bigoTransform,
      ))!;
      addTearDown(relay.close);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final manifest = await _readText(client, relay.inputUri);
      final keyUri = Uri.parse(RegExp(r'URI="([^"]+)"').firstMatch(manifest)!.group(1)!);
      final mediaUri = Uri.parse(_mediaLines(manifest).single);
      expect(await _readBytes(client, keyUri), key);
      expect(await _readBytes(client, mediaUri), plain);
      final ranged = await client.getUrl(mediaUri);
      ranged.headers.set(HttpHeaders.rangeHeader, 'bytes=188-');
      final rangedResponse = await ranged.close();
      expect(rangedResponse.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      await rangedResponse.drain<void>();
    });
  }

  test('prefix transform rejects a truncated body before staging publishes it', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    origin.listen((request) async {
      if (request.uri.path.endsWith('.m3u8')) {
        request.response.write('#EXTM3U\n#EXT-X-BIGO-WEB-PROTECTION:SEED=1\n#EXTINF:2,\nsegment.ts\n');
      } else {
        request.response.add(List<int>.filled(375, 1));
      }
      await request.response.close();
    });
    final relay = (await FFmpegHlsInputRelay.startForArguments(
      ['-i', 'http://127.0.0.1:${origin.port}/live.m3u8'],
      force: true,
      drainOnStop: true,
      manifestMediaTransform: _bigoTransform,
    ))!;
    addTearDown(relay.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final media = Uri.parse(_mediaLines(await _readText(client, relay.inputUri)).single);
    final response = await (await client.getUrl(media)).close();
    expect(response.statusCode, HttpStatus.badGateway);
    expect(await response.fold<int>(0, (total, chunk) => total + chunk.length), 0);
  });

  test('manifest-scoped media transforms reject prefetch ownership ambiguity', () async {
    await expectLater(
      FFmpegHlsInputRelay.startForArguments(
        const ['-i', 'http://127.0.0.1:1/live.m3u8'],
        force: true,
        drainOnStop: true,
        enablePrefetch: true,
        manifestMediaTransform: _bigoTransform,
      ),
      throwsArgumentError,
    );
  });
}

HlsMediaPrefixTransform? _bigoTransform(Uri _, String manifest) {
  final seed = BigoHlsProtection.seedFromManifest(manifest);
  return seed == null
      ? null
      : HlsMediaPrefixTransform(
          prefixBytes: 376,
          transform: (prefix) => BigoHlsProtection.transformSegment(prefix, seed),
        );
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

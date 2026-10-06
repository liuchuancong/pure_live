import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_api.dart';

void main() {
  test('bigo studio room wire answer', () async {
    final route = io.Platform.environment['PURELIVE_BIGO_ROUTE'] ?? 'DIRECT';
    final dio =
        Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () {
              final client = io.HttpClient();
              client.findProxy = (_) => route;
              client.badCertificateCallback = ((cert, host, port) => route != 'DIRECT');
              return client;
            },
          );
    Future<({int status, String body})> req(String m, Uri u, Map<String, String>? f, CancelToken c) async {
      final r = await dio.request<ResponseBody>(
        u.toString(),
        data: f,
        cancelToken: c,
        options: Options(
          method: m,
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: BigoApi.headers,
          contentType: f == null ? null : Headers.formUrlEncodedContentType,
          validateStatus: (_) => true,
        ),
      );
      final s = r.data!;
      final b = await utf8.decodeStream(s.stream);
      return (status: r.statusCode ?? 0, body: b);
    }

    final api = BigoApi(request: req);
    final cards = await api.directory();
    var failures = 0;
    for (final card in cards.take(6)) {
      try {
        final room = await api.studioRoom(siteId: card.siteId);
        io.stdout.writeln('OK ${card.siteId} hls=${room.hls?.host} roomId=${room.roomId}');
      } catch (e) {
        failures++;
        io.stdout.writeln('FAIL ${card.siteId} $e');
        final raw = await req(
          'POST',
          Uri.parse('https://ta.bigo.tv/official_website/studio/getInternalStudioInfo')
              .replace(queryParameters: {'siteId': card.siteId, 'verify': '', 'token': 'x'}),
          null,
          CancelToken(),
        );
        io.stdout.writeln(raw.body.substring(0, raw.body.length.clamp(0, 1000)));
      }
    }
    expect(failures, 0, reason: 'studio room parse failures');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

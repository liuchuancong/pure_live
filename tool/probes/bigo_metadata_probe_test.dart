import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_api.dart';

// Opt-in metadata contract only. No registration, credentials or media read.
//
// It walks the same three calls the room page walks — directory, the public web
// token, studio info — and records every wire answer, because "bigo 无法获取信息"
// has at least three distinct causes that look identical from the toast: a
// blocked leg (network), a body that is not JSON/JSONP (the token endpoints), and
// a JSON answer whose room fields are empty (`needLogin`, offline, or an id the
// endpoint does not accept). The report says which one it was.

/// The route site traffic really takes: the app-level proxy, which is off by
/// default and therefore direct. Override with PURELIVE_BIGO_ROUTE=PROXY host:port.
String _route() => io.Platform.environment['PURELIVE_BIGO_ROUTE'] ?? 'DIRECT';

void main() {
  test(
    'Bigo directory, web token and studio info answer the current web contract',
    () async {
      final output = io.Platform.environment['PURELIVE_BIGO_OUTPUT'];
      final wire = <Map<String, Object?>>[];
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'route': _route(),
        'contract': 'failed',
        'stage': 'directory',
        'wire': wire,
      };

      final dio =
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)))
            ..httpClientAdapter = IOHttpClientAdapter(
              createHttpClient: () {
                final client = io.HttpClient();
                client.findProxy = (_) => _route();
                // 本地代理（Clash 等）MITM 时证书链不是公根，opt-in 探针信任之。
                client.badCertificateCallback = ((cert, host, port) => _route() != 'DIRECT');
                return client;
              },
            );

      Future<({int status, String body})> record(
        String method,
        Uri uri,
        Map<String, String>? form,
        CancelToken cancel,
      ) async {
        final response = await dio.request<ResponseBody>(
          uri.toString(),
          data: form,
          cancelToken: cancel,
          options: Options(
            method: method,
            responseType: ResponseType.stream,
            followRedirects: false,
            headers: BigoApi.headers,
            contentType: form == null ? null : Headers.formUrlEncodedContentType,
            validateStatus: (_) => true,
          ),
        );
        final stream = response.data;
        if (stream == null) {
          wire.add({'url': uri.toString(), 'status': response.statusCode, 'body': '<no body>'});
          return (status: response.statusCode ?? 0, body: '');
        }
        final body = await BigoApi.readBody(stream.stream);
        // A token endpoint answers as JSONP; a WAF or a redirect page answers as
        // HTML. Both read as "not JSON" from here, so keep enough of it to tell
        // them apart without logging a whole room list.
        wire.add({
          'url': '${uri.host}${uri.path}',
          'query': uri.queryParameters.keys.toList(),
          'status': response.statusCode,
          'type': response.headers['content-type']?.first,
          'bytes': body.length,
          'head': body.length <= 240 ? body : body.substring(0, 240),
        });
        return (status: response.statusCode ?? 0, body: body);
      }

      await io.HttpOverrides.runWithHttpOverrides(() async {
        try {
          final api = BigoApi(request: record);
          final cards = await api.directory();
          report['directoryCards'] = cards.length;
          expect(cards, isNotEmpty);
          // One room cannot tell "the anonymous contract changed" from "this
          // room is gated", so read several and report the split. The first
          // playable one is also the one the media fields are checked on.
          report['stage'] = 'studio';
          final readable = <Map<String, Object?>>[];
          BigoStudioRoom? playable;
          for (final card in cards.where((card) => !card.locked).take(6)) {
            final room = await api.studioRoom(siteId: card.siteId, expectedOwnerId: card.ownerId);
            readable.add(<String, Object?>{
              'siteId': card.siteId,
              'canonical': room.status.canonicalSiteId,
              'access': room.status.access.name,
              'alive': room.status.reportedAlive,
              'roomStatus': room.status.roomStatus,
              'hasHls': room.hls != null,
              'titleChars': room.title.length,
            });
            playable ??= room.hls == null ? null : room;
          }
          report['rooms'] = readable;
          report['playableRooms'] = playable == null ? 0 : 1;
          if (playable != null) {
            report.addAll(<String, Object?>{
              'contract': 'passed',
              'stage': 'complete',
              'access': playable.status.access.name,
              'reportedAlive': playable.status.reportedAlive,
              'hlsHead': playable.hls.toString().substring(0, 90),
              'password': playable.status.password,
              'paid': playable.status.paid,
            });
          }
        } on BigoException catch (error) {
          report['failure'] = error.kind.name;
          // Keep the failing stage's answer in front of the reader; this is the
          // line that distinguishes a blocked route from a changed envelope.
          // ignore: avoid_print
          print(
            'Bigo ${error.kind.name} at stage=${report['stage']}: '
            '${jsonEncode(wire.isEmpty ? <Map<String, Object?>>[] : wire.last)}',
          );
          rethrow;
        } finally {
          dio.close(force: true);
          if (output != null) {
            await io.File(output).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(report));
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_BIGO_METADATA_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}

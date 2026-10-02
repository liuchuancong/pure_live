// Opt-in production adapter/network check, not part of offline CI.
// No visitor credentials, signed URLs, public user profiles or media are saved.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/platforms/acfun/acfun_api.dart';
import 'package:pure_live/domains/live/data/platforms/acfun/acfun_site.dart';

void main() {
  test(
    'production AcFun metadata, qualities, fresh credentials and FLV input',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final proxy = Platform.environment['PURELIVE_PROBE_PROXY'];
        if (proxy != null && proxy.isNotEmpty) {
          final address = Uri.parse(proxy);
          client.findProxy = (_) => 'PROXY ${address.host}:${address.port}';
        }
        try {
          final api = AcfunApi(
            request: (method, url, {query, body, headers}) async {
              final uri = Uri.parse(url).replace(queryParameters: query?.map((key, value) => MapEntry(key, '$value')));
              final request = await client.openUrl(method, uri);
              headers?.forEach((name, value) {
                if (value != null) request.headers.set(name, value);
              });
              if (body != null) {
                request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
                request.write(Uri(queryParameters: body.map((key, value) => MapEntry(key, '$value'))).query);
              }
              final response = await request.close().timeout(const Duration(seconds: 20));
              if (response.statusCode != 200) throw const FormatException('non-success HTTP status');
              final buffer = BytesBuilder(copy: false);
              await for (final chunk in response.timeout(const Duration(seconds: 20))) {
                buffer.add(chunk);
                if (buffer.length > 1024 * 1024) throw const FormatException('oversized JSON');
              }
              return jsonDecode(utf8.decode(buffer.takeBytes()));
            },
          );
          final directory = await api.directory(count: 2);
          expect(directory.rooms, isNotEmpty);
          final roomId = AcfunApi.text(directory.rooms.first['authorId']);
          final site = AcfunSite(api: api);
          final room = await site.getRoomDetailForRecording(roomId: roomId, platform: 'acfun');
          final qualities = await site.getPlayQualites(detail: room);
          expect(qualities, isNotEmpty);
          final selected = qualities.length == 1 ? [qualities.first] : [qualities.first, qualities.last];
          final samples = <Map<String, Object?>>[];
          for (final quality in selected) {
            final urls = await site.getPlayUrls(detail: room, quality: quality);
            expect(urls, isNotEmpty);
            final request = await client.getUrl(Uri.parse(urls.first));
            AcfunApi.playHeaders.forEach(request.headers.set);
            final response = await request.close().timeout(const Duration(seconds: 20));
            expect(response.statusCode, 200);
            final clock = Stopwatch()..start();
            final prefix = <int>[];
            var bytes = 0;
            var reachedLimit = false;
            await for (final chunk in response.timeout(const Duration(seconds: 15))) {
              if (prefix.length < 3) prefix.addAll(chunk.take(3 - prefix.length));
              bytes += chunk.length;
              if (clock.elapsed >= const Duration(seconds: 8)) {
                reachedLimit = true;
                break;
              }
            }
            expect(prefix, [70, 76, 86]);
            expect(bytes, greaterThan(1024));
            expect(reachedLimit, isTrue);
            samples.add({
              'qualityId': quality.selectionId.toString(),
              'label': quality.quality,
              'lines': urls.length,
              'bytes': bytes,
              'durationMs': clock.elapsedMilliseconds,
              'flv': true,
            });
          }
          final fresh = await site.resolvePlayUrlsForRecoveryRaw(detail: room, quality: qualities.first);
          expect(fresh.urls, isNotEmpty);
          expect(fresh.appliedQualityData, qualities.first.selectionId);
          // ignore: avoid_print
          print(
            jsonEncode({
              'probe': 'production-acfun-contract',
              'directoryCount': directory.rooms.length,
              'qualityCount': qualities.length,
              'samples': samples,
              'recoveryResolved': true,
              'proxyConfigured': proxy?.isNotEmpty == true,
              'secretsPersisted': false,
              'evidenceLayer': 'adapter-and-transport-not-render-or-recording',
            }),
          );
        } catch (error) {
          fail('AcFun public contract probe failed (${error.runtimeType})');
        } finally {
          client.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_ACFUN_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends HttpOverrides {}

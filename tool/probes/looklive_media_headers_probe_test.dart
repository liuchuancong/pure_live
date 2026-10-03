// Opt-in production probe: does LOOK's media CDN need the headers the site
// declares? Reports status codes and byte counts only — no URLs, headers or
// media are persisted.
//
//   PURELIVE_LOOK_HEADERS_PROBE=1 flutter test tool/probes/looklive_media_headers_probe_test.dart
//   PURELIVE_LOOK_PROBE_ROOMS=4            how many live rooms to sample
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/data/playback_header_resolver.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory temp;

  setUpAll(() async {
    temp = await io.Directory.systemTemp.createTemp('look-headers-probe-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.testMode = true;
    Get.put(SettingsService(), permanent: true);
  });

  tearDownAll(() async {
    await Hive.close();
    Get.reset();
    await temp.delete(recursive: true);
  });

  test(
    'LOOK media lines answer with the declared headers',
    () async {
      // flutter_test answers every HttpClient request with 400 unless the test
      // installs its own overrides; this probe needs the real network.
      await io.HttpOverrides.runWithHttpOverrides(() async {
      // The production dio resolves its proxy through SettingsService, which
      // needs controllers a probe does not own; the matrix probe swaps the
      // client instead, and that also makes the route an explicit choice.
      final route = io.Platform.environment['PURELIVE_LOOK_PROBE_ROUTE']?.trim() ?? 'DIRECT';
      final previousDio = HttpClient.instance.dio;
      final dio = Dio(
        BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
      )..httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () => io.HttpClient()
            ..connectionTimeout = const Duration(seconds: 15)
            ..findProxy = (_) => route,
        );
      HttpClient.instance.dio = dio;

      final wanted = int.tryParse(io.Platform.environment['PURELIVE_LOOK_PROBE_ROOMS'] ?? '') ?? 4;
      final roomBudget = wanted.clamp(1, 8);
      final site = Sites.of(Sites.lookLiveSite).liveSite;
      final resolver = site as LivePlayUrlResolver;

      final rooms = await site.getRecommendRooms(page: 1, pageSize: 20).timeout(const Duration(seconds: 40));
      final sessions = <Map<String, Object?>>[];

      for (final room in rooms.where((room) => room.isLiveNow).take(roomBudget)) {
        try {
          final detail = await site.getRoomDetail(room).timeout(const Duration(seconds: 30));
          if (!detail.isLiveNow) continue;

          final headers = await PlaybackHeaderResolver.resolve(
            platform: Sites.lookLiveSite,
            roomId: detail.normalizedRoomId,
            roomHeaders: detail.httpHeaders,
          );
          final qualities = await site.getPlayQualites(liveroom: detail).timeout(const Duration(seconds: 30));

          for (final quality in qualities) {
            final resolution = await resolver
                .resolvePlayUrlsRaw(liveroom: detail, quality: quality)
                .timeout(const Duration(seconds: 30));
            for (final url in resolution.urls) {
              final withHeaders = await _probe(url, headers);
              final withoutHeaders = await _probe(url, const <String, String>{});
              sessions.add(<String, Object?>{
                'roomId': detail.normalizedRoomId,
                'quality': quality.id,
                'declaredHeaderNames': headers.keys.toList(growable: false),
                'withHeaders': withHeaders,
                'withoutHeaders': withoutHeaders,
                // The comparison this probe exists for: does the CDN care?
                'headerSensitive': withHeaders['status'] != withoutHeaders['status'],
                // Advertised by the platform but not published: a 404, or a
                // connection that is accepted and then never delivers a byte.
                'ghost': withHeaders['status'] != 200 || withHeaders['bytes'] == 0,
              });
            }
          }
        } catch (error) {
          sessions.add(<String, Object?>{
            'roomId': room.normalizedRoomId,
            'result': 'failed',
            'failureType': error.runtimeType.toString(),
          });
        }
      }

      final probed = sessions.where((session) => session['withHeaders'] != null).toList(growable: false);
      final healthyRooms = <String>{
        for (final session in probed)
          if (session['ghost'] == false) session['roomId']! as String,
      };
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'roomsSampled': roomBudget,
        'linesProbed': probed.length,
        'headerSensitiveLines': probed.where((session) => session['headerSensitive'] == true).length,
        'ghostLines': probed.where((session) => session['ghost'] == true).length,
        'healthyRooms': healthyRooms.toList(growable: false),
        'urlsPersisted': false,
        'sessions': sessions,
      };
      // ignore: avoid_print
      print(const JsonEncoder.withIndent('  ').convert(report));

      expect(probed, isNotEmpty, reason: 'no live LOOK room produced a media line to probe');
      // `liveStatus=1` does not guarantee that the CDN is publishing: sampled
      // rooms have included one whose HLS line 404s while its FLV line accepts
      // the connection and then sends nothing for 30s. A ghost is therefore
      // reported as data; what must hold is that a healthy room's lines answer.
      expect(
        healthyRooms,
        isNotEmpty,
        reason: 'every sampled LOOK room was a ghost — nothing to conclude, re-run against a busier hour',
      );
      HttpClient.instance.dio = previousDio;
      dio.close(force: true);
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_LOOK_HEADERS_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Reads the first bytes of [url] and reports the status plus how much arrived.
///
/// Headers are compared against an empty set because that is exactly what the
/// player was sending while `PlaybackHeaderResolver` dropped the room's
/// declaration: mpv logged `http-header-fields=[]`.
Future<Map<String, Object?>> _probe(String url, Map<String, String> headers) async {
  final client = io.HttpClient()..connectionTimeout = const Duration(seconds: 12);
  final stopwatch = Stopwatch()..start();
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 15));
    var bytes = 0;
    await for (final chunk in response.take(4)) {
      bytes += chunk.length;
    }
    return <String, Object?>{
      'status': response.statusCode,
      'bytes': bytes,
      'ms': stopwatch.elapsedMilliseconds,
      'contentType': response.headers.value('content-type'),
    };
  } catch (error) {
    return <String, Object?>{'status': null, 'error': error.runtimeType.toString(), 'ms': stopwatch.elapsedMilliseconds};
  } finally {
    client.close(force: true);
  }
}

class _RealNetwork extends io.HttpOverrides {}

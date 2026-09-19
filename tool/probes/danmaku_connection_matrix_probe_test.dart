// Opt-in production-network probe for the room-discovery -> detail -> danmaku
// connection path. The report contains public room identity and aggregate
// callback counters only; cookies, signed endpoints and message bodies are not
// persisted.
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'current public rooms establish and retain platform danmaku sessions',
    () async {
      final route = io.Platform.environment['PURELIVE_DANMAKU_ROUTE']?.trim() ?? 'DIRECT';
      expect(route, anyOf('DIRECT', startsWith('PROXY ')));
      final seconds = int.tryParse(io.Platform.environment['PURELIVE_DANMAKU_SECONDS'] ?? '') ?? 20;
      final observation = Duration(seconds: seconds.clamp(5, 90));
      final requestedCycles = int.tryParse(io.Platform.environment['PURELIVE_DANMAKU_CYCLES'] ?? '') ?? 1;
      final cycles = requestedCycles.clamp(1, 10);
      final requireChat = io.Platform.environment['PURELIVE_DANMAKU_REQUIRE_CHAT'] == '1';
      final platforms = (io.Platform.environment['PURELIVE_DANMAKU_PLATFORMS'] ?? 'bilibili,huya,douyin')
          .split(',')
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      expect(platforms, isNotEmpty);
      expect(platforms.every(_supportedProbePlatforms.contains), isTrue);

      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'route': route,
        'observationSeconds': observation.inSeconds,
        'cycles': cycles,
        'requireChat': requireChat,
        'platforms': platforms,
        'publicRoomIdsPersisted': true,
        'cookiesOrSignedEndpointsPersisted': false,
        'messageBodiesPersisted': false,
        'result': 'failed',
      };
      await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(SettingsService());
      var passed = false;
      try {
        await io.HttpOverrides.runWithHttpOverrides(() async {
          final previousDio = HttpClient.instance.dio;
          final dio =
              Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)))
                ..httpClientAdapter = IOHttpClientAdapter(
                  createHttpClient: () => io.HttpClient()
                    ..connectionTimeout = const Duration(seconds: 15)
                    ..findProxy = (_) => route,
                );
          HttpClient.instance.dio = dio;
          configureWebSocketProxyRouting((_) => route);
          try {
            final results = <Map<String, Object?>>[];
            for (var cycle = 1; cycle <= cycles; cycle++) {
              final cycleResults = await Future.wait(
                platforms.map(
                  (platform) => _probePlatform(platform, observation, cycle: cycle, requireChat: requireChat),
                ),
              );
              results.addAll(cycleResults);
            }
            report['sessions'] = results;
            passed = results.every((result) => result['result'] == 'passed');
            report['result'] = passed ? 'passed' : 'failed';
          } finally {
            configureWebSocketProxyRouting(null);
            HttpClient.instance.dio = previousDio;
            dio.close(force: true);
          }
        }, _RealNetwork());
      } finally {
        final output = io.Platform.environment['PURELIVE_DANMAKU_OUTPUT'];
        if (output != null && output.trim().isNotEmpty) {
          await io.File(output).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
        }
        // ignore: avoid_print
        print(jsonEncode(report));
        Get.reset();
        await Hive.close();
      }
      expect(passed, isTrue, reason: 'At least one current public danmaku session did not remain connected');
    },
    skip: io.Platform.environment['PURELIVE_DANMAKU_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

const _supportedProbePlatforms = <String>{Sites.bilibiliSite, Sites.huyaSite, Sites.douyinSite};

Future<Map<String, Object?>> _probePlatform(
  String platform,
  Duration observation, {
  required int cycle,
  required bool requireChat,
}) async {
  final stopwatch = Stopwatch()..start();
  LiveDanmaku? engine;
  try {
    final site = Sites.of(platform).liveSite;
    final detail = await _findCurrentRoom(site, platform);
    engine = site.getDanmaku();
    var readyCount = 0;
    var reconnectCount = 0;
    var terminalCloseCount = 0;
    var chatCount = 0;
    var audienceCount = 0;
    final firstReady = Completer<void>();

    engine.onReady = () {
      readyCount++;
      if (!firstReady.isCompleted) firstReady.complete();
    };
    engine.onReconnect = (_) => reconnectCount++;
    engine.onClose = (_) => terminalCloseCount++;
    engine.onMessage = (message) {
      if (message.type == LiveMessageType.chat) chatCount++;
      if (message.type == LiveMessageType.online) audienceCount++;
    };

    await engine.start(detail.danmakuData).timeout(const Duration(seconds: 25));
    await firstReady.future.timeout(const Duration(seconds: 20));
    await Future<void>.delayed(observation);
    final connectedAtEnd = engine.isConnected;
    final chatRequirementMet = !requireChat || chatCount > 0;
    final passed = connectedAtEnd && terminalCloseCount == 0 && chatRequirementMet;
    return <String, Object?>{
      'platform': platform,
      'cycle': cycle,
      'roomId': detail.normalizedRoomId,
      'result': passed ? 'passed' : 'failed',
      'readyCount': readyCount,
      'reconnectCount': reconnectCount,
      'terminalCloseCount': terminalCloseCount,
      'chatCount': chatCount,
      'chatRequirementMet': chatRequirementMet,
      'audienceCount': audienceCount,
      'connectedAtEnd': connectedAtEnd,
      'durationMs': stopwatch.elapsedMilliseconds,
    };
  } catch (error) {
    return <String, Object?>{
      'platform': platform,
      'cycle': cycle,
      'result': 'failed',
      'failureType': error.runtimeType.toString(),
      'durationMs': stopwatch.elapsedMilliseconds,
    };
  } finally {
    await engine?.stop().timeout(const Duration(seconds: 5)).catchError((_) {});
  }
}

Future<LiveRoom> _findCurrentRoom(LiveSite site, String platform) async {
  final candidates = await site.getRecommendRooms(page: 1, pageSize: 20).timeout(const Duration(seconds: 30));
  Object? lastError;
  for (final room in candidates.where((room) => room.isLiveNow && room.normalizedRoomId.isNotEmpty).take(6)) {
    try {
      final detail = await site
          .getRoomDetail(roomId: room.normalizedRoomId, platform: platform)
          .timeout(const Duration(seconds: 25));
      if (detail.isLiveNow && detail.danmakuData != null) return detail;
    } catch (error) {
      lastError = error;
    }
  }
  if (lastError != null) throw StateError('No usable current room (${lastError.runtimeType})');
  throw StateError('No usable current room');
}

class _RealNetwork extends io.HttpOverrides {}

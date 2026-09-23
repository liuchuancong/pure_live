// Opt-in read-only probe of the official PandaTV LIVE and BJ search endpoints.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/pandalive/pandalive_api.dart';
import 'package:pure_live/core/site/pandalive/pandalive_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test(
    'registered PandaTV adapter searches official current rooms and BJ profiles',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final proxyUrl = io.Platform.environment['PURELIVE_PANDA_PROXY'];
        final proxy = proxyUrl == null ? null : Uri.tryParse(proxyUrl);
        if (proxyUrl != null &&
            (proxy == null || proxy.scheme != 'http' || proxy.host != '127.0.0.1' || proxy.port < 1)) {
          throw const FormatException('PURELIVE_PANDA_PROXY must be a loopback HTTP proxy URL');
        }
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = io.HttpClient();
            if (proxy != null) client.findProxy = (_) => 'PROXY 127.0.0.1:${proxy.port}';
            return client;
          },
        );
        dio.interceptors.add(
          InterceptorsWrapper(
            onError: (error, handler) {
              // ignore: avoid_print
              print('PandaTV probe transport ${error.type}: ${error.requestOptions.uri.path} ${error.error}');
              handler.next(error);
            },
          ),
        );
        HttpClient.instance.dio = dio;
        try {
          final api = PandaLiveApi();
          // ignore: avoid_print
          print('PandaTV probe BJ request');
          final bj = await api.searchBroadcasters('가온', size: 10);
          // ignore: avoid_print
          print('PandaTV probe LIVE request');
          final live = await api.searchLive('가온', size: 10);
          // ignore: avoid_print
          print('PandaTV probe registered adapter request');
          final site = Sites.of(Sites.pandaLiveSite).liveSite as PandaLiveSite;
          final merged = await site.searchRooms('가온', pageSize: 20);
          expect(bj.rooms, isNotEmpty);
          expect(merged, isNotEmpty);
          expect(merged.every((room) => room.roomId != null && room.data == null), isTrue);
          expect(live.rooms.every((room) => room.onlineViewers == null || room.onlineViewers! >= 0), isTrue);
          final bjOffline = bj.rooms.where((room) => room.state == PandaLiveState.offline).length;
          final mergedOffline = merged.where((room) => room.effectiveLiveStatus == LiveStatus.offline).length;
          if (bjOffline > 0) expect(mergedOffline, greaterThan(0));
          // ignore: avoid_print
          print(
            jsonEncode({
              'utc': DateTime.now().toUtc().toIso8601String(),
              'liveResults': live.rooms.length,
              'bjResults': bj.rooms.length,
              'bjOfflineProfiles': bjOffline,
              'mergedResults': merged.length,
              'offlineProfiles': mergedOffline,
              'nativePaging': true,
              'mediaFetched': false,
              'nativePlaybackOrRecording': false,
            }),
          );
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_PANDA_SEARCH_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}

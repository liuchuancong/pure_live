// End-to-end check of the private playback inputs (FC2, niconico, Bigo) on a
// real runner: resolve a live room, open the same owned input the player
// uses, and read real media bytes from its local URI.
//   flutter test integration_test/owned_inputs_test.dart --device-id=windows
//     [--dart-define=PURELIVE_TEST_PROXY=127.0.0.1:7897]
// Use the long device flag (see webview_sites_test.dart).
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/player/core/live_input_playback_binding.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    final settings = Get.put(SettingsService(), permanent: true);
    const proxy = String.fromEnvironment('PURELIVE_TEST_PROXY');
    final separator = proxy.lastIndexOf(':');
    if (separator > 0) {
      final host = proxy.substring(0, separator);
      final port = int.parse(proxy.substring(separator + 1));
      settings.proxy
        ..appProxyHost.value = host
        ..appProxyPort.value = port
        ..enableAppProxy.value = true
        ..proxyHost.value = host
        ..proxyPort.value = port
        ..enableProxy.value = true;
    }
  });
  tearDownAll(Hive.close);

  for (final id in const ['fc2live', 'niconico', 'bigo']) {
    testWidgets('$id: owned playback input serves media', (tester) async {
      await tester.runAsync(() async {
        final site = Sites.of(id).liveSite;
        var rooms = await site.getRecommendRooms(page: 1, pageSize: 20);
        if (rooms.isEmpty) {
          for (final category in await site.getCategores(1, 20)) {
            if (category.children.isEmpty) continue;
            rooms = await site.getCategoryRooms(category.children.first, page: 1, pageSize: 20);
            if (rooms.isNotEmpty) break;
          }
        }
        expect(rooms, isNotEmpty, reason: 'empty directory');
        Object? lastError;
        for (final card in rooms.take(3)) {
          try {
            final detail = await site.getRoomDetail(roomId: card.roomId!, platform: id);
            if (detail.liveStatus != LiveStatus.live) continue;
            final qualities = await site.getPlayQualites(detail: detail);
            final resolution = await site.resolvePlayUrls(detail: detail, quality: qualities.first);
            final recipe = resolution.inputRecipe;
            expect(recipe, isNotNull, reason: 'expected an owned input');
            final lease = await bindLiveInputForPlayback(recipe!).createInput(CancelToken());
            try {
              final kind = await _firstMedia(lease.uri);
              // ignore: avoid_print
              print('$id ${card.roomId} ${qualities.first.quality} -> $kind');
              expect(kind, startsWith('ok:'));
              return;
            } finally {
              await lease.close();
            }
          } catch (error) {
            lastError = error;
            // ignore: avoid_print
            print('$id ${card.roomId} failed: $error');
          }
        }
        fail('no room produced media: $lastError');
      });
    }, timeout: const Timeout(Duration(minutes: 6)));
  }
}

/// Follows a local HLS playlist to its first segment and classifies the bytes.
Future<String> _firstMedia(Uri uri, {int depth = 0}) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close().timeout(const Duration(seconds: 30));
    if (response.statusCode >= 400) return 'http-${response.statusCode}';
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      bytes.add(chunk);
      if (bytes.length >= 64 * 1024) break;
    }
    final data = bytes.takeBytes();
    if (data.isNotEmpty && data[0] == 0x47) return 'ok:ts';
    if (data.length >= 8 && const {'ftyp', 'styp', 'moof', 'sidx'}.contains(String.fromCharCodes(data.sublist(4, 8)))) {
      return 'ok:mp4';
    }
    if (data.length >= 3 && data[0] == 0x46 && data[1] == 0x4c && data[2] == 0x56) return 'ok:flv';
    final text = String.fromCharCodes(data);
    if (!text.startsWith('#EXTM3U') || depth >= 3) return 'unknown(${data.length})';
    final map = RegExp(r'#EXT-X-MAP:.*URI="([^"]+)"').firstMatch(text)?.group(1);
    final next =
        map ??
        text.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
    if (next.isEmpty) return 'hls-empty';
    return await _firstMedia(uri.resolve(next), depth: depth + 1);
  } finally {
    client.close(force: true);
  }
}

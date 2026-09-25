// Opt-in end-to-end check of every registered site through the app's own
// adapters: catalog -> room detail -> qualities -> play URLs -> real media bytes.
// Not part of offline CI. Nothing is saved except the stage/verdict report;
// signed URLs, cookies and media are never written.
//
//   PURELIVE_ALL_SITES_PROBE=1 flutter test tool/probes/all_sites_playback_probe_test.dart
//   PURELIVE_PROBE_SITES=huya,douyu        limit to some sites
//   PURELIVE_PROBE_REPORT=/tmp/report.json write the JSON report there
//   PURELIVE_PROBE_ALL_QUALITIES=1         also classify every offered quality (FLV codec per rung)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';

const _siteTimeout = Duration(seconds: 90);
const _mediaTimeout = Duration(seconds: 15);
const _roomsPerSite = 3;

// These adapters resolve their catalog or media through a headless WebView,
// which does not exist on a test host; verify them on a device instead.
const _webViewSites = {'dailymotion', 'nimotv', 'rumble', 'shopeelive'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('all-sites-probe-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.put(SettingsService(), permanent: true);
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test(
    'every registered site reaches real media through its adapter',
    () async {
      final wanted = (Platform.environment['PURELIVE_PROBE_SITES'] ?? '')
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
      // IPTV is a local channel list, not a live site; it needs the app database.
      final ids =
          Sites.supportedSiteIds.where((id) => id != Sites.iptvSite && (wanted.isEmpty || wanted.contains(id))).toList()
            ..sort();
      final results = <Map<String, Object?>>[];
      await HttpOverrides.runWithHttpOverrides(() async {
        for (final id in ids) {
          final clock = Stopwatch()..start();
          final result = <String, Object?>{'site': id};
          try {
            await _probeSite(id, result).timeout(_siteTimeout);
          } on TimeoutException {
            result['error'] ??= 'site timed out after ${_siteTimeout.inSeconds}s';
          } catch (error) {
            result['error'] ??= _describe(error);
          }
          result['ms'] = clock.elapsedMilliseconds;
          results.add(result);
          // ignore: avoid_print
          print(_row(result));
        }
      }, _RealNetwork());

      final ok = results.where((r) => r['verdict'] == 'media-ok').length;
      // ignore: avoid_print
      print('\nSUMMARY media-ok $ok/${results.length}');
      final reportPath = Platform.environment['PURELIVE_PROBE_REPORT'];
      if (reportPath != null && reportPath.isNotEmpty) {
        await File(reportPath).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      }
    },
    skip: Platform.environment['PURELIVE_ALL_SITES_PROBE'] != '1',
    timeout: const Timeout(Duration(hours: 2)),
  );
}

Future<void> _probeSite(String id, Map<String, Object?> result) async {
  if (_webViewSites.contains(id)) {
    result['verdict'] = 'needs-device';
    return;
  }
  final site = Sites.of(id).liveSite;
  result['stage'] = 'catalog';
  var rooms = await site.getRecommendRooms(page: 1, pageSize: 20);
  if (rooms.isEmpty) {
    final categories = await site.getCategores(1, 20);
    for (final category in categories) {
      if (category.children.isEmpty) continue;
      rooms = await site.getCategoryRooms(category.children.first, page: 1, pageSize: 20);
      if (rooms.isNotEmpty) break;
    }
  }
  result['catalogRooms'] = rooms.length;
  if (rooms.isEmpty) {
    result['verdict'] = 'no-catalog';
    return;
  }
  final candidates = rooms.where((r) => (r.roomId ?? '').trim().isNotEmpty).take(_roomsPerSite);
  final attempts = <String>[];
  for (final listed in candidates) {
    final roomId = listed.roomId!.trim();
    try {
      result['stage'] = 'detail';
      final detail = await site.getRoomDetail(roomId: roomId, platform: id);
      if (detail.liveStatus != LiveStatus.live) {
        attempts.add('not-live(${detail.liveStatus?.name})');
        continue;
      }
      result['stage'] = 'qualities';
      final qualities = await site.getPlayQualites(detail: detail);
      if (qualities.isEmpty) {
        attempts.add('no-qualities');
        continue;
      }
      result['qualities'] = qualities.map((q) => q.quality).toList();
      result['stage'] = 'urls';
      // Same entry point as the player: owned inputs carry no exportable URL.
      final resolution = await site.resolvePlayUrls(detail: detail, quality: qualities.first);
      if (resolution.inputRecipe != null) {
        result['verdict'] = 'owned-input';
        return;
      }
      final urls = resolution.urls;
      if (urls.isEmpty) {
        attempts.add('no-urls');
        continue;
      }
      result['lines'] = urls.length;
      final uri = Uri.tryParse(urls.first);
      if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
        result['verdict'] = 'private-input';
        result['scheme'] = uri?.scheme;
        return;
      }
      result['stage'] = 'media';
      final headers = await PlaybackHeaderResolver.resolve(platform: id, roomId: roomId);
      final media = await _checkMedia(uri, headers);
      result['media'] = media;
      if (Platform.environment['PURELIVE_PROBE_ALL_QUALITIES'] == '1') {
        // Codec per offered quality: HEVC is often only on non-default rungs.
        final perQuality = <String, String>{};
        for (final quality in qualities) {
          try {
            final other = await site.resolvePlayUrls(detail: detail, quality: quality);
            final otherUri = other.urls.isEmpty ? null : Uri.tryParse(other.urls.first);
            perQuality[quality.quality] = otherUri == null ? 'no-url' : await _checkMedia(otherUri, headers);
          } catch (error) {
            perQuality[quality.quality] = 'error: ${_describe(error)}';
          }
        }
        result['mediaByQuality'] = perQuality;
      }
      if (media.startsWith('ok:')) {
        result['verdict'] = 'media-ok';
        return;
      }
      attempts.add(media);
    } catch (error) {
      attempts.add('${result['stage']}: ${_describe(error)}');
    }
  }
  result['attempts'] = attempts;
  result['verdict'] ??= attempts.every((a) => a.startsWith('not-live')) ? 'no-live-room' : 'failed';
}

/// Classifies the first bytes of a stream, following HLS master -> media -> segment.
/// Cookies set by a playlist are replayed on its children, as FFmpeg's HLS
/// demuxer does (e.g. TwitCasting's per-movie `lvhls_ssid_*` segment cookie).
Future<String> _checkMedia(
  Uri uri,
  Map<String, String> headers, {
  int depth = 0,
  List<Cookie> cookies = const <Cookie>[],
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri).timeout(_mediaTimeout);
    headers.forEach((k, v) => request.headers.set(k, v, preserveHeaderCase: true));
    request.cookies.addAll(cookies);
    final response = await request.close().timeout(_mediaTimeout);
    final jar = <Cookie>[...cookies, ...response.cookies];
    if (response.statusCode >= 400) return 'http-${response.statusCode}';
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.timeout(_mediaTimeout)) {
        bytes.add(chunk);
        if (bytes.length >= 64 * 1024) break;
      }
    } on TimeoutException {
      if (bytes.isEmpty) return 'no-bytes';
    }
    final data = bytes.takeBytes();
    final isFlv = data.length >= 3 && data[0] == 0x46 && data[1] == 0x4c && data[2] == 0x56;
    if (isFlv) return 'ok:flv(${_flvVideoCodec(data)})';
    if (data.isNotEmpty && data[0] == 0x47) return 'ok:ts';
    if (data.length >= 8) {
      final box = latin1.decode(data.sublist(4, 8), allowInvalid: true);
      if (const {'ftyp', 'styp', 'moof', 'sidx'}.contains(box)) return 'ok:mp4';
    }
    if (data.length >= 3 && data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33) return 'ok:id3';
    final text = utf8.decode(data, allowMalformed: true);
    if (!text.trimLeft().startsWith('#EXTM3U')) return 'unknown-bytes(${data.length})';
    if (depth >= 3) return 'hls-too-deep';
    final base = response.redirects.isEmpty
        ? uri
        : response.redirects.last.location.isAbsolute
        ? response.redirects.last.location
        : uri.resolveUri(response.redirects.last.location);
    final lines = const LineSplitter().convert(text).map((l) => l.trim()).toList();
    final map = RegExp(r'#EXT-X-MAP:.*URI="([^"]+)"').firstMatch(text)?.group(1);
    if (map != null) return await _checkMedia(base.resolve(map), headers, depth: depth + 1, cookies: jar);
    final next = lines.firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
    if (next.isEmpty) return text.contains('#EXT-X-ENDLIST') ? 'hls-ended' : 'hls-empty';
    return await _checkMedia(base.resolve(next), headers, depth: depth + 1, cookies: jar);
  } on TimeoutException {
    return 'timeout';
  } catch (error) {
    return 'error: ${_describe(error)}';
  } finally {
    client.close(force: true);
  }
}

/// First video tag's codec: `avc` (7), `hevc-id12` (legacy HEVC, needs the
/// libmpv rewrite relay), Enhanced FLV FourCC, or `none` within the sample.
String _flvVideoCodec(List<int> data) {
  if (data.length < 13) return 'none';
  var offset = 9 + 4;
  while (offset + 12 <= data.length) {
    final type = data[offset] & 0x1f;
    final size = (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
    if (type == 9) {
      final flags = data[offset + 11];
      if ((flags & 0x80) != 0) {
        return offset + 16 <= data.length ? 'ex-${latin1.decode(data.sublist(offset + 12, offset + 16))}' : 'ex';
      }
      return switch (flags & 0x0f) {
        7 => 'avc',
        12 => 'hevc-id12',
        final id => 'id$id',
      };
    }
    offset += 11 + size + 4;
  }
  return 'none';
}

String _describe(Object error) {
  final text = error.toString().replaceAll(RegExp(r'https?://\S+'), '<url>').replaceAll('\n', ' ');
  return text.length > 140 ? '${text.substring(0, 140)}…' : text;
}

String _row(Map<String, Object?> r) {
  final detail = r['media'] ?? r['error'] ?? (r['attempts'] as List?)?.join('; ') ?? '';
  return '${(r['site'] as String).padRight(16)} ${(r['verdict'] ?? 'error').toString().padRight(14)} '
      'stage=${r['stage']} rooms=${r['catalogRooms'] ?? '-'} ${r['ms']}ms  $detail';
}

class _RealNetwork extends HttpOverrides {}

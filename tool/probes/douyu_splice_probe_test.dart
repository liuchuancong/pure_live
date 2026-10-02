// Opt-in live check of FlvSpliceRelay against a real Douyu room: renews the
// original-quality URL every PURELIVE_SPLICE_EVERY seconds (default 60) while
// ffprobe reads the relay, then checks that packet timestamps stay continuous
// across every switch.
//
//   PURELIVE_SPLICE_PROBE=1 DY_ROOM=5526219 flutter test tool/probes/douyu_splice_probe_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/domain/live_quality_discovery.dart';
import 'package:pure_live/domains/live/domain/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/live/data/stream/flv_splice_relay.dart';

void main() {
  final enabled = Platform.environment['PURELIVE_SPLICE_PROBE'] == '1';
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final temp = await Directory.systemTemp.createTemp('splice-probe-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.put(SettingsService(), permanent: true);
  });

  test(
    'Douyu original quality splices across renewed URLs',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final room = Platform.environment['DY_ROOM'] ?? '5526219';
        final every = Duration(seconds: int.parse(Platform.environment['PURELIVE_SPLICE_EVERY'] ?? '60'));
        final seconds = int.parse(Platform.environment['PURELIVE_SPLICE_SECONDS'] ?? '150');
        final site = Sites.of('douyu').liveSite;

        Future<Uri> resolve() async {
          final detail = await site.getRoomDetail(roomId: room, platform: 'douyu');
          final qualities = await site.discoverPlayQualities(detail: detail);
          final resolution = await site.resolvePlayUrls(detail: detail, quality: qualities.first);
          return Uri.parse(resolution.urls.first);
        }

        var renewals = 0;
        final relay = await FlvSpliceRelay.start(
          FlvLeasedSource(await resolve(), refreshAt: DateTime.now().add(every)),
          renew: (current) async {
            renewals++;
            final url = await resolve();
            stdout.writeln('renewal $renewals at ${DateTime.now().toIso8601String()} -> ${url.path}');
            return FlvLeasedSource(url, refreshAt: DateTime.now().add(every));
          },
          headers: const {},
          findProxy: (_) => 'DIRECT',
        );
        try {
          final probe = await Process.run('ffprobe', [
            '-v',
            'error',
            '-show_entries',
            'packet=codec_type,dts_time,flags',
            '-of',
            'csv=p=0',
            '-read_intervals',
            '%+$seconds',
            relay.inputUri.toString(),
          ]);
          final lines = const LineSplitter().convert(probe.stdout as String);
          final video = <double>[];
          final audio = <double>[];
          for (final line in lines) {
            final parts = line.split(',');
            if (parts.length < 2) continue;
            final ts = double.tryParse(parts[1]);
            if (ts == null) continue;
            (parts[0] == 'video' ? video : audio).add(ts);
          }
          double maxGap(List<double> values) {
            var gap = 0.0;
            for (var i = 1; i < values.length; i++) {
              final d = values[i] - values[i - 1];
              if (d > gap) gap = d;
            }
            return gap;
          }

          int backwards(List<double> values) {
            var count = 0;
            for (var i = 1; i < values.length; i++) {
              if (values[i] < values[i - 1]) count++;
            }
            return count;
          }

          stdout.writeln(
            'video ${video.length} packets ${video.first}..${video.last} maxGap ${maxGap(video).toStringAsFixed(3)} backwards ${backwards(video)}',
          );
          stdout.writeln(
            'audio ${audio.length} packets ${audio.first}..${audio.last} maxGap ${maxGap(audio).toStringAsFixed(3)} backwards ${backwards(audio)}',
          );
          stdout.writeln('ffprobe stderr: ${(probe.stderr as String).trim()}');
          expect(renewals, greaterThanOrEqualTo(seconds ~/ every.inSeconds));
          expect(video.last - video.first, greaterThan(seconds - 15));
          expect(maxGap(video), lessThan(0.2));
          expect(maxGap(audio), lessThan(0.2));
          expect(backwards(video), 0);
        } finally {
          await relay.close();
        }
      }, _RealNetwork());
    },
    skip: enabled ? false : 'set PURELIVE_SPLICE_PROBE=1',
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

class _RealNetwork extends HttpOverrides {}

// Opt-in actual MediaKitAdapter + libmpv test, without texture or audio output.
// Run through local_ci with PURELIVE_BUFFER_PROBE_LIB and
// PURELIVE_BUFFER_PROBE_MEDIA (synthetic FLV only). No phone or CDN access.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:pure_live/core/player/adapters/media_kit_adapter.dart';
import 'package:pure_live/core/player/utils/live_buffer_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['PURELIVE_BUFFER_PROBE_LIB'];
  final media = Platform.environment['PURELIVE_BUFFER_PROBE_MEDIA'];
  test(
    'actual native buffering survives adapter media-progress callbacks',
    () async {
      final bytes = await File(media!).readAsBytes();
      final packets = _packets(bytes);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final clock = Stopwatch()..start();
      final stop = Completer<void>();
      final handlers = <Future<void>>[];
      final timeline = <Map<String, Object>>[];
      final violations = <Map<String, Object>>[];
      var opens = 0;
      var injected = false;
      var accepted = false;
      var adapterLoading = true;
      void record(String name, bool value) {
        timeline.add({'ms': clock.elapsedMilliseconds, 'event': name, 'value': value});
      }

      Future<void> serve(HttpRequest request) async {
        if (request.uri.path != '/fixture.flv' || opens > 0) {
          request.response.statusCode = HttpStatus.conflict;
          await request.response.close();
          return;
        }
        opens++;
        request.response.headers.contentType = ContentType('video', 'x-flv');
        final started = clock.elapsedMilliseconds;
        try {
          for (final packet in packets) {
            // Keep media timestamps/bytes intact. Withhold input for 2.4 s at
            // t=12, then catch up; not an invented playing/buffering event.
            final delayed = packet.ms >= 12000 && packet.ms < 14400;
            final due = delayed ? 14400 : packet.ms;
            final remaining = started + due - clock.elapsedMilliseconds;
            if (remaining > 0) {
              await Future.any([stop.future, Future<void>.delayed(Duration(milliseconds: remaining))]);
            }
            if (stop.isCompleted) break;
            if (delayed) injected = true;
            request.response.add(packet.bytes);
            await request.response.flush();
          }
        } finally {
          await request.response.close();
        }
      }

      final serving = server.listen((request) => handlers.add(serve(request)));
      mk.MediaKit.ensureInitialized(libmpv: library!);
      final player = mk.Player(configuration: const mk.PlayerConfiguration(vo: 'null'));
      final native = player.platform as dynamic;
      // This opt-in native test stays outside test/ to avoid normal-suite I/O.
      // ignore: invalid_use_of_visible_for_testing_member
      final adapter = MediaKitAdapter.headlessForTest(player);
      final subscriptions = <StreamSubscription>[
        player.stream.buffering.listen((value) => record('nativeBuffering', value)),
        adapter.onLoading.listen((value) {
          adapterLoading = value;
          record('adapterLoading', value);
          if (accepted && !value && player.state.buffering) {
            violations.add({'ms': clock.elapsedMilliseconds, 'nativeBuffering': true});
          }
        }),
      ];
      try {
        await native.setProperty('ao', 'null');
        await native.setProperty('demuxer-lavf-analyzeduration', '2');
        await native.setProperty('network-timeout', '15');
        await LiveBufferPolicy.apply((name, value) async => await native.setProperty(name, value));
        final url = 'http://127.0.0.1:${server.port}/fixture.flv';
        await adapter.setDataSource(url, [url], const {}).timeout(const Duration(seconds: 15));
        accepted = true;
        while (clock.elapsedMilliseconds < 32000) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        final runtimeBuffering = timeline.where(
          (e) => e['event'] == 'nativeBuffering' && e['value'] == true && (e['ms'] as int) >= 10000,
        );
        // Emit even on acceptance failure so an unsuccessful run retains evidence.
        // ignore: avoid_print
        print(
          jsonEncode({
            'probe': 'real-adapter-buffering',
            'timeline': timeline,
            'violations': violations,
            'opens': opens,
            'injected': injected,
            'nativeBufferingAtEnd': player.state.buffering,
            'adapterLoadingAtEnd': adapterLoading,
          }),
        );
        expect(opens, 1);
        expect(injected, isTrue);
        expect(runtimeBuffering, isNotEmpty, reason: 'the input gap must actually exhaust native cache');
        expect(violations, isEmpty);
        expect(player.state.buffering, isFalse);
        expect(adapterLoading, isFalse);
        expect(player.state.completed, isFalse);
        expect(player.state.position.inSeconds, greaterThan(20));
      } finally {
        stop.complete();
        await Future.wait(handlers).timeout(const Duration(seconds: 6));
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await adapter.hardDispose();
        await serving.cancel();
        await server.close(force: true);
      }
    },
    skip: library == null || media == null,
    timeout: const Timeout(Duration(seconds: 65)),
  );
}

List<({int ms, Uint8List bytes})> _packets(Uint8List data) {
  if (data.length < 13 || data.length > 8 * 1024 * 1024 || ascii.decode(data.sublist(0, 3)) != 'FLV') {
    throw const FormatException('small synthetic FLV required');
  }
  final view = ByteData.sublistView(data);
  var offset = view.getUint32(5) + 4;
  if (offset < 13 || offset > data.length) throw const FormatException('FLV header');
  final result = [(ms: 0, bytes: Uint8List.sublistView(data, 0, offset))];
  var time = 0;
  while (offset < data.length) {
    if (offset + 11 > data.length) throw const FormatException('truncated tag');
    final size = (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
    final end = offset + size + 15;
    if (end > data.length || view.getUint32(end - 4) != size + 11) throw const FormatException('tag size');
    final timestamp = (data[offset + 7] << 24) | (data[offset + 4] << 16) | (data[offset + 5] << 8) | data[offset + 6];
    if (timestamp > time) time = timestamp;
    result.add((ms: time, bytes: Uint8List.sublistView(data, offset, end)));
    offset = end;
  }
  if (time < 35000) throw const FormatException('at least 35 seconds of synthetic media required');
  return result;
}

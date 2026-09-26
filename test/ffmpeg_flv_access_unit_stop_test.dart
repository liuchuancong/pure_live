import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/ffmpeg_flv_input_relay.dart';

const header = <int>[0x46, 0x4c, 0x56, 1, 5, 0, 0, 0, 9, 0, 0, 0, 0];
List<int> tag(List<int> payload, {int type = 9}) => [
  type,
  payload.length >> 16,
  (payload.length >> 8) & 255,
  payload.length & 255,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  ...payload,
  0,
  0,
  (payload.length + 11) >> 8,
  (payload.length + 11) & 255,
];
List<int> video(List<int> types) => tag([
  0x17,
  1,
  0,
  0,
  0,
  for (final type in types) ...[0, 0, 0, 1, type],
]);
final config = tag([0x17, 0, 0, 0, 0, 1, 66, 0, 30, 255, 225, 0, 1, 0x67, 1, 0, 1, 0x68]);

void main() {
  for (final lengthSize in [1, 2, 4]) {
    test('AVC boundary follows length size $lengthSize without rewriting tags', () {
      final state = FlvAvcAccessUnitBoundary();
      final configuration = [...config]..[20] = 0xfc | (lengthSize - 1);
      state.observe(configuration);
      List<int> nals(List<int> types) => tag([
        0x17,
        1,
        0,
        0,
        0,
        for (final type in types) ...[...List.filled(lengthSize - 1, 0), 1, type],
      ]);
      for (final prefixType in [6, 7, 8, 9]) {
        final packet = nals([5, prefixType]);
        final original = [...packet];
        state.observe(packet);
        expect(state.hasPendingAccessUnit, true);
        expect(packet, original);
        state.observe(tag([0xaf, 1, 1, 2], type: 8));
        expect(state.hasPendingAccessUnit, true);
        state.observe(nals([prefixType, 1]));
        expect(state.hasPendingAccessUnit, false);
      }
    });
  }

  test('configuration changes, unknown codecs and malformed AVC keep honest boundaries', () {
    final state = FlvAvcAccessUnitBoundary();
    state.observe(video([5, 6]));
    expect(state.hasPendingAccessUnit, false, reason: 'Unknown AVC framing is not guessed.');
    state.observe(config);
    state.observe(video([5, 6]));
    expect(state.hasPendingAccessUnit, true);
    state.observe(tag([0x1c, 1, 0, 0, 0, 1]));
    state.observe(tag([0x17, 2, 0, 0, 0]));
    expect(state.hasPendingAccessUnit, true);
    state.observe(tag([0x17, 1, 0, 0, 0, 0, 0, 0, 20, 5]));
    expect(state.hasPendingAccessUnit, true);
    state.observe(video([5]));
    expect(state.hasPendingAccessUnit, false);
    state.observe(tag([0x17, 1, 0, 0, 0, 0, 0, 0, 0]));
    expect(state.hasPendingAccessUnit, true);
  });

  test('reserved AVC length size is not interpreted as a picture boundary', () {
    final state = FlvAvcAccessUnitBoundary();
    state.observe(config);
    state.observe(video([5, 6]));
    state.observe([...config]..[20] = 0xfe);
    state.observe(video([1]));
    expect(state.hasPendingAccessUnit, true);
  });

  test('ordinary pictures and filler tails need no additional stop wait', () {
    final state = FlvAvcAccessUnitBoundary()..observe(config);
    for (var i = 0; i < 10000; i++) {
      state.observe(video([7, 8, 5, 12]));
      expect(state.hasPendingAccessUnit, false);
    }
  });

  for (final stalled in [false, true]) {
    test(
      'FLV stop ${stalled ? "cancels stalled lookahead" : "keeps SEI and drains only through the next complete picture"}',
      () async {
        final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final served = Completer<HttpResponse>();
        final prefix = [
          ...header,
          ...config,
          ...video([7, 8, 5, 6]),
        ];
        final upstream = origin.listen((request) async {
          request.response.bufferOutput = false;
          request.response.add(prefix);
          await request.response.flush();
          served.complete(request.response);
        });
        final relay = (await FFmpegFlvInputRelay.startForArguments([
          '-i',
          'http://127.0.0.1:${origin.port}/live.flv',
        ]))!;
        final client = HttpClient();
        final received = <int>[];
        final prefixReceived = Completer<void>();
        final ended = Completer<void>();
        StreamSubscription<List<int>>? downstream;
        try {
          final response = await (await client.getUrl(relay.inputUri)).close();
          downstream = response.listen(
            (chunk) {
              received.addAll(chunk);
              if (received.length >= prefix.length && !prefixReceived.isCompleted) prefixReceived.complete();
            },
            // Closing a stalled relay may surface as reset-then-done (POSIX)
            // or as a clean done (Windows); either one ends the downstream.
            onDone: () {
              if (!ended.isCompleted) ended.complete();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!ended.isCompleted) ended.completeError(error, stackTrace);
            },
          );
          await prefixReceived.future.timeout(const Duration(seconds: 2));
          var finished = false;
          final stopping = relay.finish().then((_) {
            finished = true;
          });
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(
            finished,
            false,
            reason: 'An already-forwarded SEI starts an incomplete picture, not a complete stop boundary.',
          );
          if (stalled) {
            ended.future.ignore();
            await relay.close().timeout(const Duration(seconds: 2));
            await stopping.timeout(const Duration(seconds: 2));
            expect(received, prefix);
          } else {
            final tail = [
              ...tag([0xaf, 1, 1, 2], type: 8),
              ...video([1]),
            ];
            final response = await served.future;
            response.add([
              ...tail,
              ...video([5, 6]),
            ]);
            await response.flush();
            await stopping.timeout(const Duration(seconds: 2));
            await ended.future.timeout(const Duration(seconds: 2));
            expect(received, [...prefix, ...tail]);
            expect(finished, true);
          }
        } finally {
          client.close(force: true);
          await relay.close();
          await downstream?.cancel();
          await origin.close(force: true);
          await upstream.cancel();
        }
      },
    );
  }
}

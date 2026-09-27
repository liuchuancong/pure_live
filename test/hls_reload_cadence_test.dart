import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/hls_body_reader.dart';
import 'package:pure_live/recorder/services/hls_prefetch_pool.dart';
import 'package:pure_live/recorder/services/hls_prefetch_scheduler.dart';
import 'package:pure_live/recorder/services/hls_retained_window.dart';
import 'package:pure_live/recorder/services/hls_session_cookies.dart';
import 'package:pure_live/recorder/services/hls_upstream_client.dart';

import 'hls_prefetch_scheduler_test.dart' as fixture;

void main() {
  test('first/changed loads wait a target; byte-identical loads wait half a target', () async {
    final pool = fixture.cache();
    final clock = Stopwatch()..start();
    final starts = <int>[];
    final finished = Completer<void>();
    final initial = fixture.playlist(0, 3);
    final changed = '$initial#comment-only-change\n';
    final scheduler = HlsPrefetchScheduler(
      pool: pool,
      fetchSnapshot: (_, _) async {
        starts.add(clock.elapsedMilliseconds);
        final text = switch (starts.length) {
          1 => initial,
          2 || 3 => changed,
          _ => '$changed#EXT-X-ENDLIST\n',
        };
        if (starts.length == 4) finished.complete();
        return HlsMediaSnapshot.parse(text, fixture.source);
      },
      loadResource: (_, _) async => HlsPrefetchResponse(Stream.value([1])),
    );
    try {
      expect(scheduler.select('video', fixture.source, HlsMediaSnapshot.parse(initial, fixture.source)), true);
      await finished.future.timeout(const Duration(seconds: 6));
      expect(starts, hasLength(4));
      expect(starts.first, inInclusiveRange(950, 1500));
      expect(starts[1] - starts[0], inInclusiveRange(450, 850));
      // Identical retained media does not mean an unchanged wire playlist.
      expect(starts[2] - starts[1], inInclusiveRange(950, 1500));
      expect(starts[3] - starts[2], inInclusiveRange(450, 850));
    } finally {
      await scheduler.close();
      // ignore: avoid_print
      print('Reload cadence start milliseconds: $starts');
    }
    expect(pool.ownedEntries, 0);
  });

  test('slow successful HTTP reloads do not add another interval or overlap and lose the rolling window', () async {
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final source = Uri.parse('http://127.0.0.1:${origin.port}/index.m3u8');
    final clock = Stopwatch()..start();
    final stopped = Completer<void>();
    final received = Completer<void>();
    final jobs = <Future<void>>{};
    final rows = <Map<String, int>>[];
    var active = 0;
    var maximumActive = 0;
    final subscription = origin.listen((request) {
      late Future<void> job;
      job = () async {
        final first = clock.elapsedMilliseconds ~/ 1000;
        final row = {'startMs': clock.elapsedMilliseconds, 'first': first};
        rows.add(row);
        active++;
        if (active > maximumActive) maximumActive = active;
        final ready = Completer<void>();
        final timer = Timer(const Duration(milliseconds: 2700), ready.complete);
        try {
          await Future.any([ready.future, stopped.future]);
          if (!stopped.isCompleted) request.response.write(fixture.playlist(first, 3));
          await request.response.close();
          row['doneMs'] = clock.elapsedMilliseconds;
          if (rows.length >= 4 && !received.isCompleted) received.complete();
        } on Object {
          // The owning test cancels its last in-flight response on close.
        } finally {
          timer.cancel();
          active--;
        }
      }().whenComplete(() => jobs.remove(job));
      jobs.add(job);
    });
    final client = HttpClient();
    final upstream = HlsUpstreamClient(client: client, source: source, headers: const {}, cookies: HlsSessionCookies());
    final pool = fixture.cache();
    final failures = <String>[];
    final scheduler = HlsPrefetchScheduler(
      pool: pool,
      pollInterval: const Duration(milliseconds: 500),
      fetchSnapshot: (uri, token) =>
          upstream.loadSnapshot(uri, token, budget: HlsResponseBudget(const Duration(seconds: 5))),
      loadResource: (_, _) async => HlsPrefetchResponse(Stream.value([1])),
      onRefreshFailure: (_, _, error) => failures.add(error.toString()),
    );
    try {
      expect(scheduler.select('video', source, HlsMediaSnapshot.parse(fixture.playlist(0, 3), source)), true);
      await received.future.timeout(const Duration(seconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(failures, isEmpty, reason: jsonEncode(rows));
      expect(scheduler.coverageIncomplete, false);
      expect(maximumActive, 1);
      // The next reload follows a slow one straight away instead of adding
      // another ~3 s interval. 1 s still separates the two while leaving room
      // for scheduler latency under a loaded Windows full-suite run (233 ms seen).
      for (var i = 1; i < 4; i++) {
        expect(rows[i]['startMs']! - rows[i - 1]['doneMs']!, lessThan(1000));
      }
      expect(scheduler.publish('video', (r) => r.uri), contains('#EXT-X-MEDIA-SEQUENCE:0'));
    } finally {
      stopped.complete();
      await scheduler.close();
      upstream.clear();
      client.close(force: true);
      await origin.close(force: true);
      await subscription.cancel();
      await Future.wait(jobs.toList());
      // ignore: avoid_print
      print('Slow reload source timing: ${jsonEncode(rows)}');
    }
    expect(pool.ownedEntries, 0);
    expect(pool.retainedBytes, 0);
  });
}

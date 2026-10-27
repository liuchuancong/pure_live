import 'dart:async';

import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/probe/probe.dart';
import 'package:test/test.dart';

/// A channel with one primary address and however many alternatives the
/// test wants; every address of a channel shares its request headers.
IptvChannel channel(String id, List<String> urls, {Map<String, String> headers = const {}}) => IptvChannel.of(
  id: id,
  entry: IptvEntry.of(name: id, url: urls.first, alternatives: urls.skip(1).toList(), headers: headers),
);

IptvLineHealth health(String url, {required bool ok, int? latencyMs, int failures = 0, DateTime? checkedAt}) =>
    IptvLineHealth(
      url: url,
      ok: ok,
      checkedAt: checkedAt ?? DateTime.utc(2026, 10, 12),
      latency: latencyMs == null ? null : Duration(milliseconds: latencyMs),
      failures: failures,
    );

void main() {
  group('iptvLineUrls', () {
    test('puts the primary address first and keeps the alternatives behind it', () {
      final entry = channel('cctv1', ['http://a/1', 'http://b/1', 'http://c/1']).entry;

      expect(iptvLineUrls(entry), ['http://a/1', 'http://b/1', 'http://c/1']);
    });

    test('drops the blanks and the repeats', () {
      final entry = IptvEntry.of(name: 'x', url: 'http://a/1', alternatives: ['http://a/1', '  ', 'http://b/1']);

      expect(iptvLineUrls(entry), ['http://a/1', 'http://b/1']);
    });

    test('trims the address it reports', () {
      final entry = IptvEntry.of(name: 'x', url: ' http://a/1 ');

      expect(iptvLineUrls(entry), ['http://a/1']);
    });
  });

  group('rankIptvLines', () {
    test('answers first, then the addresses nobody asked, then the failures', () {
      final subject = channel('c', ['http://slow', 'http://new', 'http://dead', 'http://fast']);
      final ranked = rankIptvLines(subject, {
        'http://slow': health('http://slow', ok: true, latencyMs: 400),
        'http://fast': health('http://fast', ok: true, latencyMs: 60),
        'http://dead': health('http://dead', ok: false, failures: 3),
      });

      expect(ranked.map((line) => line.url), ['http://fast', 'http://slow', 'http://new', 'http://dead']);
    });

    test('a verdict older than the freshness window says nothing', () {
      final subject = channel('c', ['http://a', 'http://b']);
      final now = DateTime.utc(2026, 10, 12, 12);
      final ranked = rankIptvLines(subject, {
        'http://a': health('http://a', ok: true, latencyMs: 50, checkedAt: now.subtract(const Duration(days: 3))),
        'http://b': health('http://b', ok: true, latencyMs: 900, checkedAt: now.subtract(const Duration(hours: 1))),
      }, now: now);

      // The fresh-but-slow answer beats a three-day-old one, which has gone
      // back to being an address nobody has asked about.
      expect(ranked.map((line) => line.url), ['http://b', 'http://a']);
      expect(ranked.last.isProbed, isFalse);
    });

    test('the playlist order breaks a tie', () {
      final subject = channel('c', ['http://a', 'http://b']);
      final ranked = rankIptvLines(subject, const {});

      expect(ranked.map((line) => line.url), ['http://a', 'http://b']);
    });

    test('a fewer-failures verdict beats a worse one among the failures', () {
      final subject = channel('c', ['http://bad3', 'http://bad1']);
      final ranked = rankIptvLines(subject, {
        'http://bad3': health('http://bad3', ok: false, failures: 3),
        'http://bad1': health('http://bad1', ok: false, failures: 1),
      });

      expect(ranked.first.url, 'http://bad1');
    });

    test('a candidate carries the headers the channel needs', () {
      final subject = channel('c', const ['http://a'], headers: const {'user-agent': 'lua/iptv'});
      final ranked = rankIptvLines(subject, const {});

      expect(ranked.single.headers, {'user-agent': 'lua/iptv'});
      expect(ranked.single.isHealthy, isFalse);
    });
  });

  group('IptvLineProber.probeChannel', () {
    test('asks every address when nothing is allowed to stop it', () async {
      final asked = <String>[];
      final prober = IptvLineProber(
        concurrency: 1,
        stopOnFirstOk: false,
        probe: (url, headers) async {
          asked.add(url);
          return const IptvProbeOutcome.answered(Duration(milliseconds: 100));
        },
      );

      final report = await prober.probeChannel(channel('c', ['http://a', 'http://b', 'http://c']));

      expect(asked, ['http://a', 'http://b', 'http://c']);
      expect(report.results.length, 3);
      expect(report.aborted, isFalse);
      expect(report.isDown, isFalse);
    });

    test('leaves the rest alone once one address answers, and says so', () async {
      final asked = <String>[];
      final prober = IptvLineProber(
        concurrency: 1,
        probe: (url, headers) async {
          asked.add(url);
          return const IptvProbeOutcome.answered(Duration(milliseconds: 50));
        },
      );

      final report = await prober.probeChannel(channel('c', ['http://a', 'http://b', 'http://c']));

      expect(asked, ['http://a']);
      expect(report.results.length, 1);
      expect(report.aborted, isTrue);
      expect(report.bestUrl, 'http://a');
    });

    test('the best url is the fastest of the ones that answered', () async {
      final prober = IptvLineProber(
        concurrency: 1,
        stopOnFirstOk: false,
        probe: (url, headers) async => url.endsWith('slow')
            ? const IptvProbeOutcome.answered(Duration(milliseconds: 800))
            : const IptvProbeOutcome.answered(Duration(milliseconds: 40)),
      );

      final report = await prober.probeChannel(channel('c', ['http://slow', 'http://fast']));

      expect(report.bestUrl, 'http://fast');
    });

    test('an address that never answers is a failure, not an unfinished future', () async {
      final prober = IptvLineProber(
        timeout: const Duration(milliseconds: 50),
        probe: (url, headers) => Completer<IptvProbeOutcome>().future,
      );

      final report = await prober.probeChannel(channel('c', ['http://blackhole']));

      expect(report.isDown, isTrue);
      expect(report.results.single.outcome.message, contains('no answer'));
    });

    test('an address that throws is a failure too', () async {
      final prober = IptvLineProber(probe: (url, headers) async => throw StateError('socket closed'));

      final report = await prober.probeChannel(channel('c', ['http://broke']));

      expect(report.results.single.outcome.ok, isFalse);
      expect(report.results.single.outcome.message, contains('socket closed'));
    });

    test('a probe that measured no latency still gets a timing', () async {
      final prober = IptvLineProber(probe: (url, headers) async => const IptvProbeOutcome(ok: true));

      final report = await prober.probeChannel(channel('c', ['http://a']));

      expect(report.results.single.outcome.latency, isNotNull);
    });

    test('a channel with no address at all reports down rather than hanging', () async {
      final prober = IptvLineProber(probe: (url, headers) async => const IptvProbeOutcome(ok: true));
      final blank = IptvChannel.of(
        id: 'blank',
        entry: IptvEntry.of(name: 'blank', url: '  '),
      );

      final report = await prober.probeChannel(blank);

      expect(report.results, isEmpty);
      expect(report.isDown, isTrue);
    });

    test('no more than the agreed number of addresses are in flight', () async {
      var inFlight = 0;
      var peak = 0;
      final prober = IptvLineProber(
        concurrency: 2,
        stopOnFirstOk: false,
        probe: (url, headers) async {
          inFlight++;
          peak = inFlight > peak ? inFlight : peak;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inFlight--;
          return const IptvProbeOutcome.down('none');
        },
      );

      await prober.probeChannel(channel('c', [for (var i = 0; i < 6; i++) 'http://a/$i']));

      expect(peak, lessThanOrEqualTo(2));
    });

    test('the report keeps the playlist order even when the answers do not', () async {
      final prober = IptvLineProber(
        concurrency: 3,
        stopOnFirstOk: false,
        probe: (url, headers) async {
          // The last address answers first.
          if (url.endsWith('2')) {
            return const IptvProbeOutcome.answered(Duration(milliseconds: 1));
          }
          return const IptvProbeOutcome.answered(Duration(milliseconds: 20));
        },
      );

      final report = await prober.probeChannel(channel('c', ['http://a/0', 'http://a/1', 'http://a/2']));

      expect(report.results.map((result) => result.url), ['http://a/0', 'http://a/1', 'http://a/2']);
      expect(report.bestUrl, 'http://a/2');
    });
  });

  group('IptvLineProber.probeChannels', () {
    test('walks one channel after another and reports as it goes', () async {
      final prober = IptvLineProber(
        concurrency: 1,
        probe: (url, headers) async => const IptvProbeOutcome.answered(Duration(milliseconds: 10)),
      );
      final seen = <String>[];

      final reports = await prober.probeChannels([
        channel('a', ['http://a']),
        channel('b', ['http://b']),
      ], onReport: (report) => seen.add('${report.channelId}:${report.bestUrl}'));

      expect(reports.map((report) => report.channelId), ['a', 'b']);
      expect(seen, ['a:http://a', 'b:http://b']);
    });

    test('a limit stops the walk short', () async {
      final prober = IptvLineProber(concurrency: 1, probe: (url, headers) async => const IptvProbeOutcome(ok: true));

      final reports = await prober.probeChannels([
        channel('a', ['http://a']),
        channel('b', ['http://b']),
        channel('c', ['http://c']),
      ], limit: 1);

      expect(reports.map((report) => report.channelId), ['a']);
    });

    test('a cancel keeps what was already learned', () async {
      // The transport cancels the walk it belongs to, which is what an
      // interface's "stop" button does to a probe in flight.
      late final IptvLineProber prober;
      prober = IptvLineProber(
        concurrency: 1,
        probe: (url, headers) async {
          prober.cancel();
          return const IptvProbeOutcome.answered(Duration(milliseconds: 1));
        },
      );

      final reports = await prober.probeChannels([
        channel('a', ['http://a']),
        channel('b', ['http://b']),
      ]);

      expect(reports.map((report) => report.channelId), ['a']);
      expect(prober.isCancelled, isTrue);
    });
  });

  group('mergeIptvLineHealth', () {
    test('a good answer resets the failures it was carrying', () {
      final previous = health('http://a', ok: false, failures: 4);
      final report = IptvProbeReport(
        channelId: 'c',
        results: const [IptvLineResult('http://a', IptvProbeOutcome.answered(Duration(milliseconds: 30)))],
      );

      final next = mergeIptvLineHealth([report], previous: {'http://a': previous}, now: DateTime.utc(2026, 10, 12));

      expect(next['http://a']?.ok, isTrue);
      expect(next['http://a']?.failures, 0);
      expect(next['http://a']?.latency, const Duration(milliseconds: 30));
    });

    test('a failure counts up from the last one', () {
      final previous = health('http://a', ok: false, failures: 2);
      final report = IptvProbeReport(
        channelId: 'c',
        results: const [IptvLineResult('http://a', IptvProbeOutcome.down('gone'))],
      );

      final next = mergeIptvLineHealth([report], previous: {'http://a': previous}, now: DateTime.utc(2026, 10, 12));

      expect(next['http://a']?.failures, 3);
      expect(next['http://a']?.message, 'gone');
    });

    test('an address the walk never reached keeps its old verdict', () {
      final old = health('http://b', ok: true, latencyMs: 70);
      final report = IptvProbeReport(
        channelId: 'c',
        results: const [IptvLineResult('http://a', IptvProbeOutcome(ok: true))],
        aborted: true,
      );

      final next = mergeIptvLineHealth([report], previous: {'http://b': old}, now: DateTime.utc(2026, 10, 12));

      expect(next['http://b'], old);
      expect(next['http://a']?.ok, isTrue);
    });
  });
}

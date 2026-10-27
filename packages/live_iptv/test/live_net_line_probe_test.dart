import 'dart:typed_data';

import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/order/iptv_channel_ordering.dart' show compareIptvChannels;
import 'package:live_iptv/src/probe/probe.dart';
import 'package:live_net/live_net.dart';
import 'package:test/test.dart';

/// The channel a real list would carry: one `rtmp://` line the HTTP probe
/// cannot speak to, one working HLS mirror, and one dead mirror.
IptvChannel mixedChannel() => IptvChannel.of(
  id: 'cctv1',
  entry: IptvEntry.of(
    name: 'CCTV-1',
    url: 'rtmp://live.example.com/live/cctv1',
    alternatives: ['http://mirror.example.com/cctv1.m3u8', 'http://dead.example.com/cctv1.m3u8'],
  ),
);

void main() {
  group('iptvOutcomeOf', () {
    test('a playable address becomes an answered line, naming its container', () {
      final outcome = iptvOutcomeOf(
        const MediaProbeResult.answered(
          latency: Duration(milliseconds: 120),
          bytes: 4096,
          container: MediaContainer.hlsPlaylist,
          statusCode: 200,
        ),
      );

      expect(outcome.ok, isTrue);
      expect(outcome.inconclusive, isFalse);
      expect(outcome.latency, const Duration(milliseconds: 120));
      expect(outcome.bytes, 4096);
      expect(outcome.message, 'hlsPlaylist');
    });

    test('an address that answered wrongly becomes a failure with its reason', () {
      final outcome = iptvOutcomeOf(const MediaProbeResult.notMedia(statusCode: 403, message: 'answered 403'));

      expect(outcome.ok, isFalse);
      expect(outcome.inconclusive, isFalse);
      expect(outcome.message, 'answered 403');
    });

    test('an abstention stays an abstention', () {
      final outcome = iptvOutcomeOf(const MediaProbeResult.inconclusive('rtmp is not an address this probe can open'));

      expect(outcome.ok, isFalse);
      expect(outcome.inconclusive, isTrue);
    });
  });

  group('the probe over a stub transport', () {
    late IptvLineProber prober;

    setUp(() {
      prober = IptvLineProber(
        concurrency: 1,
        stopOnFirstOk: false,
        probe: iptvLineProbeFrom(MediaProbe(http: _StubHttp())),
      );
    });

    test('the working mirror is found and the rtmp line is not called dead', () async {
      final report = await prober.probeChannel(mixedChannel());

      expect(report.bestUrl, 'http://mirror.example.com/cctv1.m3u8');
      expect(report.isDown, isFalse);
      expect(report.isUnprobed, isFalse);
      expect(report.results.map((result) => result.outcome.inconclusive), [
        true,
        false,
        false,
      ], reason: 'rtmp abstains, the good mirror and the dead one both answer');
    });

    test('an abstained line outranks a failed one, and follows a live one', () async {
      final report = await prober.probeChannel(mixedChannel());
      final health = mergeIptvLineHealth([report], now: DateTime.utc(2026, 10, 12));
      final ranked = rankIptvLines(mixedChannel(), health);

      expect(ranked.map((line) => line.url), [
        'http://mirror.example.com/cctv1.m3u8', // probed, alive
        'rtmp://live.example.com/live/cctv1', // nobody knows: the probe cannot ask
        'http://dead.example.com/cctv1.m3u8', // probed, dead
      ]);
      // The abstained line has no record at all, which is what keeps it in
      // the rotation instead of being buried with the mirror that refused.
      expect(health.containsKey('rtmp://live.example.com/live/cctv1'), isFalse);
      expect(health['http://dead.example.com/cctv1.m3u8']?.failures, 1);
    });

    test('a channel of nothing but unprobeable lines is unsure, not dead', () async {
      final rtmpOnly = IptvChannel.of(
        id: 'radio',
        entry: IptvEntry.of(
          name: 'Radio',
          url: 'rtmp://live.example.com/live/radio',
          alternatives: ['rtsp://live.example.com/live/radio'],
        ),
      );

      final report = await prober.probeChannel(rtmpOnly);
      final health = mergeIptvLineHealth([report], now: DateTime.utc(2026, 10, 12));

      expect(report.isUnprobed, isTrue);
      expect(report.isDown, isFalse);
      expect(health, isEmpty);
      // With no verdict written, the playlist's own order is what the player
      // gets — which is the right answer, and not a quarantine.
      expect(rankIptvLines(rtmpOnly, health).map((line) => line.url), [
        'rtmp://live.example.com/live/radio',
        'rtsp://live.example.com/live/radio',
      ]);
    });

    test('a round of probes repeated does not double-count the failure', () {
      final first = mergeIptvLineHealth([
        IptvProbeReport(channelId: 'c', results: const [IptvLineResult('http://a', IptvProbeOutcome.down('gone'))]),
      ], now: DateTime.utc(2026, 10, 12));
      final second = mergeIptvLineHealth(
        [
          IptvProbeReport(channelId: 'c', results: const [IptvLineResult('http://a', IptvProbeOutcome.down('gone'))]),
        ],
        previous: first,
        now: DateTime.utc(2026, 10, 12, 12),
      );

      expect(first['http://a']?.failures, 1);
      expect(second['http://a']?.failures, 2);

      final revived = mergeIptvLineHealth(
        [
          IptvProbeReport(
            channelId: 'c',
            results: const [IptvLineResult('http://a', IptvProbeOutcome.answered(Duration(milliseconds: 5)))],
          ),
        ],
        previous: second,
        now: DateTime.utc(2026, 10, 12, 13),
      );

      expect(revived['http://a']?.failures, 0);
      expect(revived['http://a']?.ok, isTrue);
    });
  });

  group('the probe verdicts survive the ordering rules', () {
    test('a channel is unchanged by ranking: ranking never rewrites the entry', () {
      final channel = mixedChannel();
      final ranked = rankIptvLines(channel, const {});

      expect(ranked.length, iptvLineUrls(channel.entry).length);
      expect(compareIptvChannels(channel, channel), 0);
    });
  });
}

/// The transport the probe reads through: it knows the two http addresses of
/// [mixedChannel], one of which serves a playlist and one a web page.
final class _StubHttp implements LiveHttp {
  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    final path = request.url.toString();
    if (path.contains('mirror')) {
      return _StubResponse(Uint8List.fromList(utf8Bytes('#EXTM3U\n#EXTINF:10,\n/seg.ts\n')));
    }
    return _StubResponse(Uint8List.fromList(utf8Bytes('<html><body>404</body></html>')), contentType: 'text/html');
  }

  @override
  Future<LiveResponse> send(LiveRequest request) => throw UnimplementedError('the probe never buffers a body');

  @override
  void close() {}
}

/// One canned streamed answer.
final class _StubResponse implements LiveStreamedResponse {
  new(this._body, {String contentType = 'application/vnd.apple.mpegurl'}) : headers = {'content-type': contentType};

  final Uint8List _body;

  @override
  final Map<String, String> headers;

  @override
  int get statusCode => 200;

  @override
  Stream<Uint8List> get stream => Stream.value(_body);

  @override
  Future<void> close() async {}
}

/// [text] as bytes, so the fixtures read as the playlists they are.
List<int> utf8Bytes(String text) => text.codeUnits;

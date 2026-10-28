import 'dart:convert';

import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_room_parser.dart';
import 'package:test/test.dart';

const String _shortId = 'abc123';

LivemeRoomData _data({
  LivemeState state = LivemeState.live,
  LiveRestriction? restriction,
  List<LivemeStream>? streams,
}) => LivemeRoomData(
  shortId: _shortId,
  userId: 'u1',
  state: state,
  restriction: restriction,
  streams:
      streams ??
      [
        LivemeStream(
          qualityId: LivemeEndpoints.sourceQualityId,
          flv: ['https://linkv.fun/a.flv', 'https://linkv.fun/b.flv'],
          hls: ['https://linkv.fun/a.m3u8'],
        ),
        LivemeStream(qualityId: LivemeEndpoints.smoothQualityId, flv: ['https://linkv.fun/s.flv']),
      ],
);

void main() {
  group('streams', () {
    test('the source and smooth media are read from every field, each URL once', () {
      final streams = LivemeRoomParser.streams({
        'videosource': 'http://linkv.fun/a.flv',
        'videosourcemore': [
          'http://cdn.liveme.com/b.flv',
          'http://linkv.fun/a.flv',
          'https://x.example/c.flv',
          'https://x.example/d.mp4',
        ],
        'hlsvideosource': jsonEncode({'x': 'http://linkv.fun/a.m3u8'}),
        'smallsource': 'https://other.example/s.flv',
        'smallsourcemore': 'https://other.example/s2.flv',
      });
      expect(streams.map((stream) => stream.qualityId), [
        LivemeEndpoints.sourceQualityId,
        LivemeEndpoints.smoothQualityId,
      ]);
      expect(streams.first.flv, ['https://linkv.fun/a.flv', 'https://cdn.liveme.com/b.flv', 'https://x.example/c.flv']);
      expect(streams.first.hls, ['https://linkv.fun/a.m3u8']);
      expect(streams.last.flv, ['https://other.example/s.flv', 'https://other.example/s2.flv']);
      expect(streams.last.hls, isEmpty);
    });

    test('a quality without a usable URL is left out', () {
      expect(LivemeRoomParser.streams({'videosource': 'ftp://linkv.fun/a.flv'}), isEmpty);
    });
  });

  group('qualities and lines', () {
    test('the offered qualities are named source then smooth', () {
      final qualities = LivemeRoomParser.qualities(_data());
      expect(qualities.map((quality) => quality.qualityId), [
        LivemeEndpoints.sourceQualityId,
        LivemeEndpoints.smoothQualityId,
      ]);
      expect(qualities.map((quality) => quality.label), ['原画', '流畅']);
      expect(qualities.map((quality) => quality.platformOrder), [0, 1]);
    });

    test('a restricted, ended or media-less broadcast has no quality', () {
      for (final data in [
        _data(restriction: LiveRestriction.private),
        _data(restriction: LiveRestriction.paid),
        _data(state: LivemeState.offline),
        _data(streams: const []),
      ]) {
        expect(
          () => LivemeRoomParser.qualities(data),
          throwsA(isA<LivemeFailure>().having((failure) => failure.kind, 'kind', LivemeFailureKind.streamUnavailable)),
        );
      }
    });

    test('the lines are FLV then HLS, labelled by format, without a lease', () {
      final lines = LivemeRoomParser.lines(_data(), LivemeEndpoints.sourceQualityId);
      expect(lines.map((line) => line.url), [
        'https://linkv.fun/a.flv',
        'https://linkv.fun/b.flv',
        'https://linkv.fun/a.m3u8',
      ]);
      expect(lines.map((line) => line.lineLabel), ['flv', 'flv#2', 'hls']);
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.every((line) => line.lease == null), isTrue);
      expect(lines.first.headers.toMap(), LivemeEndpoints.mediaHeaders(_shortId));
    });

    test('a stored per-protocol id names its quality now; another quality is refused', () {
      expect(LivemeEndpoints.qualityIdFromLegacy('source-flv'), LivemeEndpoints.sourceQualityId);
      expect(LivemeEndpoints.qualityIdFromLegacy('HLS'), LivemeEndpoints.sourceQualityId);
      expect(LivemeEndpoints.qualityIdFromLegacy('smooth-flv'), LivemeEndpoints.smoothQualityId);
      expect(LivemeRoomParser.lines(_data(), 'smooth-flv').single.url, 'https://linkv.fun/s.flv');
      expect(
        () => LivemeRoomParser.lines(_data(), 'unknown'),
        throwsA(isA<LivemeFailure>().having((failure) => failure.kind, 'kind', LivemeFailureKind.streamUnavailable)),
      );
    });
  });

  group('media URLs', () {
    test('the site CDN is served over https; other hosts are kept as written', () {
      expect(LivemeRoomParser.mediaUrl('http://linkv.fun/a.flv', LiveStreamFormat.flv), 'https://linkv.fun/a.flv');
      expect(
        LivemeRoomParser.mediaUrl('http://cdn.emolm.com/a.flv', LiveStreamFormat.flv),
        'https://cdn.emolm.com/a.flv',
      );
      expect(
        LivemeRoomParser.mediaUrl('http://live.liveme.com/a.m3u8', LiveStreamFormat.hls),
        'https://live.liveme.com/a.m3u8',
      );
      expect(LivemeRoomParser.mediaUrl('http://x.example/a.flv', LiveStreamFormat.flv), 'http://x.example/a.flv');
      expect(
        LivemeRoomParser.mediaUrl('http://linkv.fun:8080/a.flv', LiveStreamFormat.flv),
        'http://linkv.fun:8080/a.flv',
      );
    });

    test('a URL of the wrong shape is refused', () {
      expect(LivemeRoomParser.mediaUrl('https://linkv.fun/a.mp4', LiveStreamFormat.flv), isNull);
      expect(LivemeRoomParser.mediaUrl('https://linkv.fun/a.flv', LiveStreamFormat.hls), isNull);
      expect(LivemeRoomParser.mediaUrl('ftp://linkv.fun/a.flv', LiveStreamFormat.flv), isNull);
      expect(LivemeRoomParser.mediaUrl('https://user@linkv.fun/a.flv', LiveStreamFormat.flv), isNull);
      expect(LivemeRoomParser.mediaUrl('https://linkv.fun/a.flv#f', LiveStreamFormat.flv), isNull);
      expect(LivemeRoomParser.mediaUrl('https://linkv.fun/a b.flv', LiveStreamFormat.flv), isNull);
      expect(LivemeRoomParser.mediaUrl('', LiveStreamFormat.flv), isNull);
    });
  });

  group('restrictions and times', () {
    test('a private or paid broadcast is marked for the room list', () {
      expect(LivemeRoomParser.restrictionOf({'ispvt': 1}), LiveRestriction.private);
      expect(LivemeRoomParser.restrictionOf({'livebptype': 7}), LiveRestriction.paid);
      expect(
        LivemeRoomParser.restrictionOf({
          'hot_label_v2': jsonEncode({'text': 'Paid Broadcast'}),
        }),
        LiveRestriction.paid,
      );
      expect(
        LivemeRoomParser.restrictionOf({
          'hot_label_v2': {'text': 'paid broadcast'},
        }),
        LiveRestriction.paid,
      );
      expect(LivemeRoomParser.restrictionOf({'hot_label_v2': 'not json'}), LiveRestriction.none);
      expect(LivemeRoomParser.restrictionOf({}), LiveRestriction.none);
      expect(LivemeRoomParser.isPaidLabel({'text': ' Free '}), isFalse);
    });

    test('the start is read from whole Unix seconds only', () {
      expect(LivemeRoomParser.startedAt(1790733600), DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true));
      expect(LivemeRoomParser.startedAt('1790733600'), isNotNull);
      expect(LivemeRoomParser.startedAt(0), isNull);
      expect(LivemeRoomParser.startedAt(-1), isNull);
      expect(LivemeRoomParser.startedAt('soon'), isNull);
      expect(LivemeRoomParser.startedAt(null), isNull);
    });
  });
}

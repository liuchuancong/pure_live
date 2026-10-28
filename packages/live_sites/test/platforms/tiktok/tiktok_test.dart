import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_endpoints.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_room_parser.dart';
import 'package:test/test.dart';

final DateTime _issuedAt = DateTime.utc(2026, 9, 27, 12);

int _epoch(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

String _card({
  String uniqueId = 'ann',
  Object? status = 4,
  Object? liveStatus = 4,
  String title = '',
  Object? userCount,
  Object? enterCount,
  Object? startTime,
  Object? secret,
  Object? paidEvent,
  Object? subscriberOnly,
  Object? followers = 100,
}) => jsonEncode({
  'statusCode': 0,
  'data': {
    'user': {
      'uniqueId': uniqueId,
      'id': '123456789012345',
      'nickname': 'Ann',
      'signature': 'sig',
      'status': status,
      'roomId': 'room1',
      'secret': ?secret,
    },
    'stats': {'followerCount': ?followers},
    'liveRoom': {
      'status': liveStatus,
      'title': title,
      'startTime': ?startTime,
      'liveRoomStats': {'userCount': ?userCount, 'enterCount': ?enterCount},
      'paidEvent': ?paidEvent,
      'liveSubOnly': ?subscriberOnly,
    },
  },
});

TiktokStream _stream(
  String qualityId,
  String codec, {
  String label = '',
  String resolution = '',
  int? bitrate,
  List<Uri> flv = const [],
  List<Uri> hls = const [],
}) => TiktokStream(
  id: '$codec:$qualityId',
  qualityId: qualityId,
  codec: codec,
  label: label,
  resolution: resolution,
  bitrate: bitrate,
  flvUrls: flv,
  hlsUrls: hls,
);

TiktokRoomData _data({List<TiktokStream>? streams}) => TiktokRoomData(
  username: 'ann',
  userId: '123',
  state: TiktokState.live,
  issuedAt: _issuedAt,
  restriction: LiveRestriction.none,
  streams: streams ?? const [],
);

void main() {
  group('rooms', () {
    test('an offline card keeps the nickname, signature and followers', () {
      final room = TiktokRoomParser.room(_card(), username: 'ann', includeMedia: false, issuedAt: _issuedAt);
      expect(room.roomId, 'ann');
      expect(room.content.title, 'Ann');
      expect(room.content.introduction, 'sig');
      expect(room.anchor!.name, 'Ann');
      expect(room.anchor!.anchorId, '123456789012345');
      expect(room.anchor!.followerCount, 100);
      expect(room.anchor!.liveStatus, LiveStatus.offline);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.restriction, isNull);
      expect(room.audience.onlineViewers, isNull);
      expect(room.runtime.streamHandle, isNull);
    });

    test('a live card carries both audience figures, the start and the platform notice', () {
      final room = TiktokRoomParser.room(
        _card(status: 2, liveStatus: 2, title: 'A show', userCount: 76, enterCount: 1200, startTime: _epoch(_issuedAt)),
        username: 'ann',
        includeMedia: true,
        issuedAt: _issuedAt,
      );
      expect(room.content.title, 'A show');
      expect(room.content.notice, TiktokEndpoints.chatNotice);
      expect(room.audience.onlineViewers, 76);
      expect(room.audience.totalViewers, 1200);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(_epoch(_issuedAt) * 1000, isUtc: true));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.runtime.streamHandle, isA<TiktokRoomData>());
    });

    test('an answer about another user, or for a missing one, is refused', () {
      expect(
        () => TiktokRoomParser.room(
          _card(uniqueId: 'bob'),
          username: 'ann',
          includeMedia: false,
          issuedAt: _issuedAt,
        ),
        throwsA(isA<TiktokFailure>()),
      );
      expect(
        () => TiktokRoomParser.room(
          jsonEncode({'statusCode': TiktokEndpoints.missingUserCode, 'message': 'user not exist'}),
          username: 'ann',
          includeMedia: false,
          issuedAt: _issuedAt,
        ),
        throwsA(isA<TiktokFailure>().having((failure) => failure.kind, 'kind', TiktokFailureKind.notFound)),
      );
    });
  });

  group('restrictions', () {
    test('a private account, subscribers-only LIVE and paid LIVE are told apart', () {
      expect(TiktokRoomParser.restrictionOf({'secret': true}, {}), LiveRestriction.private);
      expect(TiktokRoomParser.restrictionOf({'secret': false}, {'liveSubOnly': 1}), LiveRestriction.subscribersOnly);
      expect(
        TiktokRoomParser.restrictionOf({}, {
          'paidEvent': {'paid_type': 1},
        }),
        LiveRestriction.paid,
      );
      expect(TiktokRoomParser.restrictionOf({}, {'paidEvent': <Object?>[]}), LiveRestriction.none);
      expect(TiktokRoomParser.restrictionOf({}, {'paidEvent': null}), LiveRestriction.none);
      expect(() => TiktokRoomParser.restrictionOf({'secret': 'yes'}, {}), throwsA(isA<TiktokFailure>()));
    });
  });

  group('qualities', () {
    final streams = [
      _stream('hd', 'h264', resolution: '720x1280'),
      _stream('uhd', 'h265', resolution: '1080x1920'),
      _stream('origin', 'h264'),
      _stream('origin', 'h265'),
    ];

    test('H.264 comes first by default, and every quality is one tier in one codec', () {
      final qualities = TiktokRoomParser.qualities(_data(streams: streams));
      expect(qualities.map((quality) => quality.qualityId), ['h264:origin', 'h264:hd', 'h265:origin', 'h265:uhd']);
      expect(qualities.map((quality) => quality.label), [
        TiktokEndpoints.originName,
        '720p',
        '${TiktokEndpoints.originName}${TiktokEndpoints.h265Suffix}',
        '1080p${TiktokEndpoints.h265Suffix}',
      ]);
      expect(qualities.map((quality) => quality.codec), [
        LiveStreamCodec.avc,
        LiveStreamCodec.avc,
        LiveStreamCodec.hevc,
        LiveStreamCodec.hevc,
      ]);
    });

    test('without the H.264 preference the best tier wins across codecs', () {
      final qualities = TiktokRoomParser.qualities(_data(streams: streams), preferH264: false);
      expect(qualities.map((quality) => quality.qualityId), ['h264:origin', 'h265:origin', 'h265:uhd', 'h264:hd']);
      expect(qualities.first.platformOrder, greaterThan(qualities.last.platformOrder));
    });

    test('a quality name falls back to the label, the resolution, the table and the key', () {
      expect(TiktokRoomParser.qualityName(_stream('hd', 'h264', label: '720p HD')), '720p HD');
      expect(TiktokRoomParser.qualityName(_stream('hd_60', 'h264', resolution: '720p')), '720p60');
      expect(TiktokRoomParser.qualityName(_stream('sd', 'h264', resolution: '480x854')), '480p');
      expect(TiktokRoomParser.qualityName(_stream('auto', 'h264')), TiktokEndpoints.qualityNames['auto']);
      expect(TiktokRoomParser.qualityName(_stream('weird', 'h264')), 'WEIRD');
    });

    test('a stored per-protocol id becomes the current quality id', () {
      expect(TiktokRoomParser.qualityIdFromLegacy('h264:origin:flv'), 'h264:origin');
      expect(TiktokRoomParser.qualityIdFromLegacy(' H265:HD_60:HLS '), 'h265:hd_60');
      expect(TiktokRoomParser.qualityIdFromLegacy(' h264:hd '), 'h264:hd');
    });
  });

  group('lines and leases', () {
    final expiry = _epoch(_issuedAt.add(const Duration(days: 14)));
    final streams = [
      _stream(
        'hd',
        'h264',
        resolution: '720x1280',
        bitrate: 1200000,
        flv: [
          Uri.parse('https://cdn.example/a.flv?expire=$expiry'),
          Uri.parse('https://cdn.example/b.flv?expire=$expiry'),
        ],
        hls: [Uri.parse('https://cdn.example/a.m3u8?expire=$expiry')],
      ),
    ];

    test('a quality gives its FLV then HLS lines, with codec, geometry and lease', () {
      final lines = TiktokRoomParser.lines(
        _data(streams: streams),
        LivePlayQuality.of(label: '720p', qualityId: 'h264:hd', platformOrder: 6100),
      );
      expect(lines.map((line) => line.lineLabel), ['flv', 'flv#2', 'hls']);
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.flv, LiveStreamFormat.hls]);
      expect(lines.every((line) => line.codec == LiveStreamCodec.avc), isTrue);
      expect(lines.every((line) => line.formatSource == LivePlayFormatSource.declared), isTrue);
      expect(lines.first.geometry.width, 720);
      expect(lines.first.geometry.height, 1280);
      expect(lines.first.geometry.bitrateKbps, 1200);
      expect(lines.first.lease?.expiresAt, DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true));
      expect(lines.first.lease?.refreshAt, lines.first.lease!.expiresAt!.subtract(TiktokEndpoints.leaseLead));
      expect(lines.first.lease?.requiresReconnect, isFalse);
      expect(lines.last.lease?.requiresReconnect, isTrue);

      final defaulted = TiktokRoomParser.lines(_data(streams: streams), null);
      expect(defaulted.first.url, 'https://cdn.example/a.flv?expire=$expiry');
    });

    test('a quality the LIVE does not offer, and a LIVE that cannot play, are refused', () {
      expect(
        () => TiktokRoomParser.lines(
          _data(streams: streams),
          LivePlayQuality.of(label: 'x', qualityId: 'h264:uhd', platformOrder: 1),
        ),
        throwsA(isA<TiktokFailure>()),
      );
      final offline = TiktokRoomData(username: 'ann', userId: '123', state: TiktokState.offline, issuedAt: _issuedAt);
      expect(() => TiktokRoomParser.lines(offline, null), throwsA(isA<TiktokFailure>()));
      final private = TiktokRoomData(
        username: 'ann',
        userId: '123',
        state: TiktokState.live,
        issuedAt: _issuedAt,
        restriction: LiveRestriction.private,
      );
      expect(() => TiktokRoomParser.lines(private, null), throwsA(isA<TiktokFailure>()));
    });

    test('a fourteen-day URL is renewed an hour early; a short one by a quarter', () {
      final long = TiktokRoomParser.lease(Uri.parse('https://cdn.example/a.flv?expire=$expiry'), _issuedAt)!;
      expect(long.expiresAt, DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true));
      expect(long.refreshAt, long.expiresAt!.subtract(TiktokEndpoints.leaseLead));

      final shortExpiry = _epoch(_issuedAt.add(const Duration(hours: 2)));
      final short = TiktokRoomParser.lease(Uri.parse('https://cdn.example/a.flv?expire=$shortExpiry'), _issuedAt)!;
      expect(short.refreshAt, short.expiresAt!.subtract(const Duration(minutes: 30)));

      expect(TiktokRoomParser.lease(Uri.parse('https://cdn.example/a.flv'), _issuedAt), isNull);
      expect(TiktokRoomParser.lease(Uri.parse('https://cdn.example/a.flv?expire=0'), _issuedAt), isNull);
    });

    test('an expired URL is no lease unless the caller allows it', () {
      final past = _epoch(_issuedAt.subtract(const Duration(hours: 1)));
      final url = Uri.parse('https://cdn.example/a.m3u8?expire=$past');
      expect(TiktokRoomParser.lease(url, _issuedAt), isNull);
      final lease = TiktokRoomParser.lease(url, _issuedAt, allowExpired: true)!;
      expect(lease.expiresAt, DateTime.fromMillisecondsSinceEpoch(past * 1000, isUtc: true));
      expect(lease.refreshAt, lease.expiresAt!.subtract(TiktokEndpoints.leaseLead));
      expect(lease.requiresReconnect, isTrue);
    });
  });

  group('helpers', () {
    test('the LIVE room owner is read from a room info answer', () {
      final owner = TiktokRoomParser.owner(
        jsonEncode({
          'status_code': 0,
          'data': {
            'id': '123456789012345',
            'owner': {'display_id': 'ann'},
          },
        }),
        liveRoomId: '123456789012345',
      );
      expect(owner, 'ann');
      expect(
        () => TiktokRoomParser.owner(jsonEncode({'status_code': 1, 'data': <String, Object?>{}}), liveRoomId: 'room1'),
        throwsA(isA<TiktokFailure>()),
      );
    });

    test('the username of a short link is read from the canonical address or the page state', () {
      expect(
        TiktokRoomParser.usernameInPage('<meta property="og:url" content="https://www.tiktok.com/@ann/live">'),
        'ann',
      );
      expect(TiktokRoomParser.usernameInPage('<script>"uniqueId":"ann"</script>'), 'ann');
      expect(TiktokRoomParser.usernameInPage('<html></html>'), isNull);
    });
  });
}

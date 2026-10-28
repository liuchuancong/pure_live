import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/inke/api/inke_endpoints.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_room_parser.dart';
import 'package:test/test.dart';

const String _uid = '555';
const String _liveId = '987';
final DateTime _receivedAt = DateTime.utc(2026, 9, 27, 12);
final String _started = '${_receivedAt.millisecondsSinceEpoch ~/ 1000}';

const String _pull = 'https://live-pull-ws.ikstatic.cn/live/987_t.flv?sign=abc';
const String _origin = 'http://live-pull-zego.ikstatic.cn/inkemain/987_0_en.flv?codecInfo=8192';

Map<String, Object?> _info({Object? status = 1, String liveName = 'Show', String nick = 'Ann'}) => {
  'live_uid': _uid,
  'status': status,
  'liveid': _liveId,
  'live_name': liveName,
  'portrait': 'https://img.inke.cn/cover.jpg',
  'media_info': {'nick': nick, 'inke_id': _uid, 'portrait': 'https://img.inke.cn/avatar.jpg'},
};

String _detail({Object? errorCode = 0, Map<String, Object?>? data}) =>
    jsonEncode({'error_code': errorCode, 'data': data ?? _info()});

String _nowPublish({Object? creator = _uid, Object? status = 1, Object? stream = _pull, Object? origin = _origin}) =>
    jsonEncode({
      'dm_error': 0,
      'live': {
        'id': _liveId,
        'creator': creator,
        'status': status,
        'name': 'App Show',
        'cover': 'https://img.inke.cn/app.jpg',
        'stream_addr': ?stream,
        'stream_multi_addr': ?origin,
        'start_time': _started,
        'numbers': {'real': 76},
        'online_users': 12000,
      },
    });

void main() {
  group('rooms', () {
    test('a live detail is a room with the website card and the broadcast link', () {
      final room = InkeRoomParser.detail(_detail(), uid: _uid);
      expect(room.roomId, _uid);
      expect(room.content.title, 'Show');
      expect(room.content.coverUrl, 'https://img.inke.cn/cover.jpg');
      expect(room.anchor!.anchorId, _uid);
      expect(room.anchor!.name, 'Ann');
      expect(room.anchor!.liveStatus, LiveStatus.live);
      expect(room.links.webUrl, contains(_liveId));
      expect((room.runtime.streamHandle! as InkeRoomData).liveId, _liveId);
    });

    test('the platform saying nobody is live gives an offline room', () {
      final room = InkeRoomParser.detail(jsonEncode({'error_code': InkeEndpoints.noLiveCode}), uid: _uid);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.content.title, '');
      expect(room.links.webUrl, contains(_uid));
    });

    test('another anchor or a broken envelope is api-changed', () {
      expect(() => InkeRoomParser.detail(_detail(data: _info(status: 2)), uid: _uid), throwsA(isA<InkeFailure>()));
      expect(
        () => InkeRoomParser.detail(jsonEncode({'data': <String, Object?>{}}), uid: _uid),
        throwsA(isA<InkeFailure>().having((failure) => failure.kind, 'kind', InkeFailureKind.apiChanged)),
      );
      expect(() => InkeRoomParser.detail(_detail(), uid: '556'), throwsA(isA<InkeFailure>()));
    });
  });

  group('app broadcasts', () {
    test('a live broadcast carries its lines, title, cover, numbers and start', () {
      final broadcast = InkeRoomParser.broadcast(_nowPublish(), uid: _uid)!;
      expect(broadcast.liveId, _liveId);
      expect(broadcast.pullUrl, _pull);
      expect(broadcast.originUrl, _origin);
      expect(broadcast.title, 'App Show');
      expect(broadcast.cover, 'https://img.inke.cn/app.jpg');
      expect(broadcast.online, 76);
      expect(broadcast.heat, 12000);
      expect(broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(int.parse(_started) * 1000, isUtc: true));
      expect(broadcast.hasLine, isTrue);
    });

    test('an ended broadcast or no broadcast at all is null', () {
      expect(InkeRoomParser.broadcast(_nowPublish(status: 2), uid: _uid), isNull);
      expect(InkeRoomParser.broadcast(jsonEncode({'dm_error': 0, 'live': null}), uid: _uid), isNull);
    });

    test('another anchor or a refused answer is api-changed', () {
      expect(() => InkeRoomParser.broadcast(_nowPublish(creator: '999'), uid: _uid), throwsA(isA<InkeFailure>()));
      expect(() => InkeRoomParser.broadcast(jsonEncode({'dm_error': 3}), uid: _uid), throwsA(isA<InkeFailure>()));
      expect(() => InkeRoomParser.broadcast('{}', uid: _uid), throwsA(isA<InkeFailure>()));
    });

    test('a room entry keeps the app card and its stream handle', () {
      final room = InkeRoomParser.detail(_detail(), uid: _uid);
      final broadcast = InkeRoomParser.broadcast(_nowPublish(), uid: _uid)!;
      final data = InkeRoomData(liveId: _liveId, broadcast: broadcast, receivedAt: _receivedAt);
      final withApp = InkeRoomParser.withBroadcast(room, broadcast, receivedAt: _receivedAt, data: data);
      expect(withApp.content.title, 'App Show');
      expect(withApp.content.coverUrl, 'https://img.inke.cn/app.jpg');
      expect(withApp.audience.onlineViewers, 76);
      expect(withApp.audience.popularity, 12000);
      expect(withApp.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(withApp.broadcast.restriction, LiveRestriction.none);
      expect(withApp.broadcast.liveStatus, LiveStatus.live);
      expect(withApp.runtime.streamHandle, same(data));

      const noLine = InkeBroadcast(liveId: _liveId);
      final withoutLine = InkeRoomParser.withBroadcast(room, noLine, receivedAt: _receivedAt, data: data);
      expect(withoutLine.broadcast.restriction, isNull);
      expect(withoutLine.content.title, 'Show');
    });
  });

  group('qualities', () {
    const both = InkeRoomData(
      liveId: _liveId,
      broadcast: InkeBroadcast(liveId: _liveId, pullUrl: _pull, originUrl: _origin),
    );

    test('H.264 FLV comes first unless the preference is off', () {
      final preferred = InkeRoomParser.qualities(both, preferH264: true);
      expect(preferred.map((quality) => quality.qualityId), [
        InkeEndpoints.flvQualityId,
        InkeEndpoints.originQualityId,
      ]);
      expect(preferred.map((quality) => quality.codec), [LiveStreamCodec.avc, LiveStreamCodec.hevc]);
      expect(preferred.map((quality) => quality.label), [
        InkeEndpoints.flvQualityLabel,
        InkeEndpoints.originQualityLabel,
      ]);

      final original = InkeRoomParser.qualities(both, preferH264: false);
      expect(original.map((quality) => quality.qualityId), [InkeEndpoints.originQualityId, InkeEndpoints.flvQualityId]);
    });

    test('without an original line only the FLV quality is offered', () {
      const flvOnly = InkeRoomData(
        liveId: _liveId,
        broadcast: InkeBroadcast(liveId: _liveId, pullUrl: _pull),
      );
      expect(InkeRoomParser.qualities(flvOnly, preferH264: false).single.qualityId, InkeEndpoints.flvQualityId);
    });

    test('a room the platform called offline has no quality', () {
      expect(
        () => InkeRoomParser.qualities(const InkeRoomData(liveId: null), preferH264: true),
        throwsA(isA<InkeFailure>().having((failure) => failure.kind, 'kind', InkeFailureKind.streamUnavailable)),
      );
    });

    test("a pull URL must be the platform's host and path for this broadcast", () {
      expect(InkeRoomParser.plainFlv(_pull, liveId: _liveId), _pull);
      expect(InkeRoomParser.plainFlv('http://live-pull-ws.ikstatic.cn/live/987_t.flv', liveId: _liveId), isNotNull);
      expect(InkeRoomParser.plainFlv('https://live-pull-ws.ikstatic.cn/live/988_t.flv', liveId: _liveId), isNull);
      expect(InkeRoomParser.plainFlv('https://evil.example/live/987_t.flv', liveId: _liveId), isNull);
      expect(InkeRoomParser.plainFlv('https://live-pull-ws.ikstatic.cn:444/live/987_t.flv', liveId: _liveId), isNull);
      expect(InkeRoomParser.plainFlv('https://user@live-pull-ws.ikstatic.cn/live/987_t.flv', liveId: _liveId), isNull);
      expect(InkeRoomParser.plainFlv('$_pull#f', liveId: _liveId), isNull);
      expect(InkeRoomParser.plainFlv(_origin, liveId: _liveId), isNull);

      expect(InkeRoomParser.zegoFlv(_origin, liveId: _liveId), _origin);
      expect(InkeRoomParser.zegoFlv(_pull, liveId: _liveId), isNull);
      expect(
        InkeRoomParser.zegoFlv('https://live-pull-zego.ikstatic.cn/inkemain/988_0_en.flv', liveId: _liveId),
        isNull,
      );
    });
  });
}

import 'dart:convert';

import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_room_parser.dart';
import 'package:test/test.dart';

const String _roomId = '123';

String _address(String host, {bool hls = false}) => 'https://$host/live/$_roomId.${hls ? 'm3u8' : 'flv'}';

Map<String, Object?> _row(String host, {String quality = 'HD', String label = '原画', bool hls = false}) => {
  'master_url': _address(host, hls: hls),
  'quality_type': quality,
  'quality_type_name': label,
};

String _config({List<Object?> h264 = const [], List<Object?> h265 = const []}) =>
    jsonEncode({'h264': h264, 'h265': h265});

String _page({
  String roomId = _roomId,
  Object? status = 2,
  String liveStatus = 'success',
  Object? monetize = 0,
  Object? limits = const [0],
  Object? pullConfig,
  String viewers = '',
  String pageStatus = 'success',
  String title = 'A room',
  String nick = 'Ann',
}) {
  final info = {
    'roomId': roomId,
    'status': status,
    'monetizeType': ?monetize,
    'joinLimitTypes': ?limits,
    'roomTitle': title,
    'roomCover': 'https://img.xhscdn.com/c.jpg',
    'pullConfig': ?pullConfig,
    'displayViewerCount': viewers,
  };
  final state = {
    'liveStream': {
      'pageStatus': pageStatus,
      'liveStatus': liveStatus,
      'roomData': {
        'roomInfo': info,
        'hostInfo': {'nickName': nick, 'avatar': ''},
      },
    },
  };
  return '<script>window.__INITIAL_STATE__=${jsonEncode(state)}</script>';
}

String _publicConfig() => _config(h264: [_row('live-source-play.xhscdn.com')]);

XiaohongshuPage _read(String body, {String requestedId = _roomId, int status = 200}) =>
    XiaohongshuRoomParser.room(body, requestedId: requestedId, status: status);

void main() {
  group('rooms', () {
    test('a live public page is a room with the room-scope and display-count notice', () {
      final page = _read(_page(pullConfig: _publicConfig(), viewers: '300万+'));
      final room = page.room;
      expect(room.roomId, _roomId);
      expect(room.content.title, 'A room');
      expect(room.content.coverUrl, 'https://img.xhscdn.com/c.jpg');
      expect(room.anchor!.name, 'Ann');
      expect(room.anchor!.liveStatus, LiveStatus.live);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.audience.onlineViewers, isNull);
      expect(
        room.content.notice,
        [XiaohongshuRoomParser.roomScopeNotice, XiaohongshuRoomParser.displayViewersNotice('300万+')].join('\n'),
      );
      expect(page.data.restriction, LiveRestriction.none);
      expect(page.data.pullConfig, isNotNull);
    });

    test('a public room without a pull address cannot be played', () {
      final page = _read(_page(pullConfig: _config()));
      expect(page.room.broadcast.restriction, LiveRestriction.unplayable);
      expect(() => XiaohongshuRoomParser.playable(page.data), throwsA(isA<XiaohongshuFailure>()));
    });

    test('a paid or limited room says so, and keeps no pull config', () {
      final paid = _read(_page(monetize: 1, pullConfig: _publicConfig()));
      expect(paid.data.restriction, LiveRestriction.paid);
      expect(paid.room.broadcast.restriction, LiveRestriction.paid);
      expect(paid.data.pullConfig, isNull);
      expect(paid.room.content.notice, contains(XiaohongshuRoomParser.restrictedNotice));
      expect(() => XiaohongshuRoomParser.playable(paid.data), throwsA(isA<XiaohongshuFailure>()));

      final chat = _read(_page(limits: const [1]));
      expect(chat.data.restriction, LiveRestriction.private);
      final fence = _read(_page(limits: '[4]'));
      expect(fence.data.restriction, LiveRestriction.regionBlocked);
      expect(
        () => XiaohongshuRoomParser.playable(fence.data),
        throwsA(
          isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', XiaohongshuFailureKind.regionBlocked),
        ),
      );
      final other = _read(_page(limits: const [8]));
      expect(other.data.restriction, LiveRestriction.unplayable);
    });

    test('an ended room is offline and without a broadcast restriction', () {
      final page = _read(_page(status: 3, liveStatus: 'end'));
      expect(page.data.live, isFalse);
      expect(page.room.anchor!.liveStatus, LiveStatus.offline);
      expect(page.room.broadcast.restriction, isNull);
      expect(page.data.pullConfig, isNull);
      expect(page.room.content.notice, XiaohongshuRoomParser.roomScopeNotice);
      expect(() => XiaohongshuRoomParser.playable(page.data), throwsA(isA<XiaohongshuFailure>()));
    });

    test('a room whose access the page does not tell says so and needs an account', () {
      final page = _read(_page(monetize: null, limits: null));
      expect(page.data.access, XiaohongshuAccess.unknown);
      expect(page.room.broadcast.restriction, isNull);
      expect(page.room.content.notice, contains(XiaohongshuRoomParser.unknownAccessNotice));
      expect(
        () => XiaohongshuRoomParser.playable(page.data),
        throwsA(isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', XiaohongshuFailureKind.needsLogin)),
      );
    });

    test('a missing room, another room and a contradicting state are refused', () {
      expect(
        () => _read(_page(pageStatus: 'error')),
        throwsA(isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', XiaohongshuFailureKind.notFound)),
      );
      expect(
        () => _read(_page(), status: 404),
        throwsA(isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', XiaohongshuFailureKind.notFound)),
      );
      expect(() => _read(_page(roomId: '999')), throwsA(isA<XiaohongshuFailure>()));
      expect(() => _read(_page(liveStatus: 'end')), throwsA(isA<XiaohongshuFailure>()));
      expect(() => _read(_page(), requestedId: 'not-a-room'), throwsA(isA<ArgumentError>()));
    });

    test('the room a page names is read out of it when a live one is there', () {
      expect(XiaohongshuRoomParser.roomIdInPage(_page()), _roomId);
      expect(XiaohongshuRoomParser.roomIdInPage(_page(status: 3, liveStatus: 'end')), _roomId);
      expect(XiaohongshuRoomParser.roomIdInPage('<html></html>'), isNull);
    });
  });

  group('streams', () {
    final config = _config(
      h264: [
        _row('live-source-play.xhscdn.com'),
        _row('live-play.xhscdn.com', hls: true),
        _row('live-sd.xhscdn.com', quality: 'SD', label: '标清'),
      ],
      h265: [_row('live-hevc.xhscdn.com')],
    );

    test('a quality is one per type across codecs, in address order', () {
      final page = _read(_page(pullConfig: config));
      final qualities = XiaohongshuRoomParser.qualities(XiaohongshuRoomParser.playable(page.data));
      expect(qualities.map((quality) => quality.qualityId), ['HD', 'SD']);
      expect(qualities.map((quality) => quality.label), ['原画', '标清']);
    });

    test('the lines are H.264 before H.265 and FLV before HLS, without a lease', () {
      final page = _read(_page(pullConfig: config));
      final lines = XiaohongshuRoomParser.lines(page.data, null);
      expect(lines.map((line) => line.url), [
        'https://live-source-play.xhscdn.com/live/$_roomId.flv',
        'https://live-play.xhscdn.com/live/$_roomId.m3u8',
        'https://live-hevc.xhscdn.com/live/$_roomId.flv',
      ]);
      expect(lines.map((line) => line.lineLabel), ['flv:live-source-play', 'hls:live-play', 'flv:live-hevc:hevc']);
      expect(lines.map((line) => line.format), [LiveStreamFormat.flv, LiveStreamFormat.hls, LiveStreamFormat.flv]);
      expect(lines.map((line) => line.codec), [LiveStreamCodec.avc, LiveStreamCodec.avc, LiveStreamCodec.hevc]);
      expect(lines.first.headers.toMap(), XiaohongshuEndpoints.headers);
      expect(lines.every((line) => line.lease == null), isTrue);

      final sd = XiaohongshuRoomParser.lines(page.data, LivePlayQuality.of(label: '标清', qualityId: 'h264:SD'));
      expect(sd.single.url, 'https://live-sd.xhscdn.com/live/$_roomId.flv');
      expect(
        () => XiaohongshuRoomParser.lines(page.data, LivePlayQuality.of(label: 'x', qualityId: 'UHD')),
        throwsA(isA<XiaohongshuFailure>()),
      );
      expect(XiaohongshuEndpoints.qualityIdFromLegacy('h264:HD'), 'HD');
      expect(XiaohongshuEndpoints.qualityIdFromLegacy('H265:UHD'), 'UHD');
      expect(XiaohongshuEndpoints.qualityIdFromLegacy(' HD '), 'HD');
    });

    test('an address off the CDN or off the room path is left out', () {
      final page = _read(
        _page(
          pullConfig: _config(
            h264: [
              {'master_url': 'https://evil.example/live/$_roomId.flv', 'quality_type': 'HD', 'quality_type_name': '原画'},
              {'master_url': 'https://live.xhscdn.com/live/999.flv', 'quality_type': 'HD', 'quality_type_name': '原画'},
              {
                'master_url': 'https://live.xhscdn.com/live/$_roomId.flv',
                'quality_type': '',
                'quality_type_name': '原画',
              },
              _row('live-good.xhscdn.com', quality: 'SD', label: '标清'),
            ],
          ),
        ),
      );
      final streams = XiaohongshuRoomParser.playable(page.data);
      expect(streams.single.url, Uri.parse('https://live-good.xhscdn.com/live/$_roomId.flv'));
      final none = _read(_page(pullConfig: _config(h264: [_row('evil.example')])));
      expect(() => XiaohongshuRoomParser.playable(none.data), throwsA(isA<XiaohongshuFailure>()));
    });
  });
}

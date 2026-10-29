import 'dart:convert';

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_play_parser.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_room_parser.dart';
import 'package:test/test.dart';

final DateTime _issuedAt = DateTime.utc(2026, 9, 27, 12);

DateTime _at(int seconds) => _issuedAt.add(Duration(seconds: seconds));

Uri _flv(int expiry) => Uri.parse('https://cdn.example/live.flv?t=$expiry');

int _epoch(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

YyMobileHls _hls({String video = 'v1', int width = 640, int height = 360, String host = 'cdn.example'}) =>
    (url: Uri.parse('https://$host/live/$video.m3u8'), width: width, height: height, video: video);

void main() {
  // `page.action`, `liveInfoDetail`, the header and `getCategory` send their
  // ids as JSON numbers while the search sends strings; a number must not
  // cost the whole card.
  group('numeric ids', () {
    test('a listing card with numbered ids is a room', () {
      final body = jsonEncode({
        'resultCode': 0,
        'data': {
          'totalCount': 1,
          'data': [
            {
              'uid': 3087474217,
              'sid': 1414787838,
              'ssid': 1414787838,
              'name': '慕婉',
              'desc': '慕婉 正在直播',
              'thumb': 'https://mobilelivephoto.example/live/a.jpg',
              'users': 42015,
              'biz': 'other',
              'startTime': 1792934557,
            },
          ],
        },
      });
      final rooms = YyRoomParser.roomList(body);
      expect(rooms, hasLength(1));
      final (:room, :channel) = rooms.single;
      expect(room.ref.roomId, '1414787838');
      expect(channel.sid, '1414787838');
      expect(channel.ssid, '1414787838');
      expect(room.anchor?.anchorId, '3087474217');
      expect(room.anchor?.name, '慕婉');
      expect(room.audience.popularity, 42015);
      expect(room.content.title, '慕婉');
      expect(room.content.coverUrl, 'https://mobilelivephoto.example/live/a.jpg');
    });

    test('header tabs and catalog areas read numbered ids', () {
      final tabs = YyRoomParser.categoryTabs(
        jsonEncode({
          'categoryTabs': [
            {'id': 1, 'title': '娱乐', 'navs': <Object?>[]},
          ],
        }),
      );
      expect(tabs.single, (id: '1', name: '娱乐'));

      final areas = YyRoomParser.areas(
        jsonEncode({
          'result': '0',
          'data': [
            {'id': 7, 'title': '音乐', 'url': 'http://www.yy.com/music/'},
          ],
        }),
        categoryId: '1',
        categoryName: '娱乐',
      );
      expect(areas.single.area.areaId, '7');
      expect(areas.single.area.areaName, '音乐');
    });

    test('a live detail with numbered ids keeps its anchor and audience', () {
      final body = jsonEncode({
        'resultCode': 0,
        'data': {
          'uid': 3087474217,
          'sid': 1414787838,
          'ssid': 1414787838,
          'desc': '慕婉',
          'name': '慕婉',
          'users': 42130,
          'biz': 'other',
          'startTime': 1792934557,
        },
      });
      final detail = YyRoomParser.liveDetail(body, requestedId: '1414787838')!;
      expect(detail.channel.sid, '1414787838');
      expect(detail.room.anchor?.anchorId, '3087474217');
      expect(detail.room.audience.popularity, 42130);
    });
  });

  group('FLV lease', () {
    test('a ten-minute URL is renewed a minute before t', () {
      final lease = YyPlayParser.lease(_flv(_epoch(_at(600))), _issuedAt)!;
      expect(lease.expiresAt, _at(600));
      expect(lease.refreshAt, _at(540));
      expect(lease.requiresReconnect, isFalse);
    });

    test('a short lifetime leads by a quarter of it', () {
      final lease = YyPlayParser.lease(_flv(_epoch(_at(120))), _issuedAt)!;
      expect(lease.expiresAt, _at(120));
      expect(lease.refreshAt, _at(90));
    });

    test('mobile HLS and unsigned URLs carry no lease', () {
      expect(YyPlayParser.lease(Uri.parse('https://cdn.example/live.m3u8?t=${_epoch(_at(600))}'), _issuedAt), isNull);
      expect(YyPlayParser.lease(Uri.parse('https://cdn.example/live.flv'), _issuedAt), isNull);
      expect(YyPlayParser.lease(_flv(999999999), _issuedAt), isNull);
    });

    test('an expired URL is no lease unless the caller allows it', () {
      final url = _flv(_epoch(_at(-10)));
      expect(YyPlayParser.lease(url, _issuedAt), isNull);
      final lease = YyPlayParser.lease(url, _issuedAt, allowExpired: true)!;
      expect(lease.expiresAt, _at(-10));
      expect(lease.refreshAt, _at(-70));
    });
  });

  group('stream-manager', () {
    Map<String, dynamic> streams(Object? answer) => jsonDecode(jsonEncode(answer)) as Map<String, dynamic>;

    Map<String, dynamic> stream(String key, String gear, String name, int rate) => {
      'stream_key': key,
      'json': jsonEncode({
        'gear_info': {'gear': gear, 'name': name},
        'rate': rate,
      }),
    };

    test('qualities are one per gear, best rate first, duplicate names disambiguated', () {
      final answer = streams({
        'channel_stream_info': {
          'streams': [
            stream('k1', '1', '标清', 1200),
            stream('k2', '2', '高清', 4000),
            stream('k3', '2', '超清', 5000),
            stream('k4', '3', '高清', 3000),
            {
              'json': jsonEncode({
                'gear_info': {'gear': '4', 'name': '蓝光'},
                'rate': 9000,
              }),
            },
          ],
        },
      });
      final qualities = YyPlayParser.qualities(answer);
      expect(qualities.map((quality) => quality.qualityId), ['2', '3', '1']);
      expect(qualities.map((quality) => quality.label), ['高清 · 2', '高清 · 3', '标清']);
      expect(qualities.first.platformOrder, 4000);
    });

    test('resolution reads every address, absolute over https, labelled and leased', () {
      final expiry = _epoch(_at(600));
      final answer = streams({
        'channel_stream_info': {
          'streams': [stream('k1', '1', '高清', 4000)],
        },
        'avp_info_res': {
          'stream_line_addr': {
            'k1': {
              'cdn_info': {'url': 'https://a.example/live.flv?t=$expiry'},
              'line_seq': '1',
            },
            'k2': {
              'cdn_info': {'url': '//b.example/live.flv?t=$expiry'},
              'line_seq': '',
            },
            'k3': {
              'cdn_info': {'url': 'https://a.example/live.flv?t=$expiry'},
              'line_seq': 3,
            },
          },
        },
      });
      final (:lines, :appliedGear) = YyPlayParser.resolution(answer, issuedAt: _issuedAt);
      expect(appliedGear, '1');
      expect(lines.map((line) => line.url), [
        'https://a.example/live.flv?t=$expiry',
        'https://b.example/live.flv?t=$expiry',
      ]);
      expect(lines.map((line) => line.lineLabel), ['1', 'b.example']);
      expect(lines.every((line) => line.format == LiveStreamFormat.flv), isTrue);
      expect(lines.every((line) => line.formatSource == LivePlayFormatSource.inferred), isTrue);
      expect(lines.first.lease?.expiresAt, _at(600));
      expect(lines.first.headers['origin'], YyEndpoints.origin);
      expect(lines.first.headers.containsKey('cookie'), isFalse);
    });

    test('otherLines lists the unserved lines of the served stream', () {
      final answer = streams({
        'avp_info_res': {
          'stream_line_addr': {
            'k1': {
              'cdn_info': {'url': 'https://a.example/live.flv'},
              'line_seq': 1,
            },
          },
          'stream_line_list': {
            'k1': {
              'line_infos': [
                {'line_seq': 1},
                {'line_seq': 2},
                {'line_seq': 2},
                {'line_seq': 3},
              ],
            },
          },
        },
      });
      expect(YyPlayParser.otherLines(answer), [2, 3]);
    });

    test('withLines backs one gear with the lines of the other answers', () {
      LivePlayLine line(String url) =>
          LivePlayLine.of(url: url, format: LiveStreamFormat.flv, formatSource: LivePlayFormatSource.inferred);
      final first = (lines: [line('https://a.example/live.flv')], appliedGear: '1');
      final merged = YyPlayParser.withLines(first, [
        (lines: [line('https://b.example/live.flv')], appliedGear: '1'),
        (lines: [line('https://c.example/live.flv')], appliedGear: '2'),
        (lines: [line('https://a.example/live.flv')], appliedGear: '1'),
      ]);
      expect(merged.map((line) => line.url), ['https://a.example/live.flv', 'https://b.example/live.flv']);
      expect(
        YyPlayParser.withLines(
          (lines: [line('https://a.example/live.flv')], appliedGear: null),
          [
            (lines: [line('https://b.example/live.flv')], appliedGear: '1'),
          ],
        ).length,
        1,
      );
    });
  });

  group('mobile HLS', () {
    test('an answer gives the playlist, the geometry and the stream', () {
      final answer = YyPlayParser.mobileHls(
        'cb({"code":0,"hls":"https://cdn.example/live.m3u8","width":1280,"height":720,"video":"v1"})',
      )!;
      expect(answer.url, Uri.parse('https://cdn.example/live.m3u8'));
      expect(answer.width, 1280);
      expect(answer.height, 720);
      expect(answer.video, 'v1');
    });

    test('a refused or non-http answer means the channel has none', () {
      expect(YyPlayParser.mobileHls('({"code":1})'), isNull);
      expect(YyPlayParser.mobileHls('({"code":0,"hls":"rtmp://cdn.example/live"})'), isNull);
      expect(() => YyPlayParser.mobileHls('ok'), throwsA(isA<YyFailure>()));
    });

    test('qualities name the tiers by rate, and a shared stream keeps the higher rate', () {
      final qualities = YyPlayParser.mobileQualities([
        (rate: '1200', hls: _hls()),
        (rate: '4000', hls: _hls(video: 'v2', host: 'hd.example')),
        (rate: '4000', hls: null),
      ]);
      expect(qualities.map((quality) => quality.qualityId), ['mobile-hls:4000', 'mobile-hls:1200']);
      expect(qualities.map((quality) => quality.label), ['高清 · 360p', '流畅 · 360p']);

      final shared = YyPlayParser.mobileQualities([
        (rate: '1200', hls: _hls()),
        (rate: '4000', hls: _hls(width: 1280, height: 720)),
      ]);
      expect(shared.length, 1);
      expect(shared.single.qualityId, 'mobile-hls:4000');
      expect(shared.single.label, '高清 · 720p');
    });

    test('the mobile line is HLS with its geometry and media headers', () {
      final line = YyPlayParser.mobileLine(_hls(width: 1280, height: 720), cookie: 'u=1');
      expect(line.format, LiveStreamFormat.hls);
      expect(line.formatSource, LivePlayFormatSource.declared);
      expect(line.lineLabel, 'cdn.example');
      expect(line.geometry.width, 1280);
      expect(line.geometry.height, 720);
      expect(line.headers['origin'], YyEndpoints.origin);
      expect(line.headers['cookie'], 'u=1');
      expect(line.lease, isNull);
    });
  });
}

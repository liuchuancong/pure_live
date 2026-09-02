import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/douyu/douyu_site.dart';
import 'package:pure_live/model/live_play_quality.dart';

void main() {
  test('Douyu room state accepts numeric strings without misclassifying a live room', () {
    expect(
      DouyuSite.isLiveRoomPayload(<String, dynamic>{'show_status': '1', 'videoLoop': '0', 'room_name': '直播中'}),
      isTrue,
    );
    expect(
      DouyuSite.isLiveRoomPayload(<String, dynamic>{'show_status': 1, 'videoLoop': 1, 'room_name': '【回放】上一场'}),
      isFalse,
    );
  });

  group('Douyu H5 playback response', () {
    test('accepts numeric/string success and preserves playback data', () {
      final data = DouyuSite.parsePlayResponse(<String, dynamic>{
        'error': '0',
        'data': <String, dynamic>{'rtmp_url': 'https://example.test/live'},
      });

      expect(data['rtmp_url'], 'https://example.test/live');
    });

    test('reports API errors and incomplete payloads', () {
      expect(
        () => DouyuSite.parsePlayResponse(<String, dynamic>{'error': 102, 'msg': 'expired'}),
        throwsA(isA<DouyuPlayApiException>()),
      );
      expect(() => DouyuSite.parsePlayResponse(<String, dynamic>{'error': 0}), throwsA(isA<DouyuPlayApiException>()));
    });

    test('deduplicates CDN codes and always provides a fallback line', () {
      expect(
        DouyuSite.parseCdnCodes(<String, dynamic>{
          'rtmp_cdn': 'ws-h5',
          'cdnsWithName': <Map<String, String>>[
            {'cdn': 'ws-h5'},
            {'cdn': 'tct-h5'},
            {'cdn': 'tct-h5'},
          ],
        }),
        <String>['ws-h5', 'tct-h5'],
      );
      expect(DouyuSite.parseCdnCodes(<String, dynamic>{}), <String>['']);
    });

    test('builds and unescapes the actual FLV URL', () {
      final url = DouyuSite.parsePlayUrl(<String, dynamic>{
        'rtmp_url': 'https://cdn.example.test/live/',
        'rtmp_live': '/stream.flv?wsAuth=a&amp;token=b',
      });

      expect(url, 'https://cdn.example.test/live/stream.flv?wsAuth=a&token=b');
      expect(
        () => DouyuSite.parsePlayUrl(<String, dynamic>{'rtmp_live': 'relative.flv'}),
        throwsA(isA<DouyuPlayApiException>()),
      );
    });

    test('keeps an absolute signed rtmp_live URL instead of prefixing a CDN base', () {
      final url = DouyuSite.parsePlayUrl(<String, dynamic>{
        'rtmp_url': 'https://cdn.example.test/live',
        'flv_url': 'https://backup.example.test/live',
        'rtmp_live': 'https://signed.example.test/room.flv?wsAuth=a&amp;token=b',
      });

      expect(url, 'https://signed.example.test/room.flv?wsAuth=a&token=b');
    });

    test('never mistakes a bare flv CDN base for the media input', () {
      expect(
        DouyuSite.parsePlayUrl(<String, dynamic>{
          'flv_url': 'https://cdn.example.test/live',
          'rtmp_live': 'room_123.flv?wsAuth=signed',
        }),
        'https://cdn.example.test/live/room_123.flv?wsAuth=signed',
      );
      expect(
        () => DouyuSite.parsePlayUrl(<String, dynamic>{'flv_url': 'https://cdn.example.test/live'}),
        throwsA(isA<DouyuPlayApiException>()),
      );
      expect(
        DouyuSite.parsePlayUrl(<String, dynamic>{'flv_url': 'https://cdn.example.test/live/room.flv'}),
        'https://cdn.example.test/live/room.flv',
      );
    });

    test('keeps API quality order because rate is an opaque request code', () {
      final qualities = DouyuSite.parsePlayQualities(
        <String, dynamic>{
          'multirates': <Map<String, dynamic>>[
            {'name': '蓝光8M', 'rate': 0},
            {'name': '蓝光4M', 'rate': 1},
            {'name': '流畅', 'rate': 3},
            {'name': '重复流畅', 'rate': 3},
          ],
        },
        const <String>['main', 'backup'],
      );

      expect(qualities.map((quality) => quality.quality), ['蓝光8M', '蓝光4M', '流畅']);
      expect(qualities.map((quality) => quality.selectionId), [0, 1, 3]);
      expect((qualities.first.data as DouyuPlayData).cdns, ['main', 'backup']);
    });

    test('recording cursor signs only the requested CDN line', () async {
      final site = _FakeDouyuCursorSite();
      final quality = LivePlayQuality(quality: '原画', id: 0, data: DouyuPlayData(0, const <String>['main', 'backup']));

      final resolved = await site.resolvePlayUrlAtRaw(
        detail: LiveRoom(roomId: '123'),
        quality: quality,
        lineIndex: 1,
      );
      final beyond = await site.resolvePlayUrlAtRaw(
        detail: LiveRoom(roomId: '123'),
        quality: quality,
        lineIndex: 2,
      );

      expect(resolved.urls, <String>['https://backup.example/123-0.flv']);
      expect(site.calls, <String>['backup']);
      expect(beyond.urls, isEmpty);
    });
  });
}

class _FakeDouyuCursorSite extends DouyuSite {
  final List<String> calls = <String>[];

  @override
  Future<String> getPlayUrl(String roomId, int rate, String cdn) async {
    calls.add(cdn);
    return 'https://$cdn.example/$roomId-$rate.flv';
  }
}

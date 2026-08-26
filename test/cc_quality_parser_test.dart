import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/cc/cc_site.dart';

void main() {
  test('CC keeps semantic quality order when source bitrate is missing', () async {
    final qualities = await CCSite().getPlayQualites(
      detail: LiveRoom(
        link: 'https://pull.test/live.m3u8?token=a',
        data: {
          'blueray': {
            'vbr': 0,
            'CDN_FMT': {'hs': 'cdn=source'},
          },
          'high': {
            'vbr': 2500,
            'CDN_FMT': {'hs': 'cdn=high'},
          },
          'low': {
            'vbr': 600,
            'CDN_FMT': {'hs': 'cdn=low'},
          },
        },
      ),
    );

    expect(qualities.map((quality) => quality.quality), ['原画', '高清', '低清']);
    expect(qualities.map((quality) => quality.selectionId), ['blueray', 'high', 'low']);
    expect(qualities.first.data, ['https://pull.test/live.m3u8?token=a&cdn=source']);
  });

  test('CC live CDN suffix uses a valid query delimiter or direct URL', () async {
    final qualities = await CCSite().getPlayQualites(
      detail: LiveRoom(
        link: 'https://pull.test/live.m3u8',
        data: {
          'high': {
            'vbr': 2500,
            'CDN_FMT': {
              'hs': '&cdn=preferred',
              'other': 'https://backup.test/live.flv?quality=high',
              'relative': '//backup-2.test/live.flv?quality=high',
              'invalid': 'javascript:alert(1)',
            },
          },
        },
      ),
    );

    expect(qualities.single.data, [
      'https://pull.test/live.m3u8?cdn=preferred',
      'https://backup.test/live.flv?quality=high',
      'https://backup-2.test/live.flv?quality=high',
    ]);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';

void main() {
  group('Douyin quality parsing', () {
    test('joins legacy pull URL maps by sdk key rather than JSON position', () {
      final qualities = DouyinSite.parseStreamQualities({
        'live_core_sdk_data': {
          'pull_data': {
            'stream_data': '',
            'options': {
              'qualities': [
                {'name': '高清', 'sdk_key': 'HD1', 'v_bit_rate': 2000000},
                {'name': '流畅', 'sdk_key': 'SD2', 'v_bit_rate': 500000},
              ],
            },
          },
        },
        // Deliberately reverse insertion order. Positional pairing used to
        // attach these URLs to the opposite quality.
        'flv_pull_url': {'SD2': 'https://cdn.test/sd2.flv', 'HD1': 'https://cdn.test/hd1.flv'},
        'hls_pull_url_map': {'HD1': 'https://cdn.test/hd1.m3u8', 'SD2': 'https://cdn.test/sd2.m3u8'},
      });

      expect(qualities.map((quality) => quality.quality), ['高清', '流畅']);
      expect(qualities.first.selectionId, 'hd1');
      expect(qualities.first.data, ['https://cdn.test/hd1.flv', 'https://cdn.test/hd1.m3u8']);
      expect(qualities.last.data, ['https://cdn.test/sd2.flv', 'https://cdn.test/sd2.m3u8']);
    });

    test('parses modern stream_data and excludes advertised choices without URLs', () {
      final streamData = jsonEncode({
        'data': {
          'origin': {
            'main': {'flv': 'https://cdn.test/source.flv'},
          },
          'hd': {
            'main': {'flv': 'https://cdn.test/hd.flv', 'hls': 'https://cdn.test/hd.m3u8'},
          },
        },
      });
      final qualities = DouyinSite.parseStreamQualities({
        'live_core_sdk_data': {
          'pull_data': {
            'stream_data': streamData,
            'options': {
              'qualities': [
                {'name': '原画', 'sdk_key': 'origin'},
                {'name': '高清', 'sdk_key': 'HD'},
                {'name': '失效项', 'sdk_key': 'missing'},
              ],
            },
          },
        },
      });

      expect(qualities.map((quality) => quality.quality), ['原画', '高清']);
      expect(qualities.map((quality) => quality.selectionId), ['origin', 'hd']);
    });
  });
}

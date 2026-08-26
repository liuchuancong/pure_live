import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/live_stream_geometry_hint.dart';

void main() {
  group('Douyin live-stream geometry hints', () {
    test('ignores top-level placeholders and dual-screen selector flags', () {
      final hint = LiveStreamGeometryHintResolver.resolveDouyin({
        'extra': {'width': 1080, 'height': 1920},
        'stream_orientation': 2,
      });

      expect(hint, isNull);
    });

    test('joins the selected URL to its sdk geometry instead of the default quality', () {
      final hint = LiveStreamGeometryHintResolver.resolveDouyin({
        'live_core_sdk_data': {
          'pull_data': {
            'options': {
              'default_quality': {'sdk_key': 'landscape'},
              'qualities': [
                {'sdk_key': 'landscape', 'resolution': '1920x1080'},
                {'sdk_key': 'portrait', 'resolution': '720x1280'},
              ],
            },
            'stream_data': jsonEncode({
              'data': {
                'landscape': {
                  'main': {
                    'flv': 'https://cdn.example/live.flv?quality=landscape',
                    'sdk_params': jsonEncode({'resolution': '1920x1080'}),
                  },
                },
                'portrait': {
                  'main': {
                    'flv': 'https://cdn.example/live.flv?quality=portrait',
                    'sdk_params': jsonEncode({'resolution': '720x1280'}),
                  },
                },
              },
            }),
          },
        },
      }, selectedUrl: 'https://cdn.example/live.flv?quality=portrait&codec=h264');

      expect(hint, isNotNull);
      expect(hint!.aspectRatio, closeTo(9 / 16, 0.001));
      expect(hint.source, 'douyin.selected_sdk_params');
    });

    test('uses the default quality resolution when extra is absent', () {
      final hint = LiveStreamGeometryHintResolver.resolveDouyin({
        'live_core_sdk_data': {
          'pull_data': {
            'options': {
              'default_quality': {'sdk_key': 'HD1'},
              'qualities': [
                {'sdk_key': 'SD2', 'resolution': '360x640'},
                {'sdk_key': 'HD1', 'resolution': '720x1280'},
              ],
            },
          },
        },
      });

      expect(hint, isNotNull);
      expect(hint!.width, 720);
      expect(hint.height, 1280);
      expect(hint.source, 'douyin.default_quality');
    });

    test('uses resolution declared directly by the selected default quality', () {
      final hint = LiveStreamGeometryHintResolver.resolveDouyin({
        'live_core_sdk_data': {
          'pull_data': {
            'options': {
              'default_quality': {'sdk_key': 'origin', 'resolution': '1080x1920'},
            },
          },
        },
        'flv_pull_url': {'origin': 'https://cdn.example/origin.flv'},
      }, selectedUrl: 'https://cdn.example/origin.flv');

      expect(hint, isNotNull);
      expect(hint!.aspectRatio, closeTo(9 / 16, 0.001));
      expect(hint.source, 'douyin.selected_default_quality');
    });

    test('does not borrow default geometry for an unmatched selected URL', () {
      final hint = LiveStreamGeometryHintResolver.resolveDouyin({
        'live_core_sdk_data': {
          'pull_data': {
            'options': {
              'default_quality': {'sdk_key': 'landscape', 'resolution': '1920x1080'},
              'qualities': [
                {'sdk_key': 'landscape', 'resolution': '1920x1080'},
              ],
            },
          },
        },
        'flv_pull_url': {'landscape': 'https://cdn.example/landscape.flv'},
      }, selectedUrl: 'https://alternate.example/portrait.flv');

      expect(hint, isNull);
    });

    test('reads resolution from nested stream sdk_params', () {
      final hint = LiveStreamGeometryHintResolver.resolveDouyin({
        'default_resolution': 'origin',
        'live_core_sdk_data': {
          'pull_data': {
            'stream_data': jsonEncode({
              'data': {
                'origin': {
                  'main': {
                    'sdk_params': jsonEncode({'VCodec': 'h264', 'resolution': '1080x1920'}),
                  },
                },
              },
            }),
          },
        },
      });

      expect(hint, isNotNull);
      expect(hint!.aspectRatio, closeTo(9 / 16, 0.001));
      expect(hint.source, 'douyin.default_sdk_params');
    });

    test('rejects malformed and implausibly narrow metadata', () {
      expect(
        LiveStreamGeometryHintResolver.resolveDouyin({
          'extra': {'width': 360, 'height': 1920},
        }),
        isNull,
      );
    });

    test('does not guess when quality resolutions disagree on orientation', () {
      final hint = LiveStreamGeometryHintResolver.resolveDouyin({
        'live_core_sdk_data': {
          'pull_data': {
            'options': {
              'qualities': [
                {'sdk_key': 'portrait', 'resolution': '720x1280'},
                {'sdk_key': 'landscape', 'resolution': '1280x720'},
              ],
            },
          },
        },
      });

      expect(hint, isNull);
    });
  });
}

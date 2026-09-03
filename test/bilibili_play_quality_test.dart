import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';

void main() {
  group('Bilibili play quality acknowledgement', () {
    test('builds choices from codec accept_qn instead of the global descriptor list', () {
      final qualities = BiliBiliSite.parsePlayQualities(_playResponse(currentQn: 250));

      expect(qualities.map((quality) => quality.data), [10000, 400, 250]);
      expect(qualities.map((quality) => quality.quality), ['原画', '蓝光', '超清']);
    });

    test('returns the actual server qn and prioritizes direct FLV lines', () {
      final result = BiliBiliSite.parsePlayUrlResolution(
        _playResponse(currentQn: 250),
        requestedQualityData: 10000,
      );

      expect(
        result.appliedQualityData,
        250,
        reason: 'an anonymous downgrade must not leave the UI on 原画',
      );
      expect(result.urls, [
        'https://direct.example/live_250.flv?qn=250',
        'https://mcdn.example/live_250.flv?qn=250',
        'https://hls.example/live_250.m3u8?qn=250',
      ]);
    });
  });
}

Map<String, dynamic> _playResponse({required int currentQn}) => {
  'code': 0,
  'message': 'OK',
  'data': {
    'playurl_info': {
      'playurl': {
        'g_qn_desc': [
          {'qn': 20000, 'desc': '4K'},
          {'qn': 10000, 'desc': '原画'},
          {'qn': 400, 'desc': '蓝光'},
          {'qn': 250, 'desc': '超清'},
          {'qn': 80, 'desc': '流畅'},
        ],
        'stream': [
          {
            'protocol_name': 'http_hls',
            'format': [
              {
                'format_name': 'ts',
                'codec': [
                  {
                    'codec_name': 'avc',
                    'current_qn': currentQn,
                    'accept_qn': [10000, 400, 250],
                    'base_url': '/live_250.m3u8',
                    'url_info': [
                      {'host': 'https://hls.example', 'extra': '?qn=250'},
                    ],
                  },
                ],
              },
            ],
          },
          {
            'protocol_name': 'http_stream',
            'format': [
              {
                'format_name': 'flv',
                'codec': [
                  {
                    'codec_name': 'avc',
                    'current_qn': currentQn,
                    'accept_qn': [10000, 400, 250],
                    'base_url': '/live_250.flv',
                    'url_info': [
                      {'host': 'https://mcdn.example', 'extra': '?qn=250'},
                      {'host': 'https://direct.example', 'extra': '?qn=250'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    },
  },
};

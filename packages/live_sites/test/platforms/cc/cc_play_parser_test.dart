import 'dart:convert';

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_play_parser.dart';
import 'package:test/test.dart';

// Fixture bodies encoded from E:\study\Pure_live\fixtures\cc (S06-play-*).

/// The S06-play-default answer: the source tier on hs with ali as backup.
Map<String, Object?> _playDefault() => {
  'show_vbr': 1,
  'vbrname_sel': 'original',
  'vbrname_list': ['original', 'ultra', 'high', 'standard'],
  'vbrname_mapping': {'high': '高清', 'ultra': '超清', 'original': '原画', 'standard': '标清'},
  'cdn_list': ['hs', 'ali'],
  'cdn_sel': 'hs',
  'bakcdn_sel': 'ali',
  'videourl': 'https://hsrelayhdl.cc.netease.com/pushstation/544d36afcaffd8355a34260267129.flv?volcSecret=2fbee5f30fe4ef25a568ec15692f6fae&src=webcc_h5&relaySecret=1790526620-ye-xcqlal-92q1340mdm8jv05v6l67l9v719q554d3&auth_key=1790526920-92mb4lki2c467e149eh4g36817086r5e-7-wh9n1b561979258utt9n55e8k95g274n&_t=b011c62f533d2b04&volcTime=1793118620',
  'bakvideourl': 'https://alirtspull.cc.netease.com/pushstationsave/544d36afcaffd8355a34260267129.flv?src=webcc_h5&_t=b011c62f533d2b04&auth_key=1790526920-0yi68apt4959345t34w6o1357932g5o6-5-4s18gq36zr3q5m05507929b6me84m627&quic_versions=46%2C43%2C39',
};

/// The S06-play-high answer: the 超清-tier transcode on ali only.
Map<String, Object?> _playHigh() => {
  'show_vbr': 1,
  'vbrname_sel': 'high',
  'vbrname_list': ['original', 'ultra', 'high', 'standard'],
  'vbrname_mapping': {'high': '高清', 'ultra': '超清', 'original': '原画', 'standard': '标清'},
  'cdn_list': ['ali'],
  'cdn_sel': 'ali',
  'bakcdn_sel': 'ali',
  'videourl': 'https://alirelayhdl.cc.netease.com/pushstation/544d36afcaffd8355a34260267129tc2.flv?src=webcc_h5&_t=53456caae904277d&auth_key=1790526930-c2399732910k7ey88q0yw67j194879fx-3-047o29312955b3151ss6m3z564g83079',
  'bakvideourl': 'https://alirelayhdl.cc.netease.com/pushstation/544d36afcaffd8355a34260267129tc2.flv?src=webcc_h5&_t=53456caae904277d&auth_key=1790526930-c2399732910k7ey88q0yw67j194879fx-3-047o29312955b3151ss6m3z564g83079',
};

/// The S06-play-replay tiers.
Map<String, Object?> _playReplay() => {
  'show_vbr': 1,
  'vbrname_sel': 'original',
  'vbrname_list': ['original', 'blueray_5M_avc', 'blueray_3M_avc_lowfps', 'ultra', 'high', 'standard', 'standard'],
  'vbrname_mapping': {
    'blueray_5M_avc': '蓝光5M',
    'blueray_3M_avc_lowfps': '蓝光3M',
    'standard': '标清',
    'high': '高清',
    'ultra': '超清',
    'original': '原画',
  },
};

CcFailure _failure(Object Function() read) {
  try {
    read();
  } on CcFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

final DateTime _issuedAt = DateTime.parse('2026-09-27T16:33:06.000Z');

/// The S05-channel-live tier list with its redirect playlist.
CcRoomData _channelData() => const CcRoomData(
  streams: {
    'original': {
      'vbr': 7999,
      'CDN_FMT': {'ali': 'auth_key=1790612944-key', 'fws': 'wsSecret=7c76c698&wsTime=6ab94450'},
      'streamname': '544d36afcaffd8355a34260267129',
    },
    'high': {
      'vbr': 2000,
      'CDN_FMT': {'fws': 'wsSecret=x'},
      'streamname': 'tc1',
    },
    'low': {
      'vbr': 600,
      'CDN_FMT': {'fws': 'wsSecret=z'},
      'streamname': 'tc4',
    },
  },
  playlist: 'http://cgi.v.cc.163.com/redirect/video/341438909.m3u8?secret=bac6536f08',
);

void main() {
  group('playData (S06-play-offline)', () {
    test('HTTP 410 (no live) and 404 are stream-unavailable', () {
      expect(
        _failure(() => CcPlayParser.playData('{"code":"Gone"}', status: 410)).kind,
        CcFailureKind.streamUnavailable,
      );
      expect(_failure(() => CcPlayParser.playData('', status: 404)).kind, CcFailureKind.streamUnavailable);
    });

    test('other non-2xx are gated, a non-object is api-changed', () {
      expect(_failure(() => CcPlayParser.playData('', status: 429)).kind, CcFailureKind.rateLimited);
      expect(_failure(() => CcPlayParser.playData('', status: 503)).kind, CcFailureKind.network);
      expect(_failure(() => CcPlayParser.playData('[1]')).kind, CcFailureKind.apiChanged);
      expect(_failure(() => CcPlayParser.playData('not json')).kind, CcFailureKind.apiChanged);
      expect(CcPlayParser.playData(jsonEncode(_playDefault())), _playDefault());
    });
  });

  group('qualities (9-1)', () {
    test('the tiers of vbrname_list in the server order, best first', () {
      final qualities = CcPlayParser.qualities(_playDefault());
      expect(qualities.map((quality) => quality.qualityId), ['original', 'ultra', 'high', 'standard']);
      expect(qualities.map((quality) => quality.label), ['原画', '超清', '高清', '标清']);
      expect(qualities.map((quality) => quality.platformOrder), [4, 3, 2, 1]);
    });

    test('the replay tiers name their mapping; repeated codes are listed once', () {
      final qualities = CcPlayParser.qualities(_playReplay());
      expect(qualities.map((quality) => quality.qualityId).toList(), [
        'original',
        'blueray_5M_avc',
        'blueray_3M_avc_lowfps',
        'ultra',
        'high',
        'standard',
      ]);
      expect(qualities[0].label, '原画');
      expect(qualities[1].label, '蓝光5M');
      expect(qualities[2].label, '蓝光3M');
      expect(qualities.last.platformOrder, 1);
    });

    test('an empty list falls back to vbrname_sel; neither is api-changed', () {
      final qualities = CcPlayParser.qualities({'vbrname_sel': 'standard'});
      expect(qualities.single.qualityId, 'standard');
      expect(qualities.single.label, '标清');
      expect(_failure(() => CcPlayParser.qualities({'show_vbr': 1})).kind, CcFailureKind.apiChanged);
    });

    test('a code unknown to the mapping and the site table falls through to the shared naming', () {
      final qualities = CcPlayParser.qualities({'vbrname_sel': 'blueray'});
      // The shared label table knows blueray; the id stays the tier code.
      expect(qualities.single.qualityId, 'blueray');
      expect(qualities.single.label, isNot('blueray'));
    });
  });

  group('uncoveredCdns', () {
    test('the CDNs the answer does not already cover', () {
      expect(CcPlayParser.uncoveredCdns(_playDefault()), isEmpty);
      expect(CcPlayParser.uncoveredCdns(_playHigh()), isEmpty);
    });

    test('a CDN left out of the lines is asked for once more', () {
      final data = _playDefault()
        ..['cdn_list'] = ['hs', 'ali', 'ks']
        ..remove('bakvideourl');
      expect(CcPlayParser.uncoveredCdns(data), ['ali', 'ks']);
    });

    test('a repeated cdn_list entry is asked for once', () {
      final data = _playDefault()
        ..['cdn_list'] = ['ks', 'ks']
        ..remove('bakvideourl');
      expect(CcPlayParser.uncoveredCdns(data), ['ks']);
    });
  });

  group('lines', () {
    test('one line per CDN of the answers, the other-tier answer dropped', () {
      final first = (data: _playDefault(), issuedAt: _issuedAt);
      // The per-CDN request for ali answers ali again (the server's habit):
      // no invented hs line, and no second ali line.
      final aliAgain = (data: _playHigh(), issuedAt: _issuedAt);
      final lines = CcPlayParser.lines([first, aliAgain], roomId: '341438909');
      expect(lines, hasLength(2));
      expect(lines[0].lineLabel, 'hs');
      expect(lines[1].lineLabel, 'ali');
      for (final line in lines) {
        expect(line.format, LiveStreamFormat.flv);
        expect(line.formatSource, LivePlayFormatSource.inferred);
        expect(line.headers['origin'], 'https://cc.163.com');
        expect(line.headers['referer'], 'https://cc.163.com/341438909/');
        expect(line.lease, isNotNull);
      }
    });

    test('the lease comes from the auth_key of the URL', () {
      final lines = CcPlayParser.lines([(data: _playDefault(), issuedAt: _issuedAt)], roomId: '341438909');
      // auth_key 1790526920 → 2026-09-27T16:35:20Z, 134 s after issue: a
      // quarter of 134 s (33.5 s) is below the 60 s lead.
      final lease = lines[0].lease!;
      expect(lease.expiresAt, DateTime.parse('2026-09-27T16:35:20.000Z'));
      expect(lease.refreshAt, DateTime.parse('2026-09-27T16:34:46.500Z'));
    });

    test('a long-lived key renews a minute before expiry', () {
      const url = 'https://hs.cc.netease.com/live.flv?auth_key=1790615324-rand-0-digest';
      final data = {'vbrname_sel': 'original', 'videourl': url, 'cdn_sel': 'hs'};
      final lines = CcPlayParser.lines([
        (data: data, issuedAt: DateTime.parse('2026-09-28T17:03:44.000Z')),
      ], roomId: 'x');
      final lease = lines.single.lease!;
      expect(lease.expiresAt, DateTime.parse('2026-09-28T17:08:44.000Z'));
      expect(lease.refreshAt, DateTime.parse('2026-09-28T17:07:44.000Z'));
    });

    test('no URLs at all is api-changed; an m3u8 line is HLS', () {
      expect(_failure(() => CcPlayParser.lines([], roomId: 'x')).kind, CcFailureKind.apiChanged);
      final data = {'vbrname_sel': 'original', 'cdn_sel': 'hs'};
      expect(
        _failure(() => CcPlayParser.lines([(data: data, issuedAt: _issuedAt)], roomId: 'x')).kind,
        CcFailureKind.apiChanged,
      );
      final hls = {
        'vbrname_sel': 'original',
        'videourl': 'https://hs.cc.netease.com/live/playlist.m3u8?auth_key=1790615324-x',
        'cdn_sel': 'hs',
      };
      final lines = CcPlayParser.lines([(data: hls, issuedAt: _issuedAt)], roomId: 'x');
      expect(lines.single.format, LiveStreamFormat.hls);
    });
  });

  group('ccAuthKeyLease', () {
    test('no key, a dead key or an already-past one is no lease', () {
      expect(ccAuthKeyLease(Uri.parse('https://x.cc.netease.com/live.flv'), _issuedAt), isNull);
      expect(ccAuthKeyLease(Uri.parse('https://x.cc.netease.com/live.flv?auth_key=abc-def'), _issuedAt), isNull);
      expect(ccAuthKeyLease(Uri.parse('https://x.cc.netease.com/live.flv?auth_key=1000-x'), _issuedAt), isNull);
    });
  });

  group('legacyQualities (3.x fallback)', () {
    test('one quality per tier, 3.x names, best first', () {
      final qualities = CcPlayParser.legacyQualities(_channelData());
      expect(qualities.map((quality) => quality.qualityId), ['original', 'high', 'low']);
      expect(qualities.map((quality) => quality.label), ['原画', '高清', '低清']);
    });

    test('the live tiers play the signed redirect playlist, preferred CDNs first', () {
      final urls = CcPlayParser.legacyUrls(_channelData(), 'original');
      expect(urls, hasLength(2));
      expect(urls[0], startsWith('http://cgi.v.cc.163.com/redirect/video/341438909.m3u8?secret=bac6536f08&auth_key='));
      // ali (preferred) before fws.
      expect(urls[0], contains('auth_key=1790612944-key'));
      expect(urls[1], contains('wsSecret=7c76c698'));
      expect(CcPlayParser.legacyUrls(_channelData(), 'high'), hasLength(1));
    });

    test('the lines of a legacy tier carry media headers and their format, no lease', () {
      final lines = CcPlayParser.legacyLines(_channelData(), 'original', roomId: '341438909');
      expect(lines, hasLength(2));
      expect(lines[0].format, LiveStreamFormat.hls);
      expect(lines[0].lease, isNull);
      expect(lines[0].headers['referer'], 'https://cc.163.com/341438909/');
      expect(lines[0].formatSource, LivePlayFormatSource.inferred);
    });

    test('a tier without CDN tiers or URLs is skipped; no streams at all is none', () {
      expect(CcPlayParser.legacyQualities(_channelData()), hasLength(3));
      expect(CcPlayParser.legacyQualities(const CcRoomData()), isEmpty);
      expect(CcPlayParser.legacyLines(_channelData(), 'missing', roomId: 'x'), isEmpty);
    });

    test('a quickplay object (the resolution tiers) plays its own URLs', () {
      const data = CcRoomData(
        streams: {
          'resolution': {
            'original': {
              'vbr': 3000,
              'cdn': {'ks': 'https://ksplay.cc.netease.com/direct.flv'},
            },
            'high': {
              'vbr': 1000,
              'cdn': {'wy': '//wycdn.cc.netease.com/direct.flv'},
            },
          },
        },
      );
      final qualities = CcPlayParser.legacyQualities(data);
      expect(qualities.map((quality) => quality.qualityId), ['original', 'high']);
      final urls = CcPlayParser.legacyUrls(data, 'high');
      expect(urls, ['https://wycdn.cc.netease.com/direct.flv']);
      final lines = CcPlayParser.legacyLines(data, 'high', roomId: 'x');
      expect(lines.single.format, LiveStreamFormat.flv);
    });
  });
}

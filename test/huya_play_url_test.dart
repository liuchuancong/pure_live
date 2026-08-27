import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';
import 'package:pure_live/model/live_play_quality.dart';

void main() {
  test('Huya treats only explicit inactive states as authoritative offline', () {
    expect(HuyaSite.isExplicitOfflineState('OFF'), isTrue);
    expect(HuyaSite.isExplicitOfflineState(' offline '), isTrue);
    expect(HuyaSite.isExplicitOfflineState('CLOSED'), isTrue);
    expect(HuyaSite.isExplicitOfflineState('ON'), isFalse);
    expect(HuyaSite.isExplicitOfflineState(null), isFalse);
  });

  HuyaLineModel line(
    HuyaLineType type,
    String base, {
    String flvAntiCode = 'wsSecret=flv-token&wsTime=6a87f351',
    String hlsAntiCode = 'wsSecret=hls-token&wsTime=6a87f351',
  }) {
    return HuyaLineModel(
      line: base,
      lineType: type,
      flvAntiCode: flvAntiCode,
      hlsAntiCode: hlsAntiCode,
      streamName: 'stream-name',
      cdnType: 'AL',
      presenterUid: 123,
    );
  }

  test('Huya FLV URL uses the FLV token and extension', () async {
    final url = await HuyaSite().getPlayUrl(line(HuyaLineType.flv, 'http://al.flv.huya.com/src'), 8000);

    expect(url, startsWith('https://al.flv.huya.com/src/stream-name.flv?'));
    expect(url, contains('wsSecret=flv-token'));
    expect(url, isNot(contains('wsSecret=hls-token')));
    expect(url, contains('&codec=264'));
    expect(url, contains('&ratio=8000'));
  });

  test('Huya HLS URL uses the HLS token and extension', () async {
    final url = await HuyaSite().getPlayUrl(line(HuyaLineType.hls, 'http://al.hls.huya.com/src'), 2000);

    expect(url, startsWith('https://al.hls.huya.com/src/stream-name.m3u8?'));
    expect(url, contains('wsSecret=hls-token'));
    expect(url, isNot(contains('wsSecret=flv-token')));
    expect(url, contains('&codec=264'));
    expect(url, contains('&ratio=2000'));
  });

  test('Huya CDN bases use HTTPS without rewriting unrelated hosts', () {
    expect(HuyaSite.secureHuyaCdnBase('http://tx.flv.huya.com/src'), 'https://tx.flv.huya.com/src');
    expect(HuyaSite.secureHuyaCdnBase('http://example.com/src'), 'http://example.com/src');
  });

  test('Huya quality selection replaces a captured ratio instead of keeping stale quality', () async {
    final url = await HuyaSite().getPlayUrl(
      line(
        HuyaLineType.hls,
        'https://al.hls.huya.com/src',
        hlsAntiCode: 'wsSecret=hls-token&wsTime=6a87f351&codec=265&ratio=4000',
      ),
      2000,
    );

    expect(RegExp(r'(^|&)codec=').allMatches(Uri.parse(url).query).length, 1);
    expect(RegExp(r'(^|&)ratio=').allMatches(Uri.parse(url).query).length, 1);
    expect(url, contains('&codec=265'));
    expect(url, contains('&ratio=2000'));
    expect(url, isNot(contains('&ratio=4000')));
  });

  test('Huya source quality removes a captured transcode ratio', () async {
    final url = await HuyaSite().getPlayUrl(
      line(
        HuyaLineType.flv,
        'https://tx.flv.huya.com/src',
        flvAntiCode: 'wsSecret=flv-token&wsTime=6a87f351&ratio=500',
      ),
      0,
    );

    expect(Uri.parse(url).queryParameters.containsKey('ratio'), isFalse);
  });

  test('Huya rebuilds single-use stream signatures with a fresh expiry and seqid', () {
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(r'prefix_$0_$1_$2_$3')));
    final site = HuyaSite();
    final firstTime = DateTime.fromMillisecondsSinceEpoch(1_800_000_000_000);
    final secondTime = firstTime.add(const Duration(milliseconds: 1));
    final captured = 'wsSecret=stale&wsTime=1&fm=$fm&ctype=huya_live&fs=bgct&t=100';

    final first = Uri.splitQueryString(site.buildAntiCode('stream-name', 123, captured, now: firstTime));
    final second = Uri.splitQueryString(site.buildAntiCode('stream-name', 123, captured, now: secondTime));

    expect(int.parse(first['wsTime']!, radix: 16), greaterThan(firstTime.millisecondsSinceEpoch ~/ 1000));
    expect(first['wsSecret'], isNot('stale'));
    expect(first['seqid'], isNot(second['seqid']));
    expect(first['wsSecret'], isNot(second['wsSecret']));
    expect(first['u'], isNotEmpty);
  });

  test('Huya exposes only server advertised bitrates and has stable selection ids', () {
    final data = HuyaUrlDataModel(
      url: '',
      uid: '',
      lines: [line(HuyaLineType.flv, 'https://tx.flv.huya.com/src')],
      bitRates: [
        HuyaBitRateModel(name: '蓝光4M', bitRate: 0),
        HuyaBitRateModel(name: '超清', bitRate: 2000),
        HuyaBitRateModel(name: '重复超清', bitRate: 2000),
        HuyaBitRateModel(name: '流畅', bitRate: 500),
      ],
      isXingxiu: false,
    );

    final qualities = HuyaSite.parsePlayQualities(data);

    expect(qualities.map((quality) => quality.quality), ['蓝光4M', '超清', '流畅']);
    expect(qualities.map((quality) => quality.selectionId), [0, 2000, 500]);
  });

  test('Huya does not invent an unsupported transcode when no rate list exists', () {
    final qualities = HuyaSite.parsePlayQualities(
      HuyaUrlDataModel(url: '', uid: '', lines: const [], bitRates: const [], isXingxiu: false),
    );

    expect(qualities, hasLength(1));
    expect(qualities.single.selectionId, 0);
  });

  test('Huya recording cursor signs only the requested line', () async {
    final site = _FakeHuyaCursorSite();
    final lines = <HuyaLineModel>[
      line(HuyaLineType.flv, 'https://first.example/live'),
      line(HuyaLineType.hls, 'https://second.example/live'),
    ];
    final quality = LivePlayQuality(quality: '原画', id: 0, data: <String, Object>{'urls': lines, 'bitRate': 0});

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

    expect(resolved.urls, <String>['https://selected.example/stream.flv']);
    expect(site.lines, <HuyaLineModel>[lines[1]]);
    expect(beyond.urls, isEmpty);
  });
}

class _FakeHuyaCursorSite extends HuyaSite {
  final List<HuyaLineModel> lines = <HuyaLineModel>[];

  @override
  Future<String> getPlayUrl(HuyaLineModel line, int bitRate) async {
    lines.add(line);
    return 'https://selected.example/stream.flv';
  }
}

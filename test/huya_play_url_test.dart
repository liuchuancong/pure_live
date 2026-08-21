import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';

void main() {
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
    final url = await HuyaSite().getPlayUrl(
      line(HuyaLineType.flv, 'http://al.flv.huya.com/src'),
      8000,
    );

    expect(url, startsWith('https://al.flv.huya.com/src/stream-name.flv?'));
    expect(url, contains('wsSecret=flv-token'));
    expect(url, isNot(contains('wsSecret=hls-token')));
    expect(url, contains('&codec=264'));
    expect(url, contains('&ratio=8000'));
  });

  test('Huya HLS URL uses the HLS token and extension', () async {
    final url = await HuyaSite().getPlayUrl(
      line(HuyaLineType.hls, 'http://al.hls.huya.com/src'),
      2000,
    );

    expect(url, startsWith('https://al.hls.huya.com/src/stream-name.m3u8?'));
    expect(url, contains('wsSecret=hls-token'));
    expect(url, isNot(contains('wsSecret=flv-token')));
    expect(url, contains('&codec=264'));
    expect(url, contains('&ratio=2000'));
  });

  test('Huya CDN bases use HTTPS without rewriting unrelated hosts', () {
    expect(
      HuyaSite.secureHuyaCdnBase('http://tx.flv.huya.com/src'),
      'https://tx.flv.huya.com/src',
    );
    expect(
      HuyaSite.secureHuyaCdnBase('http://example.com/src'),
      'http://example.com/src',
    );
  });

  test('Huya room tokens do not duplicate codec or ratio parameters', () async {
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
    expect(url, contains('&ratio=4000'));
  });
}

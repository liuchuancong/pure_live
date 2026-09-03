import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';

void main() {
  test('Douyin SDK names become Chinese without changing native labels', () {
    expect(
      LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'ORIGION', id: 'origion'),
      '原画',
    );
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'UHD', id: 'uhd'), '蓝光');
    expect(
      LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'FULL_HD1', id: 'FULL_HD1'),
      '蓝光',
    );
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'HD', id: 'hd'), '超清');
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'SD', id: 'sd'), '高清');
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'SD2', id: 'sd2'), '高清');
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'LD', id: 'ld'), '标清');
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'SD1', id: 'sd1'), '标清');
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'MD', id: 'md'), '流畅');
    expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: '蓝光', id: 'origin'), '蓝光');
  });

  test('platform source labels are localized while technical resolution stays precise', () {
    expect(
      LiveQualityLabel.normalize(platform: 'soop', rawLabel: 'original', id: 'original'),
      '原画',
    );
    expect(LiveQualityLabel.normalize(platform: 'huya', rawLabel: 'source', id: 0), '原画');
    expect(LiveQualityLabel.normalize(platform: 'iptv', rawLabel: 'default'), '默认');
    expect(
      LiveQualityLabel.normalize(platform: 'twitch', rawLabel: '1080p60 (Source)'),
      '1080P60（原画）',
    );
    expect(LiveQualityLabel.normalize(platform: 'twitch', rawLabel: '720p'), '720P');
  });

  test('Bilibili qn and resolution fallback remain deterministic', () {
    expect(LiveQualityLabel.normalize(platform: 'bilibili', rawLabel: '', id: 10000), '原画');
    expect(LiveQualityLabel.normalize(platform: 'bilibili', rawLabel: '', id: 400), '蓝光');
    expect(
      LiveQualityLabel.normalize(platform: 'unknown', rawLabel: '', resolution: '1080x1920'),
      '1080P 高清',
    );
  });
}

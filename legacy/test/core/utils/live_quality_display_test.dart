import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/utils/live_quality_label.dart';

/// 清晰度文案的两条不变量。
///
/// `LiveQualityLabel.normalize` 的答案同时是**内部标识**（`selectionId` 的回退、
/// 录制任务的已存偏好都按它比较），所以它不能跟着界面语言变；本地化只发生在
/// 展示层。于是新加一档而忘了配语言行时，症状是英文界面里冒出「超清」这种
/// 中文词——测试必须自己把「所有中文出口都有对应行」钉住，而不是抽查几个。
///
/// 站点自己给的中文（`raw` 含汉字）是另一回事：那是远端数据，原样透传。
Map<String, dynamic> _bundle(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);

/// (platform, rawLabel, id, resolution) — one row per branch of the normalizer.
const List<(String, String, Object?, String?)> _samples = <(String, String, Object?, String?)>[
  ('bilibili', '1080p', 30000, null),
  ('bilibili', '1080p', 20000, null),
  ('bilibili', '1080p', 10000, null),
  ('bilibili', '1080p', 400, null),
  ('bilibili', '1080p', 250, null),
  ('bilibili', '1080p', 150, null),
  ('bilibili', '1080p', 80, null),
  ('douyin', 'origin', null, null),
  ('douyin', 'fullhd', null, null),
  ('douyin', 'hd', null, null),
  ('douyin', 'sd', null, null),
  ('douyin', 'ld', null, null),
  ('douyin', 'md', null, null),
  ('douyin', 'auto', null, null),
  ('soop', 'master', null, null),
  ('soop', 'normal', null, null),
  ('douyu', 'source', null, null),
  ('douyu', 'superhd', null, null),
  ('douyu', 'standard', null, null),
  ('douyu', 'fluent', null, null),
  ('douyu', 'default', null, null),
  ('huya', 'unknown-token', null, null),
  ('iptv', 'default', null, null),
  ('twitch', 'source', null, null),
  ('twitch', '1080p60 source', null, null),
  ('twitch', '720p30', null, null),
  ('cc', '', null, '1920x1080'),
  ('cc', '', null, '2560x1440'),
  ('cc', '', null, '3840x2160'),
  ('yy', '', 320, null),
  ('yy', '', null, null),
];

bool _hasCjk(String value) => RegExp(r'[一-鿿]').hasMatch(value);

void main() {
  final zh = _bundle('assets/translations/zh.json');
  final en = _bundle('assets/translations/en.json');

  List<String> normalized() => [
    for (final (platform, raw, id, resolution) in _samples)
      LiveQualityLabel.normalize(platform: platform, rawLabel: raw, id: id, resolution: resolution),
  ];

  group('清晰度展示文案', () {
    test('归一化产出的中文档名都能在语言包里查到', () {
      final unmapped = <String>[
        for (final label in normalized())
          if (_hasCjk(label) &&
              !liveQualityDisplayKeys.containsKey(label) &&
              !label.startsWith(liveQualityIdPrefix) &&
              !label.contains(liveQualitySourceSuffix))
            label,
      ];

      expect(unmapped, isEmpty, reason: '英文界面会把这些档名直接画成中文');
    });

    test('映射表里的每一行在中英文都存在，且英文不含汉字', () {
      final problems = <String>[
        for (final entry in liveQualityDisplayKeys.entries)
          if (!zh.containsKey(entry.value) || (zh[entry.value] as String?)?.isEmpty == true) 'zh:${entry.value}',
        for (final entry in liveQualityDisplayKeys.entries)
          if (!en.containsKey(entry.value) || (en[entry.value] as String?)?.isEmpty == true) 'en:${entry.value}',
        for (final entry in liveQualityDisplayKeys.entries)
          if (_hasCjk(en[entry.value] as String)) 'en:${entry.value}=${en[entry.value]}',
        if (!en.containsKey(liveQualityIdKey)) 'missing $liveQualityIdKey',
        if (!en.containsKey(liveQualitySourceSuffixKey)) 'missing $liveQualitySourceSuffixKey',
      ];

      expect(problems, isEmpty);
    });

    test('内部档名不随语言变化', () {
      // 展示层本地化之后，比较用的值必须还是原来那几个字。
      expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'origin'), '原画');
      expect(LiveQualityLabel.normalize(platform: 'bilibili', rawLabel: '1080p', id: 400), '蓝光');
      expect(LiveQualityLabel.normalize(platform: 'twitch', rawLabel: '1080p60 source'), contains('1080P60'));
    });

    test('站点自带的中文原样透传', () {
      expect(LiveQualityLabel.normalize(platform: 'douyu', rawLabel: '超清 1128'), '超清 1128');
    });
  });
}

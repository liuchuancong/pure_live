import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 播放器手册的表里只剩 id 和渲染开关，文字全在语言包。
///
/// "新加一行忘了配文字"只能靠扫源码来挡：界面缺键时不会抛异常，而是把
/// `player_guide_entry_xxx_body` 原样画成一段说明文字，比空白更难发现。
/// 所以这里把 Dart 里的 id 重新解析一遍，再要求两个语言包每个派生键都有非空值。
Map<String, dynamic> _bundle(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);

const String _pagePath = 'lib/features/settings/pages/player_guide_page.dart';

void main() {
  final source = File(_pagePath).readAsStringSync();
  final zh = _bundle('assets/translations/zh.json');
  final en = _bundle('assets/translations/en.json');

  final chapters = RegExp(r"_GuideChapter\([^,]+,\s*'([a-z_]+)'").allMatches(source).map((m) => m.group(1)!).toList();
  final entries = RegExp(r"_GuideEntry\('([a-z_0-9]+)'").allMatches(source).map((m) => m.group(1)!).toList();
  final badges = RegExp(r"badge:\s*'([a-z_]+)'").allMatches(source).map((m) => m.group(1)!).toSet();
  final platforms = RegExp(r'enum _GuidePlatform \{([\s\S]*?);\n')
      .firstMatch(source)!
      .group(1)!
      .split(',')
      .map((line) => line.trim())
      .where((name) => name.isNotEmpty)
      .toList();

  test('手册表解析得到预期的章节与行', () {
    // 解析失效时后面每条断言都会空对空地通过，所以先把数量钉住。
    expect(chapters, <String>['concepts', 'presets', 'picture_sync', 'quality', 'audio', 'symptoms']);
    expect(entries, hasLength(25));
    expect(entries.toSet(), hasLength(25), reason: '行 id 必须唯一，否则两行共用一段文字');
    expect(badges, <String>{'hwdec', 'vo', 'ao'});
    expect(platforms, <String>['android', 'windows']);
  });

  test('手册每一行的标题和正文在中英文里都有', () {
    final keys = <String>[
      for (final id in chapters) 'player_guide_chapter_$id',
      for (final id in entries) ...<String>['player_guide_entry_${id}_title', 'player_guide_entry_${id}_body'],
      for (final badge in badges) 'player_guide_badge_$badge',
      for (final platform in platforms) 'player_guide_platform_$platform',
      'player_guide_manual_title',
      'player_guide_manual_hint',
    ];

    final missing = <String>[
      for (final key in keys)
        if (!zh.containsKey(key) || (zh[key] as String?)?.isEmpty == true) 'zh:$key',
      for (final key in keys)
        if (!en.containsKey(key) || (en[key] as String?)?.isEmpty == true) 'en:$key',
    ];

    expect(missing, isEmpty);
  });

  test('手册页面里不再有写死的中文文案', () {
    // 直接扫源码：任何带汉字的字符串字面量都是没搬进语言包的界面文案。
    final literals = RegExp("['\"][^'\"]*[\\u4e00-\\u9fff][^'\"]*['\"]")
        .allMatches(source)
        .map((m) => m.group(0)!)
        .toList();

    expect(literals, isEmpty, reason: '这些文案应当放在 assets/translations 里');
  });
}

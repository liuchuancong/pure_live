import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_api_catalog.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';

/// The compiled-in wallpaper tree carries no names any more, so the locale
/// bundles are the only place they can come from. A missing row does not throw:
/// the browser paints the key itself in the row title, which is how
/// `wallpaper_group_wallhaven_sci_fi` would reach a user's screen. Hence an
/// enumeration test rather than a spot check.
Map<String, dynamic> _bundle(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);

List<String> _missing(Map<String, dynamic> zh, Map<String, dynamic> en, Iterable<String> keys) => <String>[
  for (final key in keys)
    if (!zh.containsKey(key) || (zh[key] as String?)?.isEmpty == true) 'zh:$key',
  for (final key in keys)
    if (!en.containsKey(key) || (en[key] as String?)?.isEmpty == true) 'en:$key',
];

void main() {
  final zh = _bundle('assets/translations/zh.json');
  final en = _bundle('assets/translations/en.json');
  final catalog = WallpaperCatalog.builtIn();

  final List<String> nameKeys = <String>[
    for (final WallpaperSource source in catalog.sources) ...<String>[
      source.nameKey,
      for (final WallpaperGroup group in source.groups) group.nameKey,
    ],
  ];

  group('壁纸目录标签', () {
    test('每个图源和分组在两个语言包里都有名字', () {
      expect(nameKeys.length, greaterThan(30), reason: '目录没枚举到东西，测试自身失效');
      expect(_missing(zh, en, nameKeys), isEmpty);
    });

    test('分组名按图源命名，两个图源的 nature 不串台', () {
      expect(wallpaperGroupNameKey('official', 'nature'), 'wallpaper_group_official_nature');
      expect(wallpaperGroupNameKey('wallhaven', 'nature'), 'wallpaper_group_wallhaven_nature');
      expect(
        catalog.sourceById('official')!.groups.firstWhere((g) => g.id == 'nature').nameKey,
        isNot(catalog.sourceById('wallhaven')!.groups.firstWhere((g) => g.id == 'nature').nameKey),
      );
    });

    test('带连字符的 id 在键名里换成下划线', () {
      expect(wallpaperSourceNameKey(WallpaperSourceIds.solidColor), 'wallpaper_source_solid_color');
      expect(wallpaperGroupNameKey('wallhaven', 'sci-fi'), 'wallpaper_group_wallhaven_sci_fi');
      expect(wallpaperGroupNameKey('wallhaven', 'final-fantasy'), 'wallpaper_group_wallhaven_final_fantasy');
    });

    test('单图源仍然暴露那一个隐藏分组', () {
      for (final id in <String>['bing', 'deepin', 'video', 'solid-color']) {
        final source = catalog.sourceById(id)!;
        expect(source.groups, hasLength(1), reason: '$id 应当只有一个 all 分组');
        expect(source.groups.single.hidden, isTrue);
        expect(source.visibleGroups, hasLength(1), reason: '$id 的网格入口靠 visibleGroups');
      }
    });

    test('随机图源每个分组和每个源都有中英文名字', () {
      final apiKeys = <String>[
        for (final WallpaperApiGroup group in kWallpaperApiGroups) ...<String>[
          group.nameKey,
          for (final WallpaperApiSource source in group.sources) source.nameKey,
        ],
      ];

      // 7 families, 82 endpoints (alcy 的分类在目录里就展开成 11 条)。
      expect(kWallpaperApiGroups, hasLength(7));
      expect(apiKeys.length, 7 + 82);
      expect(apiKeys.toSet().length, apiKeys.length, reason: '两个图源不能共用一行名字');
      expect(_missing(zh, en, apiKeys), isEmpty);
    });

    test('随机图源按 id 派生键，分类模板各行独立', () {
      expect(wallpaperApiGroupNameKey('360'), 'wallpaper_api_group_360');
      expect(wallpaperApiSourceNameKey('bing_biturl'), 'wallpaper_api_source_bing_biturl');
      final alcy = kWallpaperApiGroups.firstWhere((group) => group.id == 'alcy');
      expect(alcy.sources.map((source) => source.nameKey).toSet(), hasLength(12));
      expect(alcy.sources.map((source) => source.url).toSet().length, alcy.sources.length);
    });
  });
}

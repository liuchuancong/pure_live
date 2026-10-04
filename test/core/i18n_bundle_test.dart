import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 语言包的两条不变量。
///
/// 缺键在界面上的表现不是报错，而是把**键名本身**画出来（"1.2count_k"、
/// "sixroom_chat_notice"），所以只有测试能挡住它。曾经 zh 有 `count_wan`、en 没有，
/// 反过来 `count_k` 也是——两边各缺一个，谁都没发现。
Map<String, dynamic> _bundle(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
}

/// 源码里以字面量形式引用的键。
///
/// 只认字面量：`i18n('site_' + id)` 这类拼出来的键扫不到，所以这是**下界**——
/// 它能保证"写死的键都在包里"，不能反过来证明"包里的键都被用到"（死键要靠
/// 人工核，间接引用太多，例如站点各自的 `directoryNoticeKey`）。
Set<String> _literalKeysInLib() {
  final pattern = RegExp(r'''i18n(?:Or)?\(\s*['"]([A-Za-z0-9_]+)['"]''');
  final keys = <String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final match in pattern.allMatches(entity.readAsStringSync())) {
      keys.add(match.group(1)!);
    }
  }
  return keys;
}

void main() {
  final zh = _bundle('assets/translations/zh.json');
  final en = _bundle('assets/translations/en.json');

  // `count_wan` / `count_k` 是按包分工的单位键：`readableCount` 用 i18nExists
  // 选分支，中文包只带「万」、其它包只带 K。两处断言都要放行这一对，
  // 否则"每个被引用的键两个包都有"会和这个设计打架。
  const bundleSpecific = <String>{'count_wan', 'count_k'};

  group('语言包', () {
    test('中英文键集一致', () {
      final onlyZh = zh.keys.toSet().difference(en.keys.toSet()).difference(bundleSpecific);
      final onlyEn = en.keys.toSet().difference(zh.keys.toSet()).difference(bundleSpecific);

      expect(onlyZh, isEmpty, reason: 'en 缺这些键，英文界面会把键名画出来');
      expect(onlyEn, isEmpty, reason: 'zh 缺这些键，中文界面会把键名画出来');
    });

    test('源码里写死的键两个包都有', () {
      final referenced = _literalKeysInLib();
      expect(referenced.length, greaterThan(100), reason: '扫描没扫到东西，正则或工作目录不对');

      final missingZh = referenced.where((key) => !zh.containsKey(key)).toSet().difference(bundleSpecific);
      final missingEn = referenced.where((key) => !en.containsKey(key)).toSet().difference(bundleSpecific);

      expect(missingZh, isEmpty, reason: 'zh.json 缺这些被引用的键');
      expect(missingEn, isEmpty, reason: 'en.json 缺这些被引用的键');
    });
  });
}

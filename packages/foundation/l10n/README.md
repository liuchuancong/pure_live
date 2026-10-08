# pure_live_l10n

> 职责:多语言与本地化资源

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_l10n.dart`;内部实现放 `lib/src/` |

## 内容

- `locale.dart` —— `LocaleTag`(`zh` / `zh_CN` / `zh-Hans-CN` 解析)、`resolveLocale`(精确 → 语言+书写系统 → 语言 → 兜底,**指定了 script 的请求绝不落到另一套书写系统**)、`isRightToLeft`、`pluralCategory` / `pluralize`(en / zh / ru 规则,缺 `other` 时返回裸计数而不是在 build 里抛)

翻译资源本身在应用侧;这里只回答"该用哪一份"和"这个数怎么说"。

## 
## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

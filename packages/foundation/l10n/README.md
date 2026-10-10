# pure_live_l10n

> 职责:多语言与本地化资源

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_l10n.dart`;内部实现放 `lib/src/` |

## 内容

翻译资源本身在应用侧;这个包只回答"该用哪一份"、"这个数怎么说"、"这一格翻译到底缺不缺"。

- `locale.dart` —— `LocaleTag`(`zh` / `zh_CN` / `zh-Hans-CN` 解析)、`resolveLocale`(精确 → 语言+书写系统 → 语言 → 兜底,**指定了 script 的请求绝不落到另一套书写系统**)、`isRightToLeft`
- `plural_math.dart` —— CLDR 复数操作数 `PluralOperands`(n / i / v / w / f / t / e)。规则是写在操作数上的,只取 `int` 会把 `1.0 kg`、`2,5`、`1e3` 全部读错
- `plural_rules.dart` —— `pluralCategoryOf` / `pluralCategory` / `pluralize`,以及约 30 种语言的真表(de / nl / sv / da / fi / el / hu / tr / he / no / fr / es / pt / it / ca / ru / uk / be / sr / hr / bs / pl / cs / sk / lt / lv / sl / ar / ro + 单形态的 zh ja ko id ms th vi km lo my ka hy)。未列出的语言落 `other`(每种翻译都必须带)。`requiredCategories` / `requiredFormNames` 反推一种语言需要几格,给校验用
- `message_format.dart` —— ICU 子集解析器:`{name}`、`{n, plural, one{…} other{…}}`、`=N`、`#`、`{x, select, …}`、`{{`/`}}` 转义。**不用 `intl` 的 MessageFormat 是因为它遇到畸形 pattern 直接抛**,一个 locales 文件里的手误就变成第一个渲染该串的界面上崩;这里返回问题清单,让目录在装载时拒收并指出是哪个 key
- `catalog.dart` —— `LocalizationCatalog`:按 owner 分命名空间(四个 app + 十几个共享包都在贡献字符串,合并成一张平表就是两个 owner 互相静默覆盖)、`registerSource` / `loadBundle`(整包替换,热重载语义)、`translate` / `translateString` / `translateText`、`coverageFor` / `orphanedKeys`(改名后留下的孤儿串)、`argumentsOf`(源码串用到哪些参数,给调用点自检)、`formatNumber` / `formatDate`。校验在装载时跑:缺 `other`、缺该语言要求的复数格、翻译丢了源串的参数,都记成 `CatalogProblem`;上报条数上限 `kCatalogProblemLimit`,超出只计数不无限长
- `relative_time.dart` —— `RelativeSpan.of`(45 秒 / 45 分 / 22 小时 / 6 天 / 30 天的分档,**月与年按日历数**,`2026-10-11` 减 `2026-09-11` 是 1 个月,而 `inDays ~/ 30` 报 0)、`RelativePhrases` 接口 + `RelativePhraseTable`(措辞由宿主给,包不内置任何语言的句子)、`RelativeTimeFormatter`(`now` 可注入,回放录制数据时同一行不会每次重绘都变)
- `translation_bundle.dart` —— `TranslationBundle` / `TranslationResolver`:平表 JSON(每语言一份文档,`{name}` 插值,缺键回吐键名)的读取与兜底链,给还没迁到 `LocalizationCatalog` 的串用

## 依赖

- `intl: ^0.20.0` —— 只做数字分隔符与月名/星期名这类**已发布的 locale 符号表**;复数规则不走 `intl`,因为它只接 `int`,且畸形 pattern 会抛。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 平台矩阵

纯 Dart,无 `dart:io`、无 Flutter 依赖,因此 web / Android / iOS / Windows / Linux / macOS / Android TV 同一份代码。

## 验证

- 分析:`dart analyze packages/foundation/l10n`(2026-10-11:`No issues found!`)
- 测试:`dart test`(`test/locale_test.dart` 覆盖 tag / 兜底 / RTL / 复数;新增的 plural 表、消息解析器与目录**未跑过测试**)

## 未验证(2026-10-11)

- **locale 符号数据没注册**:`intl` 默认只带 en。`formatNumber` / `formatDate` 在别的 locale 上会走 `on Object` 兜底(退回裸十进制与 ISO-8601),也就是说"法语千位分隔符"这类效果**需要宿主先注册符号数据**(Flutter 侧 `intl/date_symbol_data_local`、`number_symbols_data`)。这条兜底路径是被设计出来的,不是在设备上观测到的。
- 新加的 30 语言复数表是照 CLDR 誊的,没有逐语种母语者核对;`he` / `ar` / `sl` / `lv` 这类多形态语种只在代码里推演过。
- **整包零消费者**:`grep pure_live_l10n apps` 为空,四个 app 的 pubspec 都没引它。`apps/pure_live/assets/translations/{en,zh}.json` 在 `apps/pure_live/pubspec.yaml:303` 声明为 asset,但**没有任何 Dart 代码读它** —— 这套机制是先建、后有迁移,不是替换掉一条在跑的通路。
- `RelativePhraseTable` 的措辞完全由宿主提供,包内不含任何语言的句子,因此真机上"3 分钟前"的排版(尤其是 RTL 语言里计数与单位词的顺序)**未验证**。

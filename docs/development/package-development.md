# 包开发指南

## 工程组织

单仓多包用 **pub workspace**:仓库根 `pubspec.yaml` 的 `workspace:` 列出全部成员,成员写 `resolution: workspace`,全仓共用根 `pubspec.lock` 与根 `.dart_tool/package_config.json`。melos 之后可直接叠在同一份列表上,不改目录形态。

## 新建包

```powershell
# 位置参数 = 层/短名(短名可嵌套);-Description 必填,写进 README 与 pubspec 的职责一句话
tool/scaffold_package.ps1 foundation/network -Description "dio 封装:超时、重试、代理与网络错误分类"
tool/scaffold_package.ps1 features/live/repository -Flutter -Description "直播域数据与用例"
tool/scaffold_package.ps1 foundation/utils -Force -Description "..."   # 只重写骨架文件,不动 lib/src/ 与 test/
```

产出目录固定为 `packages/<层>/<短名>`(见 [../adr/0015-monorepo-layout.md](../adr/0015-monorepo-layout.md))。脚手架产出(LF + UTF-8 无 BOM,占位符未替换即报错):
`pubspec.yaml`(name = `pure_live_<短名>`、`resolution: workspace`、继承根 SDK 约束、**不预置依赖也不留注释掉的示例依赖**)+
`lib/<包名>.dart` 唯一 barrel(带 `Module/Purpose/Author/Created` 文件头)+ 层模板目录(foundation/ecosystem/… 为 `lib/src/`,features 为 `lib/src/{data,domain,presentation}`,providers 为 `lib/src/models` + `fixtures/`)+
`README.md`(职责/允许依赖/禁止依赖/公共面)+ `CHANGELOG.md` + `analysis_options.yaml`(include 仓库根 `analysis_options.package.yaml`)+ `test/` 占位,并把包按字典序登记进根 `workspace:`。

`-Description` 缺失即报错:[../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md) §3.1 禁止占位符文本,脚手架不代为编造职责。注释语言按 §4 —— 代码与配置注释一律英文,README 沿用 docs/ 的中文。

结构不得私自偏离;偏离先改模板。模板回归测试:`tool/test_scaffold_package.ps1`。

## 包级静态规则

包不各写一套 lint:统一 include 仓库根 `analysis_options.package.yaml`(纯 Dart 规则,不依赖 Flutter lints)。应用侧(组合根)规则仍写在根 `analysis_options.yaml`,其中 `legacy/**` 已排除 —— v1 代码只作协议参考,不进质量门禁。

## 日常

1. 只在包内改;跨包需求先看依赖矩阵(允许吗?)。
2. 公开 API 全部经 barrel 导出;内部实现 `lib/src/`。
3. 每包 README 的"职责一句话"失效时,先改文档再改代码。
4. analyze/test 在包目录跑(纯 Dart 包 `dart analyze` + `dart test`,Flutter 包 `flutter test`),提交前全绿。

## 晋升

目录 → 独立包:超 ~800 行或出现第二个消费方;走 ADR。包 → 拆分:同规则。

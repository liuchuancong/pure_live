# pure_live_release

> 职责:更新检查、版本与发布通道

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_release.dart`;内部实现放 `lib/src/` |

## 内容

- `version.dart` —— `AppVersion`(解析 `4.0.0+5000`、语义段优先、build 做同版本 tie-break)、`manifestBuildForArm64`(BUILD_POLICY 里 `--split-per-abi` 给 arm64 `versionCode` +2000 那条坑,写成函数而不是注释)、`decideUpdate`(none / available / forced)

低于 `minimumSupported` 一律 forced,即使 feed 里没有更新的 build —— 继续用下去是对着已经不满足的协议取流。

## 
## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

# pure_live_plugin_host

> 职责:Plugin install pipeline: bundle parsing, manifest validation, on-disk store and per-plugin state

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_plugin_host.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

## 未验证(2026-10-10 复核)

- **零消费者**:整条插件栈仍悬空(台账 §2bis 第 1 组),所以 `..` 那条删除路径是**推演出来的**,
  不是观测到的事故 —— 它值得修,但记清楚来源。
- 新加的 5 个测试跑在临时目录上;真机(Android 的外部存储 / Windows 的 AppData)路径权限差异**未验证**。
- `install` 的三文件写(staging → 目标)仍是**非原子**的:崩溃在两步之间会留下 `.staging` 残骸,
  `list()` 靠「manifest/state 缺一个就当没装」兜住,但没人清理那个残骸目录。

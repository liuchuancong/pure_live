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

## 行为契约

| 项 | 规则 |
|---|---|
| 目录 | `plugins/<id>/manifest.json + plugin.js(或 content.txt) + state.json`。三文件分开:半个坏脚本不能把声明一起带走,启用位是用户数据。 |
| id → 路径 | 只有一处做 sanitise(`_directoryFor`):非 `[A-Za-z0-9._-]` 换 `_`,连续点折叠,首尾点换 `_`,再过一次"仍在 root 内"。id `..` 曾经直接指到 `plugins/` 的**上一层**,而 `uninstall` 是递归删除。 |
| 安装 | 校验(交 plugin_api 的 validator,不在这里重判)→ 写满 staging → 删旧目录 → rename。启用位从旧 state 带过来:更新版本不该顺手关掉一个源。 |
| `.staging` 残骸 | `list()` 跳过它。崩溃发生在最后一次写之后、rename 之前时,残骸是**内容完整**的目录,读它就等于把同一个插件列两遍,第二遍挂在一个没有任何 manifest 声称过的 id 上(那个幻影还能被启用、写状态、卸载)。下一次同 id 安装会清掉它。 |
| 撞名 | 两个不同 id 可能被 sanitise 成同一个目录(`com.a$b` 与 `com.a_b`、`com.a..b` 与 `com.a_b`)。装第二个时直接拒,理由是目录里已有别人的 manifest —— 静默覆盖会留下一个声称第三个 id 的插件。 |
| 读取上限 | `readSource` / `readContent` 带 `maxBytes`(默认 4 MiB),超了抛具名 `PluginTooLargeException`;文件不存在是 `PluginInstallException`,不是 `FileNotFoundError`。 |

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | ✅ | `dart:io` 文件与目录,无插件、无 Flutter。 |
| Web | ❌ | 本包 `lib/` 直接 import `dart:io`(staging 目录与 rename),浏览器沙箱里没有这个原语。真要支持 Web,得换一个 KV 而不是加条件导入。 |

## 验证

- 分析:`dart analyze packages/ecosystem/plugin_host`(0 issue)
- 测试:`dart test`(11 例 = 路径与字节上限 5 + 列表/撞名/升级 6,跑在临时目录)

## 未验证(2026-10-10 复核)

- **零消费者**:整条插件栈仍悬空(台账 §2bis 第 1 组),所以 `..` 那条删除路径是**推演出来的**,
  不是观测到的事故 —— 它值得修,但记清楚来源。
- 测试跑在临时目录上;真机(Android 的外部存储 / Windows 的 AppData)路径权限差异**未验证**,
  `rename` 跨卷失败的情况也没验过。
- `.staging` 残骸现在**不会被列出来**,但也没有后台清理:它占着磁盘直到同 id 再装一次。
  要不要在启动时扫一遍并删除,是一次需要产品判断的清理动作,不是本包的默认。

# pure_live_js_runtime

> 职责:The JS plugin host: fjs sandbox implementing the plugin_api sandbox and runtime contracts

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_js_runtime.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | 需要 Flutter 宿主 | `fjs` 是 Rust + QuickJS 的 FFI 插件(`flutter_rust_bridge`),五个平台都有 ffiPlugin 产物;所以本包不是纯 Dart 包,`dart test` 跑不了它,只能 `flutter test`。 |
| Web | ❌ | fjs 的 `plugin.platforms` 里没有 web 条目,FFI 在浏览器里也没有对应物。 |

## 未验证

- **本包一条测试都没有**(`test/` 里只有 .gitkeep):沙箱执行、`dispose()` 是否真的释放引擎、超时打断,QuickJS 实际分配与回收没有观测过(台账 §4 的 DoD 里 paired resource release 那条,这里只做到了代码面)。
- ffiPlugin 的 Android / Windows 产物是否随构建带上(BUILD_POLICY §3 的 native 预取顺序)没有验过。
- 沙箱逃逸面:`SandboxPolicy` 允许的全局集合在真实 fjs 里是否真的被限制,没有对照测试。
## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

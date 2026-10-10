# pure_live_js_runtime

> 职责:The JS plugin host: fjs sandbox implementing the plugin_api sandbox and runtime contracts

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_js_runtime.dart`;内部实现放 `lib/src/` |

## 结构

- `lib/src/fjs_sandbox.dart` —— 一插件一引擎：`start` / `evaluate` / `evaluateModuleSource` / `dispatch` /
  `describeRegistrations` / `dispose`，加 host bridge 的 api 派发
- `lib/src/js_plugin_runtime.dart` —— 一个 JS 插件的宿主生命周期与两个能力适配器（live/browse、search）
- `lib/src/js_prelude.dart` —— 注入沙箱的 `PureLive` 宿主前置（JS 源码字符串）

## 行为契约

- **沙箱由宿主创建**：插件不能选自己的隔离级别，也看不到 `FjsJsSandbox` 这个类型。引擎只开 console 与
  timers，**没有内置 fetch** —— 请求必须走 host 的 `PluginNetwork`，否则就绕过了权限天花板，而那正是沙箱存在的理由。
- `start()` 是**单飞**且**失败即关引擎**：并发 `start()` 以前都过 `_engine != null` 那道检查（await 之间），
  于是建出两个原生引擎而没人持有第二个；`init` / 资源上限 / 前置求值任一步抛错时，已创建的引擎以前会留在
  那里而 `_engine` 仍为 null —— `dispose()` 无手可关，调用方也拿不到那个泄漏。
- 进程级 `LibFjs.init()` 同样单飞，失败**不记入缓存**（下一个插件还能再试）。
- **每次求值都在同一道门上**：closed 检查、`policy.limits.maxConcurrentScripts` 并发额度、`finally` 释放。
  模块加载(`evaluateModuleSource`)以前绕过这道门直调引擎 —— 于是一个顶层代码挂死的 ES module 会**永远等**，
  policy 承诺的超时对"加载"这一步根本不生效，而加载正是跑不可信代码的地方。现在超时与并发额度都覆盖它。
- `dispose()` 先给在飞求值一个宽限期（等于该求值自己的超时预算）再关引擎：在脚本运行中关引擎，那条调用会以
  原生层随机选择的方式失败，拿着 future 的调用方收到的是崩溃而不是答案；宽限期到点就不再等。
- 输出体积：`maxOutputBytes` 之外，`http` 的响应体**在解码前**按同一额度拒 —— 先 `utf8.decode` 一个 200 MB 体
  再报 "output too large"，就是从那道本意挡住它的门走进来的 OOM。
- **扩展 api 的 `null` 是"我不认这个 api"**：`extendedApiHandler` 返回 null 以前会被当成一次成功但答了空的调用，
  脚本无从分辨；现在它转成具名 `unknown host api` 错误。providers/music 的 crypto/zlib 桥正是靠这个约定。
- 并发额度耗尽的消息是**真插值**（`${policy.limits.maxConcurrentScripts}`）；以前写成了 `\${...}`，
  报出来的诊断里那个数字永远是字面量。
- 脚本侧错误保持短（不带 host 栈），因为那段文字会进插件可见的 error 文本。
- 一个能力方法**没人实现**用结构化标记回报（prelude 返回 `{__noRegistration__: "live.categories"}`，
  Dart 侧抛 `NoRegistration`）。以前 host 是拿异常 message 的**措辞**做匹配的（`contains('no registration implements')`），
  文字一改，可选方法就变成硬失败。异常类型而不是文案才是可依赖的判据。
- 插件回答的形状一律宽松读：描述自己不是 list / 某行不是 map / `capabilityNames` 不是数组 —— 都是坏插件而不是
  host 崩溃；**一行坏不丢整页**（`_asObjectMap(row)!` 以前会抛，整页结果消失，用户看到的是"没有结果"而不是
  "部分结果"）。票据读不出 → 带 group.method 的具名失败。
- `registeredGroups` 返回不可变快照；以前给的是活 set，任何调用方都能往里加一个 manifest 没声明过的组，
  或者把 runtime 自己的状态清空。
- manifest 是天花板：`enable()` 把脚本自报的组与 manifest 声明的组取交集，多报的在这里被砍。
- 加载失败回收：`load()` 现在把 `_manifest` / `_bridge` / `_groups` 一起清掉，失败不再留下一个"没启动但已认领
  身份与 host 句柄"的运行时。

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | 需要 Flutter 宿主 | `fjs` 是 Rust + QuickJS 的 FFI 插件(`flutter_rust_bridge`),五个平台都有 ffiPlugin 产物;所以本包不是纯 Dart 包,`dart test` 跑不了它,只能 `flutter test`。 |
| Web | ❌ | fjs 的 `plugin.platforms` 里没有 web 条目,FFI 在浏览器里也没有对应物。 |

## 验证

- `dart analyze packages/ecosystem/js_runtime` → No issues found；`dart run tool/check_architecture.dart --strict` → 0 错。
- **没有执行过任何一条**：`fjs` 是 Flutter FFI 插件，`dart run` / `dart test` 起不了它的原生库，
  要跑就得进 `flutter test`（台账 §4 的包级门在此失效，见下）。所以上面每条契约的现状是**代码面 + 推演**，
  不是观测。

## 未验证

- **本包一条测试都没有**(`test/` 里只有 .gitkeep):沙箱执行、`dispose()` 是否真的释放引擎、超时打断,QuickJS 实际分配与回收没有观测过(台账 §4 的 DoD 里 paired resource release 那条,这里只做到了代码面)。
- 本轮新增的释放与预算路径同样没跑过:`start()` 失败时 `engine.close()`、`dispose()` 的在飞宽限、
  模块加载的超时、`http` 体的解码前上限、并发额度消息。**它们都是"会让原生层承担后果"的分支,最需要真机的一批。**
- ffiPlugin 的 Android / Windows 产物是否随构建带上(BUILD_POLICY §3 的 native 预取顺序)没有验过。
- 沙箱逃逸面:`SandboxPolicy` 允许的全局集合在真实 fjs 里是否真的被限制,没有对照测试。
- `NoRegistration` 这条新契约要求 prelude 与 Dart 两侧同步:**老插件脚本不受影响**(标记只由 prelude 自己产生),
  但任何绕过 prelude 直接抛 `no registration implements …` 文本的第三方前置都不再被识别为"没实现" ——
  这条要靠一个真插件来验。

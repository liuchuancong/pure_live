# pure_live_extension

> 职责:扩展统一入口:ExtensionGateway、Runtime 选择与生命周期、Source 契约与 ExtensionContext 注入边界

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation + 共享模型伞包 `pure_live_platform`;并按 [ADR 0019](../../../docs/adr/0019-gateway-service-edges.md) 定向依赖 `pure_live_permission` 与 `pure_live_task`(只用于装配 `ExtensionContext`) |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);除 ADR 0019 之外禁止同层互依 |
| 公共面 | 只有 `lib/pure_live_extension.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/extension.dart` —— `Extension`(扩展实现方)与 `ExtensionHandle`(平台看到的扩展)
- `lib/src/runtime.dart` —— `ExtensionRuntime` / `RuntimeInstance` / `RuntimeRegistry`
- `lib/src/source.dart` —— `Source` 契约
- `lib/src/context.dart` —— `ExtensionContext` 注入边界 + `ExtensionCache` / `ExtensionStorage` / `DiagnosticTracer` 与其内存实现
- `lib/src/gateway.dart` —— `ExtensionGateway` 契约与 `ExtensionGatewayException`
- `lib/src/managed_extension_gateway.dart` —— 生命周期状态机与运行时选择

## 生命周期(platform-infrastructure.md §3)

| 动作 | 转移 | 抛出 |
|---|---|---|
| `register` | → `identified`;无匹配 Runtime 或 API 版本不合 → `incompatible` | `extension.incompatible`、`extension.already_registered` |
| `load` | `identified`/`error` → `loading` → `validating` → `ready` | `extension.load_failed`、`extension.disabled`、`extension.state_invalid`、`extension.not_found` |
| `start` | `ready` → `running` | `extension.state_invalid`、`extension.load_failed` |
| `stop` | `running` → `stopping` → `ready` | `extension.state_invalid` |
| `disable` | 任意存活态 → `disabled`(停 + dispose,**保留记录**) | `extension.not_found` |
| `unload` | 同上但**删除记录**,须重新 register 才能回来 | `extension.not_found` |

`ERROR → RETRY` 是文档里的失败分支,所以 `load` 允许从 `error` 重来;重试前会先释放失败留下的实例。
每次状态变化同时产生一个 `ExtensionStatus`(stream)与一条 `extension.<state>` 诊断事件,二者同源。

## 相对契约示例的两处形状差异(以本文与实现为准)

`platform-contracts.md` §7 的示例写 `String get id; String get version;` 与 `load(descriptor)`。实现改为:

1. `ExtensionRuntime.descriptor`(`RuntimeDescriptor`)—— 选择运行时本来就要用 `protocols` 与 `supportedTypes`,
   两个裸 getter 会把这些信息重复一遍。
2. `load(descriptor, context)` —— §19 规定扩展只能经 `ExtensionContext` 取得平台服务,而**构造扩展实例的正是
   运行时**,所以 context 必须在 load 时交给它;示例里没有它。

`changes` stream 同理:§6 只列了 `find/getAll`,而生命周期迁移必须能被发现(§17 要求 `extension.load/error`
可观测),否则调用方只能轮询。

## 已知边界

- `supportedApiVersions` 默认空 = 不做版本检查;插件可声明 `platformApiVersion` 时必须由组合根显式给值。
- 本包**不**装 JS/Python:PluginRuntime、TvBoxRuntime 等是 `ExtensionRuntime` 的实现,分别落在
  `ecosystem/plugin_api`(W2 接口)与 `ecosystem/external_tvbox`(W7)。
- `ExtensionCache` / `ExtensionStorage` 的默认实现是内存的;换成 Drift/KV 底座由接线层注入,扩展侧 API 不变
  (§19 "实现可换而 Extension API 不变")。
- `NetworkTransport` 的 dio 适配尚未落地,所以真实站点路径未验证。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
